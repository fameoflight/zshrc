import { Script } from "./Script";
import type { ScriptDependencies, GitService, Context } from "../types";

/**
 * Base class for Git-related scripts
 *
 * Extends Script with:
 * - Git service injection
 * - Git repository validation
 * - Common Git helper methods
 *
 * @example
 * @Script({ args: { ... } })
 * export class MyGitScript extends GitScript {
 *   async run(ctx: Context) {
 *     const files = await ctx.git.getChangedFiles({});
 *     // ...
 *   }
 * }
 */
export abstract class GitScript extends Script {
  protected readonly git: GitService;

  constructor(deps: ScriptDependencies) {
    super(deps);

    if (!deps.git) {
      throw new Error("GitService is required for GitScript");
    }

    this.git = deps.git;
  }

  /**
   * Validate we're in a git repository
   * Called automatically before run()
   */
  async validate(ctx: Context): Promise<void> {
    try {
      await this.git.validateRepository();
    } catch (error: any) {
      throw new Error(
        "Not a git repository. Please run this command from within a git repository."
      );
    }
  }

  /**
   * Helper: Get current branch name
   */
  protected async getCurrentBranch(): Promise<string> {
    const result = await this.shell.exec({
      command: "git rev-parse --abbrev-ref HEAD",
      silent: true,
    });

    if (!result.success) {
      throw new Error("Failed to get current branch");
    }

    return result.stdout.trim();
  }

  /**
   * Helper: Check if working directory is clean
   */
  protected async isWorkingDirectoryClean(): Promise<boolean> {
    const result = await this.shell.exec({
      command: "git status --porcelain",
      silent: true,
    });

    return result.stdout.trim() === "";
  }

  /**
   * Helper: Require clean working directory
   */
  protected async requireCleanWorkingDirectory(message?: string): Promise<void> {
    const clean = await this.isWorkingDirectoryClean();
    if (!clean) {
      throw new Error(
        message || "Working directory has uncommitted changes. Please commit or stash them first."
      );
    }
  }

  /**
   * Helper: Check if we're on a specific branch
   */
  protected async requireBranch(branch: string, message?: string): Promise<void> {
    const current = await this.getCurrentBranch();
    if (current !== branch) {
      throw new Error(message || `Must be on ${branch} branch (currently on ${current})`);
    }
  }

  /**
   * Helper: Format git file status for display
   */
  protected formatFileStatus(status: string): string {
    const statusMap: Record<string, string> = {
      M: "Modified",
      A: "Added",
      D: "Deleted",
      R: "Renamed",
      C: "Copied",
      U: "Unmerged",
      "??": "Untracked",
    };

    return statusMap[status] || status;
  }
}
