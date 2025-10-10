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
		label: '/clear',
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
		description: 'Show detailed token usage statistics',
		execute: (context: ChatContext) => {
			// Calculate token usage by role
			const userChars = context.messages
				.filter(msg => msg.role === 'user')
				.reduce((sum, msg) => sum + msg.content.length, 0);

			const assistantChars = context.messages
				.filter(msg => msg.role === 'assistant')
				.reduce((sum, msg) => sum + msg.content.length, 0);

			const systemChars = context.messages
				.filter(msg => msg.role === 'system')
				.reduce((sum, msg) => sum + msg.content.length, 0);

			const totalChars = userChars + assistantChars + systemChars;

			// Simple token estimation (rough approximation: ~4 characters per token)
			const userTokens = Math.ceil(userChars / 4);
			const assistantTokens = Math.ceil(assistantChars / 4);
			const systemTokens = Math.ceil(systemChars / 4);
			const totalTokens = Math.ceil(totalChars / 4);

			// Count messages by role
			const userMessages = context.messages.filter(
				msg => msg.role === 'user',
			).length;
			const assistantMessages = context.messages.filter(
				msg => msg.role === 'assistant',
			).length;
			const systemMessages = context.messages.filter(
				msg => msg.role === 'system',
			).length;

			context.addMessage(
				'system',
				`📊 Token Usage:\n\n📥 Input Tokens:\n• User: ${userTokens} tokens (${userMessages} messages, ${userChars} chars)\n• System: ${systemTokens} tokens (${systemMessages} messages, ${systemChars} chars)\n\n📤 Output Tokens:\n• Assistant: ${assistantTokens} tokens (${assistantMessages} messages, ${assistantChars} chars)\n\n📈 Summary:\n• Total Messages: ${context.messageCount}\n• Total Characters: ${totalChars}\n• Estimated Total Tokens: ${totalTokens}\n\nNote: This is a rough approximation (~4 chars/token). Actual token count may vary based on the model's tokenizer.`,
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
