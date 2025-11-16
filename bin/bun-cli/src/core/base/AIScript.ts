import { Script } from "./Script";
import type { ScriptDependencies, Context } from "../types";
import { OpenAIService } from "../services/OpenAIService";

/**
 * Base class for AI-related scripts
 *
 * Automatically initializes OpenAI service with defaults
 * Override via environment variables:
 * - AI_BASE_URL (default: http://localhost:1234/v1)
 * - AI_API_KEY (default: not-required)
 *
 * @example
 * @Script({ args: { ... } })
 * export class MyAIScript extends AIScript {
 *   async run(ctx: Context) {
 *     const models = await this.openai.listModels();
 *     // ...
 *   }
 * }
 */
export abstract class AIScript extends Script {
  protected readonly openai: OpenAIService;

  constructor(deps: ScriptDependencies) {
    super(deps);

    // Initialize OpenAI service directly - much simpler!
    this.openai = new OpenAIService({
      baseURL: process.env.AI_BASE_URL || "http://localhost:1234/v1",
      apiKey: process.env.AI_API_KEY || "not-required",
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
