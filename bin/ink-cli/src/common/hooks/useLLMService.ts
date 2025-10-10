import {useState, useEffect} from 'react';
import {createLLMService, LLMConfig} from '../llm/index.js';
import {LLMService} from '../llm/LLMService.js';
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
	defaultConfig: LLMConfig;
	loggerName?: string;
}

export interface UseLLMServiceResult {
	llmService: LLMService | null;
	isInitialized: boolean;
	error: string | null;
	resolvedProvider: string;
	setError: (error: string | null) => void;
}

/**
 * useLLMService - LLM service initialization and management
 *
 * Handles configuration resolution, provider setup, and health checks.
 * Supports preset configurations and custom configs.
 *
 * @example
 * const { llmService, isInitialized, error } = useLLMService({
 *   flags: cliFlags,
 *   defaultConfig: DEFAULT_LLM_CONFIG
 * });
 */
export function useLLMService(
	options: UseLLMServiceOptions,
): UseLLMServiceResult {
	const {flags, defaultConfig, loggerName = 'llm-service'} = options;

	const [llmService, setLLMService] = useState<LLMService | null>(null);
	const [isInitialized, setIsInitialized] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [resolvedProvider, setResolvedProvider] = useState<string>(
		defaultConfig.provider || 'lmstudio',
	);

	const logger = createCommandLogger(loggerName);

	useEffect(() => {
		try {
			let config: LLMConfig;
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

			const service = createLLMService(config);
			setLLMService(service);
			setIsInitialized(true);

			// Health check
			service.healthCheck().then(isHealthy => {
				if (!isHealthy) {
					setError(
						`Cannot connect to LLM at ${config.baseURL}. Make sure the server is running and has loaded a model.`,
					);
				}
			});
		} catch (err) {
			setError(err instanceof Error ? err.message : String(err));
			setIsInitialized(true);
		}
	}, [flags, defaultConfig]);

	return {
		llmService,
		isInitialized,
		error,
		resolvedProvider,
		setError,
	};
}
