import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import * as path from "path";

interface FileMetrics {
  path: string;
  size: number;
  lines: number;
}

/**
 * Find largest files while respecting .gitignore patterns
 *
 * Features:
 * - Sort by lines (default) or file size
 * - Respects .gitignore patterns
 * - Filter by minimum size or lines
 * - Include/exclude hidden files
 * - Shows total statistics
 *
 * @example
 * largest-files                    # Show 20 files with most lines in current directory
 * largest-files -s                 # Show 20 largest files by size in current directory
 * largest-files /path/to/dir       # Show files with most lines in specific directory
 * largest-files -n 50              # Show 50 files with most lines
 * largest-files -s -n 50           # Show 50 largest files by size
 * largest-files -m 10M             # Show files larger than 10MB (requires -s)
 * largest-files --min-lines 100    # Show files with at least 100 lines
 * largest-files --hidden           # Include hidden files
 * largest-files --no-gitignore     # Ignore .gitignore patterns
 * largest-files -n 10 -s -m 5M /path # Custom options with directory
 */
@Script({
  emoji: "📊",
  tags: ["utils", "files"],
  args: {
    directory: {
      type: "string",
      position: 0,
      required: false,
      description: "Directory to analyze (defaults to current directory)",
    },
    count: {
      type: "integer",
      flag: "-n, --count",
      default: 20,
      description: "Number of files to show",
    },
    size: {
      type: "boolean",
      flag: "-s, --size",
      description: "Sort by file size instead of number of lines",
    },
    minSize: {
      type: "string",
      flag: "-m, --min-size",
      description: "Minimum file size to consider (e.g., 1M, 100K)",
    },
    minLines: {
      type: "integer",
      flag: "--min-lines",
      description: "Minimum number of lines to consider",
    },
    hidden: {
      type: "boolean",
      flag: "--hidden",
      description: "Include hidden files and directories",
    },
    noGitignore: {
      type: "boolean",
      flag: "--no-gitignore",
      description: "Ignore .gitignore patterns",
    },
  },
})
export class LargestFiles extends ScriptBase {
  private directory!: string;
  private count!: number;
  private minSizeBytes: number = 0;
  private minLines: number = 0;
  private sortBySize: boolean = false;
  private includeHidden: boolean = false;
  private respectGitignore: boolean = true;
  private gitignorePatterns: GitignorePattern[] = [];

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Finding Largest Files");

    // Parse arguments
    this.directory = ctx.args.directory || process.cwd();
    this.count = ctx.args.count;
    this.sortBySize = ctx.args.size || false;
    this.includeHidden = ctx.args.hidden || false;
    this.respectGitignore = !ctx.args.noGitignore;
    this.minLines = ctx.args.minLines || 0;

    // Parse min size if provided
    if (ctx.args.minSize) {
      this.minSizeBytes = this.parseSize(ctx.args.minSize);
    }

    // Validate directory
    await this.requireDirectory(this.directory);

    this.logger.info(`Scanning directory: ${this.directory}`);
    if (this.count > 0) {
      this.logger.info(`Showing top ${this.count} files`);
    }

    if (this.sortBySize) {
      this.logger.info("Sorting by: File size");
      if (this.minSizeBytes > 0) {
        this.logger.info(`Minimum size: ${this.formatSize(this.minSizeBytes)}`);
      }
    } else {
      this.logger.info("Sorting by: Number of lines");
      if (this.minLines > 0) {
        this.logger.info(`Minimum lines: ${this.minLines}`);
      }
    }

    this.logger.info(`Respecting .gitignore: ${this.respectGitignore ? "Yes" : "No"}`);
    this.logger.info(`Including hidden files: ${this.includeHidden ? "Yes" : "No"}`);

    // Load gitignore patterns if needed
    if (this.respectGitignore) {
      this.gitignorePatterns = await this.loadGitignorePatterns();
    }

    this.logger.progress("Scanning for files...");
    const files = await this.findFiles();

    if (files.length === 0) {
      this.logger.warn("No files found matching criteria");
      return;
    }

    this.logger.progress(this.sortBySize ? "Calculating file sizes..." : "Counting lines...");
    const filesWithMetrics = await this.getFileMetrics(files);

    this.logger.progress("Filtering and sorting...");
    const filteredFiles = this.filterAndSortFiles(filesWithMetrics);

    this.displayResults(filteredFiles);
    this.logger.success("Largest files analysis complete");
  }

  private parseSize(sizeStr: string): number {
    const match = sizeStr.match(/^(\d+)([BKMG])?$/i);
    if (!match) {
      throw new Error(`Invalid size format: ${sizeStr}. Use formats like 100K, 1M, 1G`);
    }

    const value = parseInt(match[1]);
    const unit = (match[2] || "B").toUpperCase();

    const multipliers: Record<string, number> = {
      B: 1,
      K: 1024,
      M: 1024 * 1024,
      G: 1024 * 1024 * 1024,
    };

    return value * multipliers[unit];
  }

  private formatSize(bytes: number): string {
    const units = ["B", "KB", "MB", "GB", "TB"];
    let size = bytes;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    if (unitIndex === 0) {
      return `${size}${units[unitIndex]}`;
    }

    return `${size.toFixed(1)}${units[unitIndex]}`;
  }

  private async loadGitignorePatterns(): Promise<GitignorePattern[]> {
    const gitignorePath = path.join(this.directory, ".gitignore");

    if (!(await this.fs.exists(gitignorePath))) {
      return [];
    }

    const content = await this.fs.readFile(gitignorePath);
    const patterns: GitignorePattern[] = [];

    for (const line of content.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;

      const pattern = this.gitignorePatternToRegex(trimmed);
      if (pattern) {
        patterns.push(pattern);
      }
    }

    this.logger.info(`Loaded ${patterns.length} patterns from .gitignore`);
    return patterns;
  }

  private gitignorePatternToRegex(pattern: string): GitignorePattern | null {
    try {
      // Handle negation patterns starting with !
      const negated = pattern.startsWith("!");
      if (negated) {
        pattern = pattern.slice(1);
      }

      // Escape regex special characters except * and ?
      let escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&");
      escaped = escaped.replace(/\*/g, ".*").replace(/\?/g, ".");

      // Handle directory patterns ending with /
      if (escaped.endsWith("/")) {
        escaped = escaped.slice(0, -1) + "(/.*)?$";
      } else {
        escaped += "(/.*)?";
      }

      // Handle leading slash (absolute path)
      if (escaped.startsWith("/")) {
        escaped = "^" + escaped.slice(1);
      } else {
        escaped = "(^|/)" + escaped;
      }

      const regex = new RegExp(escaped, "i");
      return { regex, negated };
    } catch (error) {
      this.logger.warn(`Invalid gitignore pattern: ${pattern}`);
      return null;
    }
  }

  private isFileIgnored(filePath: string): boolean {
    if (this.gitignorePatterns.length === 0) return false;

    const relativePath = path.relative(this.directory, filePath);

    for (const pattern of this.gitignorePatterns) {
      if (pattern.regex.test(relativePath)) {
        return !pattern.negated;
      }
    }

    return false;
  }

  private async findFiles(): Promise<string[]> {
    const result = await this.fs.glob({
      pattern: "**/*",
      cwd: this.directory,
      ignore: this.includeHidden ? [] : ["**/.*", "**/.*/**"],
    });

    const files: string[] = [];

    for (const file of result) {
      const fullPath = path.join(this.directory, file);

      // Check if it's a file
      if (!(await this.fs.isFile(fullPath))) continue;

      // Skip hidden files unless requested
      if (!this.includeHidden && path.basename(file).startsWith(".")) continue;

      // Skip if ignored by gitignore
      if (this.respectGitignore && this.isFileIgnored(fullPath)) continue;

      files.push(fullPath);
    }

    this.logger.info(`Found ${files.length} files`);
    return files;
  }

  private async getFileMetrics(files: string[]): Promise<FileMetrics[]> {
    const metrics: FileMetrics[] = [];

    for (const filePath of files) {
      try {
        const stats = await this.fs.stat(filePath);
        let lines = 0;

        if (!this.sortBySize) {
          // Only count lines for text files
          if (await this.isTextFile(filePath)) {
            const content = await this.fs.readFile(filePath);
            lines = content.split("\n").length;
          }
        }

        metrics.push({
          path: filePath,
          size: stats.size,
          lines,
        });
      } catch (error) {
        this.logger.debug(`Could not read ${filePath}: ${(error as Error).message}`);
      }
    }

    return metrics;
  }

  private async isTextFile(filePath: string): Promise<boolean> {
    const textExtensions = [
      ".txt", ".rb", ".py", ".js", ".html", ".css", ".json", ".xml", ".yaml", ".yml",
      ".md", ".sh", ".zsh", ".sql", ".go", ".rs", ".java", ".c", ".cpp", ".h", ".hpp",
      ".php", ".pl", ".swift", ".kt", ".scala", ".clj", ".hs", ".ml", ".r", ".R", ".m",
      ".mm", ".dart", ".ts", ".jsx", ".tsx", ".vue", ".svelte", ".elm", ".ex", ".exs",
      ".erl", ".hrl", ".nim", ".zig", ".v", ".vsh", ".jl", ".lua", ".tcl", ".tk", ".vim",
      ".vimrc", ".gitignore", ".gitattributes", ".editorconfig", ".dockerfile", ".makefile",
      ".rake", ".gemfile", ".toml", ".ini", ".cfg", ".conf", ".config", ".env", ".log",
    ];

    const ext = path.extname(filePath).toLowerCase();
    if (textExtensions.includes(ext)) return true;

    // Check file content for null bytes (indicator of binary)
    try {
      const file = Bun.file(filePath);
      const buffer = await file.arrayBuffer();
      const bytes = new Uint8Array(buffer.slice(0, 1024));

      // Check for null bytes
      for (const byte of bytes) {
        if (byte === 0) return false;
      }

      return true;
    } catch {
      return false;
    }
  }

  private filterAndSortFiles(files: FileMetrics[]): FileMetrics[] {
    // Filter by minimum criteria
    let filtered = files;

    if (this.sortBySize) {
      filtered = filtered.filter(f => f.size >= this.minSizeBytes);
      // Sort by size (largest first)
      filtered.sort((a, b) => b.size - a.size);
    } else {
      filtered = filtered.filter(f => f.lines >= this.minLines);
      // Sort by lines (largest first)
      filtered.sort((a, b) => b.lines - a.lines);
    }

    // Take top N files
    return this.count > 0 ? filtered.slice(0, this.count) : filtered;
  }

  private displayResults(files: FileMetrics[]): void {
    this.logger.section(this.sortBySize ? "Largest Files by Size" : "Largest Files by Lines");

    if (files.length === 0) {
      this.logger.warn("No files found matching criteria");
      return;
    }

    // Calculate totals
    const totalSize = files.reduce((sum, f) => sum + f.size, 0);
    const totalLines = files.reduce((sum, f) => sum + f.lines, 0);

    if (this.sortBySize) {
      console.log(`Total size of shown files: ${this.formatSize(totalSize)}`);
    } else {
      console.log(`Total lines of shown files: ${totalLines.toLocaleString()}`);
    }
    console.log();

    // Display header based on sorting method
    const maxPathLength = Math.min(40, Math.max(...files.map(f => path.basename(f.path).length)));

    if (this.sortBySize) {
      console.log(`${"File".padEnd(maxPathLength)} ${"Size".padStart(10)} Path`);
      console.log("-".repeat(maxPathLength + 10 + 50));

      for (const file of files) {
        const sizeStr = this.formatSize(file.size);
        const relativePath = path.relative(this.directory, file.path);
        const displayPath = relativePath.length > 50 ? "..." + relativePath.slice(-47) : relativePath;

        console.log(
          `${path.basename(file.path).padEnd(maxPathLength)} ${sizeStr.padStart(10)} ${displayPath}`
        );
      }
    } else {
      console.log(`${"File".padEnd(maxPathLength)} ${"Lines".padStart(8)} ${"Size".padStart(10)} Path`);
      console.log("-".repeat(maxPathLength + 8 + 10 + 50));

      for (const file of files) {
        const linesStr = file.lines.toLocaleString();
        const sizeStr = this.formatSize(file.size);
        const relativePath = path.relative(this.directory, file.path);
        const displayPath = relativePath.length > 50 ? "..." + relativePath.slice(-47) : relativePath;

        console.log(
          `${path.basename(file.path).padEnd(maxPathLength)} ${linesStr.padStart(8)} ${sizeStr.padStart(10)} ${displayPath}`
        );
      }
    }

    console.log();
    this.logger.info(`Found ${files.length} files matching criteria`);
  }
}

interface GitignorePattern {
  regex: RegExp;
  negated: boolean;
}
