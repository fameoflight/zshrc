import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, Plugin, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {LLMProvider} from '../services/LLMProvider.js';
import {serviceContainer} from '../services/ServiceProvider.js';

export interface LLMPluginOptions {
	/** Custom LLM provider (overrides service container) */
	llmProvider?: LLMProvider;
	/** Enable tool calling (when available) */
	enableToolCalling?: boolean;
	/** Custom system prompt */
	systemPrompt?: string;
	/** Temperature override */
	temperature?: number;
	/** Model override */
	model?: string;
}

/**
 * LLM Plugin - Provides LLM integration for interactive commands
 *
 * This plugin enables any interactive command to optionally use LLM capabilities
 * for conversation, content generation, and intelligent responses.
 */
export class LLMPlugin implements Plugin {
	name = 'llm';

	private command?: BaseInteractiveCommand<any>;
	private llmProvider?: LLMProvider;
	private options: LLMPluginOptions;

	constructor(options: LLMPluginOptions = {}) {
		this.options = options;
	}

	async initialize(command: BaseInteractiveCommand<any>): Promise<void> {
		this.command = command;

		// Get LLM provider from options or service container
		this.llmProvider = this.options.llmProvider ||
			serviceContainer.resolve<LLMProvider>('llm-provider');

		if (!this.llmProvider) {
			console.warn('[LLMPlugin] No LLM provider available in service container');
			return;
		}

		// Configure LLM provider if options are provided
		if (this.options.systemPrompt || this.options.temperature !== undefined || this.options.model) {
			const currentConfig = this.llmProvider.getConfig();
			const newConfig = {
				...currentConfig,
				systemPrompt: this.options.systemPrompt || currentConfig.systemPrompt,
				temperature: this.options.temperature !== undefined
					? this.options.temperature
					: currentConfig.temperature,
				model: this.options.model || currentConfig.model,
			};

			await this.llmProvider.updateConfig(newConfig);
		}
	}

	async cleanup(): Promise<void> {
		// Cleanup any LLM-related resources
	}

	async onMessage(message: string): Promise<boolean> {
		if (!this.command || !this.llmProvider || !this.llmProvider.isReady()) {
			return false;
		}

		// Handle LLM-specific commands
		if (message.startsWith('/')) {
			const commandName = message.substring(1).toLowerCase();

			switch (commandName) {
				case 'llm-status':
					await this.showLLMStatus();
					return true;

				case 'llm-config':
					await this.showLLMConfig();
					return true;

				case 'llm-reset':
					await this.resetLLMConfig();
					return true;

				default:
					// Check for LLM configuration commands
					if (commandName.startsWith('llm-')) {
						return await this.handleLLMConfigCommand(commandName, message);
					}
					return false;
			}
		}

		return false; // Not an LLM-specific command
	}

	onStateChange(state: BaseInteractiveState): void {
		// React to state changes if needed
		// For example, could trigger LLM actions based on certain state conditions
	}

	renderComponents(): ReactElement[] {
		// LLM plugin doesn't render UI components by default
		// It enhances the command's behavior rather than adding visual elements
		return [];
	}

	/**
	 * Enhanced processUserMessage method for LLM integration
	 */
	async processWithLLM(message: string): Promise<void> {
		if (!this.command || !this.llmProvider || !this.llmProvider.isReady()) {
			return;
		}

		const state = this.command.getState();

		try {
			this.command.updateState({isStreaming: true, error: null, currentResponse: ''});

			// Get conversation history
			const messages = state.messages.map(msg => ({
				role: msg.role as 'user' | 'assistant' | 'system',
				content: msg.content,
			}));

			// Add current user message if not already in messages
			if (messages.length === 0 || messages[messages.length - 1].content !== message) {
				messages.push({role: 'user', content: message});
			}

			// Stream response from LLM
			let assistantResponse = '';
			await this.llmProvider.streamChat(
				messages,
				(chunk) => {
					if (chunk.content) {
						assistantResponse += chunk.content;
						this.command!.updateState({
							currentResponse: assistantResponse,
						});
					}
					if (chunk.isComplete) {
						this.command!.updateState({
							isStreaming: false,
							currentResponse: '',
						});
					}
					if (chunk.error) {
						this.command!.updateState({
							error: chunk.error,
							isStreaming: false,
							currentResponse: '',
						});
					}
				}
			);

			// Add final assistant message
			if (assistantResponse.trim()) {
				await this.command.addMessage('assistant', assistantResponse);
			}

		} catch (error) {
			const errorMessage = error instanceof Error ? error.message : String(error);
			this.command.updateState({
				error: errorMessage,
				isStreaming: false,
				currentResponse: '',
			});
			await this.command.addMessage('system', `❌ LLM Error: ${errorMessage}`);
		}
	}

	/**
	 * Show LLM provider status
	 */
	private async showLLMStatus(): Promise<void> {
		if (!this.command) return;

		if (!this.llmProvider) {
			await this.command.addMessage('system', '❌ No LLM provider available');
			return;
		}

		const isReady = this.llmProvider.isReady();
		const providerType = this.llmProvider.getProviderType();
		const config = this.llmProvider.getConfig();

		const statusText = `
🤖 LLM Provider Status:

📡 Provider: ${providerType}
🟢 Status: ${isReady ? 'Ready' : 'Not Ready'}
🔗 Base URL: ${config.baseURL || 'Not set'}
🏷️ Model: ${config.model || 'Default'}
🌡️ Temperature: ${config.temperature ?? 0.7}
📏 Max Tokens: ${config.maxTokens || 'Default'}
📋 System Prompt: ${config.systemPrompt || 'None'}
		`.trim();

		await this.command.addMessage('system', statusText);
	}

	/**
	 * Show current LLM configuration
	 */
	private async showLLMConfig(): Promise<void> {
		if (!this.command || !this.llmProvider) return;

		const config = this.llmProvider.getConfig();

		const configText = `
⚙️ Current LLM Configuration:

Base URL: ${config.baseURL || 'Not set'}
API Key: ${config.apiKey ? '***' + config.apiKey.slice(-4) : 'Not set'}
Model: ${config.model || 'Default'}
Temperature: ${config.temperature ?? 0.7}
Max Tokens: ${config.maxTokens || 'Default'}
System Prompt: ${config.systemPrompt || 'None'}
		`.trim();

		await this.command.addMessage('system', configText);
	}

	/**
	 * Reset LLM configuration to defaults
	 */
	private async resetLLMConfig(): Promise<void> {
		if (!this.command || !this.llmProvider) return;

		try {
			const defaultConfig = {
				temperature: 0.7,
				maxTokens: 2048,
				systemPrompt: this.options.systemPrompt || '',
			};

			await this.llmProvider.updateConfig(defaultConfig);
			await this.command.addMessage('system', '✅ LLM configuration reset to defaults');
		} catch (error) {
			await this.command.addMessage('system', `❌ Failed to reset LLM config: ${error}`);
		}
	}

	/**
	 * Handle LLM configuration commands
	 */
	private async handleLLMConfigCommand(commandName: string, fullCommand: string): Promise<boolean> {
		if (!this.command || !this.llmProvider) return false;

		const parts = fullCommand.split(' ');
		const configKey = parts[2]; // /llm-set <key> <value>
		const configValue = parts.slice(3).join(' ');

		if (commandName === 'llm-set' && configKey && configValue) {
			try {
				const update: any = {};

				switch (configKey.toLowerCase()) {
					case 'temperature':
						const temp = parseFloat(configValue);
						if (isNaN(temp) || temp < 0 || temp > 2) {
							await this.command.addMessage('system', '❌ Temperature must be a number between 0.0 and 2.0');
							return true;
						}
						update.temperature = temp;
						break;

					case 'model':
						update.model = configValue;
						break;

					case 'maxtokens':
					case 'max-tokens':
						const tokens = parseInt(configValue);
						if (isNaN(tokens) || tokens <= 0) {
							await this.command.addMessage('system', '❌ Max tokens must be a positive number');
							return true;
						}
						update.maxTokens = tokens;
						break;

					case 'systemprompt':
					case 'system-prompt':
						update.systemPrompt = configValue;
						break;

					default:
						await this.command.addMessage('system', `❌ Unknown config key: ${configKey}`);
						return true;
				}

				await this.llmProvider.updateConfig(update);
				await this.command.addMessage('system', `✅ Updated ${configKey} to ${configValue}`);
				return true;

			} catch (error) {
				await this.command.addMessage('system', `❌ Failed to update config: ${error}`);
				return true;
			}
		}

		return false;
	}

	/**
	 * Get the current LLM provider
	 */
	getLLMProvider(): LLMProvider | undefined {
		return this.llmProvider;
	}

	/**
	 * Check if LLM is available and ready
	 */
	isLLMReady(): boolean {
		return this.llmProvider?.isReady() || false;
	}
}

/**
 * Factory function to create an LLM plugin
 */
export function createLLMPlugin(options?: LLMPluginOptions): LLMPlugin {
	return new LLMPlugin(options);
}