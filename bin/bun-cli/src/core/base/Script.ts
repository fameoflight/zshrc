import type { Context, Logger, ShellExecutor, FileSystem } from "../types";
import { Logger as LoggerImpl } from "../utils/logger";
import { ShellExecutor as ShellExecutorImpl } from "../utils/shell";
import { FileSystem as FileSystemImpl } from "../utils/filesystem";

/**
 * Base script class
 *
 * Provides:
 * - Direct access to logger, shell, fs utilities
 * - Helper methods for common tasks
 *
 * @example
 * @Script({ args: { ... } })
 * export class MyScript extends Script {
 *   async run(ctx: Context) {
 *     this.logger.info("Running script");
 *   }
 * }
 */
export abstract class Script {
  protected readonly logger: Logger;
  protected readonly shell: ShellExecutor;
  protected readonly fs: FileSystem;

  constructor() {
    this.logger = new LoggerImpl({ verbose: false, debug: false });
    this.shell = new ShellExecutorImpl({ logger: this.logger, dryRun: false });
    this.fs = new FileSystemImpl();
  }

  /**
   * Main entry point - must be implemented by subclasses
   */
  abstract run(ctx: Context): Promise<void>;

  /**
   * Optional validation hook
   * Called after argument validation but before run()
   */
  async validate?(ctx: Context): Promise<void>;

  /**
   * Helper: Check if a command exists
   */
  protected requireCommand(command: string, message?: string): void {
    if (!this.shell.commandExists(command)) {
      throw new Error(message || `Required command not found: ${command}`);
    }
  }

  /**
   * Helper: Check if a file exists
   */
  protected async requireFile(path: string, message?: string): Promise<void> {
    if (!(await this.fs.exists(path))) {
      throw new Error(message || `Required file not found: ${path}`);
    }
  }

  /**
   * Helper: Check if a directory exists
   */
  protected async requireDirectory(path: string, message?: string): Promise<void> {
    if (!(await this.fs.isDirectory(path))) {
      throw new Error(message || `Required directory not found: ${path}`);
    }
  }

  /**
   * Helper: Exit with error
   */
  protected exit(message: string, code: number = 1): never {
    this.logger.error(message);
    process.exit(code);
  }
}
