import {ChatStatus, ChatState} from '../types/chat.js';

/**
 * Chat status utilities
 *
 * Helper functions to compute status and info text for chat UIs.
 */

/**
 * Compute status indicator based on chat state
 *
 * @example
 * const status = computeChatStatus({ isStreaming: true, error: null, ... });
 * // Returns: { text: 'Drizzling…', color: 'yellow', icon: '💧', pulse: true }
 */
export function computeChatStatus(state: ChatState): ChatStatus {
	const {error, isInterrupting, isStreaming, isInitialized, currentInput} =
		state;

	if (error) {
		return {text: 'Error', color: 'red', icon: '❌'};
	}

	if (isInterrupting) {
		return {text: 'Interrupting...', color: 'magenta', icon: '⏸'};
	}

	if (isStreaming) {
		return {text: 'Loading...', color: 'yellow', icon: '💧', pulse: true};
	}

	if (!isInitialized) {
		return {text: 'Initializing...', color: 'cyan', icon: '🔄', pulse: true};
	}

	if (currentInput) {
		return {text: 'Typing...', color: 'blue', icon: '✏️'};
	}

	return {text: 'Ready', color: 'green', icon: '✓'};
}

/**
 * Compute info text for bottom bar
 *
 * Shows message count if there are messages, otherwise shows provider name.
 *
 * @example
 * const info = computeInfoText(5, 'LM Studio');
 * // Returns: "5 messages"
 */
export function computeInfoText(
	messageCount: number,
	provider: string,
): string {
	if (messageCount > 0) {
		return `${messageCount} message${messageCount === 1 ? '' : 's'}`;
	}

	return provider;
}

/**
 * Get shortcuts based on chat state
 */
export function getShortcuts(isStreaming: boolean, error: boolean): string[] {
	if (error) {
		return [];
	}

	if (isStreaming) {
		return ['esc to interrupt'];
	}

	return ['Enter=send', 'Ctrl+L=clear', 'Ctrl+C=exit'];
}
