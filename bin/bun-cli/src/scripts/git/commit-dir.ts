import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import type { Context } from "../../core/types";

/**
 * Stage and commit changes in a specific directory
 *
 * Commits all changes within a given directory, making it easy to
 * create focused commits for specific parts of your codebase.
 *
 * @example
 * commit-dir src/components
 * commit-dir lib --message "Update library"
 * commit-dir docs --no-verify
 */
@Script({
  emoji: "📁",
  tags: ["git", "commit"],
  args: {
    directory: {
      type: "string",
      position: 0,
      required: true,
      description: "Directory to stage and commit changes from",
    },
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
export class GitCommitDirScript extends GitScript {
  async validate(ctx: Context): Promise<void> {
    // First validate git repository
    await super.validate(ctx);

    const { directory } = ctx.args;

    // Check if directory exists
    if (!(await this.fs.exists(directory))) {
      throw new Error(`Directory '${directory}' does not exist`);
    }

    if (!(await this.fs.isDirectory(directory))) {
      throw new Error(`'${directory}' is not a directory`);
    }
  }

  async run(ctx: Context): Promise<void> {
    const { directory, message, noVerify } = ctx.args;

    this.logger.banner(`Git Commit Directory - ${directory}`);

    this.logger.info(`Checking for changes in directory: ${directory}`);

    // Check if there are any changes in the specified directory
    const result = await this.shell.exec({
      command: `git status --porcelain "${directory}"`,
      silent: true,
    });

    if (!result.success || result.stdout.trim() === "") {
      this.logger.warn(`No changes found in directory: ${directory}`);
      return;
    }

    console.log("");
    console.log(`Changes to be committed in '${directory}':`);
    console.log(result.stdout.trim());
    console.log("");

    // Get commit message
    let commitMessage = message;
    if (!commitMessage || commitMessage.trim() === "") {
      commitMessage = await ctx.prompt(
        `💬 Enter commit message for changes in '${directory}'`
      );
      if (!commitMessage || commitMessage.trim() === "") {
        this.logger.error("Commit message cannot be empty");
        process.exit(1);
      }
    } else {
      this.logger.info(`Using provided commit message: ${commitMessage}`);
    }

    // Confirm before staging
    const shouldContinue = await ctx.confirm("Stage and commit these changes?");
    if (!shouldContinue) {
      this.logger.info(`Skipping commit for directory: ${directory}`);
      return;
    }

    // Stage directory
    this.logger.info(`Staging changes in directory: ${directory}`);
    const stageResult = await this.shell.exec({
      command: `git add "${directory}"`,
    });

    if (!stageResult.success) {
      this.logger.error("Failed to stage changes");
      process.exit(1);
    }

    // Commit
    this.logger.info(`Committing changes with message: ${commitMessage}`);
    let commitCommand = `git commit -m "${commitMessage.replace(/"/g, '\\"')}"`;
    if (noVerify) {
      commitCommand += " --no-verify";
      this.logger.info("Skipping pre-commit hooks with --no-verify");
    }

    const commitResult = await this.shell.exec({ command: commitCommand });
    if (commitResult.success) {
      this.logger.success(`Changes in '${directory}' committed successfully!`);
    } else {
      this.logger.error("Failed to commit changes");
      process.exit(1);
    }
  }
}
