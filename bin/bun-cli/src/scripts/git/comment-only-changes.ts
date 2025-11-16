import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import { logger } from "../../core/utils/logger";
import { exec } from "../../core/utils/shell";
import { existsSync } from "node:fs";
import { join } from "node:path";
import * as readline from "node:readline/promises";

interface FileChange {
  file: string;
  isCommentOnly: boolean;
}

/**
 * Identifies files with only comment changes for safe low-risk commits
 */
@Script({
  name: "comment-only-changes",
  description:
    "Analyzes git dirty files to identify those with only comment changes. Perfect for identifying low-risk changes that can be committed first.",
  emoji: "🔍",
  arguments: "[repository_path]",
  examples: [
    "comment-only-changes                                    # Analyze current directory",
    "comment-only-changes /path/to/repo                      # Analyze specific repository",
    "comment-only-changes --stage                            # Stage comment-only files",
    "comment-only-changes --commit                           # Stage and commit comment-only files",
    "comment-only-changes --commit 'Update documentation'    # Custom commit message",
    "comment-only-changes --commit --skip-hooks              # Skip git hooks (e.g., linters)",
    "comment-only-changes --languages ruby,python,javascript # Check specific languages",
  ],
  options: [
    {
      flag: "-l, --list-only",
      description: "Only list comment-only files (default behavior)",
    },
    {
      flag: "-s, --stage",
      description: "Stage the comment-only files for commit",
    },
    {
      flag: "-c, --commit [message]",
      description:
        "Commit comment-only files with optional message (default: 'Update comments and documentation')",
    },
    {
      flag: "--skip-hooks",
      description: "Skip git hooks when committing (useful for comment-only changes)",
    },
    {
      flag: "--languages <langs>",
      description: "Comma-separated list of languages to check (default: ruby,python)",
    },
  ],
})
export class CommentOnlyChangesScript extends GitScript {
  private repositoryPath!: string;
  private languages: string[] = ["ruby", "python"];

  async run(args: string[], options: Record<string, any>): Promise<void> {
    logger.banner("Comment-Only Changes Detector");

    // Parse options
    this.languages = options.languages
      ? options.languages.split(",").map((l: string) => l.trim())
      : ["ruby", "python"];

    this.repositoryPath = args[0] || process.cwd();

    // Validate repository
    if (!existsSync(this.repositoryPath)) {
      logger.error(`Repository path does not exist: ${this.repositoryPath}`);
      process.exit(1);
    }

    const gitDir = join(this.repositoryPath, ".git");
    if (!existsSync(gitDir)) {
      logger.error(`Not a git repository: ${this.repositoryPath}`);
      process.exit(1);
    }

    // Change to repository directory
    process.chdir(this.repositoryPath);

    // Get dirty files
    const dirtyFiles = await this.getDirtyFiles();

    if (dirtyFiles.length === 0) {
      logger.info("No dirty files found in repository");
      return;
    }

    logger.info(`Found ${dirtyFiles.length} dirty files, analyzing...`);

    // Analyze files
    const analysis = await this.analyzeFiles(dirtyFiles);

    // Display results
    this.displayResults(analysis, dirtyFiles.length);

    // Stage files if requested
    if (options.stage && analysis.commentOnly.length > 0) {
      await this.stageFiles(analysis.commentOnly);
    }

    // Commit files if requested
    if (options.commit && analysis.commentOnly.length > 0) {
      const message =
        typeof options.commit === "string"
          ? options.commit
          : "Update comments and documentation";
      await this.commitFiles(analysis.commentOnly, message, options.skipHooks, options.stage);
    }

    logger.completion("Comment-Only Changes Detector");
  }

  private async getDirtyFiles(): Promise<string[]> {
    try {
      const result = await exec("git status --porcelain");
      const lines = result.stdout.split("\n").filter((line) => line.trim());

      const files: string[] = [];
      for (const line of lines) {
        // Extract filename from git status output (handle spaces in filenames)
        const parts = line.trim().split(/\s+/, 2);
        if (parts.length < 2) continue;

        const file = parts[1];

        // Only process files that exist and match our supported languages
        if (existsSync(file) && this.isSupportedLanguage(file)) {
          files.push(file);
        }
      }

      return files;
    } catch (error) {
      logger.error("Failed to get git status");
      return [];
    }
  }

  private isSupportedLanguage(file: string): boolean {
    const extension = file.substring(file.lastIndexOf(".")).toLowerCase();

    const languageExtensions: Record<string, string[]> = {
      ruby: [".rb", ".rake", ".gemspec"],
      python: [".py", ".pyx", ".pxd", ".pxi"],
      javascript: [".js", ".jsx", ".mjs"],
      typescript: [".ts", ".tsx"],
      java: [".java"],
      php: [".php"],
      go: [".go"],
      rust: [".rs"],
      shell: [".sh", ".bash", ".zsh"],
    };

    return this.languages.some((lang) => {
      const exts = languageExtensions[lang];
      return exts && exts.includes(extension);
    });
  }

  private async analyzeFiles(
    files: string[]
  ): Promise<{ commentOnly: string[]; hasCodeChanges: string[] }> {
    const commentOnly: string[] = [];
    const hasCodeChanges: string[] = [];

    for (const file of files) {
      logger.progress(`Analyzing ${file}`);

      if (await this.isCommentOnlyChanges(file)) {
        commentOnly.push(file);
        logger.success(`✅ ${file} - comment changes only`);
      } else {
        hasCodeChanges.push(file);
        logger.info(`⚠️  ${file} - has code changes`);
      }
    }

    return { commentOnly, hasCodeChanges };
  }

  private async isCommentOnlyChanges(file: string): Promise<boolean> {
    try {
      // Check both staged and unstaged changes
      const unstagedResult = await exec(`git diff "${file}"`);
      const stagedResult = await exec(`git diff --staged "${file}"`);

      // Combine both diffs
      const combinedDiff = unstagedResult.stdout + stagedResult.stdout;
      if (!combinedDiff.trim()) {
        return false;
      }

      const language = this.detectLanguage(file);
      const commentPatterns = this.getCommentPatterns(language);

      // Parse diff and check if all changes are comments
      const diffLines = combinedDiff.split("\n");
      const changeLines = diffLines.filter(
        (line) => (line.startsWith("+") || line.startsWith("-")) &&
                  !line.startsWith("+++") &&
                  !line.startsWith("---")
      );

      if (changeLines.length === 0) {
        return false;
      }

      // Remove the +/- prefix and check if remaining content is comment or whitespace
      return changeLines.every((line) => {
        const content = line.substring(1); // Remove +/- prefix
        return this.isCommentOrWhitespace(content, commentPatterns);
      });
    } catch (error) {
      return false;
    }
  }

  private detectLanguage(file: string): string {
    const extension = file.substring(file.lastIndexOf(".")).toLowerCase();

    const extensionToLanguage: Record<string, string> = {
      ".rb": "ruby",
      ".rake": "ruby",
      ".gemspec": "ruby",
      ".py": "python",
      ".pyx": "python",
      ".pxd": "python",
      ".pxi": "python",
      ".js": "javascript",
      ".jsx": "javascript",
      ".mjs": "javascript",
      ".ts": "typescript",
      ".tsx": "typescript",
      ".java": "java",
      ".php": "php",
      ".go": "go",
      ".rs": "rust",
      ".sh": "shell",
      ".bash": "shell",
      ".zsh": "shell",
    };

    return extensionToLanguage[extension] || "unknown";
  }

  private getCommentPatterns(language: string): RegExp[] {
    const patterns: Record<string, RegExp[]> = {
      ruby: [
        /^\s*#.*$/,      // Single line comments
        /^\s*=begin.*$/, // Multi-line comment start
        /^\s*=end.*$/,   // Multi-line comment end
      ],
      python: [
        /^\s*#.*$/,      // Single line comments
        /^\s*""".*$/,    // Triple quote docstrings (start)
        /^\s*'''.*$/,    // Triple quote docstrings (start)
        /^.*""".*$/,     // Triple quote docstrings (end)
        /^.*'''.*$/,     // Triple quote docstrings (end)
      ],
      javascript: [
        /^\s*\/\/.*$/,   // Single line comments
        /^\s*\/\*.*$/,   // Multi-line comment start
        /^.*\*\/.*$/,    // Multi-line comment end
      ],
      typescript: [
        /^\s*\/\/.*$/,   // Single line comments
        /^\s*\/\*.*$/,   // Multi-line comment start
        /^.*\*\/.*$/,    // Multi-line comment end
      ],
      java: [
        /^\s*\/\/.*$/,   // Single line comments
        /^\s*\/\*.*$/,   // Multi-line comment start
        /^.*\*\/.*$/,    // Multi-line comment end
      ],
      php: [
        /^\s*\/\/.*$/,   // Single line comments
        /^\s*#.*$/,      // Shell-style comments
        /^\s*\/\*.*$/,   // Multi-line comment start
        /^.*\*\/.*$/,    // Multi-line comment end
      ],
      go: [
        /^\s*\/\/.*$/,   // Single line comments
        /^\s*\/\*.*$/,   // Multi-line comment start
        /^.*\*\/.*$/,    // Multi-line comment end
      ],
      rust: [
        /^\s*\/\/.*$/,   // Single line comments
        /^\s*\/\*.*$/,   // Multi-line comment start
        /^.*\*\/.*$/,    // Multi-line comment end
      ],
      shell: [
        /^\s*#.*$/,      // Single line comments
      ],
    };

    return patterns[language] || [];
  }

  private isCommentOrWhitespace(content: string, commentPatterns: RegExp[]): boolean {
    // Check if line is whitespace only
    if (!content.trim()) {
      return true;
    }

    // Check if line matches any comment pattern
    return commentPatterns.some((pattern) => pattern.test(content));
  }

  private displayResults(
    analysis: { commentOnly: string[]; hasCodeChanges: string[] },
    totalFiles: number
  ): void {
    console.log();
    logger.section("═══════════════════════════════════════");

    if (analysis.commentOnly.length === 0) {
      logger.warning("No files found with comment-only changes");
      logger.info(`All ${totalFiles} dirty files contain code changes`);
    } else {
      logger.success(
        `Found ${analysis.commentOnly.length} files with comment-only changes:`
      );
      analysis.commentOnly.forEach((file) => {
        console.log(`  📄 ${file}`);
      });

      const remaining = analysis.hasCodeChanges.length;
      if (remaining > 0) {
        logger.info(
          `${remaining} files contain code changes and should be reviewed separately`
        );
      }
    }

    logger.section("═══════════════════════════════════════");
  }

  private async stageFiles(files: string[]): Promise<void> {
    logger.info(`Staging ${files.length} comment-only files...`);

    for (const file of files) {
      await exec(`git add "${file}"`);
      logger.fileUpdated(file);
    }

    logger.success("Files staged successfully!");
  }

  private async commitFiles(
    files: string[],
    message: string,
    skipHooks: boolean = false,
    alreadyStaged: boolean = false
  ): Promise<void> {
    // Stage files first if not already staged
    if (!alreadyStaged) {
      await this.stageFiles(files);
    }

    logger.info("Committing comment-only changes...");

    const commitMessage = `${message}\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>`;

    // Build commit command with optional --no-verify flag
    let cmd = `git commit -m "${commitMessage.replace(/"/g, '\\"')}"`;
    if (skipHooks) {
      cmd += " --no-verify";
    }

    try {
      await exec(cmd);
      logger.success(`Successfully committed ${files.length} files with comment-only changes!`);
    } catch (error) {
      logger.error("Failed to commit changes");
      process.exit(1);
    }
  }
}
