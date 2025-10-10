/**
 * Chat type definitions
 *
 * Shared types for chat-related components and functionality.
 */

export interface ChatMessage {
	role: 'user' | 'assistant' | 'system';
	content: string;
}

export interface ChatStatus {
	text: string;
	color: string;
	icon?: string;
	pulse?: boolean;
}

export interface ChatState {
	isStreaming: boolean;
	isInterrupting: boolean;
	isInitialized: boolean;
	error: string | null;
	currentInput: string;
	messageCount: number;
}

export type ChatRole = ChatMessage['role'];
