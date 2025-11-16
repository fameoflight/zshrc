import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import type { Context } from "../../core/types";
import { multiselect } from "@clack/prompts";

interface FileInfo {
  status: string;
  path: string;
  type: "modified" | "deleted" | "renamed" | "unknown";
}

interface CommitInfo {
  shortHash: string;
  fullHash: string;
  message: string;
  files: FileInfo[];
}

/**
 * Interactive tool to split an existing git commit into multiple commits
 *
 * Features:
 * - Interactive file selection using multiselect
 * - Split any commit (defaults to HEAD)
 * - Automatically creates backup branch
 * - Reapplies subsequent commits after split
 * - Shows preview before committing
 * - File status icons for clarity
 *
 * @example
 * commit-splitter                    # Split HEAD commit
 * commit-splitter abc123            # Split specific commit
 * commit-splitter --commit abc123   # Split specific commit (explicit flag)
 */
@Script({
  emoji: "✂️",
  tags: ["git", "interactive"],
  args: {
    commitHash: {
      type: "string",
      position: 0,
      required: false,
      description: "Commit hash to split (defaults to HEAD)",
    },
    commit: {
      type: "string",
      flag: "-c, --commit",
      description: "Commit hash to split (alternative to positional arg)",
    },
  },
})
export class GitCommitSplitter extends GitScript {
  private commitHash!: string;
  private commitInfo!: CommitInfo;

  async validate(ctx: Context): Promise<void> {
    // First validate we're in a git repo
    await super.validate(ctx);

    // Check for uncommitted changes
    const diffResult = await this.shell.exec({
      command: "git diff-index --quiet HEAD",
      silent: true,
    });

    if (!diffResult.success) {
      throw new Error("You have uncommitted changes. Please commit or stash them first.");
    }

    // Get commit hash from args
    this.commitHash = ctx.args.commit || ctx.args.commitHash || "HEAD";

    // Validate commit exists
    const verifyResult = await this.shell.exec({
      command: `git rev-parse --verify ${this.commitHash}`,
      silent: true,
    });

    if (!verifyResult.success) {
      throw new Error(`Invalid commit hash: ${this.commitHash}`);
    }
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Git Commit Splitter");

    // Get commit info
    this.commitInfo = await this.getCommitInfo(this.commitHash);
    this.logger.info(`Working with commit: ${this.commitInfo.shortHash}`);
    this.logger.info(`Original message: ${this.commitInfo.message}`);
    this.logger.info(`Files changed: ${this.commitInfo.files.length}`);

    // Interactive file selection
    const [selectedFiles, remainingFiles] = await this.selectFilesInteractive(
      this.commitInfo.files
    );

    if (selectedFiles.length === 0) {
      this.logger.warn("No files selected for splitting");
      return;
    }

    // Show what will be split
    this.showSplitPreview(selectedFiles, remainingFiles);

    this.logger.info(`Splitting commit ${this.commitInfo.shortHash} into two commits...`);
    this.logger.info(`First commit: [FIRST] ${this.commitInfo.message}`);
    this.logger.info(`Second commit: [SECOND] ${this.commitInfo.message}`);

    // Perform the split
    await this.performCommitSplit(selectedFiles, remainingFiles);

    this.logger.success("Git Commit Splitter complete");
  }

  private async getCommitInfo(commitHash: string): Promise<CommitInfo> {
    this.logger.info(`Analyzing commit ${commitHash}...`);

    // Get commit message
    const messageResult = await this.shell.exec({
      command: `git log -1 --pretty=format:%B ${commitHash}`,
      silent: true,
    });
    const message = messageResult.stdout.trim();

    // Get changed files with status
    const diffResult = await this.shell.exec({
      command: `git show --name-status --format= ${commitHash}`,
      silent: true,
    });

    const files: FileInfo[] = [];
    for (const line of diffResult.stdout.trim().split("\n")) {
      if (!line.trim()) continue;

      const parts = line.trim().split("\t", 2);
      if (parts.length < 2) continue;

      const [status, path] = parts;
      files.push({
        status,
        path,
        type: this.getFileType(status),
      });
    }

    // Get short and full hash
    const shortHashResult = await this.shell.exec({
      command: `git rev-parse --short ${commitHash}`,
      silent: true,
    });
    const fullHashResult = await this.shell.exec({
      command: `git rev-parse ${commitHash}`,
      silent: true,
    });

    return {
      shortHash: shortHashResult.stdout.trim(),
      fullHash: fullHashResult.stdout.trim(),
      message,
      files,
    };
  }

  private getFileType(statusCode: string): "modified" | "deleted" | "renamed" | "unknown" {
    switch (statusCode) {
      case "A":
      case "M":
      case "T":
        return "modified";
      case "D":
        return "deleted";
      case "R":
        return "renamed";
      default:
        return "unknown";
    }
  }

  private async selectFilesInteractive(files: FileInfo[]): Promise<[FileInfo[], FileInfo[]]> {
    this.logger.section("File Selection");
    this.logger.info("Select files for the FIRST commit (remaining files will go to the SECOND commit)");

    // Create choices with proper display text
    const options = files.map(file => {
      const statusIcon = this.getStatusIcon(file.status);
      const displayPath = file.path.length > 60 ? file.path.slice(0, 57) + "..." : file.path;
      const displayText = `${statusIcon} ${displayPath} (${file.type})`;

      return {
        label: displayText,
        value: file,
      };
    });

    const result = await multiselect({
      message: `📁 Select files for the FIRST commit (${files.length} files available):`,
      options,
      required: true,
    });

    // Handle cancellation
    if (typeof result === "symbol") {
      this.logger.warn("Selection cancelled");
      process.exit(0);
    }

    const selectedFiles = result as FileInfo[];

    if (selectedFiles.length === 0) {
      this.logger.warn("Please select at least one file");
      return this.selectFilesInteractive(files); // Retry
    }

    const remainingFiles = files.filter(file => !selectedFiles.includes(file));

    this.logger.success(`Selected ${selectedFiles.length} files for first commit`);
    this.logger.info(`Remaining ${remainingFiles.length} files will go to second commit`);

    return [selectedFiles, remainingFiles];
  }

  private getStatusIcon(statusCode: string): string {
    switch (statusCode) {
      case "A":
        return "➕";
      case "M":
        return "📝";
      case "D":
        return "🗑️";
      case "R":
        return "🔄";
      case "T":
        return "🔧";
      default:
        return "❓";
    }
  }

  private showSplitPreview(selectedFiles: FileInfo[], remainingFiles: FileInfo[]): void {
    this.logger.section("Split Preview");

    if (selectedFiles.length > 0) {
      this.logger.info("📦 First commit will contain:");
      selectedFiles.forEach(file => {
        console.log(`  ${this.getStatusIcon(file.status)} ${file.path}`);
      });
      console.log();
    }

    if (remainingFiles.length > 0) {
      this.logger.info("📦 Second commit will contain:");
      remainingFiles.forEach(file => {
        console.log(`  ${this.getStatusIcon(file.status)} ${file.path}`);
      });
      console.log();
    }

    console.log(`Original commit: ${this.commitInfo.shortHash} - ${this.commitInfo.message}`);
  }

  private async performCommitSplit(
    selectedFiles: FileInfo[],
    remainingFiles: FileInfo[]
  ): Promise<void> {
    this.logger.progress("Starting commit split operation...");

    // Get commits that come after the target commit
    const commitsAfterResult = await this.shell.exec({
      command: `git rev-list ${this.commitHash}..HEAD`,
      silent: true,
    });

    const commitsAfter = commitsAfterResult.stdout
      .trim()
      .split("\n")
      .filter(h => h)
      .reverse();

    this.logger.info(`Found ${commitsAfter.length} commits after target commit`);

    // Create a backup branch
    const backupBranch = `backup-split-${Date.now()}`;
    this.logger.info(`Creating backup branch: ${backupBranch}`);
    await this.shell.exec({
      command: `git branch ${backupBranch}`,
      silent: true,
    });

    try {
      // Reset to the parent of the target commit
      const parentCommit = `${this.commitHash}^`;
      this.logger.info(`Resetting to parent commit: ${parentCommit}`);

      const resetResult = await this.shell.exec({
        command: `git reset --hard ${parentCommit}`,
        silent: false,
      });

      if (!resetResult.success) {
        this.logger.error("Failed to reset to parent commit");
        await this.restoreBackup(backupBranch);
        return;
      }

      // Recreate the target commit's changes in staging
      this.logger.info("Reapplying changes from target commit...");
      await this.shell.exec({
        command: `git cherry-pick --no-commit ${this.commitHash}`,
        silent: false,
      });

      // Create first commit with selected files
      if (selectedFiles.length > 0) {
        this.logger.info("Creating first commit with selected files...");
        await this.stageFiles(selectedFiles);

        const message = this.getCommitMessageForSplit("first");
        const commitResult = await this.shell.exec({
          command: `git commit -m "${message.replace(/"/g, '\\"')}"`,
          silent: false,
        });

        if (!commitResult.success) {
          this.logger.error("Failed to create first commit");
          await this.restoreBackup(backupBranch);
          return;
        }
        this.logger.success("✅ Created first commit");
      }

      // Create second commit with remaining files
      if (remainingFiles.length > 0) {
        this.logger.info("Creating second commit with remaining files...");
        await this.stageFiles(remainingFiles);

        const message = this.getCommitMessageForSplit("second");
        const commitResult = await this.shell.exec({
          command: `git commit -m "${message.replace(/"/g, '\\"')}"`,
          silent: false,
        });

        if (!commitResult.success) {
          this.logger.error("Failed to create second commit");
          await this.restoreBackup(backupBranch);
          return;
        }
        this.logger.success("✅ Created second commit");
      }

      // Reapply commits that came after the target commit
      if (commitsAfter.length > 0) {
        this.logger.info(`Reapplying ${commitsAfter.length} commits that came after...`);

        for (const commitHash of commitsAfter) {
          this.logger.info(`Reapplying commit: ${commitHash.slice(0, 7)}`);

          const cherryPickResult = await this.shell.exec({
            command: `git cherry-pick ${commitHash}`,
            silent: false,
          });

          if (!cherryPickResult.success) {
            this.logger.error(`Failed to reapply commit ${commitHash.slice(0, 7)}`);
            this.logger.error("You may need to resolve conflicts manually");
            this.logger.info("Run 'git cherry-pick --continue' after resolving conflicts");
            return;
          }
        }

        this.logger.success("✅ All subsequent commits reapplied");
      }

      // Show results
      this.logger.success("🎉 Commit split completed successfully!");
      this.logger.info("New commits (replacing original):");
      await this.shell.exec({
        command: "git log --oneline -10",
        silent: false,
      });

      // Clean up backup branch automatically
      await this.shell.exec({
        command: `git branch -D ${backupBranch}`,
        silent: true,
      });
      this.logger.info("✅ Backup branch removed");
    } catch (error) {
      this.logger.error(`Error during commit split: ${(error as Error).message}`);
      this.logger.info("You can restore from backup:");
      console.log(`  git checkout ${backupBranch}`);
    }
  }

  private async stageFiles(files: FileInfo[]): Promise<void> {
    // Reset everything first
    await this.shell.exec({
      command: "git reset HEAD .",
      silent: true,
    });

    // Stage selected files
    for (const file of files) {
      switch (file.status) {
        case "A":
        case "M":
        case "T":
        case "D":
        case "R":
          await this.shell.exec({
            command: `git add '${file.path}'`,
            silent: true,
          });
          break;
      }
    }
  }

  private getCommitMessageForSplit(which: "first" | "second"): string {
    const originalMessage = this.commitInfo.message;

    switch (which) {
      case "first":
        return `[FIRST] ${originalMessage}`;
      case "second":
        return `[SECOND] ${originalMessage}`;
    }
  }

  private async restoreBackup(backupBranch: string): Promise<void> {
    this.logger.warn(`Restoring from backup branch: ${backupBranch}`);

    await this.shell.exec({
      command: "git rebase --abort",
      silent: true,
    });

    await this.shell.exec({
      command: `git checkout ${backupBranch}`,
      silent: false,
    });

    await this.shell.exec({
      command: `git reset --hard ${this.commitHash}`,
      silent: false,
    });
  }
}
