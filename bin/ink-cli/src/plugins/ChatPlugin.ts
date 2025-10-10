import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, Plugin, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {MessageDisplay, WelcomeMessage} from '../components/interactive/MessageDisplay.js';
import {CommandInput} from '../components/interactive/CommandInput.js';

/**
 * Chat Plugin - Provides chat-like behavior for interactive commands
 *
 * This plugin adds conversational capabilities to any interactive command,
 * handling message display, input processing, and chat-specific commands.
 */
export class ChatPlugin implements Plugin {
	name = 'chat';

	private command?: BaseInteractiveCommand<any>;
	private conversationHistory: string[] = [];
	private maxHistoryLength = 100;

	async initialize(command: BaseInteractiveCommand<any>): Promise<void> {
		this.command = command;
	}

	async cleanup(): Promise<void> {
		// Cleanup any resources
	}

	async onMessage(message: string): Promise<boolean> {
		if (!this.command) return false;

		// Handle chat-specific commands
		if (message.startsWith('/')) {
			const commandName = message.substring(1).toLowerCase();

			switch (commandName) {
				case 'history':
					await this.showHistory();
					return true;

				case 'export':
					await this.exportConversation();
					return true;

				case 'stats':
					await this.showStats();
					return true;

				default:
					return false; // Let other handlers process unknown commands
			}
		}

		return false; // Not a chat-specific command
	}

	onStateChange(state: BaseInteractiveState): void {
		// Track conversation history
		if (state.messages && state.messages.length > 0) {
			const lastMessage = state.messages[state.messages.length - 1];
			const messageKey = `${lastMessage.role}:${lastMessage.content.substring(0, 50)}`;

			if (!this.conversationHistory.includes(messageKey)) {
				this.conversationHistory.push(messageKey);

				// Limit history length
				if (this.conversationHistory.length > this.maxHistoryLength) {
					this.conversationHistory = this.conversationHistory.slice(-this.maxHistoryLength);
				}
			}
		}
	}

	renderComponents(): ReactElement[] {
		if (!this.command) return [];

		const state = this.command.getState();

		return [
			// Message display component
			React.createElement(MessageDisplay, {
				messages: state.messages,
				currentResponse: state.currentResponse,
				isStreaming: state.isStreaming,
				showTimestamps: false,
				maxMessages: 50,
				autoScroll: true,
			}),

			// Welcome message (shown when appropriate)
			state.showWelcome && state.messages.length === 0 &&
			React.createElement(WelcomeMessage, {
				title: '💬 Chat Started',
				description: 'Start typing your message and press Enter to send.',
				tips: [
					'Type /help to see available commands',
					'Type /clear to clear conversation history',
					'Type /history to see conversation history',
					'Type /export to export this conversation',
				],
				shortcuts: {
					'Ctrl + L': 'Clear history',
					'Escape': 'Cancel response',
					'Tab': 'Autocomplete commands',
				},
				color: 'green',
			}),

			// Command input
			React.createElement(CommandInput, {
				value: state.currentInput,
				onChange: (value) => {
					this.command!.updateState({currentInput: value});
				},
				onSubmit: async (value) => {
					await this.command!.processInput(value);
					this.command!.updateState({currentInput: ''});
				},
				onCancel: () => {
					if (state.isStreaming && this.command) {
						// Handle stream cancellation
						this.command.updateState({isStreaming: false, currentResponse: ''});
					}
				},
				disabled: state.isStreaming,
				shortcuts: {
					l: () => {
						this.command!.clearMessages();
					},
					h: () => {
						this.command!.processInput('/help');
					},
					c: () => {
						this.command!.clearMessages();
					},
				},
				history: this.getSimpleHistory(),
				multiline: false,
			}),
		];
	}

	/**
	 * Show conversation history
	 */
	private async showHistory(): Promise<void> {
		if (!this.command) return;

		const state = this.command.getState();
		const messages = state.messages;

		if (messages.length === 0) {
			await this.command.addMessage('system', 'No conversation history yet.');
			return;
		}

		const historyText = messages
			.slice(-10) // Show last 10 messages
			.map((msg, index) => {
				const icon = msg.role === 'user' ? '👤' : msg.role === 'assistant' ? '🤖' : '⚙️';
				const preview = msg.content.length > 100
					? msg.content.substring(0, 100) + '...'
					: msg.content;
				return `${icon} ${msg.role}: ${preview}`;
			})
			.join('\n');

		await this.command.addMessage(
			'system',
			`📜 Recent Conversation History:\n\n${historyText}\n\nShowing last ${Math.min(10, messages.length)} messages.`
		);
	}

	/**
	 * Export conversation to text format
	 */
	private async exportConversation(): Promise<void> {
		if (!this.command) return;

		const state = this.command.getState();
		const messages = state.messages;

		if (messages.length === 0) {
			await this.command.addMessage('system', 'No conversation to export.');
			return;
		}

		const exportText = messages
			.map(msg => `[${msg.role.toUpperCase()}] ${msg.content}`)
			.join('\n\n');

		await this.command.addMessage(
			'system',
			`📄 Conversation Export:\n\n${exportText}\n\n--- End of export ---`
		);
	}

	/**
	 * Show conversation statistics
	 */
	private async showStats(): Promise<void> {
		if (!this.command) return;

		const state = this.command.getState();
		const messages = state.messages;

		const userMessages = messages.filter(m => m.role === 'user').length;
		const assistantMessages = messages.filter(m => m.role === 'assistant').length;
		const systemMessages = messages.filter(m => m.role === 'system').length;
		const toolMessages = messages.filter(m => m.role === 'tool').length;

		const totalChars = messages.reduce((sum, m) => sum + m.content.length, 0);
		const userChars = messages.filter(m => m.role === 'user').reduce((sum, m) => sum + m.content.length, 0);
		const assistantChars = messages.filter(m => m.role === 'assistant').reduce((sum, m) => sum + m.content.length, 0);

		const statsText = `
📊 Conversation Statistics:

📥 Input:
• User messages: ${userMessages}
• User characters: ${userChars}
• Average user message length: ${userMessages > 0 ? Math.round(userChars / userMessages) : 0} chars

📤 Output:
• Assistant messages: ${assistantMessages}
• Assistant characters: ${assistantChars}
• Average assistant message length: ${assistantMessages > 0 ? Math.round(assistantChars / assistantMessages) : 0} chars

📋 System:
• System messages: ${systemMessages}
• Tool messages: ${toolMessages}

📈 Summary:
• Total messages: ${messages.length}
• Total characters: ${totalChars}
• Estimated tokens (≈4 chars/token): ${Math.round(totalChars / 4)}
		`.trim();

		await this.command.addMessage('system', statsText);
	}

	/**
	 * Get simple history for input component
	 */
	private getSimpleHistory(): string[] {
		if (!this.command) return [];

		const state = this.command.getState();
		return state.messages
			.filter(m => m.role === 'user')
			.map(m => m.content)
			.slice(-20); // Last 20 user messages
	}
}

/**
 * Factory function to create a chat plugin
 */
export function createChatPlugin(): ChatPlugin {
	return new ChatPlugin();
}