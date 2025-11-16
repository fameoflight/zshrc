import { OpenAIService, type ChatMessage } from './OpenAIService';
import type { Logger } from '../types';

/**
 * LLM provider configuration
 */
export interface LLMProvider {
  name: string;
  baseURL: string;
  requiresApiKey: boolean;
  defaultModel?: string;
}

/**
 * Supported LLM providers
 */
export const LLM_PROVIDERS: Record<string, LLMProvider> = {
  ollama: {
    name: 'Ollama',
    baseURL: 'http://localhost:11434/v1',
    requiresApiKey: false,
    defaultModel: 'llama3:70b',
  },
  lm_studio: {
    name: 'LM Studio',
    baseURL: 'http://localhost:1234/v1',
    requiresApiKey: false,
    defaultModel: 'local-model',
  },
  openai: {
    name: 'OpenAI',
    baseURL: 'https://api.openai.com/v1',
    requiresApiKey: true,
    defaultModel: 'gpt-4',
  },
  openrouter: {
    name: 'OpenRouter',
    baseURL: 'https://openrouter.ai/api/v1',
    requiresApiKey: true,
    defaultModel: 'anthropic/claude-3.5-sonnet',
  },
};

/**
 * Parsed model specification
 */
export interface ModelSpecification {
  provider: string;
  model: string;
  fullSpec: string;
}

/**
 * LLM service options
 */
export interface LLMServiceOptions {
  model?: string;
  apiKey?: string;
  logger: Logger;
  debug?: boolean;
  temperature?: number;
  maxTokens?: number;
}

/**
 * Unified LLM service that supports multiple providers
 *
 * Supports model specifications in format:
 * - provider:model (e.g., "ollama:llama3:70b")
 * - provider:model:variant (e.g., "ollama:llama3:70b")
 * - Just model name (defaults to ollama)
 *
 * Supported providers:
 * - ollama: Local Ollama instance (http://localhost:11434)
 * - lm_studio: Local LM Studio (http://localhost:1234)
 * - openai: OpenAI API
 * - openrouter: OpenRouter API
 */
export class LLMService {
  private service: OpenAIService;
  private modelSpec: ModelSpecification;
  private logger: Logger;
  private temperature: number;
  private maxTokens: number;

  constructor(options: LLMServiceOptions) {
    this.logger = options.logger;
    this.temperature = options.temperature ?? 0.7;
    this.maxTokens = options.maxTokens ?? 4096;

    // Parse model specification
    const modelString = options.model || process.env.MODEL || 'ollama:llama3:70b';
    this.modelSpec = this.parseModelSpecification(modelString);

    // Get provider config
    const providerConfig = LLM_PROVIDERS[this.modelSpec.provider];
    if (!providerConfig) {
      throw new Error(`Unsupported provider: ${this.modelSpec.provider}`);
    }

    // Create OpenAI-compatible service
    const apiKey = options.apiKey || this.getApiKeyForProvider(this.modelSpec.provider);

    if (providerConfig.requiresApiKey && !apiKey) {
      throw new Error(
        `API key required for ${providerConfig.name}. Set ${this.modelSpec.provider.toUpperCase()}_API_KEY environment variable.`
      );
    }

    this.service = new OpenAIService({
      baseURL: providerConfig.baseURL,
      apiKey: apiKey || 'not-needed',
      logger: this.logger,
    });

    if (options.debug) {
      this.logger.debug(
        `Initialized LLM service: ${this.modelSpec.provider}:${this.modelSpec.model}`
      );
    }
  }

  /**
   * Check if the service is available
   */
  async available(): Promise<boolean> {
    try {
      return await this.service.testConnection();
    } catch {
      return false;
    }
  }

  /**
   * Get the current provider name
   */
  getCurrentProvider(): string {
    return this.modelSpec.provider;
  }

  /**
   * Get the current model name
   */
  getCurrentModel(): string {
    return this.modelSpec.model;
  }

  /**
   * Get the full model specification
   */
  getModelSpecification(): string {
    return this.modelSpec.fullSpec;
  }

  /**
   * Send a chat request
   */
  async chat(
    messages: ChatMessage[],
    options?: {
      temperature?: number;
      maxTokens?: number;
    }
  ): Promise<string> {
    return this.service.chat({
      model: this.modelSpec.model,
      messages,
      temperature: options?.temperature ?? this.temperature,
      maxTokens: options?.maxTokens ?? this.maxTokens,
    });
  }

  /**
   * Send a streaming chat request
   */
  async *chatStream(
    messages: ChatMessage[],
    options?: {
      temperature?: number;
      maxTokens?: number;
    }
  ): AsyncGenerator<string, void, unknown> {
    yield* this.service.chatStream({
      model: this.modelSpec.model,
      messages,
      temperature: options?.temperature ?? this.temperature,
      maxTokens: options?.maxTokens ?? this.maxTokens,
    });
  }

  /**
   * Send a completion request
   */
  async complete(
    prompt: string,
    options?: {
      temperature?: number;
      maxTokens?: number;
    }
  ): Promise<string> {
    return this.service.complete({
      model: this.modelSpec.model,
      prompt,
      temperature: options?.temperature ?? this.temperature,
      maxTokens: options?.maxTokens ?? this.maxTokens,
    });
  }

  /**
   * Get available models from the current provider
   */
  async listModels(): Promise<string[]> {
    try {
      const models = await this.service.listModels();
      return models.map((m) => m.id);
    } catch {
      return [];
    }
  }

  /**
   * Parse model specification string
   *
   * Formats supported:
   * - provider:model (e.g., "ollama:llama3")
   * - provider:model:variant (e.g., "ollama:llama3:70b")
   * - model (defaults to ollama)
   */
  private parseModelSpecification(modelSpec: string): ModelSpecification {
    if (!modelSpec) {
      return {
        provider: 'ollama',
        model: 'llama3:70b',
        fullSpec: 'ollama:llama3:70b',
      };
    }

    const parts = modelSpec.split(':');

    if (parts.length === 1) {
      // Just model name, default to ollama
      return {
        provider: 'ollama',
        model: parts[0],
        fullSpec: `ollama:${parts[0]}`,
      };
    }

    const provider = parts[0];
    const model = parts.slice(1).join(':');

    // Validate provider
    if (!LLM_PROVIDERS[provider]) {
      this.logger.warn(`Unsupported provider '${provider}', falling back to ollama`);
      return {
        provider: 'ollama',
        model: modelSpec,
        fullSpec: `ollama:${modelSpec}`,
      };
    }

    return {
      provider,
      model,
      fullSpec: modelSpec,
    };
  }

  /**
   * Get API key for a provider from environment
   */
  private getApiKeyForProvider(provider: string): string | undefined {
    const envVarName = `${provider.toUpperCase()}_API_KEY`;
    return process.env[envVarName];
  }
}
