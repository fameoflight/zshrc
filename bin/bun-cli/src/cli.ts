#!/usr/bin/env bun

import { join } from "path";
import { discoverScripts, findScript, listScripts } from "./core/runtime/discovery";
import { ScriptRunner } from "./core/runtime/runner";

/**
 * Main CLI entry point
 *
 * Usage:
 *   zsh-utils <category> <command> [args...]
 *   zsh-utils list
 *   zsh-utils help
 */
async function main() {
  const argv = process.argv.slice(2);

  // Show help if no arguments
  if (argv.length === 0 || argv[0] === "help") {
    showHelp();
    process.exit(0);
  }

  // Discover all scripts
  const scriptsDir = join(import.meta.dir, "scripts");
  const scripts = await discoverScripts(scriptsDir);

  // Handle list command
  if (argv[0] === "list") {
    listScripts(scripts);
    process.exit(0);
  }

  // Parse command format: <category> <command> [args...]
  if (argv.length < 2) {
    console.error("Error: Missing command\n");
    showHelp();
    process.exit(1);
  }

  const category = argv[0];
  const command = argv[1];
  const scriptArgs = argv.slice(2);

  // Find the script
  const script = findScript(scripts, category, command);
  if (!script) {
    console.error(`Error: Script not found: ${category}/${command}\n`);
    console.error("Run 'zsh-utils list' to see available scripts.");
    process.exit(1);
  }

  // Parse global options
  const globalOptions = {
    verbose: scriptArgs.includes("--verbose"),
    debug: scriptArgs.includes("--debug"),
    dryRun: scriptArgs.includes("--dry-run"),
  };

  // Remove global options from script args
  const filteredArgs = scriptArgs.filter(
    (arg) => !["--verbose", "--debug", "--dry-run"].includes(arg)
  );

  // Run the script
  const runner = new ScriptRunner(globalOptions);
  await runner.run(script, filteredArgs);
}

/**
 * Show help message
 */
function showHelp() {
  console.log(`
╭─────────────────────────────────────────────╮
│  ZSH Utils - Bun + TypeScript CLI System   │
╰─────────────────────────────────────────────╯

Usage:
  zsh-utils <category> <command> [args...]
  zsh-utils list
  zsh-utils help

Examples:
  zsh-utils network info
  zsh-utils git commit-dir src
  zsh-utils system largest-files --count 50

Global Options:
  --verbose    Show verbose output
  --debug      Show debug information
  --dry-run    Show what would be done without executing

Commands:
  list         List all available scripts
  help         Show this help message
`);
}

// Run CLI
main().catch((error) => {
  console.error("Fatal error:", error.message);
  if (process.env.DEBUG === "1") {
    console.error(error.stack);
  }
  process.exit(1);
});
