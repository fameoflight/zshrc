import { Script } from "../../core/decorators/Script";
import { BaseScript } from "../../core/base/Script";
import { logger } from "../../core/utils/logger";
import { readdir, readFile, writeFile, stat } from "node:fs/promises";
import { join, extname } from "node:path";

interface ConsoleLogRemoverOptions {
  directory?: string;
  recursive?: boolean;
  backup?: boolean;
  dryRun?: boolean;
}

/**
 * Removes single-line console.log statements from source files
 */
@Script({
  name: "console-log-remover",
  description: "Removes single-line console.log statements from source files",
  emoji: "🧹",
  arguments: "[OPTIONS] <extension>",
  examples: [
    "console-log-remover js                              # Process .js files in current directory",
    "console-log-remover --directory src --recursive ts  # Process .ts files recursively in src/",
    "console-log-remover --backup --dry-run js           # Show what would be removed with backup",
    "console-log-remover --recursive --verbose jsx       # Process .jsx files recursively with verbose output",
  ],
  options: [
    {
      flag: "-d, --directory <dir>",
      description: "Target directory (default: current directory)",
    },
    {
      flag: "-r, --recursive",
      description: "Search recursively in subdirectories",
    },
    {
      flag: "--backup",
      description: "Create backup files before modification",
    },
    {
      flag: "--dry-run",
      description: "Show what would be removed without making changes",
    },
  ],
})
export class ConsoleLogRemoverScript extends BaseScript {
  private extension!: string;
  private targetDir!: string;
  private options: ConsoleLogRemoverOptions = {};

  async run(args: string[], options: Record<string, any>): Promise<void> {
    logger.banner("Console Log Remover");

    // Parse options
    this.options = {
      directory: options.directory,
      recursive: options.recursive || false,
      backup: options.backup || false,
      dryRun: options.dryRun || false,
    };

    // Validate arguments
    if (args.length === 0) {
      logger.error("Missing required argument: file extension");
      logger.info("Usage: console-log-remover [OPTIONS] <extension>");
      logger.info("Example: console-log-remover js");
      logger.info("Example: console-log-remover --directory src --recursive ts");
      process.exit(1);
    }

    this.extension = args[0].startsWith(".") ? args[0] : `.${args[0]}`;
    this.targetDir = this.options.directory
      ? this.options.directory
      : process.cwd();

    // Verify target directory exists
    try {
      const stats = await stat(this.targetDir);
      if (!stats.isDirectory()) {
        logger.error(`Not a directory: ${this.targetDir}`);
        process.exit(1);
      }
    } catch {
      logger.error(`Directory not found: ${this.targetDir}`);
      process.exit(1);
    }

    logger.info(`Target directory: ${this.targetDir}`);
    logger.info(`File extension: ${this.extension}`);
    logger.info(`Recursive search: ${this.options.recursive ? "Yes" : "No"}`);

    if (this.options.backup) {
      logger.info("Backup files will be created");
    }

    if (this.options.dryRun) {
      logger.warning("DRY RUN MODE - No files will be modified");
    }

    // Find target files
    const files = await this.findTargetFiles(this.targetDir);

    if (files.length === 0) {
      logger.warning(`No files found with extension '${this.extension}'`);
      return;
    }

    logger.info(`Found ${files.length} files to process`);

    // Process files
    await this.processFiles(files);

    logger.completion("Console Log Remover");
  }

  private async findTargetFiles(dir: string): Promise<string[]> {
    const files: string[] = [];

    const entries = await readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = join(dir, entry.name);

      if (entry.isDirectory() && this.options.recursive) {
        const subFiles = await this.findTargetFiles(fullPath);
        files.push(...subFiles);
      } else if (entry.isFile() && extname(entry.name) === this.extension) {
        files.push(fullPath);
      }
    }

    return files;
  }

  private async processFiles(files: string[]): Promise<void> {
    const stats = {
      filesProcessed: 0,
      logsRemoved: 0,
      filesModified: 0,
    };

    for (const file of files) {
      await this.processFile(file, stats);
    }

    logger.section("Summary");
    logger.info(`Files processed: ${stats.filesProcessed}`);
    logger.info(`Console.log statements removed: ${stats.logsRemoved}`);
    logger.info(`Files modified: ${stats.filesModified}`);
  }

  private async processFile(
    filePath: string,
    stats: { filesProcessed: number; logsRemoved: number; filesModified: number }
  ): Promise<void> {
    stats.filesProcessed++;

    try {
      const content = await readFile(filePath, "utf-8");
      const originalLines = content.split("\n");
      const modifiedLines: string[] = [];
      let logsRemovedThisFile = 0;

      for (let i = 0; i < originalLines.length; i++) {
        const line = originalLines[i];
        if (this.isConsoleLogLine(line.trim())) {
          logsRemovedThisFile++;
          logger.debug(
            `Removed console.log from ${filePath}:${i + 1}`,
            this.options.dryRun
          );
          // Skip this line (don't add to modifiedLines)
        } else {
          modifiedLines.push(line);
        }
      }

      if (logsRemovedThisFile > 0) {
        stats.logsRemoved += logsRemovedThisFile;
        stats.filesModified++;

        logger.success(
          `Removed ${logsRemovedThisFile} console.log statement(s) from ${filePath}`
        );

        if (!this.options.dryRun) {
          // Create backup if requested
          if (this.options.backup) {
            const timestamp = new Date()
              .toISOString()
              .replace(/[-:]/g, "")
              .replace(/\..+/, "");
            const backupPath = `${filePath}.backup${timestamp}`;
            await writeFile(backupPath, content);
            logger.debug(`Backed up to: ${backupPath}`, true);
          }

          // Write modified content
          await writeFile(filePath, modifiedLines.join("\n"));
          logger.debug(`Updated: ${filePath}`, true);
        }
      } else {
        logger.debug(`No console.log statements found in ${filePath}`, false);
      }
    } catch (error) {
      logger.error(
        `Failed to process ${filePath}: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private isConsoleLogLine(line: string): boolean {
    // Skip empty lines and comments
    if (
      !line ||
      line.startsWith("//") ||
      line.startsWith("/*") ||
      line.startsWith("*")
    ) {
      return false;
    }

    // Must start with console.
    if (!line.startsWith("console.")) {
      return false;
    }

    // Match various console.log patterns
    const consoleLogPatterns = [
      /^\s*console\.log\s*\(/,              // console.log(
      /^\s*console\.debug\s*\(/,            // console.debug(
      /^\s*console\.info\s*\(/,             // console.info(
      /^\s*console\.warn\s*\(/,             // console.warn(
      /^\s*console\.error\s*\(/,            // console.error(
      /^\s*console\.log\(`.*`\)\s*$/,       // console.log(`...`) - template literals
      /^\s*console\.log\('.*'\)\s*$/,       // console.log('...') - single quotes
      /^\s*console\.log\(".*"\)\s*$/,       // console.log("...") - double quotes
      /^\s*console\.log\([^)]+\)\s*$/,      // console.log(...) - general pattern
    ];

    // Check if the line matches any console.log pattern
    return consoleLogPatterns.some((pattern) => pattern.test(line));
  }
}
