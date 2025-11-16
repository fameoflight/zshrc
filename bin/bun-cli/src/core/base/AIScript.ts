import { Script } from "./Script";
import type { ScriptDependencies, OpenAIService, Context } from "../types";

/**
 * Base class for AI-related scripts
 *
 * Extends Script with:
 * - OpenAI service injection
 * - Connection validation
 * - Common AI helper methods
 *
 * @example
 * @Script({ args: { ... } })
 * export class MyAIScript extends AIScript {
 *   async run(ctx: Context) {
 *     const models = await ctx.openai.listModels();
 *     // ...
 *   }
 * }
 */
export abstract class AIScript extends Script {
  protected readonly openai: OpenAIService;

  constructor(deps: ScriptDependencies) {
    super(deps);

    if (!deps.openai) {
      throw new Error("OpenAIService is required for AIScript");
    }

    this.openai = deps.openai;
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
