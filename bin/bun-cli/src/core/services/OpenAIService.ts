import OpenAI from "openai";
import type { Logger } from "../types";

/**
 * OpenAI-compatible service configuration
 */
export interface OpenAIServiceConfig {
  baseURL: string;
  apiKey: string;
  logger: Logger;
}

/**
 * Chat message format
 */
export type ChatMessage = OpenAI.Chat.ChatCompletionMessageParam;

/**
 * Model information
 */
export interface ModelInfo {
  id: string;
  created: Date;
  ownedBy?: string;
  raw: OpenAI.Model;
}

/**
 * OpenAI-compatible service
 *
 * Works with OpenAI API, local LLMs (LM Studio, Ollama), and other compatible endpoints
 */
export class OpenAIService {
  private client: OpenAI;
  private logger: Logger;

  constructor(config: OpenAIServiceConfig) {
    this.logger = config.logger;
    this.client = new OpenAI({
      baseURL: config.baseURL,
      apiKey: config.apiKey,
    });
  }

  /**
   * Get the base URL
   */
  get baseURL(): string {
    return this.client.baseURL;
  }

  /**
   * List available models
   */
  async listModels(): Promise<ModelInfo[]> {
    try {
      const response = await this.client.models.list();
      return response.data.map((model) => ({
        id: model.id,
        created: new Date(model.created * 1000),
        ownedBy: model.owned_by,
        raw: model,
      }));
    } catch (error: any) {
      throw new Error(`Failed to list models: ${error.message}`);
    }
  }

  /**
   * Get a specific model
   */
  async getModel(modelId: string): Promise<ModelInfo | null> {
    try {
      const model = await this.client.models.retrieve(modelId);
      return {
        id: model.id,
        created: new Date(model.created * 1000),
        ownedBy: model.owned_by,
        raw: model,
      };
    } catch (error: any) {
      this.logger.debug(`Failed to get model ${modelId}: ${error.message}`);
      return null;
    }
  }

  /**
   * Create a chat completion (non-streaming)
   */
  async chat(params: {
    model: string;
    messages: ChatMessage[];
    temperature?: number;
    maxTokens?: number;
  }): Promise<string> {
    const { model, messages, temperature, maxTokens } = params;

    try {
      const response = await this.client.chat.completions.create({
        model,
        messages,
        temperature,
        max_tokens: maxTokens,
        stream: false,
      });

      return response.choices[0]?.message?.content || "";
    } catch (error: any) {
      throw new Error(`Chat completion failed: ${error.message}`);
    }
  }

  /**
   * Create a streaming chat completion
   */
  async *chatStream(params: {
    model: string;
    messages: ChatMessage[];
    temperature?: number;
    maxTokens?: number;
  }): AsyncGenerator<string, void, unknown> {
    const { model, messages, temperature, maxTokens } = params;

    try {
      const stream = await this.client.chat.completions.create({
        model,
        messages,
        temperature,
        max_tokens: maxTokens,
        stream: true,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || "";
        if (content) {
          yield content;
        }
      }
    } catch (error: any) {
      throw new Error(`Streaming chat failed: ${error.message}`);
    }
  }

  /**
   * Create a completion (non-streaming)
   */
  async complete(params: {
    model: string;
    prompt: string;
    temperature?: number;
    maxTokens?: number;
  }): Promise<string> {
    const { model, prompt, temperature, maxTokens } = params;

    try {
      const response = await this.client.completions.create({
        model,
        prompt,
        temperature,
        max_tokens: maxTokens,
        stream: false,
      });

      return response.choices[0]?.text || "";
    } catch (error: any) {
      throw new Error(`Completion failed: ${error.message}`);
    }
  }

  /**
   * Create embeddings
   */
  async createEmbedding(params: {
    model: string;
    input: string | string[];
  }): Promise<number[][]> {
    const { model, input } = params;

    try {
      const response = await this.client.embeddings.create({
        model,
        input,
      });

      return response.data.map((item) => item.embedding);
    } catch (error: any) {
      throw new Error(`Embedding creation failed: ${error.message}`);
    }
  }

  /**
   * Test connection to the API
   */
  async testConnection(): Promise<boolean> {
    try {
      await this.listModels();
      return true;
    } catch {
      return false;
    }
  }
}
