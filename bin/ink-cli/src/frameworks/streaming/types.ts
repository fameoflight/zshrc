/**
 * Generic streaming framework types
 */

export interface StreamChunk<T = string> {
	content?: T;
	error?: string;
	isComplete?: boolean;
	progress?: number; // 0-100 for progress indication
	metadata?: Record<string, any>;
}

export interface AsyncStreamOptions<T = string> {
	batchInterval?: number;
	onProgress?: (progress: number) => void;
	onComplete?: (result: T) => void;
	onError?: (error: string) => void;
	onChunk?: (chunk: StreamChunk<T>) => void;
}

export interface AsyncStreamResult<T = string> {
	currentData: T;
	isStreaming: boolean;
	progress: number;
	error: string | null;
	handleChunk: (chunk: StreamChunk<T>) => void;
	reset: () => void;
	setIsStreaming: (value: boolean) => void;
	cancel: () => void;
}

export interface StreamStatus {
	text: string;
	color: string;
	icon: string;
	pulse?: boolean;
}

export interface StreamState<T = string> {
	isStreaming: boolean;
	isCancelling: boolean;
	isInitialized: boolean;
	error: string | null;
	currentData: T;
	progress: number;
}