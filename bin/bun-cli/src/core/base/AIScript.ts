import { Script } from "./Script";
import type { ScriptDependencies, Context } from "../types";
import { OpenAIService } from "../services/OpenAIService";

/**
 * Configuration options for AI scripts
 */
export interface AIScriptOptions {
  /** OpenAI-compatible API endpoint */
  endpoint: string;
  /** API key for authentication */
  apiKey: string;
}

/**
 * Base class for AI-related scripts
 *
 * Requires strongly-typed options for OpenAI configuration.
 * Child classes must provide endpoint and apiKey.
 *
 * @example
 * @Script({ args: { ... } })
 * export class MyAIScript extends AIScript {
 *   constructor(deps: ScriptDependencies) {
 *     super(deps, {
 *       endpoint: process.env.AI_BASE_URL || "http://localhost:1234/v1",
 *       apiKey: process.env.AI_API_KEY || "not-required"
 *     });
 *   }
 *
 *   async run(ctx: Context) {
 *     const models = await this.openai.listModels();
 *     // ...
 *   }
 * }
 */
export abstract class AIScript extends Script {
  protected readonly openai: OpenAIService;

  constructor(deps: ScriptDependencies, opts: AIScriptOptions) {
    super(deps);

    this.openai = new OpenAIService({
      baseURL: opts.endpoint,
      apiKey: opts.apiKey,
      logger: this.logger,
    });
  }

  /**
   * Validate connection to AI service
   * Called automatically before run()
   */
  async validate(ctx: Context): Promise<void> {
    const connected = await this.openai.testConnection();
    if (!connected) {
      throw new Error(
        `Could not connect to AI service at ${this.openai.baseURL}\n` +
          `Make sure the server is running.`
      );
    }
  }

  /**
   * Helper: Get available models
   */
  protected async getAvailableModels() {
    return this.openai.listModels();
  }

  /**
   * Helper: Format model for display
   */
  protected formatModel(model: { id: string; created: Date }): string {
    return `${model.id} (${model.created.toLocaleDateString()})`;
  }

  /**
   * Helper: Create a simple chat message
   */
  protected createMessage(
    role: "system" | "user" | "assistant",
    content: string
  ) {
    return { role, content };
  }
}
