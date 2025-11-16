import { Script } from "../../core/decorators/Script";
import { BaseScript } from "../../core/base/Script";
import { logger } from "../../core/utils/logger";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative, basename, extname } from "node:path";
import { existsSync } from "node:fs";
import * as readline from "node:readline/promises";

/**
 * Merge markdown files with their references into a single file
 */
@Script({
  name: "merge-markdown",
  description: "Merges markdown files into a single document",
  emoji: "📚",
  arguments: "<input_file> [output_file]",
  examples: [
    "merge-markdown README.md",
    "merge-markdown docs/main.md merged_docs.md",
    "merge-markdown --dry-run --preserve-structure project.md",
    "merge-markdown --no-recursive simple.md",
  ],
  options: [
    {
      flag: "-p, --preserve-structure",
      description: "Preserve directory structure in headers",
    },
    {
      flag: "-r, --recursive",
      description: "Recursively scan referenced markdown files (default: true)",
    },
    {
      flag: "--no-recursive",
      description: "Disable recursive scanning",
    },
    {
      flag: "-o, --overwrite",
      description: "Overwrite output file if it exists",
    },
  ],
})
export class MergeMarkdownScript extends BaseScript {
  private inputFile!: string;
  private outputFile!: string;
  private baseDir!: string;
  private processedFiles = new Set<string>();
  private fileOrder: string[] = [];
  private fileContents = new Map<string, string>();
  private options: {
    preserveStructure: boolean;
    recursive: boolean;
    overwrite: boolean;
  } = {
    preserveStructure: false,
    recursive: true,
    overwrite: false,
  };

  async run(args: string[], options: Record<string, any>): Promise<void> {
    logger.banner("Merge Markdown Files");

    // Parse options
    this.options = {
      preserveStructure: options.preserveStructure || false,
      recursive: options.recursive !== false, // Default to true unless explicitly disabled
      overwrite: options.overwrite || false,
    };

    // Validate arguments
    if (args.length === 0) {
      logger.error("Input file is required");
      logger.info("Usage: merge-markdown <input_file> [output_file]");
      process.exit(1);
    }

    this.inputFile = args[0];
    if (!existsSync(this.inputFile)) {
      logger.error(`Input file not found: ${this.inputFile}`);
      process.exit(1);
    }

    if (extname(this.inputFile).toLowerCase() !== ".md") {
      logger.error("Input file must be a markdown (.md) file");
      process.exit(1);
    }

    // Set output file
    if (args.length > 1) {
      this.outputFile = args[1];
    } else {
      const inputBasename = basename(this.inputFile, ".md");
      this.outputFile = join(dirname(this.inputFile), `${inputBasename}-merged.md`);
    }

    // Ensure output file has .md extension
    if (!this.outputFile.endsWith(".md")) {
      this.outputFile += ".md";
    }

    // Check if output file exists
    if (existsSync(this.outputFile) && !this.options.overwrite) {
      logger.error(`Output file '${this.outputFile}' already exists. Use --overwrite to replace.`);
      process.exit(1);
    }

    this.baseDir = dirname(this.inputFile);

    // Collect files
    logger.progress("Scanning for referenced files...");
    await this.scanFile(this.inputFile);

    if (this.fileOrder.length === 0) {
      logger.error("No files found to merge");
      process.exit(1);
    }

    logger.info(`Found ${this.fileOrder.length} files:`);
    this.fileOrder.forEach((file) => console.log(`  📄 ${this.relativePath(file)}`));

    if (options.dryRun) {
      logger.info("[DRY-RUN] Would create merged file");
      logger.completion("Merge Markdown Files");
      return;
    }

    // Confirm action
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    const answer = await rl.question(
      `\nMerge ${this.fileOrder.length} files into '${this.outputFile}'? (y/N): `
    );
    rl.close();

    if (answer.toLowerCase() !== "y") {
      logger.info("Operation cancelled");
      return;
    }

    // Merge files
    await this.mergeFiles();

    logger.completion("Merge Markdown Files");
  }

  private async scanFile(filePath: string): Promise<void> {
    if (this.processedFiles.has(filePath)) {
      return;
    }

    logger.debug(`Scanning: ${filePath}`, false);
    this.processedFiles.add(filePath);
    this.fileOrder.push(filePath);

    if (!existsSync(filePath)) {
      logger.warning(`Referenced file not found: ${filePath}`);
      return;
    }

    const content = await readFile(filePath, "utf-8");
    this.fileContents.set(filePath, content);

    if (!this.options.recursive) {
      return;
    }

    // Find markdown file references
    const references = this.findMarkdownReferences(content, dirname(filePath));
    for (const ref of references) {
      await this.scanFile(ref);
    }
  }

  private findMarkdownReferences(content: string, baseDir: string): string[] {
    const references: string[] = [];

    // Match markdown links: [text](path.md) or [text](./path.md) or [text](../path.md)
    const linkRegex = /\[([^\]]*)\]\(([^)]+\.md)\)/gi;
    let match;
    while ((match = linkRegex.exec(content)) !== null) {
      const path = match[2];
      const fullPath = path.startsWith("/")
        ? path
        : join(baseDir, path);

      if (existsSync(fullPath)) {
        references.push(fullPath);
      }
    }

    // Match file includes: <!-- include: path.md --> or similar
    const includeRegex = /<!--\s*include:\s*([^>]+\.md)\s*-->/gi;
    while ((match = includeRegex.exec(content)) !== null) {
      const path = match[1].trim();
      const fullPath = path.startsWith("/")
        ? path
        : join(baseDir, path);

      if (existsSync(fullPath)) {
        references.push(fullPath);
      }
    }

    return [...new Set(references)]; // Remove duplicates
  }

  private async mergeFiles(): Promise<void> {
    logger.progress("Creating merged file...");

    const sections: string[] = [];

    // Write header
    sections.push("# Merged Documentation\n");
    sections.push(`Generated on: ${new Date().toLocaleString()}`);
    sections.push(`Source file: ${this.relativePath(this.inputFile)}`);
    sections.push(`Files merged: ${this.fileOrder.length}\n`);
    sections.push("---\n");

    // Write files in discovery order
    for (const filePath of this.fileOrder) {
      sections.push(this.createFileSection(filePath));
    }

    await writeFile(this.outputFile, sections.join("\n"));

    logger.fileCreated(this.outputFile);
    logger.success(`Merged ${this.fileOrder.length} files into ${this.relativePath(this.outputFile)}`);
  }

  private createFileSection(filePath: string): string {
    const relativePath = this.relativePath(filePath);
    const content = this.fileContents.get(filePath) || "";

    // Create section header
    let header: string;
    if (this.options.preserveStructure) {
      header = `# ${relativePath}`;
    } else {
      const name = basename(filePath, ".md")
        .replace(/[-_]/g, " ")
        .split(" ")
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(" ");
      header = `# ${name}`;
    }

    const lines = content.split("\n");

    // Skip first line if it's an H1 header to avoid duplication
    const contentLines = lines[0]?.startsWith("# ") ? lines.slice(1) : lines;

    return `${header}\n\n**Source:** \`${relativePath}\`\n\n${contentLines.join("\n")}\n\n---\n`;
  }

  private relativePath(filePath: string): string {
    return relative(this.baseDir, filePath);
  }
}
