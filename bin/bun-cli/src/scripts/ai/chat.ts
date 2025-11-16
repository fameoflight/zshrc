import { Script } from "../../core/decorators/Script";
import { AIScript } from "../../core/base/AIScript";
import type { Context } from "../../core/types";
import type { ChatMessage } from "../../core/services/OpenAIService";
import * as clack from "@clack/prompts";

/**
 * Interactive chat with local LLM
 *
 * @example
 * chat
 * chat --system "You are a helpful coding assistant"
 */
@Script({
  emoji: "🤖",
  tags: ["ai", "interactive", "chat"],
  args: {
    systemPrompt: {
      type: "string",
      flag: "--system",
      description: "System prompt for the conversation",
    },
    temperature: {
      type: "number",
      flag: "-t, --temperature",
      min: 0,
      max: 2,
      default: 0.7,
      description: "Temperature (0.0 - 2.0)",
    },
    noStream: {
      type: "boolean",
      flag: "--no-stream",
      description: "Disable streaming responses",
    },
  },
})
export class AIChatScript extends AIScript {
  private conversationHistory: ChatMessage[] = [];
  private selectedModel: string = "";

  async run(ctx: Context): Promise<void> {
    const { systemPrompt, temperature, noStream } = ctx.args;
    const stream = !noStream;

    clack.intro("🤖 AI Chat");

    // Get and select model
    const model = await this.selectModel();
    if (!model) {
      clack.cancel("Chat cancelled");
      process.exit(0);
    }

    this.selectedModel = model;

    // Show configuration
    clack.note(
      `
Model:       ${model}
Server:      ${this.openai.baseURL}
Temperature: ${temperature}
Streaming:   ${stream ? "enabled" : "disabled"}
    `.trim(),
      "Configuration"
    );

    // Add system prompt if provided
    if (systemPrompt) {
      this.conversationHistory.push(this.createMessage("system", systemPrompt));
      clack.note(systemPrompt, "System Prompt");
    }

    // Start chat loop
    await this.chatLoop(stream, temperature);
  }

  /**
   * Select a model from available models
   */
  private async selectModel(): Promise<string | null> {
    const spinner = clack.spinner();
    spinner.start("Fetching available models...");

    try {
      const models = await this.getAvailableModels();

      if (models.length === 0) {
        spinner.stop("No models available");
        this.logger.error("No models found. Is the LLM server running?");
        return null;
      }

      spinner.stop(`Found ${models.length} model(s)`);

      const selected = await clack.select({
        message: "Select a model:",
        options: models.map((model) => ({
          value: model.id,
          label: model.id,
          hint: model.created.toLocaleDateString(),
        })),
      });

      if (clack.isCancel(selected)) {
        return null;
      }

      return selected as string;
    } catch (error: any) {
      spinner.stop("Error");
      this.logger.error(`Failed to fetch models: ${error.message}`);
      return null;
    }
  }

  /**
   * Main chat loop
   */
  private async chatLoop(stream: boolean, temperature: number): Promise<void> {
    console.log("\n💬 Chat started!");
    console.log("📝 Commands: 'exit' to quit | 'clear' to reset | 'save' to export\n");

    while (true) {
      // Show input box
      const userInput = await clack.text({
        message: "You",
        placeholder: "Type your message...",
        validate: (value) => {
          if (!value) return "Message cannot be empty";
        },
      });

      if (clack.isCancel(userInput)) {
        clack.outro("👋 Goodbye!");
        break;
      }

      const message = (userInput as string).trim();

      // Handle commands
      if (await this.handleCommand(message)) {
        continue;
      }

      // Add user message to history
      this.conversationHistory.push(this.createMessage("user", message));

      // Get AI response
      try {
        await this.getAIResponse(stream, temperature);
      } catch (error: any) {
        this.logger.error(`Failed to get response: ${error.message}`);
        // Remove failed message from history
        this.conversationHistory.pop();
      }

      console.log(); // Spacing
    }
  }

  /**
   * Handle special commands
   */
  private async handleCommand(message: string): Promise<boolean> {
    const cmd = message.toLowerCase();

    if (cmd === "exit" || cmd === "quit") {
      clack.outro("👋 Goodbye!");
      process.exit(0);
    }

    if (cmd === "clear" || cmd === "reset") {
      const systemMessages = this.conversationHistory.filter(
        (msg) => msg.role === "system"
      );
      this.conversationHistory = systemMessages;
      clack.note("Conversation history cleared", "✨ Reset");
      return true;
    }

    if (cmd === "save" || cmd === "export") {
      await this.saveConversation();
      return true;
    }

    if (cmd === "help") {
      this.showHelp();
      return true;
    }

    return false;
  }

  /**
   * Get AI response
   */
  private async getAIResponse(stream: boolean, temperature: number): Promise<void> {
    if (stream) {
      await this.getStreamingResponse(temperature);
    } else {
      await this.getNonStreamingResponse(temperature);
    }
  }

  /**
   * Get streaming response from AI
   */
  private async getStreamingResponse(temperature: number): Promise<void> {
    const spinner = clack.spinner();
    spinner.start("Thinking...");

    try {
      const streamGenerator = this.openai.chatStream({
        model: this.selectedModel,
        messages: this.conversationHistory,
        temperature,
      });

      spinner.stop("");

      // Show AI label
      console.log("\x1b[1m\x1b[36mAI:\x1b[0m"); // Bold cyan
      console.log("─".repeat(60));

      let fullResponse = "";

      for await (const chunk of streamGenerator) {
        process.stdout.write(chunk);
        fullResponse += chunk;
      }

      console.log("\n" + "─".repeat(60));

      // Add assistant message to history
      this.conversationHistory.push(this.createMessage("assistant", fullResponse));
    } catch (error: any) {
      spinner.stop("Error");
      throw error;
    }
  }

  /**
   * Get non-streaming response from AI
   */
  private async getNonStreamingResponse(temperature: number): Promise<void> {
    const spinner = clack.spinner();
    spinner.start("Thinking...");

    try {
      const response = await this.openai.chat({
        model: this.selectedModel,
        messages: this.conversationHistory,
        temperature,
      });

      spinner.stop("");

      // Show response box
      console.log("\x1b[1m\x1b[36mAI:\x1b[0m"); // Bold cyan
      console.log("─".repeat(60));
      console.log(response);
      console.log("─".repeat(60));

      // Add assistant message to history
      this.conversationHistory.push(this.createMessage("assistant", response));
    } catch (error: any) {
      spinner.stop("Error");
      throw error;
    }
  }

  /**
   * Save conversation to file
   */
  private async saveConversation(): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const filename = `chat-${timestamp}.json`;

    const data = {
      model: this.selectedModel,
      server: this.openai.baseURL,
      timestamp: new Date().toISOString(),
      messages: this.conversationHistory,
    };

    try {
      await this.fs.writeFile(filename, JSON.stringify(data, null, 2));
      clack.note(`Saved to ${filename}`, "💾 Export");
    } catch (error: any) {
      this.logger.error(`Failed to save: ${error.message}`);
    }
  }

  /**
   * Show help message
   */
  private showHelp(): void {
    clack.note(
      `
Commands:
  exit, quit    - Exit the chat
  clear, reset  - Clear conversation history
  save, export  - Save conversation to JSON file
  help          - Show this help message
    `.trim(),
      "📚 Help"
    );
  }
}
