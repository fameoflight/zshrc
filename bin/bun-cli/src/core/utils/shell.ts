import { $ } from "bun";
import type { ShellExecutor as ShellExecutorInterface, ExecResult, Logger } from "../types";

/**
 * Shell command executor using Bun's native shell
 *
 * Follows 5-parameter law: uses options object
 */
export class ShellExecutor implements ShellExecutorInterface {
  constructor(
    private deps: {
      logger: Logger;
      dryRun?: boolean;
    }
  ) {}

  /**
   * Execute shell command
   *
   * @param params Options object (follows 5-param law)
   */
  async exec(params: {
    command: string;
    description?: string;
    silent?: boolean;
    cwd?: string;
  }): Promise<ExecResult> {
    const { command, description, silent, cwd } = params;

    if (description && !silent) {
      this.deps.logger.progress(description);
    }

    if (this.deps.dryRun) {
      if (!silent) {
        console.log(`[DRY RUN] ${command}`);
      }
      return {
        success: true,
        stdout: "",
        stderr: "",
        exitCode: 0,
      };
    }

    try {
      // Use Bun's $ shell with proper template literal
      // We need to use eval-style to execute the command string
      const proc = await $`sh -c ${command}`.cwd(cwd || process.cwd()).quiet();

      return {
        success: proc.exitCode === 0,
        stdout: proc.stdout.toString().trim(),
        stderr: proc.stderr.toString().trim(),
        exitCode: proc.exitCode,
      };
    } catch (error: any) {
      return {
        success: false,
        stdout: error.stdout?.toString().trim() || "",
        stderr: error.stderr?.toString().trim() || error.message,
        exitCode: error.exitCode || 1,
      };
    }
  }

  /**
   * Execute command and throw on error
   */
  async execOrThrow(command: string, errorMessage?: string): Promise<string> {
    const result = await this.exec({ command, silent: true });

    if (!result.success) {
      throw new Error(errorMessage || result.stderr || "Command failed");
    }

    return result.stdout;
  }

  /**
   * Check if command exists in PATH
   */
  commandExists(command: string): boolean {
    try {
      const which = Bun.which(command);
      return which !== null;
    } catch {
      return false;
    }
  }
}

/**
 * Standalone exec function for simple command execution
 * Returns stdout on success, throws on error
 */
export async function exec(
  command: string,
  options?: { description?: string; cwd?: string }
): Promise<string> {
  if (options?.description) {
    console.log(`⏳ ${options.description}...`);
  }

  try {
    const proc = await $`sh -c ${command}`
      .cwd(options?.cwd || process.cwd())
      .quiet();

    if (proc.exitCode !== 0) {
      throw new Error(proc.stderr.toString().trim() || 'Command failed');
    }

    return proc.stdout.toString().trim();
  } catch (error: any) {
    throw new Error(
      error.stderr?.toString().trim() || error.message || 'Command failed'
    );
  }
}

/**
 * Standalone execSilent function for silent command execution
 * Returns stdout on success, returns empty string on error
 */
export async function execSilent(command: string): Promise<string> {
  try {
    const proc = await $`sh -c ${command}`.quiet();
    return proc.stdout.toString().trim();
  } catch (error: any) {
    return '';
  }
}
