import React, {ReactElement, useMemo} from 'react';
import {
	Command,
	CommandConfig,
	CommandFlags,
	CommandHelp,
} from '../base/command.js';
import {
	BaseInteractiveCommand,
	BaseInteractiveState,
	Plugin,
} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {
	InteractiveLayout,
	InteractiveHeader,
	InteractiveFooter,
} from '../components/interactive/InteractiveLayout.js';
import {createChatPlugin} from '../plugins/ChatPlugin.js';
import {createLLMPlugin} from '../plugins/LLMPlugin.js';
import {createConfigPlugin} from '../plugins/ConfigPlugin.js';
import {LLMProviderFactory} from '../services/LLMProviderFactory.js';
import {registerSingleton} from '../services/ServiceProvider.js';
import {createCommandLogger} from '../common/logger.js';

// LLM Chat specific configuration interface
interface LLMChatConfig {
	temperature: number;
	maxTokens?: number;
	systemPrompt?: string;
	model?: string;
}

interface LLMChatState extends BaseInteractiveState {
	temperature: number;
	maxTokens?: number;
	systemPrompt?: string;
	model?: string;
}

interface LLMChatFlags extends CommandFlags {
	provider?: string;
	baseurl?: string;
	apikey?: string;
	model?: string;
	'system-prompt'?: string;
	temperature?: number;
	'max-tokens'?: number;
}

/**
 * LLM Chat Command V2 - Using the new interactive command foundation
 *
 * This demonstrates how the new architecture reduces code complexity while
 * maintaining all functionality and adding new capabilities.
 */
class LLMChatCommand
	extends BaseInteractiveCommand<LLMChatState>
	implements Command
{
	override logger = createCommandLogger('llm-chat');

	constructor() {
		super();
		this.setLogger(this.logger); // Make logger available to base class and plugins
	}

	name(): string {
		return 'llm-chat';
	}

	description(): string {
		return 'Interactive chat with OpenAI-compatible LLM (LM Studio, Ollama, OpenAI, etc.)';
	}

	config(): CommandConfig<LLMChatFlags> {
		return {
			name: this.name(),
			description: this.description(),
			flags: {
				provider: {
					type: 'string',
					description: 'LLM provider preset (lmstudio, openai, ollama, custom)',
					default: 'lmstudio',
				},
				baseurl: {
					type: 'string',
					description: 'Custom API base URL (overrides provider)',
				},
				apikey: {
					type: 'string',
					description: 'API key for providers that require authentication',
				},
				model: {
					type: 'string',
					description: 'Model name to use',
				},
				'system-prompt': {
					type: 'string',
					description: 'System prompt to set conversation context',
				},
				temperature: {
					type: 'number',
					description: 'Temperature for response randomness (0.0-2.0)',
				},
				'max-tokens': {
					type: 'number',
					description: 'Maximum tokens in response',
				},
			},
		};
	}

	help(): CommandHelp {
		return {
			description:
				'Start an interactive chat session with persistent conversation context using any OpenAI-compatible LLM provider.',
			usage: 'llm-chat [OPTIONS]',
			examples: [
				'llm-chat',
				'llm-chat --provider=openai --apikey=sk-...',
				'llm-chat --provider=ollama --model=llama2',
				'llm-chat --baseurl=http://localhost:8080 --model=custom-model',
				'llm-chat --system-prompt="You are a helpful assistant"',
			],
			notes: [
				'Default provider is LM Studio (localhost:1234)',
				'Supports streaming responses for real-time interaction',
				'Conversation context is maintained throughout the session',
				'Use Ctrl+L to clear conversation history',
				'Use Escape to cancel streaming responses',
				'Use Ctrl+C to exit the chat',
				'Provider presets: lmstudio, openai, ollama, custom',
			],
		};
	}

	createInitialState(): LLMChatState {
		return {
			sessionId: '',
			showWelcome: true,
			isStreaming: false,
			currentInput: '',
			error: null,
			messages: [],
			currentResponse: '',
			temperature: 0.7,
			maxTokens: undefined,
			systemPrompt: undefined,
			model: undefined,
		};
	}

	override async initializeServices(): Promise<void> {
		this.logger.info('[LLMChat] initializeServices called');

		// Initialize LLM provider and register in service container
		await this.initializeLLMProvider();

		// Add plugins for chat functionality
		this.logger.info('[LLMChat] Adding plugins...');
		const chatPlugin = createChatPlugin();
		const llmPlugin = createLLMPlugin();
		const configPlugin = createConfigPlugin<LLMChatConfig>({
			schema: {
				defaults: {
					temperature: 0.7,
				},
				validation: {
					temperature: value => {
						if (typeof value !== 'number' || isNaN(value)) {
							return 'Temperature must be a number';
						}
						if (value < 0 || value > 2) {
							return 'Temperature must be between 0.0 and 2.0';
						}
						return true;
					},
					model: value => {
						if (typeof value !== 'string') {
							return 'Model must be a string';
						}
						return true;
					},
					maxTokens: value => {
						if (
							value !== undefined &&
							(typeof value !== 'number' || value <= 0)
						) {
							return 'Max tokens must be a positive number';
						}
						return true;
					},
					systemPrompt: value => {
						if (value !== undefined && typeof value !== 'string') {
							return 'System prompt must be a string';
						}
						return true;
					},
				},
			},
			namespace: 'llm-chat',
		});

		this.addPlugin(chatPlugin);
		this.addPlugin(llmPlugin);
		this.addPlugin(configPlugin);
		this.logger.info('[LLMChat] All plugins added');

		// Call parent initialization
		this.logger.info('[LLMChat] Calling parent initializeServices...');
		await super.initializeServices();
		this.logger.info('[LLMChat] Parent initializeServices completed');
	}

	private async initializeLLMProvider(): Promise<void> {
		try {
			// Get LLM provider from flags
			let flags = this.getCurrentFlags();
			this.logger.info('Current flags:', flags);

			if (!flags) {
				this.logger.info('No flags available, using defaults');
				// Use default flags
				flags = {
					provider: 'lmstudio',
					baseurl: 'http://localhost:1234/v1',
					apikey: '',
					model: 'default',
					temperature: 0.7,
				};
			}

			const llmProvider = await LLMProviderFactory.createFromFlags(flags, {
				provider: 'lmstudio',
				baseURL: 'http://localhost:1234/v1',
				apiKey: '',
				model: 'default',
				temperature: 0.7,
				maxTokens: 2048,
				systemPrompt: '',
			});

			this.logger.info('LLM Provider created:', llmProvider.getProviderType());

			// Register as singleton for dependency injection
			registerSingleton('llm-provider', () => llmProvider);

			this.logger.info('LLM Provider initialized successfully');
		} catch (error) {
			this.logger.error('Failed to initialize LLM Provider:', error);
			this.updateState({error: String(error)});
		}
	}

	private getCurrentFlags(): LLMChatFlags | null {
		// Get flags from the base class
		return this.getFlags() as LLMChatFlags;
	}

	protected override async processUserMessage(message: string): Promise<void> {
		// Add user message to UI first
		await this.addMessage('user', message);
		this.updateState({showWelcome: false} as Partial<LLMChatState>);

		// Use LLM plugin for processing
		const llmPlugin = this.getPlugin('llm');
		if (llmPlugin && 'processWithLLM' in llmPlugin) {
			await (llmPlugin as any).processWithLLM(message);
		} else {
			// Fallback to parent implementation (but don't add user message again)
			await super.processUserMessage(message);
		}
	}

	renderInteractiveUI(state: LLMChatState, flags: CommandFlags): ReactElement {
		this.logger.info('renderInteractiveUI called');
		this.logger.debug('State:', JSON.stringify(state, null, 2));
		this.logger.debug('Flags:', JSON.stringify(flags, null, 2));

		// Get resolved provider from LLM plugin if available
		const llmPlugin = this.getPlugin('llm');
		this.logger.debug('LLM plugin found:', !!llmPlugin);

		const resolvedProvider =
			llmPlugin && 'getLLMProvider' in llmPlugin
				? (llmPlugin as any).getLLMProvider()?.getProviderType() || 'unknown'
				: 'lmstudio';

		this.logger.debug('Resolved provider:', resolvedProvider);

		// Create header info
		const headerInfo = useMemo(
			() => [
				{
					label: 'Provider',
					value: resolvedProvider,
					valueColor: 'cyan',
					icon: '🤖',
				},
				{
					label: 'Temperature',
					value: state.temperature.toFixed(1),
					valueColor: 'yellow',
					icon: '🌡️',
				},
				{
					label: 'Model',
					value: state.model || 'default',
					valueColor: 'gray',
				},
				...(state.systemPrompt
					? [
							{
								label: 'System Prompt',
								value:
									state.systemPrompt.length > 50
										? state.systemPrompt.substring(0, 47) + '...'
										: state.systemPrompt,
								valueColor: 'gray',
								icon: '📋',
							},
					  ]
					: []),
				...(state.error
					? [
							{
								label: 'Error',
								value: state.error,
								valueColor: 'red',
								icon: '⚠️',
							},
					  ]
					: []),
			],
			[
				resolvedProvider,
				state.temperature,
				state.model,
				state.systemPrompt,
				state.error,
			],
		);

		// Render using interactive layout
		this.logger.debug('Rendering InteractiveLayout');
		const result = (
			<InteractiveLayout
				header={
					<InteractiveHeader
						title={`LLM Chat - ${resolvedProvider}`}
						titleIcon="💬"
						titleColor="blue"
						infoItems={headerInfo}
					/>
				}
				footer={
					<InteractiveFooter
						status={state.isStreaming ? 'Streaming...' : 'Ready'}
						statusColor={state.isStreaming ? 'yellow' : 'green'}
						info={`${state.messages.length} messages`}
						shortcuts={{
							'Ctrl+L': 'Clear',
							'Ctrl+C': 'Quit',
							Escape: 'Cancel',
							Tab: 'Complete',
						}}
					/>
				}
			>
				{/* Content will be rendered by plugins */}
				{this.renderPluginComponents()}
			</InteractiveLayout>
		);

		this.logger.debug('InteractiveLayout rendered');
		return result;
	}

	private renderPluginComponents(): ReactElement[] {
		this.logger.debug('Rendering plugin components...');
		const components: ReactElement[] = [];

		// Collect components from all plugins
		for (const plugin of this.plugins) {
			this.logger.debug(`Processing plugin: ${plugin.name}`);
			if (plugin.renderComponents) {
				const pluginComponents = plugin.renderComponents();
				this.logger.debug(
					`Plugin ${plugin.name} rendered ${pluginComponents.length} components`,
				);
				components.push(...pluginComponents);
			} else {
				this.logger.debug(
					`Plugin ${plugin.name} has no renderComponents method`,
				);
			}
		}

		this.logger.debug(`Total components rendered: ${components.length}`);
		return components;
	}
}

export default LLMChatCommand;
