/**
 * Streaming Response Manager
 *
 * Handles real-time streaming of responses from LLMs and other sources
 * with support for progress tracking, cancellation, and error handling.
 */

export interface StreamChunk {
	content?: string;
	isComplete?: boolean;
	error?: string;
	metadata?: Record<string, any>;
	progress?: number;
	total?: number;
}

export interface StreamOptions {
	onChunk?: (chunk: StreamChunk) => void;
	onComplete?: (finalContent: string) => void;
	onError?: (error: string) => void;
	onProgress?: (progress: number, total: number) => void;
	batchInterval?: number; // milliseconds between chunk processing
	maxBufferLength?: number; // maximum buffer length before forcing processing
}

export interface ActiveStream {
	id: string;
	source: string;
	startTime: Date;
	options: StreamOptions;
	buffer: string[];
	isActive: boolean;
	abortController?: AbortController;
}

/**
 * Manages multiple concurrent streams with unified interface
 */
export class StreamingManager {
	private activeStreams: Map<string, ActiveStream> = new Map();
	private batchTimers: Map<string, NodeJS.Timeout> = new Map();

	/**
	 * Start a new stream
	 */
	startStream(
		streamId: string,
		source: string,
		options: StreamOptions = {}
	): ActiveStream {
		const stream: ActiveStream = {
			id: streamId,
			source,
			startTime: new Date(),
			options: {
				batchInterval: 100, // Default 100ms batching
				maxBufferLength: 1000, // Default 1000 char buffer
				...options,
			},
			buffer: [],
			isActive: true,
			abortController: new AbortController(),
		};

		this.activeStreams.set(streamId, stream);
		return stream;
	}

	/**
	 * Add a chunk to a stream
	 */
	addChunk(streamId: string, chunk: StreamChunk): void {
		const stream = this.activeStreams.get(streamId);
		if (!stream || !stream.isActive) {
			return;
		}

		// Handle error chunks
		if (chunk.error) {
			this.handleError(streamId, chunk.error);
			return;
		}

		// Handle completion
		if (chunk.isComplete) {
			this.handleCompletion(streamId);
			return;
		}

		// Handle progress updates
		if (chunk.progress !== undefined && chunk.total !== undefined) {
			stream.options.onProgress?.(chunk.progress, chunk.total);
		}

		// Handle content chunks
		if (chunk.content) {
			stream.buffer.push(chunk.content);

			// Check if we should process the buffer
			const bufferLength = stream.buffer.join('').length;
			if (bufferLength >= (stream.options.maxBufferLength || 1000)) {
				this.processBuffer(streamId);
			} else {
				this.scheduleBatchProcessing(streamId);
			}
		}
	}

	/**
	 * Process the accumulated buffer for a stream
	 */
	processBuffer(streamId: string): void {
		const stream = this.activeStreams.get(streamId);
		if (!stream || stream.buffer.length === 0) {
			return;
		}

		const content = stream.buffer.join('');
		stream.buffer = [];

		// Call chunk handler
		stream.options.onChunk?.({
			content,
			isComplete: false,
		});

		// Clear any pending batch timer
		const timer = this.batchTimers.get(streamId);
		if (timer) {
			clearTimeout(timer);
			this.batchTimers.delete(streamId);
		}
	}

	/**
	 * Schedule batch processing for a stream
	 */
	private scheduleBatchProcessing(streamId: string): void {
		const stream = this.activeStreams.get(streamId);
		if (!stream) {
			return;
		}

		// Don't schedule if we already have a timer
		if (this.batchTimers.has(streamId)) {
			return;
		}

		const timer = setTimeout(() => {
			this.processBuffer(streamId);
		}, stream.options.batchInterval || 100);

		this.batchTimers.set(streamId, timer);
	}

	/**
	 * Handle stream completion
	 */
	private handleCompletion(streamId: string): void {
		const stream = this.activeStreams.get(streamId);
		if (!stream) {
			return;
		}

		// Process any remaining buffer content
		this.processBuffer(streamId);

		// Mark as inactive
		stream.isActive = false;

		// Call completion handler
		const finalContent = stream.buffer.join('');
		stream.options.onComplete?.(finalContent);

		// Clean up
		this.cleanupStream(streamId);
	}

	/**
	 * Handle stream errors
	 */
	private handleError(streamId: string, error: string): void {
		const stream = this.activeStreams.get(streamId);
		if (!stream) {
			return;
		}

		stream.isActive = false;
		stream.options.onError?.(error);
		this.cleanupStream(streamId);
	}

	/**
	 * Clean up a completed or failed stream
	 */
	private cleanupStream(streamId: string): void {
		const timer = this.batchTimers.get(streamId);
		if (timer) {
			clearTimeout(timer);
			this.batchTimers.delete(streamId);
		}

		// Remove stream after a short delay to allow for final processing
		setTimeout(() => {
			this.activeStreams.delete(streamId);
		}, 100);
	}

	/**
	 * Cancel a stream
	 */
	cancelStream(streamId: string): boolean {
		const stream = this.activeStreams.get(streamId);
		if (!stream || !stream.isActive) {
			return false;
		}

		stream.isActive = false;
		stream.abortController?.abort();

		// Process any remaining buffer
		this.processBuffer(streamId);

		// Clean up
		this.cleanupStream(streamId);

		return true;
	}

	/**
	 * Get an active stream
	 */
	getStream(streamId: string): ActiveStream | undefined {
		return this.activeStreams.get(streamId);
	}

	/**
	 * Get all active streams
	 */
	getActiveStreams(): ActiveStream[] {
		return Array.from(this.activeStreams.values()).filter(s => s.isActive);
	}

	/**
	 * Cancel all active streams
	 */
	cancelAllStreams(): void {
		for (const streamId of this.activeStreams.keys()) {
			this.cancelStream(streamId);
		}
	}

	/**
	 * Create a stream from an async iterable (like ReadableStream)
	 */
	async processAsyncIterable(
		streamId: string,
		source: string,
		iterable: AsyncIterable<StreamChunk>,
		options: StreamOptions = {}
	): Promise<void> {
		const stream = this.startStream(streamId, source, options);

		try {
			for await (const chunk of iterable) {
				if (!stream.isActive) {
					break;
				}

				this.addChunk(streamId, chunk);
			}
		} catch (error) {
			this.handleError(streamId, String(error));
		}
	}

	/**
	 * Create a simple text stream with a callback
	 */
	createTextStream(
		streamId: string,
		source: string,
		textGenerator: (abortSignal: AbortSignal) => AsyncGenerator<string>,
		options: StreamOptions = {}
	): void {
		const stream = this.startStream(streamId, source, options);

		const processGenerator = async () => {
			try {
				for await (const text of textGenerator(stream.abortController!.signal)) {
					if (!stream.isActive) {
						break;
					}

					this.addChunk(streamId, {content: text});
				}

				// Mark as complete
				this.addChunk(streamId, {isComplete: true});
			} catch (error) {
				this.handleError(streamId, String(error));
			}
		};

		processGenerator();
	}

	/**
	 * Get statistics about streaming
	 */
	getStats(): {
		activeStreams: number;
		totalBufferedChunks: number;
		averageStreamDuration: number;
	} {
		const activeStreams = this.getActiveStreams();
		const totalBufferedChunks = Array.from(this.activeStreams.values())
			.reduce((sum, stream) => sum + stream.buffer.length, 0);

		const now = new Date();
		const averageStreamDuration = activeStreams.length > 0
			? activeStreams.reduce((sum, stream) =>
					sum + (now.getTime() - stream.startTime.getTime()), 0) / activeStreams.length
			: 0;

		return {
			activeStreams: activeStreams.length,
			totalBufferedChunks,
			averageStreamDuration,
		};
	}
}

// Global streaming manager instance
export const streamingManager = new StreamingManager();

/**
 * Convenience functions for global streaming management
 */
export function startStream(
	streamId: string,
	source: string,
	options?: StreamOptions
): ActiveStream {
	return streamingManager.startStream(streamId, source, options);
}

export function addChunk(streamId: string, chunk: StreamChunk): void {
	streamingManager.addChunk(streamId, chunk);
}

export function cancelStream(streamId: string): boolean {
	return streamingManager.cancelStream(streamId);
}

export function cancelAllStreams(): void {
	streamingManager.cancelAllStreams();
}