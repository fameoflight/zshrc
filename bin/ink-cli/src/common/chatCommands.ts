import {ChatMessage, ChatRole} from './types/chat.js';

export interface ChatContext {
	messages: ChatMessage[];
	messageCount: number;
	clearMessages: () => void;
	addMessage: (role: ChatRole, content: string) => void;
	currentResponse?: string;
	isStreaming: boolean;
	setError: (error: string | null) => void;
}

export interface ChatCommand {
	label: string;
	value: string;
	description: string;
	execute: (context: ChatContext) => void | Promise<void>;
}

export const CHAT_COMMANDS: ChatCommand[] = [
	{
		label: '/clear (reset, new)',
		value: 'clear',
		description: 'Clear conversation history and free up context',
		execute: (context: ChatContext) => {
			context.clearMessages();
			context.setError(null);
		},
	},
	{
		label: '/tokens',
		value: 'tokens',
		description: 'Total number of tokens till now',
		execute: (context: ChatContext) => {
			// Simple token estimation (rough approximation: ~4 characters per token)
			const totalChars = context.messages.reduce(
				(sum, msg) => sum + msg.content.length,
				0,
			);
			const estimatedTokens = Math.ceil(totalChars / 4);

			context.addMessage(
				'system',
				`📊 Token Usage:\n• Messages: ${context.messageCount}\n• Characters: ${totalChars}\n• Estimated Tokens: ${estimatedTokens}\n\nNote: This is a rough approximation. Actual token count may vary based on the model's tokenizer.`,
			);
		},
	},
];

export const getCommandByValue = (value: string): ChatCommand | undefined => {
	return CHAT_COMMANDS.find(cmd => cmd.value === value);
};

export const getCommandByLabel = (label: string): ChatCommand | undefined => {
	return CHAT_COMMANDS.find(cmd => cmd.label === label);
};