import {useState, useCallback} from 'react';
import {ChatMessage, ChatRole} from '../types/chat.js';

export interface UseChatMessagesOptions {
	systemPrompt?: string;
	initialMessages?: ChatMessage[];
}

export interface UseChatMessagesResult {
	messages: ChatMessage[];
	messageCount: number;
	addMessage: (role: ChatRole, content: string) => void;
	clearMessages: () => void;
	getMessagesWithSystem: () => ChatMessage[];
}

/**
 * useChatMessages - Generic message management
 *
 * Manages a list of chat messages with support for system prompts.
 * Works for any chat/conversation interface.
 *
 * @example
 * const { messages, addMessage, clearMessages } = useChatMessages({
 *   systemPrompt: 'You are a helpful assistant'
 * });
 */
export function useChatMessages(
	options: UseChatMessagesOptions = {},
): UseChatMessagesResult {
	const {systemPrompt, initialMessages = []} = options;

	const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);

	// Add a message to the conversation
	const addMessage = useCallback(
		(role: ChatRole, content: string) => {
			setMessages(prev => [...prev, {role, content}]);
		},
		[],
	);

	// Clear all messages
	const clearMessages = useCallback(() => {
		setMessages([]);
	}, []);

	// Get messages with system prompt prepended (for sending to LLM)
	const getMessagesWithSystem = useCallback((): ChatMessage[] => {
		if (!systemPrompt) {
			return messages;
		}

		// Check if system prompt is already first message
		const hasSystemPrompt =
			messages.length > 0 && messages[0]?.role === 'system';

		if (hasSystemPrompt) {
			return messages;
		}

		// Prepend system prompt
		return [{role: 'system', content: systemPrompt}, ...messages];
	}, [messages, systemPrompt]);

	return {
		messages,
		messageCount: messages.length,
		addMessage,
		clearMessages,
		getMessagesWithSystem,
	};
}
