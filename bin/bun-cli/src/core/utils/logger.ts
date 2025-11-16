import type { Logger as LoggerInterface } from "../types";

/**
 * Logger implementation with emoji indicators and colors
 *
 * Simple, no dependencies, just ANSI escape codes
 */
export class Logger implements LoggerInterface {
  private verbose: boolean;
  private debug: boolean;

  constructor(params: { verbose?: boolean; debug?: boolean } = {}) {
    this.verbose = params.verbose ?? false;
    this.debug = params.debug ?? (process.env.DEBUG === "1");
  }

  info(message: string): void {
    console.log(`ℹ️  ${this.blue(message)}`);
  }

  success(message: string): void {
    console.log(`✅ ${this.green(message)}`);
  }

  warn(message: string): void {
    console.log(`⚠️  ${this.yellow(message)}`);
  }

  error(message: string): void {
    console.error(`❌ ${this.red(message)}`);
  }

  progress(message: string): void {
    console.log(`🔄 ${this.cyan(message)}`);
  }

  section(title: string): void {
    console.log(`\n🔧 ${this.magenta(title)}`);
  }

  banner(title: string): void {
    const line = "=".repeat(60);
    console.log(`\n${line}\n  ${title}\n${line}\n`);
  }

  debug(message: string): void {
    if (this.debug) {
      console.log(`🐛 ${this.dim(message)}`);
    }
  }

  // Color helpers
  private blue(s: string): string {
    return `\x1b[34m${s}\x1b[0m`;
  }

  private green(s: string): string {
    return `\x1b[32m${s}\x1b[0m`;
  }

  private yellow(s: string): string {
    return `\x1b[33m${s}\x1b[0m`;
  }

  private red(s: string): string {
    return `\x1b[31m${s}\x1b[0m`;
  }

  private cyan(s: string): string {
    return `\x1b[36m${s}\x1b[0m`;
  }

  private magenta(s: string): string {
    return `\x1b[35m${s}\x1b[0m`;
  }

  private dim(s: string): string {
    return `\x1b[2m${s}\x1b[0m`;
  }
}
