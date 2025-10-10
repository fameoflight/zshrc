import {LLMProvider, LLMConfig, LLMMessage, ToolDefinition, ToolResult} from '../LLMProvider.js';
import {LLMService as ExistingLLMService, StreamChunk as ExistingStreamChunk} from '../../common/llm/LLMService.js';
import {LLMConfig as ExistingLLMConfig} from '../../common/llm/LLMService.js';

/**
 * Adapter to bridge existing LLMService to new LLMProvider interface
 *
 * This allows us to migrate to the new architecture incrementally
 * without breaking existing functionality.
 */
export class LLMServiceAdapter implements LLMProvider {
	private service: ExistingLLMService;
	private config: LLMConfig;

	constructor(service: ExistingLLMService, config: LLMConfig) {
		this.service = service;
		this.config = config;
	}

	async initialize(config: LLMConfig): Promise<void> {
		this.config = config;
		// Update the underlying service config
		this.service.updateConfig({
			provider: config.baseURL ? 'custom' : config.baseURL?.split('/')[2] || 'unknown',
			name: config.baseURL ? 'Custom API' : config.baseURL?.split('/')[2] || 'Unknown',
			baseURL: config.baseURL || '',
			apiKey: config.apiKey || '',
			model: config.model || 'default',
			temperature: config.temperature ?? 0.7,
			maxTokens: config.maxTokens || 2048,
			systemPrompt: config.systemPrompt || '',
		});
	}

	async streamChat(
		messages: LLMMessage[],
		onChunk: (chunk: any) => void,
		tools?: ToolDefinition[]
	): Promise<void> {
		// Convert new LLMMessage format to existing ChatMessage format
		const existingMessages = messages.map(msg => ({
			role: msg.role as 'user' | 'assistant' | 'system',
			content: msg.content,
		}));

		// Handle tools in the future (for now ignore)
		if (tools && tools.length > 0) {
			console.warn('[LLMServiceAdapter] Tool calling not yet supported in adapter');
		}

		// Convert new chunk format to existing chunk format
		const adapterOnChunk = (chunk: ExistingStreamChunk) => {
			onChunk({
				content: chunk.content,
				isComplete: chunk.isComplete,
				error: chunk.error,
			});
		};

		await this.service.streamChat(existingMessages, adapterOnChunk);
	}

	getConfig(): LLMConfig {
		const existingConfig = this.service.getConfig();
		return {
			baseURL: existingConfig.baseURL,
			apiKey: existingConfig.apiKey,
			model: existingConfig.model,
			temperature: existingConfig.temperature,
			maxTokens: existingConfig.maxTokens,
			systemPrompt: existingConfig.systemPrompt,
		};
	}

	async updateConfig(config: Partial<LLMConfig>): Promise<void> {
		// Update internal config
		this.config = {...this.config, ...config};

		// Convert to existing config format and update service
		const existingConfig: Partial<ExistingLLMConfig> = {};
		if (config.baseURL) existingConfig.baseURL = config.baseURL;
		if (config.apiKey) existingConfig.apiKey = config.apiKey;
		if (config.model) existingConfig.model = config.model;
		if (config.temperature !== undefined) existingConfig.temperature = config.temperature;
		if (config.maxTokens !== undefined) existingConfig.maxTokens = config.maxTokens;
		if (config.systemPrompt !== undefined) existingConfig.systemPrompt = config.systemPrompt;

		this.service.updateConfig(existingConfig);
	}

	isReady(): boolean {
		// Check if service is ready by doing a quick health check
		// For now, return true if we have a service instance
		return this.service !== null;
	}

	getProviderType(): string {
		const config = this.service.getConfig();
		return config.provider || 'unknown';
	}

	// Future features (not implemented yet)
	async executeTool(toolName: string, parameters: Record<string, any>): Promise<ToolResult> {
		throw new Error(`Tool execution not yet supported in LLMServiceAdapter. Tool: ${toolName}`);
	}

	registerTools(tools: ToolDefinition[]): void {
		console.warn('[LLMServiceAdapter] Tool registration not yet supported in adapter');
	}
}

/**
 * Factory function to create an LLMProvider from existing LLMService
 */
export function createLLMProviderFromService(
	service: ExistingLLMService,
	config: LLMConfig
): LLMProvider {
	return new LLMServiceAdapter(service, config);
}