import type {
  GitService as GitServiceInterface,
  GitFile,
  CommitInfo,
  ShellExecutor,
  Logger,
} from "../types";

/**
 * Git operations service
 *
 * Provides type-safe Git operations using shell executor
 */
export class GitService implements GitServiceInterface {
  constructor(
    private deps: {
      shell: ShellExecutor;
      logger: Logger;
    }
  ) {}

  /**
   * Validate we're in a git repository
   */
  async validateRepository(): Promise<void> {
    const result = await this.deps.shell.exec({
      command: "git rev-parse --git-dir",
      silent: true,
    });

    if (!result.success) {
      throw new Error("Not a git repository");
    }
  }

  /**
   * Get changed files in repository
   *
   * @param params Options object (follows 5-param law)
   */
  async getChangedFiles(params: {
    directory?: string;
    staged?: boolean;
  }): Promise<GitFile[]> {
    const { directory, staged } = params;

    // Build command based on options
    let command = "git status --porcelain";
    if (staged) {
      command += " --staged";
    }
    if (directory) {
      command += ` -- ${directory}`;
    }

    const result = await this.deps.shell.exec({
      command,
      silent: true,
    });

    if (!result.success) {
      throw new Error(`Failed to get changed files: ${result.stderr}`);
    }

    return this.parseStatusOutput(result.stdout);
  }

  /**
   * Stage files for commit
   */
  async stageFiles(params: { paths: string[] }): Promise<void> {
    const { paths } = params;

    if (paths.length === 0) {
      return;
    }

    const pathList = paths.map((p) => `"${p}"`).join(" ");
    const result = await this.deps.shell.exec({
      command: `git add ${pathList}`,
      description: `Staging ${paths.length} file(s)`,
    });

    if (!result.success) {
      throw new Error(`Failed to stage files: ${result.stderr}`);
    }
  }

  /**
   * Create a commit
   */
  async commit(params: {
    message: string;
    noVerify?: boolean;
    amend?: boolean;
  }): Promise<CommitInfo> {
    const { message, noVerify, amend } = params;

    // Build command
    let command = 'git commit -m "';
    command += message.replace(/"/g, '\\"'); // Escape quotes
    command += '"';

    if (noVerify) {
      command += " --no-verify";
    }
    if (amend) {
      command += " --amend";
    }

    const result = await this.deps.shell.exec({
      command,
      description: "Creating commit",
    });

    if (!result.success) {
      throw new Error(`Failed to create commit: ${result.stderr}`);
    }

    // Get info about the new commit
    return this.getCommitInfo({ ref: "HEAD" });
  }

  /**
   * Get commit information
   */
  async getCommitInfo(params: { ref: string }): Promise<CommitInfo> {
    const { ref } = params;

    const result = await this.deps.shell.exec({
      command: `git show ${ref} --format="%H%n%an%n%ae%n%s%n%ai" --no-patch`,
      silent: true,
    });

    if (!result.success) {
      throw new Error(`Failed to get commit info: ${result.stderr}`);
    }

    return this.parseCommitInfo(result.stdout);
  }

  /**
   * Parse git status --porcelain output
   */
  private parseStatusOutput(output: string): GitFile[] {
    if (!output.trim()) {
      return [];
    }

    return output
      .trim()
      .split("\n")
      .map((line) => {
        // Format: XY path
        // X = staged status, Y = unstaged status
        const status = line.substring(0, 2).trim();
        const path = line.substring(3).trim();

        // File is staged if first character is not space or ?
        const staged = status[0] !== " " && status[0] !== "?";

        return {
          path,
          status,
          staged,
        };
      });
  }

  /**
   * Parse git show output for commit info
   */
  private parseCommitInfo(output: string): CommitInfo {
    const lines = output.trim().split("\n");

    if (lines.length < 5) {
      throw new Error("Invalid commit info format");
    }

    return {
      hash: lines[0],
      author: lines[1],
      email: lines[2],
      subject: lines[3],
      date: new Date(lines[4]),
    };
  }
}
