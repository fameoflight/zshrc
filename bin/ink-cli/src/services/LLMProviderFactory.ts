import {LLMProvider, LLMConfig} from './LLMProvider.js';
import {NoOpLLMProvider} from './LLMProvider.js';
import {createLLMProviderFromService} from './adapters/LLMServiceAdapter.js';
import {createLLMService} from '../common/llm/LLMService.js';
import {PRESET_CONFIGS} from '../common/llm/config.js';

export type ProviderType = 'openai' | 'lmstudio' | 'ollama' | 'custom' | 'noop';

/**
 * Factory for creating LLM providers
 *
 * Provides a unified way to create different types of LLM providers
 * with proper configuration and error handling.
 */
export class LLMProviderFactory {
	/**
	 * Create an LLM provider for the specified type
	 */
	static async createProvider(
		type: ProviderType,
		config: Partial<LLMConfig> = {},
	): Promise<LLMProvider> {
		switch (type) {
			case 'openai':
				return this.createOpenAIProvider(config);
			case 'lmstudio':
				return this.createLMStudioProvider(config);
			case 'ollama':
				return this.createOllamaProvider(config);
			case 'custom':
				return this.createCustomProvider(config);
			case 'noop':
				return new NoOpLLMProvider();
			default:
				throw new Error(`Unknown provider type: ${type}`);
		}
	}

	/**
	 * Create OpenAI provider
	 */
	private static async createOpenAIProvider(
		config: Partial<LLMConfig>,
	): Promise<LLMProvider> {
		const fullConfig: LLMConfig = {
			baseURL: config.baseURL ? config.baseURL : 'https://api.openai.com/v1',
			apiKey: config.apiKey !== undefined ? config.apiKey : '',
			model: config.model ? config.model : 'gpt-3.5-turbo',
			temperature: config.temperature !== undefined ? config.temperature : 0.7,
			maxTokens: config.maxTokens,
			systemPrompt: config.systemPrompt,
		};

		const service = createLLMService({
			provider: 'openai',
			name: 'OpenAI',
			baseURL: fullConfig.baseURL
				? fullConfig.baseURL
				: 'https://api.openai.com/v1',
			apiKey: fullConfig.apiKey !== undefined ? fullConfig.apiKey : '',
			model: fullConfig.model ? fullConfig.model : 'gpt-3.5-turbo',
			temperature:
				fullConfig.temperature !== undefined ? fullConfig.temperature : 0.7,
			maxTokens: fullConfig.maxTokens || 2048,
			systemPrompt: fullConfig.systemPrompt || '',
		});

		return createLLMProviderFromService(service, fullConfig);
	}

	/**
	 * Create LM Studio provider
	 */
	private static async createLMStudioProvider(
		config: Partial<LLMConfig>,
	): Promise<LLMProvider> {
		const fullConfig: LLMConfig = {
			baseURL: config.baseURL ? config.baseURL : 'http://localhost:1234/v1',
			apiKey: config.apiKey !== undefined ? config.apiKey : '', // LM Studio often doesn't require API key
			model: config.model ? config.model : 'default',
			temperature: config.temperature !== undefined ? config.temperature : 0.7,
			maxTokens: config.maxTokens,
			systemPrompt: config.systemPrompt,
		};

		const service = createLLMService({
			provider: 'lmstudio',
			name: 'LM Studio',
			baseURL: fullConfig.baseURL
				? fullConfig.baseURL
				: 'http://localhost:1234/v1',
			apiKey: fullConfig.apiKey !== undefined ? fullConfig.apiKey : '',
			model: fullConfig.model ? fullConfig.model : 'default',
			temperature:
				fullConfig.temperature !== undefined ? fullConfig.temperature : 0.7,
			maxTokens: fullConfig.maxTokens || 2048,
			systemPrompt: fullConfig.systemPrompt || '',
		});

		return createLLMProviderFromService(service, fullConfig);
	}

	/**
	 * Create Ollama provider
	 */
	private static async createOllamaProvider(
		config: Partial<LLMConfig>,
	): Promise<LLMProvider> {
		const fullConfig: LLMConfig = {
			baseURL: config.baseURL ? config.baseURL : 'http://localhost:11434/v1',
			apiKey: config.apiKey !== undefined ? config.apiKey : 'ollama', // Ollama often uses 'ollama' as placeholder
			model: config.model ? config.model : 'llama2',
			temperature: config.temperature !== undefined ? config.temperature : 0.7,
			maxTokens: config.maxTokens,
			systemPrompt: config.systemPrompt,
		};

		const service = createLLMService({
			provider: 'ollama',
			name: 'Ollama',
			baseURL: fullConfig.baseURL
				? fullConfig.baseURL
				: 'http://localhost:11434/v1',
			apiKey: fullConfig.apiKey !== undefined ? fullConfig.apiKey : 'ollama',
			model: fullConfig.model ? fullConfig.model : 'llama2',
			temperature:
				fullConfig.temperature !== undefined ? fullConfig.temperature : 0.7,
			maxTokens: fullConfig.maxTokens || 2048,
			systemPrompt: fullConfig.systemPrompt || '',
		});

		return createLLMProviderFromService(service, fullConfig);
	}

	/**
	 * Create custom provider with user-specified configuration
	 */
	private static async createCustomProvider(
		config: Partial<LLMConfig>,
	): Promise<LLMProvider> {
		if (!config.baseURL) {
			throw new Error('Custom provider requires baseURL');
		}

		const fullConfig: LLMConfig = {
			baseURL: config.baseURL,
			apiKey: config.apiKey !== undefined ? config.apiKey : '',
			model: config.model ? config.model : 'default',
			temperature: config.temperature !== undefined ? config.temperature : 0.7,
			maxTokens: config.maxTokens,
			systemPrompt: config.systemPrompt,
		};

		const service = createLLMService({
			provider: 'custom',
			name: 'Custom API',
			baseURL: fullConfig.baseURL
				? fullConfig.baseURL
				: 'https://api.example.com/v1',
			apiKey: fullConfig.apiKey !== undefined ? fullConfig.apiKey : '',
			model: fullConfig.model ? fullConfig.model : 'default',
			temperature:
				fullConfig.temperature !== undefined ? fullConfig.temperature : 0.7,
			maxTokens: fullConfig.maxTokens || 2048,
			systemPrompt: fullConfig.systemPrompt || '',
		});

		return createLLMProviderFromService(service, fullConfig);
	}

	/**
	 * Create provider from flags (legacy compatibility)
	 */
	static async createFromFlags(
		flags: any,
		defaultConfig: any,
	): Promise<LLMProvider> {
		let providerType: ProviderType;
		let config: Partial<LLMConfig> = {};

		// Determine provider type and configuration
		if (flags.baseurl) {
			providerType = 'custom';
			config = {
				baseURL: flags.baseurl,
				apiKey: flags.apikey,
				model: flags.model,
				temperature: flags.temperature,
				maxTokens: flags['max-tokens'],
				systemPrompt: flags['system-prompt'],
			};
		} else {
			const preset = flags.provider?.toLowerCase() || 'lmstudio';
			providerType = preset as ProviderType;

			// Get base config from presets
			let baseConfig;
			if (preset === 'lmstudio') {
				baseConfig = defaultConfig;
			} else {
				baseConfig = PRESET_CONFIGS[preset as keyof typeof PRESET_CONFIGS];
				if (!baseConfig) {
					throw new Error(`Unknown provider: ${preset}`);
				}
			}

			config = {
				baseURL: baseConfig.baseURL,
				apiKey: flags.apikey !== undefined ? flags.apikey : baseConfig.apiKey,
				model: flags.model !== undefined ? flags.model : baseConfig.model,
				temperature:
					flags.temperature !== undefined
						? flags.temperature
						: baseConfig.temperature,
				maxTokens:
					flags['max-tokens'] !== undefined
						? flags['max-tokens']
						: baseConfig.maxTokens,
				systemPrompt:
					flags['system-prompt'] !== undefined
						? flags['system-prompt']
						: baseConfig.systemPrompt,
			};
		}

		return this.createProvider(providerType, config);
	}

	/**
	 * Get available provider types
	 */
	static getAvailableProviders(): ProviderType[] {
		return ['openai', 'lmstudio', 'ollama', 'custom', 'noop'];
	}

	/**
	 * Validate provider configuration
	 */
	static validateConfig(
		type: ProviderType,
		config: Partial<LLMConfig>,
	): string[] {
		const errors: string[] = [];

		switch (type) {
			case 'custom':
				if (!config.baseURL) {
					errors.push('Custom provider requires baseURL');
				}
				break;
			case 'openai':
				if (!config.apiKey) {
					errors.push('OpenAI provider requires apiKey');
				}
				break;
			case 'lmstudio':
			case 'ollama':
				// These providers often work with defaults
				break;
		}

		// General validation
		if (
			config.temperature !== undefined &&
			(config.temperature < 0 || config.temperature > 2)
		) {
			errors.push('Temperature must be between 0.0 and 2.0');
		}

		if (config.maxTokens !== undefined && config.maxTokens <= 0) {
			errors.push('Max tokens must be greater than 0');
		}

		return errors;
	}
}

/**
 * Convenience function to create an LLM provider
 */
export async function createLLMProvider(
	type: ProviderType,
	config?: Partial<LLMConfig>,
): Promise<LLMProvider> {
	return LLMProviderFactory.createProvider(type, config);
}
