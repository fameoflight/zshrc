import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import type { Context } from "../../core/types";

/**
 * Show files that exist in both git commits
 *
 * Analyzes two commits and displays files that are common to both,
 * with optional detailed information and statistics.
 *
 * @example
 * common HEAD~5 HEAD
 * common main feature-branch
 * common --details abc123 def456
 * common --count HEAD~10 HEAD
 * common --paths main dev
 */
@Script({
  emoji: "🔗",
  tags: ["git", "analysis"],
  args: {
    commit1: {
      type: "string",
      position: 0,
      required: true,
      description: "First commit reference",
    },
    commit2: {
      type: "string",
      position: 1,
      required: true,
      description: "Second commit reference",
    },
    details: {
      type: "boolean",
      flag: "-d, --details",
      description: "Show detailed file information",
    },
    count: {
      type: "boolean",
      flag: "-c, --count",
      description: "Show only the count of common files",
    },
    paths: {
      type: "boolean",
      flag: "-p, --paths",
      description: "Show only file paths (no formatting)",
    },
  },
})
export class GitCommonScript extends GitScript {
  async validate(ctx: Context): Promise<void> {
    // Validate git repository
    await super.validate(ctx);

    const { commit1, commit2 } = ctx.args;

    // Verify both commits exist
    const result1 = await this.shell.exec({
      command: `git rev-parse --verify ${commit1}`,
      silent: true,
    });

    if (!result1.success) {
      throw new Error(`Commit '${commit1}' does not exist`);
    }

    const result2 = await this.shell.exec({
      command: `git rev-parse --verify ${commit2}`,
      silent: true,
    });

    if (!result2.success) {
      throw new Error(`Commit '${commit2}' does not exist`);
    }
  }

  async run(ctx: Context): Promise<void> {
    const { commit1, commit2, details, count, paths } = ctx.args;

    this.logger.banner("Git Common Files Analysis");

    // Get commit info
    const info1 = await this.getCommitInfo(commit1);
    const info2 = await this.getCommitInfo(commit2);

    this.logger.info("Comparing commits:");
    this.logger.info(`  Commit 1: ${commit1} (${info1})`);
    this.logger.info(`  Commit 2: ${commit2} (${info2})`);
    this.logger.section("Analysis");

    // Get files in each commit
    const files1 = await this.getFilesInCommit(commit1);
    const files2 = await this.getFilesInCommit(commit2);

    // Find common files
    const commonFiles = files1.filter((file) => files2.includes(file));

    this.logger.info(`Files in ${commit1}: ${files1.length}`);
    this.logger.info(`Files in ${commit2}: ${files2.length}`);
    this.logger.success(`Common files: ${commonFiles.length}`);

    // Handle output format
    if (count) {
      console.log(commonFiles.length);
      this.logger.success("Git Common Files Analysis");
      return;
    }

    if (paths) {
      commonFiles.forEach((file) => console.log(file));
      this.logger.success("Git Common Files Analysis");
      return;
    }

    // Display files
    await this.displayFiles(commonFiles, files1, files2, details, commit1, commit2);

    this.logger.success("Git Common Files Analysis");
  }

  /**
   * Get commit info (short hash and subject)
   */
  private async getCommitInfo(commit: string): Promise<string> {
    const result = await this.shell.exec({
      command: `git log -1 --format='%h - %s' ${commit}`,
      silent: true,
    });

    return result.stdout.trim();
  }

  /**
   * Get all files in a commit
   */
  private async getFilesInCommit(commit: string): Promise<string[]> {
    const result = await this.shell.exec({
      command: `git ls-tree -r --name-only ${commit}`,
      silent: true,
    });

    if (!result.success) {
      return [];
    }

    return result.stdout
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0)
      .sort();
  }

  /**
   * Display files and statistics
   */
  private async displayFiles(
    commonFiles: string[],
    files1: string[],
    files2: string[],
    details: boolean,
    commit1: string,
    commit2: string
  ): Promise<void> {
    if (commonFiles.length === 0) {
      return;
    }

    this.logger.section("Common Files");

    if (details) {
      for (const file of commonFiles) {
        const status1 = await this.getFileStatus(commit1, file);
        const status2 = await this.getFileStatus(commit2, file);

        console.log(file);
        console.log(`  ${commit1}: ${status1}`);
        console.log(`  ${commit2}: ${status2}`);
        console.log();
      }
    } else {
      commonFiles.forEach((file) => console.log(file));
    }

    // Show statistics
    this.logger.section("Statistics");

    const onlyInCommit1 = files1.filter((file) => !commonFiles.includes(file));
    const onlyInCommit2 = files2.filter((file) => !commonFiles.includes(file));

    this.logger.info(`Only in ${commit1}: ${onlyInCommit1.length} files`);
    this.logger.info(`Only in ${commit2}: ${onlyInCommit2.length} files`);
    this.logger.success(`Common: ${commonFiles.length} files`);

    if (onlyInCommit1.length > 0 || onlyInCommit2.length > 0) {
      const totalUnique = files1.length + files2.length - commonFiles.length;
      this.logger.info(`Total unique files across both commits: ${totalUnique}`);
    }
  }

  /**
   * Get file status (type) in a commit
   */
  private async getFileStatus(commit: string, file: string): Promise<string> {
    try {
      const result = await this.shell.exec({
        command: `git ls-tree ${commit} "${file}"`,
        silent: true,
      });

      if (!result.success || result.stdout.trim() === "") {
        return "Not found";
      }

      const parts = result.stdout.trim().split(/\s+/);
      const type = parts[1];

      switch (type) {
        case "100644":
          return "Regular file";
        case "100755":
          return "Executable";
        case "120000":
          return "Symlink";
        case "040000":
          return "Directory";
        default:
          return `Unknown (${type})`;
      }
    } catch (error) {
      return "Error getting status";
    }
  }
}
