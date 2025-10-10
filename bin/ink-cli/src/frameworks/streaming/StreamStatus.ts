import {StreamState, StreamStatus} from './types.js';

/**
 * Generic status computation for streaming operations
 */

export interface StreamStatusOptions {
	loadingText?: string;
	cancellingText?: string;
	errorText?: string;
	readyText?: string;
	initializedText?: string;
	progressText?: string;
}

export interface StreamStatusConfig {
	loading: StreamStatus;
	cancelling: StreamStatus;
	error: StreamStatus;
	ready: StreamStatus;
	initialized: StreamStatus;
	progress: StreamStatus;
}

const defaultStatusConfig: StreamStatusConfig = {
	loading: { text: 'Loading...', color: 'yellow', icon: '💧', pulse: true },
	cancelling: { text: 'Cancelling...', color: 'magenta', icon: '⏸' },
	error: { text: 'Error', color: 'red', icon: '❌' },
	ready: { text: 'Ready', color: 'green', icon: '✓' },
	initialized: { text: 'Initializing...', color: 'cyan', icon: '🔄', pulse: true },
	progress: { text: 'In Progress', color: 'blue', icon: '📊' },
};

/**
 * Compute status indicator based on stream state
 */
export function computeStreamStatus<T = string>(
	state: StreamState<T>,
	options: StreamStatusOptions = {},
	config: StreamStatusConfig = defaultStatusConfig,
): StreamStatus {
	const {
		isStreaming,
		isCancelling,
		isInitialized,
		error,
		progress,
		currentData,
	} = state;

	if (error) {
		return { ...config.error, text: options.errorText || config.error.text };
	}

	if (isCancelling) {
		return { ...config.cancelling, text: options.cancellingText || config.cancelling.text };
	}

	if (isStreaming) {
		if (progress > 0 && progress < 100) {
			return { ...config.progress, text: `${options.progressText || config.progress.text} (${Math.round(progress)}%)` };
		}
		return { ...config.loading, text: options.loadingText || config.loading.text };
	}

	if (!isInitialized) {
		return { ...config.initialized, text: options.initializedText || config.initialized.text };
	}

	if (currentData) {
		return { ...config.ready, text: options.readyText || 'Completed' };
	}

	return config.ready;
}

/**
 * Get shortcuts based on stream state
 */
export function getStreamShortcuts(
	isStreaming: boolean,
	error: boolean,
	customShortcuts?: string[],
): string[] {
	if (error) {
		return [];
	}

	if (isStreaming) {
		return ['esc to cancel'];
	}

	return customShortcuts || [];
}

/**
 * Get info text based on stream state
 */
export function getStreamInfo<T = string>(
	state: StreamState<T>,
	itemCount?: number,
	dataType?: string,
): string {
	const { isStreaming, progress, currentData, error } = state;

	if (error) {
		return 'Error occurred';
	}

	if (isStreaming) {
		if (progress > 0) {
			return `${Math.round(progress)}% complete`;
		}
		return 'Processing...';
	}

	if (itemCount && itemCount > 0) {
		return `${itemCount} ${dataType || 'items'}`;
	}

	if (currentData) {
		return 'Operation complete';
	}

	return 'Ready';
}