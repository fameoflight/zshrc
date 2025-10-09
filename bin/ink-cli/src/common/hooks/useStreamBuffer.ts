import {useState, useCallback, useRef, useEffect} from 'react';
import {StreamChunk} from '../llm/index.js';

export interface UseStreamBufferOptions {
	batchInterval?: number;
	onComplete?: (content: string) => void;
	onError?: (error: string) => void;
}

export interface UseStreamBufferResult {
	currentResponse: string;
	isStreaming: boolean;
	handleChunk: (chunk: StreamChunk) => void;
	resetBuffer: () => void;
	setIsStreaming: (value: boolean) => void;
}

/**
 * useStreamBuffer - Generic streaming buffer with batching
 *
 * Batches streaming updates to reduce UI flicker and improve performance.
 * Works for any streaming data: LLM responses, logs, downloads, etc.
 *
 * @example
 * const { currentResponse, handleChunk, isStreaming } = useStreamBuffer({
 *   batchInterval: 5,
 *   onComplete: (content) => addMessage('assistant', content)
 * });
 */
export function useStreamBuffer(
	options: UseStreamBufferOptions = {},
): UseStreamBufferResult {
	const {batchInterval = 5, onComplete, onError} = options;

	const [currentResponse, setCurrentResponse] = useState('');
	const [isStreaming, setIsStreaming] = useState(false);

	const streamBufferRef = useRef('');
	const streamTimerRef = useRef<NodeJS.Timeout | null>(null);

	// Cleanup timers on unmount
	useEffect(() => {
		return () => {
			if (streamTimerRef.current) {
				clearTimeout(streamTimerRef.current);
			}
		};
	}, []);

	// Flush buffer to state
	const flushBuffer = useCallback(() => {
		if (streamBufferRef.current) {
			const content = streamBufferRef.current;
			setCurrentResponse(prev => prev + content);
			streamBufferRef.current = '';
		}
	}, []);

	// Handle incoming stream chunks
	const handleChunk = useCallback(
		(chunk: StreamChunk) => {
			// Handle errors
			if (chunk.error) {
				if (streamTimerRef.current) {
					clearTimeout(streamTimerRef.current);
					streamTimerRef.current = null;
				}
				flushBuffer();
				setIsStreaming(false);
				if (onError) {
					onError(chunk.error);
				}
				return;
			}

			// Accumulate content in buffer
			if (chunk.content) {
				streamBufferRef.current += chunk.content;

				// Clear existing timer
				if (streamTimerRef.current) {
					clearTimeout(streamTimerRef.current);
				}

				// Batch updates - flush after interval
				streamTimerRef.current = setTimeout(() => {
					flushBuffer();
					streamTimerRef.current = null;
				}, batchInterval);
			}

			// Handle completion
			if (chunk.isComplete) {
				// Clear timer and flush any remaining content
				if (streamTimerRef.current) {
					clearTimeout(streamTimerRef.current);
					streamTimerRef.current = null;
				}
				flushBuffer();

				// Call onComplete with final content
				setTimeout(() => {
					setCurrentResponse(prev => {
						if (prev && onComplete) {
							onComplete(prev);
						}
						setIsStreaming(false);
						return ''; // Clear response
					});
				}, 20);
			}
		},
		[batchInterval, flushBuffer, onComplete, onError],
	);

	// Reset buffer and state
	const resetBuffer = useCallback(() => {
		streamBufferRef.current = '';
		setCurrentResponse('');
		if (streamTimerRef.current) {
			clearTimeout(streamTimerRef.current);
			streamTimerRef.current = null;
		}
	}, []);

	return {
		currentResponse,
		isStreaming,
		handleChunk,
		resetBuffer,
		setIsStreaming,
	};
}
