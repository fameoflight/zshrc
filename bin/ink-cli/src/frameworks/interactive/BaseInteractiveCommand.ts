import React, {ReactElement, useState, useMemo} from 'react';
import {Text, Box, useApp} from 'ink';
import {Command, CommandFlags, CommandConfig, CommandHelp} from '../../base/command.js';
import {LLMProvider} from '../../services/LLMProvider.js';
import {serviceContainer} from '../../services/ServiceProvider.js';
import {contextManager} from '../../services/ContextManager.js';
import {toolRegistry} from '../../services/ToolRegistry.js';

export interface BaseInteractiveState {
	sessionId: string;
	showWelcome: boolean;
	isStreaming: boolean;
	currentInput: string;
	error: string | null;
	messages: Array<{
		id: string;
		role: 'user' | 'assistant' | 'system' | 'tool';
		content: string;
		timestamp: Date;
	}>;
	currentResponse?: string;
}

export interface Plugin {
	name: string;
	initialize?(command: BaseInteractiveCommand<any>): Promise<void>;
	cleanup?(): Promise<void>;
	onMessage?(message: string): Promise<boolean>; // Return true if handled
	onStateChange?(state: any): void;
	renderComponents?(): ReactElement[];
}

/**
 * Base class for all interactive commands
 *
 * Provides common functionality like state management, command processing,
 * LLM integration, and plugin system. Commands extend this and implement
 * only their specific logic.
 */
export abstract class BaseInteractiveCommand<TState extends BaseInteractiveState = BaseInteractiveState>
	implements Command {
	protected plugins: Plugin[] = [];
	protected state: TState;
	protected sessionId: string;
	protected llmProvider?: LLMProvider;
	protected appExit: () => void;
	protected stateUpdater: (updates: Partial<TState>) => void;

	constructor() {
		this.sessionId = this.generateSessionId();
		this.state = this.createInitialState() as TState;
		// Note: useApp() will be called in the wrapper component
	}

	// Abstract methods that subclasses must implement
	abstract name(): string;
	abstract description(): string;
	abstract config(): CommandConfig;
	abstract help(): CommandHelp;
	abstract createInitialState(): TState;
	abstract renderInteractiveUI(state: TState, flags: CommandFlags): ReactElement;

	// Optional methods subclasses can override
	protected async initializeServices(): Promise<void> {
		// Try to get LLM provider if available
		this.llmProvider = serviceContainer.resolve<LLMProvider>('llm-provider');

		// Initialize context session
		contextManager.createSession(this.sessionId);

		// Initialize plugins
		for (const plugin of this.plugins) {
			if (plugin.initialize) {
				await plugin.initialize(this);
			}
		}
	}

	// Execute method from Command interface
	execute(flags: CommandFlags): ReactElement {
		return (
			<InteractiveWrapper command={this} flags={flags} />
		);
	}

	// Plugin management
	addPlugin(plugin: Plugin): void {
		this.plugins.push(plugin);
	}

	removePlugin(pluginName: string): void {
		this.plugins = this.plugins.filter(p => p.name !== pluginName);
	}

	getPlugin(pluginName: string): Plugin | undefined {
		return this.plugins.find(p => p.name === pluginName);
	}

	// State management
	protected updateState(updates: Partial<TState>): void {
		this.state = {...this.state, ...updates};

		// Notify plugins of state change
		for (const plugin of this.plugins) {
			if (plugin.onStateChange) {
				plugin.onStateChange(this.state);
			}
		}

		// Call React state updater if available
		if (this.stateUpdater) {
			this.stateUpdater(updates);
		}
	}

	protected getState(): TState {
		return this.state;
	}

	protected setStateUpdater(updater: (updates: Partial<TState>) => void): void {
		this.stateUpdater = updater;
	}

	protected setAppExit(exit: () => void): void {
		this.appExit = exit;
	}

	// Message handling
	protected async addMessage(
		role: 'user' | 'assistant' | 'system' | 'tool',
		content: string,
		metadata?: Record<string, any>
	): Promise<string> {
		const messageId = contextManager.addMessage(this.sessionId, role, content, metadata);

		const message = {
			id: messageId,
			role,
			content,
			timestamp: new Date(),
		};

		const updatedMessages = [...this.state.messages, message];
		this.updateState({messages: updatedMessages});

		return messageId;
	}

	protected getMessages(): TState['messages'] {
		return this.state.messages;
	}

	protected clearMessages(): void {
		contextManager.clearConversation(this.sessionId);
		this.updateState({
			messages: [],
			showWelcome: true,
		});
	}

	// Command processing
	protected async processInput(input: string): Promise<void> {
		if (input.trim() === '') return;

		// Try to handle with plugins first
		for (const plugin of this.plugins) {
			if (plugin.onMessage) {
				const handled = await plugin.onMessage(input);
				if (handled) return;
			}
		}

		// Default handling for commands
		if (input.startsWith('/')) {
			await this.processCommand(input);
		} else {
			await this.processUserMessage(input);
		}
	}

	protected async processCommand(command: string): Promise<void> {
		const commandName = command.substring(1).toLowerCase();

		switch (commandName) {
			case 'clear':
				this.clearMessages();
				break;

			case 'exit':
			case 'quit':
				if (this.appExit) {
					this.appExit();
				}
				break;

			case 'help':
				await this.showHelp();
				break;

			default:
				await this.handleCustomCommand(command);
				break;
		}
	}

	protected async processUserMessage(message: string): Promise<void> {
		// Add user message
		await this.addMessage('user', message);
		this.updateState({showWelcome: false});

		// Process with LLM if available
		if (this.llmProvider && this.llmProvider.isReady()) {
			await this.processWithLLM(message);
		} else {
			await this.processWithoutLLM(message);
		}
	}

	protected async processWithLLM(message: string): Promise<void> {
		if (!this.llmProvider) return;

		this.updateState({isStreaming: true, error: null, currentResponse: ''});

		try {
			// Get conversation history
			const conversation = contextManager.getConversation(this.sessionId);
			const messages = conversation.map(msg => ({
				role: msg.role,
				content: msg.content,
			}));

			// Stream response
			let assistantResponse = '';
			await this.llmProvider.streamChat(
				messages,
				(chunk) => {
					if (chunk.content) {
						assistantResponse += chunk.content;
						// Update streaming state
						this.updateState({
							currentResponse: assistantResponse,
						});
					}
				}
			);

			// Add final assistant message
			await this.addMessage('assistant', assistantResponse);
		} catch (error) {
			this.updateState({error: String(error)});
			await this.addMessage('system', `❌ Error: ${error}`);
		} finally {
			this.updateState({isStreaming: false, currentResponse: ''});
		}
	}

	protected async processWithoutLLM(message: string): Promise<void> {
		await this.addMessage(
			'system',
			'🤖 LLM service not available. Please configure an LLM provider to chat.'
		);
	}

	// Custom command handling (override in subclasses)
	protected async handleCustomCommand(command: string): Promise<void> {
		await this.addMessage('system', `❌ Unknown command: ${command}`);
	}

	protected async showHelp(): Promise<void> {
		const help = this.help();
		const helpText = `
📚 ${help.description}

Usage: ${help.usage || this.name()}

${help.examples ? 'Examples:\n' + help.examples.map(ex => `  • ${ex}`).join('\n') : ''}

${help.notes ? '\nNotes:\n' + help.notes.map(note => `  • ${note}`).join('\n') : ''}
		`.trim();

		await this.addMessage('system', helpText);
	}

	// Utility methods
	protected generateSessionId(): string {
		return `${this.name()}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
	}

	// Cleanup
	async cleanup(): Promise<void> {
		// Cleanup plugins
		for (const plugin of this.plugins) {
			if (plugin.cleanup) {
				await plugin.cleanup();
			}
		}
	}
}

// Wrapper component to handle React lifecycle
interface InteractiveWrapperProps<T extends BaseInteractiveState> {
	command: BaseInteractiveCommand<T>;
	flags: CommandFlags;
}

function InteractiveWrapper<T extends BaseInteractiveState>({command, flags}: InteractiveWrapperProps<T>) {
	const {exit} = useApp();
	const [state, setState] = useState(command.getState());

	// Set up app exit function
	command.setAppExit(exit);

	// Sync state with command
	const updateState = (updates: Partial<T>) => {
		const newState = {...command.getState(), ...updates};
		setState(newState);
		command.state = newState;

		// Notify plugins of state change
		for (const plugin of command.plugins) {
			if (plugin.onStateChange) {
				plugin.onStateChange(newState);
			}
		}
	};

	command.setStateUpdater(updateState);

	// Initialize services on mount
	React.useEffect(() => {
		command.initializeServices().catch(console.error);

		// Cleanup on unmount
		return () => {
			command.cleanup().catch(console.error);
		};
	}, []);

	// Render command-specific UI
	return command.renderInteractiveUI(state, flags);
}