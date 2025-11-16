import type { Context } from "../types";
import type { DiscoveredScript } from "./discovery";
import { parseArguments } from "./parser";
import { validateArguments } from "../decorators/Script";

/**
 * Script runner
 *
 * Orchestrates:
 * - Argument parsing
 * - Validation
 * - Script execution
 */
export class ScriptRunner {
  constructor(
    private options: {
      verbose?: boolean;
      debug?: boolean;
      dryRun?: boolean;
    } = {}
  ) {}

  /**
   * Run a script
   */
  async run(script: DiscoveredScript, argv: string[]): Promise<void> {
    try {
      // 1. Parse arguments
      const args = parseArguments(argv, script.metadata.args);

      // 2. Create context
      const ctx = this.createContext(args);

      // 3. Validate arguments
      await validateArguments(script.scriptClass, args, ctx);

      // 4. Instantiate script (no dependency injection)
      const instance = new script.scriptClass();

      // 5. Run script validation hook (if exists)
      if (instance.validate) {
        await instance.validate(ctx);
      }

      // 6. Run script
      await instance.run(ctx);
    } catch (error: any) {
      console.error(`Error: ${error.message}`);
      if (this.options.debug) {
        console.error(error.stack);
      }
      process.exit(1);
    }
  }

  /**
   * Create execution context
   */
  private createContext(args: Record<string, any>): Context {
    return {
      args,

      // Helper methods
      prompt: async (message: string, defaultValue?: string) => {
        return this.prompt(message, defaultValue);
      },

      confirm: async (message: string) => {
        return this.confirm(message);
      },

      select: async <T>(items: T[], display?: (item: T) => string) => {
        return this.select(items, display);
      },
    };
  }

  /**
   * Prompt user for input
   */
  private async prompt(message: string, defaultValue?: string): Promise<string> {
    const displayMessage = defaultValue
      ? `${message} [${defaultValue}]: `
      : `${message}: `;

    process.stdout.write(displayMessage);

    // Read from stdin
    const input = await this.readLine();
    return input.trim() || defaultValue || "";
  }

  /**
   * Confirm yes/no
   */
  private async confirm(message: string): Promise<boolean> {
    const answer = await this.prompt(`${message} (y/n)`, "y");
    return answer.toLowerCase() === "y" || answer.toLowerCase() === "yes";
  }

  /**
   * Select from list
   */
  private async select<T>(
    items: T[],
    display?: (item: T) => string
  ): Promise<T | null> {
    if (items.length === 0) {
      return null;
    }

    console.log("\nSelect an option:");
    items.forEach((item, index) => {
      const label = display ? display(item) : String(item);
      console.log(`  ${index + 1}. ${label}`);
    });

    const answer = await this.prompt("Enter number", "1");
    const index = parseInt(answer, 10) - 1;

    if (index < 0 || index >= items.length) {
      console.error("Error: Invalid selection");
      return null;
    }

    return items[index];
  }

  /**
   * Read a line from stdin
   */
  private async readLine(): Promise<string> {
    const decoder = new TextDecoder();
    const chunks: Uint8Array[] = [];

    for await (const chunk of Bun.stdin.stream()) {
      chunks.push(chunk);
      // Check if we have a newline
      const text = decoder.decode(chunk);
      if (text.includes("\n")) {
        break;
      }
    }

    const combined = new Uint8Array(chunks.reduce((acc, c) => acc + c.length, 0));
    let offset = 0;
    for (const chunk of chunks) {
      combined.set(chunk, offset);
      offset += chunk.length;
    }

    return decoder.decode(combined).trim();
  }
}
