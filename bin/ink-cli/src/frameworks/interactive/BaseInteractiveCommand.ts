import React, {ReactElement, useState, useMemo} from 'react';
import {Text, Box, useApp, useInput} from 'ink';
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
	protected appExit!: () => void;
	protected stateUpdater!: (updates: Partial<TState>) => void;
	protected flags!: CommandFlags;
	protected logger?: any; // Command logger that plugins can use

	constructor() {
		this.sessionId = this.generateSessionId();
		this.state = this.createInitialState() as TState;
		// Note: useApp() will be called in the wrapper component
	}

	/**
	 * Get the command logger for plugins to use
	 */
	getLogger(): any {
		return this.logger;
	}

	/**
	 * Set the logger (called by subclasses that have a logger)
	 */
	setLogger(logger: any): void {
		this.logger = logger;
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
		this.logger?.debug('LLM Provider resolved:', this.llmProvider ? this.llmProvider.getProviderType() : 'None');

		// Initialize context session
		contextManager.createSession(this.sessionId);
		this.logger?.debug('Context session created:', this.sessionId);

		// Initialize plugins
		this.logger?.info(`Initializing ${this.plugins.length} plugins...`);
		for (const plugin of this.plugins) {
			this.logger?.info(`Initializing plugin: ${plugin.name}`);
			if (plugin.initialize) {
				await plugin.initialize(this);
				this.logger?.info(`Plugin ${plugin.name} initialized successfully`);
			}
		}
		this.logger?.info(`All services initialized`);
	}

	// Execute method from Command interface
	execute(flags: CommandFlags): ReactElement {
		this.flags = flags;
		return React.createElement(InteractiveWrapper as any, {command: this, flags});
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
	public updateState(updates: Partial<TState>): void {
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

	public getState(): TState {
		return this.state;
	}

	public setStateUpdater(updater: (updates: Partial<TState>) => void): void {
		this.stateUpdater = updater;
	}

	public getFlags(): CommandFlags {
		return this.flags;
	}

	protected setAppExit(exit: () => void): void {
		this.appExit = exit;
	}

	// Message handling
	public async addMessage(
		role: 'user' | 'assistant' | 'system' | 'tool',
		content: string,
		metadata?: Record<string, any>
	): Promise<string> {
		// Convert 'tool' role to 'system' for contextManager compatibility
		const contextRole = role === 'tool' ? 'system' : role;
		const messageId = contextManager.addMessage(this.sessionId, contextRole, content, metadata);

		const message = {
			id: messageId,
			role,
			content,
			timestamp: new Date(),
		};

		const updatedMessages = [...this.state.messages, message];
		this.updateState({messages: updatedMessages} as Partial<TState>);

		return messageId;
	}

	protected getMessages(): TState['messages'] {
		return this.state.messages;
	}

	public clearMessages(): void {
		contextManager.clearConversation(this.sessionId);
		this.updateState({
			messages: [],
			showWelcome: true,
		} as unknown as Partial<TState>);
	}

	// Command processing
	public async processInput(input: string): Promise<void> {
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
		this.updateState({showWelcome: false} as Partial<TState>);

		// Process with LLM if available
		if (this.llmProvider && this.llmProvider.isReady()) {
			await this.processWithLLM(message);
		} else {
			await this.processWithoutLLM(message);
		}
	}

	protected async processWithLLM(message: string): Promise<void> {
		if (!this.llmProvider) return;

		this.updateState({isStreaming: true, error: null, currentResponse: ''} as Partial<TState>);

		try {
			// Get conversation history
			const conversation = contextManager.getConversation(this.sessionId);
			const messages = conversation.map(msg => ({
				role: msg.role,
				content: msg.content,
			}));

			this.logger?.debug('Calling LLM streamChat with messages:', messages);

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
						} as Partial<TState>);
					}
					if (chunk.error) {
						this.logger?.error('LLM streaming error:', chunk.error);
						throw new Error(chunk.error);
					}
				}
			);

			// Add final assistant message
			await this.addMessage('assistant', assistantResponse);
			this.logger?.debug('LLM response completed');
		} catch (error) {
			this.logger?.error('LLM processing failed:', error);
			const errorMessage = error instanceof Error ? error.message : String(error);
			this.updateState({error: errorMessage} as Partial<TState>);
			await this.addMessage('system', `❌ LLM Error: ${errorMessage}`);
		} finally {
			this.updateState({isStreaming: false, currentResponse: ''} as Partial<TState>);
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
	const [forceUpdate, setForceUpdate] = useState(0);

	// Set up app exit function
	(command as any).setAppExit(exit);

	// Sync state with command
	const updateState = (updates: Partial<T>) => {
		const currentCommandState = command.getState();
		const newState = {...currentCommandState, ...updates};

		// Update both React state and force re-render
		setState(newState);
		(command as any).state = newState;
		setForceUpdate(prev => prev + 1); // Force re-render

		// Notify plugins of state change
		for (const plugin of (command as any).plugins) {
			if (plugin.onStateChange) {
				plugin.onStateChange(newState);
			}
		}
	};

	command.setStateUpdater(updateState);

	// Add effect to sync state changes from command to React state
	React.useEffect(() => {
		const commandState = command.getState();
		if (JSON.stringify(commandState) !== JSON.stringify(state)) {
			setState(commandState);
		}
	});

	// Initialize services on mount
	React.useEffect(() => {
		(command as any).initializeServices().then(() => {
			try {
				const newState = command.getState();
				setState(newState);
				setForceUpdate(prev => prev + 1);
			} catch (error) {
				command.getLogger()?.error('Error during re-render:', error);
			}
		}).catch((error: any) => {
			command.getLogger()?.error('Error during initialization:', error);
		});

		// Cleanup on unmount
		return () => {
			command.cleanup().catch(console.error);
		};
	}, []);

	// Remove fallback input handler to avoid conflicts with component input handlers

	// Add effect to trigger re-render when state changes
	React.useEffect(() => {
		// This effect ensures re-render when state changes
	}, [state, command, flags, forceUpdate]);

	// Render command-specific UI
	return command.renderInteractiveUI(state, flags);
}