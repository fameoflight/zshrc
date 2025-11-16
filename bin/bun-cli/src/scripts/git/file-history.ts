import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import { logger } from "../../core/utils/logger";
import { exec } from "../../core/utils/shell";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, basename, extname } from "node:path";
import * as readline from "node:readline/promises";

interface CommitInfo {
  hash: string;
  message: string;
  date: string;
}

interface FileHistory {
  [filename: string]: CommitInfo[];
}

/**
 * Find files by extension in git history with view commands
 */
@Script({
  name: "git-history",
  description: "Find files by extension in git history with view commands",
  emoji: "🐙",
  arguments: "<extension>",
  examples: [
    "git-history txt                    # Find .txt files in git history",
    "git-history .rb                   # Find .rb files in git history",
    'git-history "*.md"                # Find .md files in git history',
    "git-history --limit 5 js          # Show only 5 most recent commits per file",
    "git-history --since 2024-01-01 py # Show Python files changed since 2024-01-01",
    "git-history --interactive rb      # Interactive mode to select Ruby files to open",
    "git-history --open md             # Create temp files for all markdown versions and open directory",
  ],
  options: [
    {
      flag: "-i, --interactive",
      description: "Interactive mode - select files to open in EDITOR",
    },
    {
      flag: "-n, --limit <count>",
      description: "Limit number of commits per file",
    },
    {
      flag: "-d, --debug",
      description: "Enable debug output",
    },
    {
      flag: "-o, --open",
      description: "Open all files in temporary directory with EDITOR",
    },
    {
      flag: "--since <date>",
      description: "Show commits since DATE (YYYY-MM-DD)",
    },
    {
      flag: "--until <date>",
      description: "Show commits until DATE (YYYY-MM-DD)",
    },
  ],
})
export class GitHistoryScript extends GitScript {
  private repoPath!: string;

  async run(args: string[], options: Record<string, any>): Promise<void> {
    logger.banner("Git History");

    if (args.length === 0) {
      logger.error("Extension is required");
      console.log();
      this.showExamples();
      process.exit(1);
    }

    const extension = this.normalizeExtension(args[0]);
    this.repoPath = process.env.ORIGINAL_WORKING_DIR || process.cwd();

    // Validate git repository
    if (!(await this.isGitRepository(this.repoPath))) {
      logger.error(`Not a git repository: ${this.repoPath}`);
      process.exit(1);
    }

    logger.info(`Searching for ${extension} files in git history...`);

    // Get files history
    const filesHistory = await this.getFilesHistory(extension, options);

    if (Object.keys(filesHistory).length === 0) {
      logger.warning(`No files with extension '${extension}' found in git history`);
      return;
    }

    // Handle different modes
    if (options.open) {
      await this.openAllFiles(filesHistory);
    } else if (options.interactive) {
      await this.interactiveMode(filesHistory);
    } else {
      this.displayFilesHistory(filesHistory);
    }

    logger.completion("Git History");
  }

  private showExamples(): void {
    console.log("Examples:");
    console.log("  git-history txt                    # Find .txt files in git history");
    console.log("  git-history .rb                   # Find .rb files in git history");
    console.log('  git-history "*.md"                # Find .md files in git history');
    console.log("  git-history --limit 5 js          # Show only 5 most recent commits per file");
    console.log("  git-history --since 2024-01-01 py # Show Python files changed since 2024-01-01");
    console.log("  git-history --interactive rb      # Interactive mode to select Ruby files to open");
    console.log("  git-history --open md             # Create temp files for all markdown versions and open directory");
  }

  private normalizeExtension(ext: string): string {
    const cleanExt = ext.replace(/[*"']/g, "");
    return cleanExt.startsWith(".") ? cleanExt : `.${cleanExt}`;
  }

  private async isGitRepository(path: string): Promise<boolean> {
    try {
      process.chdir(path);
      await exec("git rev-parse --git-dir");
      return true;
    } catch {
      return false;
    }
  }

  private async getFilesHistory(
    extension: string,
    options: Record<string, any>
  ): Promise<FileHistory> {
    const filesHistory: FileHistory = {};

    process.chdir(this.repoPath);

    const cmd = this.buildGitLogCommand(options);

    try {
      const result = await exec(cmd);
      const output = result.stdout;

      let currentCommit: CommitInfo | null = null;
      let currentFiles: string[] = [];

      const lines = output.split("\n");
      for (const line of lines) {
        const trimmedLine = line.trim();

        // Match commit line: hash|message|date
        const commitMatch = trimmedLine.match(/^([a-f0-9]{7,})\|(.+)\|(\d{4}-\d{2}-\d{2})$/);
        if (commitMatch) {
          // Process previous commit's files
          if (currentCommit) {
            this.processCommitFiles(currentFiles, currentCommit, extension, filesHistory);
          }

          currentCommit = {
            hash: commitMatch[1],
            message: commitMatch[2],
            date: commitMatch[3],
          };
          currentFiles = [];
        } else if (trimmedLine && currentCommit) {
          currentFiles.push(trimmedLine);
        }
      }

      // Process last commit
      if (currentCommit) {
        this.processCommitFiles(currentFiles, currentCommit, extension, filesHistory);
      }
    } catch (error) {
      logger.error("Failed to execute git command");
      process.exit(1);
    }

    // Apply limit if specified
    if (options.limit) {
      Object.keys(filesHistory).forEach((file) => {
        filesHistory[file] = filesHistory[file].slice(0, options.limit);
      });
    }

    return filesHistory;
  }

  private buildGitLogCommand(options: Record<string, any>): string {
    let cmd = 'git log --all --pretty=format:"%H|%s|%ad" --date=short --name-only';

    if (options.since) {
      cmd += ` --since=${options.since}`;
    }

    if (options.until) {
      cmd += ` --until=${options.until}`;
    }

    return cmd;
  }

  private processCommitFiles(
    files: string[],
    commit: CommitInfo,
    extension: string,
    filesHistory: FileHistory
  ): void {
    for (const file of files) {
      if (file.endsWith(extension)) {
        if (!filesHistory[file]) {
          filesHistory[file] = [];
        }
        filesHistory[file].push(commit);
      }
    }
  }

  private displayFilesHistory(filesHistory: FileHistory): void {
    const totalFiles = Object.keys(filesHistory).length;
    const totalCommits = Object.values(filesHistory).reduce(
      (sum, commits) => sum + commits.length,
      0
    );

    logger.info(`Found ${totalFiles} files with ${totalCommits} total commits:`);
    console.log();

    const sortedFiles = Object.keys(filesHistory).sort();
    for (const file of sortedFiles) {
      this.displayFileHistory(file, filesHistory[file]);
      console.log();
    }
  }

  private displayFileHistory(file: string, commits: CommitInfo[]): void {
    const fullPath = join(this.repoPath, file);
    const fileExists = existsSync(fullPath);
    const statusIndicator = fileExists ? "✓" : "✗";
    const statusText = fileExists ? "" : " (deleted)";

    console.log(`${statusIndicator} ${file}${statusText}`);

    for (const commit of commits) {
      console.log(`  ↳ ${commit.hash} (${commit.date}) ${commit.message}`);
      console.log(`     → git show ${commit.hash}:${file}`);
    }
  }

  private async interactiveMode(filesHistory: FileHistory): Promise<void> {
    logger.info("Interactive mode - select files to open in EDITOR");
    console.log();

    const fileOptions = Object.entries(filesHistory)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([file, commits]) => {
        const fullPath = join(this.repoPath, file);
        const status = existsSync(fullPath) ? "✓" : "✗";
        return {
          name: `${status} ${file} (${commits.length} commits)`,
          value: file,
        };
      });

    fileOptions.push({ name: "Exit", value: ":exit" });

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    while (true) {
      console.log("\nSelect a file to open:");
      fileOptions.forEach((opt, index) => {
        console.log(`  ${index + 1}. ${opt.name}`);
      });

      const answer = await rl.question(`\nEnter choice (1-${fileOptions.length}): `);
      const choice = parseInt(answer.trim(), 10);

      if (isNaN(choice) || choice < 1 || choice > fileOptions.length) {
        logger.warning("Invalid choice");
        continue;
      }

      const selected = fileOptions[choice - 1].value;

      if (selected === ":exit") {
        logger.info("Exiting interactive mode");
        rl.close();
        break;
      }

      await this.openFileInteractive(selected, filesHistory[selected]);
    }
  }

  private async openFileInteractive(file: string, commits: CommitInfo[]): Promise<void> {
    logger.info(`Opening ${file} from git history...`);

    // Try each commit until we find one that works
    for (const commit of commits) {
      if (await this.openFileAtCommit(file, commit)) {
        return;
      }
    }

    logger.warning(`Could not open ${file} - no working commits found`);
  }

  private async openFileAtCommit(file: string, commit: CommitInfo): Promise<boolean> {
    try {
      const result = await exec(`git show ${commit.hash}:"${file}"`);
      if (!result.stdout) {
        return false;
      }

      // Create temp file
      const tempDir = tmpdir();
      const fileExt = extname(file);
      const tempFileName = `git-history-${commit.hash}${fileExt}`;
      const tempFilePath = join(tempDir, tempFileName);

      writeFileSync(tempFilePath, result.stdout);

      const editor = process.env.EDITOR || "vim";
      logger.info(`Opening ${file} (${commit.hash}) in ${editor}...`);

      const editorResult = await exec(`${editor} "${tempFilePath}"`);
      logger.success(`Closed ${file} (${commit.hash})`);
      return true;
    } catch (error) {
      return false;
    }
  }

  private async openAllFiles(filesHistory: FileHistory): Promise<void> {
    logger.info("Creating temporary files for all versions...");

    const tempDir = this.createTempDirectory();
    let filesCreated = 0;

    for (const [file, commits] of Object.entries(filesHistory)) {
      for (const commit of commits) {
        if (await this.createTempFileForCommit(file, commit, tempDir)) {
          filesCreated++;
        }
      }
    }

    if (filesCreated > 0) {
      logger.success(`Created ${filesCreated} temporary files in ${tempDir}`);
      await this.openTempDirectory(tempDir);
    } else {
      logger.warning("No temporary files were created");
    }
  }

  private createTempDirectory(): string {
    const timestamp = new Date().toISOString().replace(/[-:T.]/g, "").slice(0, 14);
    const tempDir = join(tmpdir(), `git-history-${timestamp}`);

    if (!existsSync(tempDir)) {
      mkdirSync(tempDir, { recursive: true });
    }

    logger.info(`Created temporary directory: ${tempDir}`);
    return tempDir;
  }

  private async createTempFileForCommit(
    file: string,
    commit: CommitInfo,
    tempDir: string
  ): Promise<boolean> {
    try {
      const result = await exec(`git show ${commit.hash}:"${file}"`);
      if (!result.stdout) {
        return false;
      }

      const fileBasename = basename(file, extname(file));
      const fileExtension = extname(file);
      const tempFileName = `${fileBasename}-${commit.hash}${fileExtension}`;
      const tempFilePath = join(tempDir, tempFileName);

      writeFileSync(tempFilePath, result.stdout);
      logger.debug(`Created: ${tempFileName}`, false);
      return true;
    } catch (error) {
      logger.error(
        `Failed to create ${file} at ${commit.hash}: ${error instanceof Error ? error.message : String(error)}`
      );
      return false;
    }
  }

  private async openTempDirectory(tempDir: string): Promise<void> {
    const editor = process.env.EDITOR || "vim";

    logger.info(`Opening directory ${tempDir} with ${editor}...`);

    try {
      await exec(`${editor} "${tempDir}"`);
      logger.success(`Opened ${tempDir}`);
    } catch {
      // If editor fails, try system file manager
      try {
        if (process.platform === "darwin") {
          await exec(`open "${tempDir}"`);
        } else if (process.platform === "linux") {
          await exec(`xdg-open "${tempDir}"`);
        }
        logger.success(`Opened ${tempDir}`);
      } catch {
        logger.warning(`Could not open ${tempDir}. Directory created at: ${tempDir}`);
      }
    }
  }
}
