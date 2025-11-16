import { OpenAIService, type ChatMessage } from './OpenAIService';
import type { LLMService } from './LLMService';
import type { Logger } from '../types';

/**
 * Conversation message
 */
export interface ConversationMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * Conversation summary
 */
export interface ConversationSummary {
  totalMessages: number;
  userMessages: number;
  assistantMessages: number;
  hasSystemPrompt: boolean;
}

/**
 * LLM service interface for conversation
 */
interface ConversationLLMService {
  chat(params: {
    model: string;
    messages: ChatMessage[];
    temperature?: number;
    maxTokens?: number;
  }): Promise<string>;
  getCurrentModel(): string;
}

/**
 * Service for managing conversational interactions with LLM
 *
 * Maintains conversation history and provides methods for continuing conversations
 */
export class ConversationService {
  private messages: ConversationMessage[] = [];
  private systemPrompt?: string;
  private llm: ConversationLLMService;

  constructor(llmService: OpenAIService | LLMService, systemPrompt?: string) {
    this.llm = llmService as unknown as ConversationLLMService;
    this.systemPrompt = systemPrompt;

    if (systemPrompt) {
      this.addSystemMessage(systemPrompt);
    }
  }

  /**
   * Set or update the system prompt
   */
  setSystemPrompt(prompt: string): this {
    this.systemPrompt = prompt;

    // Remove any existing system message and add new one at the beginning
    this.messages = this.messages.filter((msg) => msg.role !== 'system');
    this.messages.unshift({ role: 'system', content: prompt });

    return this;
  }

  /**
   * Add a system message
   */
  addSystemMessage(content: string): this {
    this.messages.push({ role: 'system', content });
    return this;
  }

  /**
   * Add a user message to the conversation
   */
  addUserMessage(content: string): this {
    this.messages.push({ role: 'user', content });
    return this;
  }

  /**
   * Add an assistant message to the conversation
   */
  addAssistantMessage(content: string): this {
    this.messages.push({ role: 'assistant', content });
    return this;
  }

  /**
   * Send a message and get a response
   *
   * Automatically adds the user message and response to conversation history
   */
  async sendMessage(
    userMessage: string,
    options?: {
      model?: string;
      temperature?: number;
      maxTokens?: number;
    }
  ): Promise<string> {
    // Add user message to conversation
    this.addUserMessage(userMessage);

    // Send conversation to LLM
    const response = await this.llm.chat({
      model: options?.model || this.llm.getCurrentModel(),
      messages: this.messages as ChatMessage[],
      temperature: options?.temperature,
      maxTokens: options?.maxTokens,
    });

    // Add LLM response to conversation history
    this.addAssistantMessage(response);

    return response;
  }

  /**
   * Continue the conversation with a new user message
   *
   * Alias for sendMessage for clearer intent
   */
  async continue(
    userMessage: string,
    options?: {
      model?: string;
      temperature?: number;
      maxTokens?: number;
    }
  ): Promise<string> {
    return this.sendMessage(userMessage, options);
  }

  /**
   * Get the last assistant response
   */
  getLastResponse(): string | undefined {
    const assistantMessages = this.messages.filter((msg) => msg.role === 'assistant');
    return assistantMessages[assistantMessages.length - 1]?.content;
  }

  /**
   * Get the last user message
   */
  getLastUserMessage(): string | undefined {
    const userMessages = this.messages.filter((msg) => msg.role === 'user');
    return userMessages[userMessages.length - 1]?.content;
  }

  /**
   * Clear conversation history but keep system prompt
   */
  clearHistory(): this {
    const systemMsg = this.messages.find((msg) => msg.role === 'system');
    this.messages = systemMsg ? [systemMsg] : [];
    return this;
  }

  /**
   * Get all messages
   */
  getMessages(): ConversationMessage[] {
    return [...this.messages];
  }

  /**
   * Get conversation summary for display
   */
  getSummary(): ConversationSummary {
    const userCount = this.messages.filter((msg) => msg.role === 'user').length;
    const assistantCount = this.messages.filter((msg) => msg.role === 'assistant').length;

    return {
      totalMessages: this.messages.length,
      userMessages: userCount,
      assistantMessages: assistantCount,
      hasSystemPrompt: this.messages.some((msg) => msg.role === 'system'),
    };
  }
}
