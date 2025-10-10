import React, {ReactElement, useMemo} from 'react';
import {Command, CommandConfig, CommandFlags, CommandHelp} from '../base/command.js';
import {
	BaseInteractiveCommand,
	BaseInteractiveState,
	Plugin,
} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {InteractiveLayout, InteractiveHeader, InteractiveFooter} from '../components/interactive/InteractiveLayout.js';
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
class LLMChatCommand extends BaseInteractiveCommand<LLMChatState> implements Command {
	private logger = createCommandLogger('llm-chat');

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

	async initializeServices(): Promise<void> {
		// Initialize LLM provider and register in service container
		await this.initializeLLMProvider();

		// Add plugins for chat functionality
		this.addPlugin(createChatPlugin());
		this.addPlugin(createLLMPlugin());
		this.addPlugin(createConfigPlugin<LLMChatConfig>({
			schema: {
				defaults: {
					temperature: 0.7,
				},
				validation: {
					temperature: (value) => {
						if (typeof value !== 'number' || isNaN(value)) {
							return 'Temperature must be a number';
						}
						if (value < 0 || value > 2) {
							return 'Temperature must be between 0.0 and 2.0';
						}
						return true;
					},
				},
			},
			namespace: 'llm-chat',
		}));

		// Call parent initialization
		await super.initializeServices();
	}

	private async initializeLLMProvider(): Promise<void> {
		try {
			// Get LLM provider from flags
			const flags = this.getCurrentFlags();
			if (!flags) return;

			const llmProvider = await LLMProviderFactory.createFromFlags(
				flags,
				{
					provider: 'lmstudio',
					baseURL: 'http://localhost:1234/v1',
					apiKey: '',
					model: 'default',
					temperature: 0.7,
					maxTokens: 2048,
					systemPrompt: '',
				}
			);

			// Register as singleton for dependency injection
			registerSingleton('llm-provider', () => llmProvider);

			this.logger.info('LLM Provider initialized successfully');
		} catch (error) {
			this.logger.error('Failed to initialize LLM Provider:', error);
			this.updateState({error: String(error)});
		}
	}

	private getCurrentFlags(): LLMChatFlags | null {
		// In a real implementation, this would come from the command execution context
		// For now, we'll return null and let the LLM plugin handle provider setup
		return null;
	}

	protected async processUserMessage(message: string): Promise<void> {
		// Override to use LLM plugin for processing
		const llmPlugin = this.getPlugin('llm');
		if (llmPlugin && 'processWithLLM' in llmPlugin) {
			await (llmPlugin as any).processWithLLM(message);
		} else {
			// Fallback to parent implementation
			await super.processUserMessage(message);
		}
	}

	renderInteractiveUI(state: LLMChatState, flags: CommandFlags): ReactElement {
		// Get resolved provider from LLM plugin if available
		const llmPlugin = this.getPlugin('llm');
		const resolvedProvider = (llmPlugin && 'getLLMProvider' in llmPlugin)
			? (llmPlugin as any).getLLMProvider()?.getProviderType() || 'unknown'
			: 'lmstudio';

		// Create header info
		const headerInfo = useMemo(() => [
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
			...(state.systemPrompt ? [{
				label: 'System Prompt',
				value: state.systemPrompt.length > 50
					? state.systemPrompt.substring(0, 47) + '...'
					: state.systemPrompt,
				valueColor: 'gray',
				icon: '📋',
			}] : []),
			...(state.error ? [{
				label: 'Error',
				value: state.error,
				valueColor: 'red',
				icon: '⚠️',
			}] : []),
		], [resolvedProvider, state.temperature, state.model, state.systemPrompt, state.error]);

		// Render using interactive layout
		return (
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
	}

	private renderPluginComponents(): ReactElement[] {
		const components: ReactElement[] = [];

		// Collect components from all plugins
		for (const plugin of this.plugins) {
			if (plugin.renderComponents) {
				components.push(...plugin.renderComponents());
			}
		}

		return components;
	}
}

export default LLMChatCommand;