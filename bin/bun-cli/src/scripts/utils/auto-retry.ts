import { Script } from "../../core/decorators/Script";
import { AIScript } from "../../core/base/AIScript";
import type { Context } from "../../core/types";
import { $ } from "bun";

interface ErrorDetails {
  command: string;
  exitCode: number;
  stdout: string;
  stderr: string;
  duration: number;
  attempt: number;
}

interface RetryDecision {
  shouldRetry: boolean;
  reason: string;
}

/**
 * Auto-retry utility that uses LLM to analyze command failures and determine retry strategies
 *
 * Features:
 * - Automatically reruns failed commands
 * - Uses LLM to analyze errors and determine if retry is worthwhile
 * - Supports simple retry mode (no LLM analysis)
 * - Configurable max retries and delay
 * - Multiple LLM provider support (OpenAI-compatible)
 *
 * @example
 * auto-retry -- npm install                              # Retry npm install on failure
 * auto-retry --max-retries 5 -- git push                # Retry up to 5 times
 * auto-retry --delay 2.5 -- curl https://api.example.com # Wait 2.5s between retries
 * auto-retry --no-analysis -- flaky-command             # Simple retry without AI
 */
@Script({
  emoji: "🔄",
  tags: ["utils", "retry", "ai"],
  args: {
    command: {
      type: "array",
      position: 0,
      required: true,
      description: "Command to retry (use -- to separate from options)",
    },
    maxRetries: {
      type: "integer",
      flag: "-m, --max-retries",
      default: 3,
      min: 1,
      max: 10,
      description: "Maximum retry attempts",
    },
    delay: {
      type: "number",
      flag: "-d, --delay",
      default: 1.0,
      min: 0,
      description: "Delay between retries in seconds",
    },
    noAnalysis: {
      type: "boolean",
      flag: "--no-analysis",
      description: "Skip LLM analysis, just retry on any failure",
    },
  },
})
export class AutoRetry extends AIScript {
  private maxRetries!: number;
  private retryDelay!: number;
  private noAnalysis!: boolean;
  private command!: string;
  private currentAttempt: number = 0;
  private lastError?: ErrorDetails;
  private selectedModel: string = "";

  constructor() {
    super({
      endpoint: process.env.AI_BASE_URL || "http://localhost:1234/v1",
      apiKey: process.env.AI_API_KEY || "not-required",
    });
  }

  // Override validate to make it optional - we'll fall back gracefully if LLM is unavailable
  async validate(ctx: Context): Promise<void> {
    // Skip AI service validation - we'll check connection when needed
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Auto-Retry Command");

    // Parse arguments
    this.maxRetries = ctx.args.maxRetries;
    this.retryDelay = ctx.args.delay;
    this.noAnalysis = ctx.args.noAnalysis;

    // Get command from args (everything after --)
    const args = process.argv.slice(2);
    const separatorIndex = args.indexOf("--");

    if (separatorIndex === -1 || separatorIndex === args.length - 1) {
      this.logger.error("No command specified. Use -- to separate options from the command.");
      this.showExamples();
      process.exit(1);
    }

    const commandParts = args.slice(separatorIndex + 1);
    this.command = commandParts.join(" ");

    this.logger.info(`Command: ${this.command}`);
    this.logger.info(`Max retries: ${this.maxRetries}`);
    this.logger.info(`Analysis: ${this.noAnalysis ? "disabled" : "enabled"}`);

    let success = false;
    this.currentAttempt = 0;

    while (this.currentAttempt <= this.maxRetries && !success) {
      this.currentAttempt++;
      const attemptLabel =
        this.currentAttempt === 1
          ? "Initial attempt"
          : `Retry ${this.currentAttempt - 1}/${this.maxRetries}`;

      this.logger.section(attemptLabel);

      success = await this.executeCommandAttempt();

      if (success) {
        this.logger.success(`Command succeeded on attempt ${this.currentAttempt}`);
        break;
      } else if (this.currentAttempt <= this.maxRetries) {
        await this.handleFailure();
      } else {
        this.logger.error(`Command failed after ${this.maxRetries + 1} attempts`);
        process.exit(1);
      }
    }

    this.logger.success("Auto-retry command complete");
  }

  private async executeCommandAttempt(): Promise<boolean> {
    this.logger.progress(`Executing: ${this.command}`);

    const startTime = Date.now();

    try {
      console.log("\n--- Command Output ---");

      // Execute command and capture output
      const result = await $`sh -c ${this.command}`.nothrow();

      const duration = (Date.now() - startTime) / 1000;

      if (result.exitCode === 0) {
        this.logger.success(`Command completed successfully in ${duration.toFixed(2)}s`);
        return true;
      } else {
        this.logger.error(`Command failed with exit code ${result.exitCode} after ${duration.toFixed(2)}s`);

        // Store error details for analysis
        this.lastError = {
          command: this.command,
          exitCode: result.exitCode,
          stdout: result.stdout.toString(),
          stderr: result.stderr.toString(),
          duration,
          attempt: this.currentAttempt,
        };

        return false;
      }
    } catch (error) {
      const duration = (Date.now() - startTime) / 1000;
      this.logger.error(`Command execution error after ${duration.toFixed(2)}s`);

      this.lastError = {
        command: this.command,
        exitCode: -1,
        stdout: "",
        stderr: (error as Error).message,
        duration,
        attempt: this.currentAttempt,
      };

      return false;
    }
  }

  private async handleFailure(): Promise<void> {
    if (this.currentAttempt <= this.maxRetries) {
      const shouldRetry = await this.shouldRetryCommand();

      if (shouldRetry) {
        if (this.retryDelay > 0) {
          this.logger.info(`Will retry in ${this.retryDelay} seconds...`);
          await new Promise(resolve => setTimeout(resolve, this.retryDelay * 1000));
        }
      } else {
        this.logger.warn("Analysis suggests not to retry this error");
        process.exit(1);
      }
    }
  }

  private async shouldRetryCommand(): Promise<boolean> {
    if (this.noAnalysis) {
      return true;
    }

    // Try to get a model if we don't have one
    if (!this.selectedModel) {
      try {
        const models = await this.getAvailableModels();
        if (models.length > 0) {
          this.selectedModel = models[0].id;
        } else {
          this.logger.warn("No LLM models available, falling back to simple retry");
          return true;
        }
      } catch (error) {
        this.logger.warn("Could not connect to LLM service, falling back to simple retry");
        return true;
      }
    }

    this.logger.progress("Analyzing error with LLM...");

    try {
      const analysisPrompt = this.buildErrorAnalysisPrompt();
      const response = await this.openai.complete({
        model: this.selectedModel,
        prompt: analysisPrompt,
        temperature: 0.3,
        maxTokens: 500,
      });

      this.logger.debug(`LLM response: ${response}`);

      // Parse the response to determine if we should retry
      const decision = this.parseRetryDecision(response);

      if (decision.shouldRetry) {
        this.logger.info(`✅ LLM recommends retry: ${decision.reason}`);
      } else {
        this.logger.warn(`❌ LLM recommends not to retry: ${decision.reason}`);
      }

      return decision.shouldRetry;
    } catch (error) {
      this.logger.warn(`Error during LLM analysis: ${(error as Error).message}`);
      this.logger.info("Falling back to simple retry");
      return true; // Default to retry on analysis failure
    }
  }

  private buildErrorAnalysisPrompt(): string {
    if (!this.lastError) {
      return "";
    }

    const { command, exitCode, stderr, stdout, duration, attempt } = this.lastError;

    return `Analyze this command failure and determine if it should be retried:

Command: ${command}
Exit Code: ${exitCode}
Attempt: ${attempt}/${this.maxRetries + 1}
Duration: ${duration.toFixed(2)}s

STDERR:
${stderr.trim() || "(empty)"}

STDOUT:
${stdout.trim() || "(empty)"}

Please analyze this error and respond with:
1. DECISION: Either "RETRY" or "STOP"
2. REASON: Brief explanation of why

Consider these factors:
- Network/connectivity issues → usually worth retrying
- Rate limiting/throttling → usually worth retrying
- Temporary resource unavailability → usually worth retrying
- Invalid syntax/arguments → not worth retrying
- Missing files/permissions → not worth retrying
- Authentication failures → not worth retrying

Format your response as:
DECISION: [RETRY|STOP]
REASON: [your explanation]`;
  }

  private parseRetryDecision(response: string): RetryDecision {
    // Look for DECISION line
    const decisionMatch = response.match(/^DECISION:\s*(RETRY|STOP)/im);
    const reasonMatch = response.match(/^REASON:\s*(.+)$/im);

    const shouldRetry = decisionMatch ? decisionMatch[1].toUpperCase() === "RETRY" : true;
    const reason = reasonMatch ? reasonMatch[1].trim() : "Analysis completed";

    return { shouldRetry, reason };
  }

  private showExamples(): void {
    console.log("\nExamples:");
    console.log("  auto-retry -- npm install                              # Retry npm install on failure");
    console.log("  auto-retry --max-retries 5 -- git push                # Retry up to 5 times");
    console.log("  auto-retry --delay 2.5 -- curl https://api.example.com # Wait 2.5s between retries");
    console.log("  auto-retry --no-analysis -- flaky-command             # Simple retry without AI");
    console.log("");
    console.log("Note: Use -- to separate script options from the command to retry");
  }
}
