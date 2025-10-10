import {useState, useCallback, useRef, useEffect} from 'react';
import {StreamChunk, AsyncStreamOptions, AsyncStreamResult} from './types.js';

/**
 * useAsyncStream - Generic async streaming framework
 *
 * Handles any streaming operation with batching, cancellation, and progress tracking.
 * Works for file operations, API calls, log monitoring, LLM responses, etc.
 *
 * @example
 * const { currentData, isStreaming, handleChunk, cancel } = useAsyncStream({
 *   batchInterval: 2,
 *   onComplete: (result) => console.log('Complete:', result),
 *   onError: (error) => console.error('Error:', error)
 * });
 */
export function useAsyncStream<T = string>(
	options: AsyncStreamOptions<T> = {},
): AsyncStreamResult<T> {
	const {batchInterval = 2, onProgress, onComplete, onError, onChunk} = options;

	const [currentData, setCurrentData] = useState<T>('' as T);
	const [isStreaming, setIsStreaming] = useState(false);
	const [_isCancelling, setIsCancelling] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [progress, setProgress] = useState(0);

	const streamBufferRef = useRef<T | null>(null);
	const streamTimerRef = useRef<NodeJS.Timeout | null>(null);
	const abortControllerRef = useRef<AbortController | null>(null);

	// Cleanup timers and abort controllers on unmount
	useEffect(() => {
		return () => {
			if (streamTimerRef.current) {
				clearTimeout(streamTimerRef.current);
			}
			if (abortControllerRef.current) {
				abortControllerRef.current.abort();
			}
		};
	}, []);

	// Flush buffer to state
	const flushBuffer = useCallback(() => {
		if (streamBufferRef.current !== null) {
			const data = streamBufferRef.current;
			setCurrentData(prev => {
				// For strings, concatenate. For arrays/objects, replace.
				if (typeof prev === 'string' && typeof data === 'string') {
					return (prev + data) as T;
				}
				return data;
			});
			streamBufferRef.current = null;
		}
	}, []);

	// Handle incoming stream chunks
	const handleChunk = useCallback(
		(chunk: StreamChunk<T>) => {
			// Notify chunk handler
			if (onChunk) {
				onChunk(chunk);
			}

			// Handle errors
			if (chunk.error) {
				if (streamTimerRef.current) {
					clearTimeout(streamTimerRef.current);
					streamTimerRef.current = null;
				}
				flushBuffer();
				setIsStreaming(false);
				setError(chunk.error);
				if (onError) {
					onError(chunk.error);
				}
				return;
			}

			// Update progress
			if (chunk.progress !== undefined) {
				setProgress(chunk.progress);
				if (onProgress) {
					onProgress(chunk.progress);
				}
			}

			// Accumulate content in buffer
			if (chunk.content !== undefined) {
				streamBufferRef.current = chunk.content;

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

				// Call onComplete with final result
				setTimeout(() => {
					setIsStreaming(false);
					setIsCancelling(false);
					if (onComplete) {
						onComplete(currentData);
					}
				}, 20);
			}
		},
		[
			batchInterval,
			flushBuffer,
			onComplete,
			onError,
			onProgress,
			onChunk,
			currentData,
		],
	);

	// Reset all state
	const reset = useCallback(() => {
		streamBufferRef.current = null;
		setCurrentData('' as T);
		setIsStreaming(false);
		setIsCancelling(false);
		setError(null);
		setProgress(0);
		if (streamTimerRef.current) {
			clearTimeout(streamTimerRef.current);
			streamTimerRef.current = null;
		}
		if (abortControllerRef.current) {
			abortControllerRef.current.abort();
			abortControllerRef.current = null;
		}
	}, []);

	// Cancel current streaming operation
	const cancel = useCallback(() => {
		if (isStreaming && abortControllerRef.current) {
			setIsCancelling(true);
			abortControllerRef.current.abort();

			// Add partial result indication
			if (currentData && typeof currentData === 'string') {
				const partialResult = (currentData +
					'\n\n*(Operation cancelled)*') as T;
				setCurrentData(partialResult);
			}

			setIsStreaming(false);
			setIsCancelling(false);
		}
	}, [isStreaming, currentData]);

	// Set streaming state (for external control)
	const setIsStreamingState = useCallback((streaming: boolean) => {
		setIsStreaming(streaming);
		if (!streaming) {
			setIsCancelling(false);
		}
	}, []);

	return {
		currentData,
		isStreaming,
		progress,
		error,
		handleChunk,
		reset,
		setIsStreaming: setIsStreamingState,
		cancel,
	};
}
