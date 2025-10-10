import {StreamChunk} from '../common/llm/index.js';

export interface LLMConfig {
	baseURL?: string;
	apiKey?: string;
	model?: string;
	temperature?: number;
	maxTokens?: number;
	systemPrompt?: string;
}

export interface LLMMessage {
	role: 'user' | 'assistant' | 'system';
	content: string;
}

export interface ToolDefinition {
	name: string;
	description: string;
	parameters: Record<string, any>;
}

export interface ToolResult {
	toolName: string;
	result: any;
	error?: string;
}

/**
 * Injectable LLM Service Interface
 *
 * This interface provides a contract for LLM services that can be injected
 * into any interactive command. Commands can optionally use LLM capabilities
 * without being tied to a specific implementation.
 */
export interface LLMProvider {
	/**
	 * Initialize the LLM provider with configuration
	 */
	initialize(config: LLMConfig): Promise<void>;

	/**
	 * Stream chat completion with messages
	 */
	streamChat(
		messages: LLMMessage[],
		onChunk: (chunk: StreamChunk) => void,
		tools?: ToolDefinition[]
	): Promise<void>;

	/**
	 * Get current LLM configuration
	 */
	getConfig(): LLMConfig;

	/**
	 * Update configuration (for runtime changes like temperature)
	 */
	updateConfig(config: Partial<LLMConfig>): Promise<void>;

	/**
	 * Check if provider is ready for use
	 */
	isReady(): boolean;

	/**
	 * Get provider name/type (e.g., 'openai', 'lmstudio', 'ollama')
	 */
	getProviderType(): string;

	// Optional advanced features for future tool calling

	/**
	 * Execute a tool call (for when LLMs can call tools directly)
	 */
	executeTool?(
		toolName: string,
		parameters: Record<string, any>
	): Promise<ToolResult>;

	/**
	 * Register available tools for this provider
	 */
	registerTools?(tools: ToolDefinition[]): void;
}

/**
 * Factory function type for creating LLM providers
 */
export type LLMProviderFactory = (
	providerType: string,
	config: LLMConfig
) => Promise<LLMProvider>;

/**
 * Default no-op LLM provider for graceful degradation
 */
export class NoOpLLMProvider implements LLMProvider {
	async initialize(): Promise<void> {
		// Do nothing
	}

	async streamChat(
		messages: LLMMessage[],
		onChunk: (chunk: StreamChunk) => void
	): Promise<void> {
		// Send a simple response indicating LLM is not available
		onChunk({
			content: 'LLM service not available. Please install or configure an LLM provider.',
			isComplete: true,
		});
	}

	getConfig(): LLMConfig {
		return {};
	}

	async updateConfig(): Promise<void> {
		// Do nothing
	}

	isReady(): boolean {
		return false;
	}

	getProviderType(): string {
		return 'noop';
	}
}