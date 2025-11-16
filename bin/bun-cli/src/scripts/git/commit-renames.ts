import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import type { Context } from "../../core/types";

/**
 * Commit only pure file renames
 *
 * Stages and commits only files with R100 (pure rename) status.
 * Useful for separating renames from content changes.
 *
 * @example
 * commit-renames
 * commit-renames --message "Rename components"
 * commit-renames --no-verify
 */
@Script({
  emoji: "🔄",
  tags: ["git", "commit", "rename"],
  args: {
    message: {
      type: "string",
      flag: "-m, --message",
      description: "Commit message (skip interactive prompt)",
    },
    noVerify: {
      type: "boolean",
      flag: "--no-verify",
      description: "Skip pre-commit hooks",
    },
  },
})
export class GitCommitRenamesScript extends GitScript {
  async run(ctx: Context): Promise<void> {
    const { message, noVerify } = ctx.args;

    this.logger.banner("Git Commit Pure Renames");

    // Stage all changes first
    this.logger.info("Staging all changes...");
    await this.shell.execOrThrow("git add .", "Failed to stage changes");

    // Get staged changes
    this.logger.info("Checking staged changes...");
    const result = await this.shell.exec({
      command: "git diff --cached --name-status",
      silent: true,
    });

    if (!result.success || result.stdout.trim() === "") {
      this.logger.warn("No staged changes found");
      return;
    }

    // Filter pure renames (R100)
    const pureRenames: string[] = [];
    const otherChanges: string[] = [];

    result.stdout.split("\n").forEach((line) => {
      const trimmed = line.trim();
      if (!trimmed) return;

      if (trimmed.startsWith("R100\t")) {
        pureRenames.push(trimmed);
      } else {
        otherChanges.push(trimmed);
      }
    });

    // Summarize changes
    this.logger.info("📊 Changes Summary:");
    console.log(`  Total staged: ${pureRenames.length + otherChanges.length}`);
    console.log(`  Pure renames to commit: ${pureRenames.length}`);
    console.log(`  Other changes: ${otherChanges.length}`);

    if (pureRenames.length === 0) {
      this.logger.warn("No pure renames found in staged changes");
      if (otherChanges.length > 0) {
        this.logger.info("Sample of other changes (up to 5):");
        otherChanges.slice(0, 5).forEach((change) => console.log(`  ${change}`));
      }
      return;
    }

    this.logger.success(`Found ${pureRenames.length} pure rename(s) to commit:`);
    pureRenames.slice(0, 5).forEach((change) => console.log(`  ${change}`));
    if (pureRenames.length > 5) {
      console.log(`  ... and ${pureRenames.length - 5} more`);
    }

    // Warn about other changes
    if (otherChanges.length > 0) {
      this.logger.warn(
        `Found ${otherChanges.length} other change(s) that will NOT be committed:`
      );
      otherChanges.slice(0, 5).forEach((change) => console.log(`  ${change}`));
      if (otherChanges.length > 5) {
        console.log(`  ... and ${otherChanges.length - 5} more`);
      }

      const shouldContinue = await ctx.confirm(
        "Do you want to continue and commit only the pure renames?"
      );
      if (!shouldContinue) {
        this.logger.error("Operation cancelled by user");
        process.exit(1);
      }
    }

    // Get commit message
    let commitMessage = message;
    if (!commitMessage || commitMessage.trim() === "") {
      commitMessage = await ctx.prompt(
        "💬 Enter commit message for the pure renames"
      );
      if (!commitMessage || commitMessage.trim() === "") {
        this.logger.error("Commit message cannot be empty");
        process.exit(1);
      }
    } else {
      this.logger.info(`Using provided commit message: ${commitMessage}`);
    }

    // Reset and stage only renames
    this.logger.info("Resetting staged changes...");
    await this.shell.exec({ command: "git reset", silent: true });

    this.logger.info("Staging only pure renames...");
    for (const rename of pureRenames) {
      // Parse: R100\told_file\tnew_file
      const parts = rename.split("\t");
      const oldFile = parts[1];
      const newFile = parts[2];
      await this.shell.exec({
        command: `git add '${oldFile}' '${newFile}'`,
        silent: true,
      });
    }

    // Commit
    this.logger.progress("Committing pure renames...");
    let commitCommand = `git commit -m "${commitMessage.replace(/"/g, '\\"')}"`;
    if (noVerify) {
      commitCommand += " --no-verify";
      this.logger.info("Skipping pre-commit hooks with --no-verify");
    }

    const commitResult = await this.shell.exec({ command: commitCommand });
    if (commitResult.success) {
      this.logger.success(
        `Successfully committed ${pureRenames.length} pure rename(s)`
      );
      this.logger.info("Final repository status:");
      await this.shell.exec({ command: "git status --short" });
    } else {
      this.logger.error("Failed to commit changes");
      process.exit(1);
    }
  }
}
