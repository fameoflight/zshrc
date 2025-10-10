import {LLMConfig} from './LLMService.js';

/**
 * LLM Configuration Presets
 *
 * Centralized configuration for LLM services.
 * All configs should be defined here, not scattered across files.
 */

/**
 * Provider preset configurations
 * Used by useLLMService hook for --provider flag
 */
export const PRESET_CONFIGS: Record<string, LLMConfig> = {
	lmstudio: {
		provider: 'lmstudio',
		name: 'LM Studio',
		baseURL: 'http://localhost:1234',
		apiKey: 'not-needed',
		model: 'qwen/qwen3-next-80b',
		temperature: 0.7,
		maxTokens: 262144,
		systemPrompt: 'You are helpful assistant who responds in markdown.',
	},
	openai: {
		provider: 'openai',
		name: 'OpenAI',
		baseURL: 'https://api.openai.com',
		apiKey: process.env['OPENAI_API_KEY'] || '',
		model: 'gpt-3.5-turbo',
		temperature: 0.7,
		maxTokens: 2048,
		systemPrompt: 'You are a helpful assistant.',
	},
};

/**
 * Default config for llm-chat command
 * References the lmstudio preset to avoid duplication
 */
export const DEFAULT_LLM_CONFIG: LLMConfig = PRESET_CONFIGS['lmstudio']!;
