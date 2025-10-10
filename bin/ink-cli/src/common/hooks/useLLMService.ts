import {useState, useEffect} from 'react';
import {LLMProvider} from '../../services/LLMProvider.js';
import {serviceContainer, registerSingleton} from '../../services/ServiceProvider.js';
import {createLLMService} from '../llm/LLMService.js';
import {createLLMProviderFromService} from '../../services/adapters/LLMServiceAdapter.js';
import {createCommandLogger} from '../logger.js';
import {PRESET_CONFIGS} from '../llm/config.js';

export interface LLMServiceFlags {
	provider?: string;
	baseurl?: string;
	apikey?: string;
	model?: string;
	'system-prompt'?: string;
	temperature?: number;
	'max-tokens'?: number;
}

export interface UseLLMServiceOptions {
	flags: LLMServiceFlags;
	defaultConfig: any;
	loggerName?: string;
}

export interface UseLLMServiceResult {
	llmProvider: LLMProvider | null;
	isInitialized: boolean;
	error: string | null;
	resolvedProvider: string;
	setError: (error: string | null) => void;
}

/**
 * useLLMService - Updated LLM service hook for new architecture
 *
 * This hook bridges the existing LLMService to the new LLMProvider interface
 * and registers the provider in the service container for dependency injection.
 *
 * @example
 * const { llmProvider, isInitialized, error } = useLLMService({
 *   flags: cliFlags,
 *   defaultConfig: DEFAULT_LLM_CONFIG
 * });
 */
export function useLLMService(
	options: UseLLMServiceOptions,
): UseLLMServiceResult {
	const {flags, defaultConfig, loggerName = 'llm-service'} = options;

	const [llmProvider, setLLMProvider] = useState<LLMProvider | null>(null);
	const [isInitialized, setIsInitialized] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [resolvedProvider, setResolvedProvider] = useState<string>(
		defaultConfig.provider || 'lmstudio',
	);

	const logger = createCommandLogger(loggerName);

	useEffect(() => {
		const initializeLLMProvider = async () => {
			try {
				let config: any;
				let providerName: string;

				// Use custom base URL if provided
				if (flags.baseurl) {
					config = {
						provider: 'custom',
						name: 'Custom API',
						baseURL: flags.baseurl,
						apiKey: flags.apikey || '',
						model: flags.model || 'default',
						temperature: flags.temperature ?? 0.7,
						maxTokens: flags['max-tokens'] ?? 2048,
						systemPrompt: flags['system-prompt'] || '',
					};
					providerName = 'custom';
				} else {
					// Use preset configuration
					const preset = flags.provider?.toLowerCase() || 'lmstudio';

					let baseConfig;

					if (preset === 'lmstudio') {
						// Use local defaultConfig for lmstudio
						baseConfig = defaultConfig;
						providerName = defaultConfig.provider || preset;
					} else {
						// Use PRESET_CONFIGS for other providers
						const presetConfig =
							PRESET_CONFIGS[preset as keyof typeof PRESET_CONFIGS];

						if (!presetConfig) {
							setError(
								`Unknown provider: ${preset}. Available: ${Object.keys(
									PRESET_CONFIGS,
								).join(', ')}`,
							);
							setIsInitialized(true);
							return;
						}

						baseConfig = presetConfig;
						providerName = presetConfig.provider || preset;
					}

					config = {
						...baseConfig,
						apiKey: flags.apikey || baseConfig.apiKey,
						model: flags.model || baseConfig.model,
						temperature: flags.temperature ?? baseConfig.temperature,
						maxTokens: flags['max-tokens'] ?? baseConfig.maxTokens,
						systemPrompt: flags['system-prompt'] || baseConfig.systemPrompt,
					};
				}

				// Set the resolved provider name
				setResolvedProvider(providerName);

				// Log configuration
				logger.info('=== LLM Configuration ===');
				logger.info(`Provider: ${providerName}`);
				logger.info(`Base URL: ${config.baseURL}`);
				logger.info(`Model: ${config.model || 'default'}`);
				logger.info(`Temperature: ${config.temperature ?? 0.7}`);
				logger.info(`Max Tokens: ${config.maxTokens || 'unlimited'}`);
				logger.info(`System Prompt: ${config.systemPrompt || '(none)'}`);
				logger.info('========================');

				// Create the existing LLM service
				const existingService = createLLMService(config);

				// Create adapter to new LLMProvider interface
				const provider = createLLMProviderFromService(existingService, {
					baseURL: config.baseURL,
					apiKey: config.apiKey,
					model: config.model,
					temperature: config.temperature,
					maxTokens: config.maxTokens,
					systemPrompt: config.systemPrompt,
				});

				// Initialize the provider
				await provider.initialize({
					baseURL: config.baseURL,
					apiKey: config.apiKey,
					model: config.model,
					temperature: config.temperature,
					maxTokens: config.maxTokens,
					systemPrompt: config.systemPrompt,
				});

				// Register in service container for dependency injection
				serviceContainer.register('llm-provider', provider);

				setLLMProvider(provider);
				setIsInitialized(true);

				// Health check using the existing service
				const isHealthy = await existingService.healthCheck();
				if (!isHealthy) {
					setError(
						`Cannot connect to LLM at ${config.baseURL}. Make sure the server is running and has loaded a model.`,
					);
				}
			} catch (err) {
				setError(err instanceof Error ? err.message : String(err));
				setIsInitialized(true);
			}
		};

		initializeLLMProvider();
	}, [flags, defaultConfig]);

	return {
		llmProvider,
		isInitialized,
		error,
		resolvedProvider,
		setError,
	};
}

