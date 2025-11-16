import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import type { Context } from "../../core/types";
import { confirm, select } from "@clack/prompts";
import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";

interface SubmoduleInfo {
  name: string;
  path: string;
  commit: string;
  description: string;
  url: string;
}

type SubmoduleAction = "preserve" | "convert" | "remove";

/**
 * Compress git history by creating fresh repository with single commit
 *
 * ⚠️  WARNING: This is a DESTRUCTIVE operation!
 * - Deletes all git history
 * - Creates new repository with single commit
 * - Requires force push to remote
 *
 * Features:
 * - Safety checks for pending changes
 * - Remote sync validation
 * - Submodule handling (preserve/convert/remove)
 * - Creates backup before compression
 * - Generates recovery information
 *
 * @example
 * compress                    # Compress with default commit message
 * compress -m 'Fresh start'   # Custom initial commit message
 * compress --force           # Skip all confirmations (dangerous)
 */
@Script({
  emoji: "🗜️",
  tags: ["git", "history"],
  args: {
    message: {
      type: "string",
      flag: "-m, --message",
      default: "Initial commit",
      description: "Initial commit message",
    },
    force: {
      type: "boolean",
      flag: "-f, --force",
      description: "Skip confirmations (dangerous!)",
    },
  },
})
export class GitCompress extends GitScript {
  private submodules: SubmoduleInfo[] = [];
  private submoduleActions: Map<string, SubmoduleAction> = new Map();
  private backupDir?: string;

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Git History Compression");

    // Check if we have any pending changes
    await this.checkPendingChanges(ctx);

    // Get the remote URL
    const remoteUrl = await this.getRemoteUrl();
    if (!remoteUrl) {
      this.logger.error("No remote URL found");
      process.exit(1);
    }

    // Show repository information
    await this.showRepositoryInfo();

    // Handle submodules if any exist
    if (this.submodules.length > 0) {
      await this.handleSubmodules();
    }

    // Get user confirmation with detailed warning
    const confirmed = await this.confirmCompression(ctx);
    if (!confirmed) {
      this.logger.info("Compression cancelled");
      return;
    }

    // Perform the compression
    await this.performCompression(remoteUrl, ctx);

    this.logger.success("Git history compression complete");
  }

  private async checkPendingChanges(ctx: Context): Promise<void> {
    this.logger.info("Checking for pending changes...");

    // Check for uncommitted changes
    const statusResult = await this.shell.exec({
      command: "git status --porcelain",
      silent: true,
    });

    if (statusResult.stdout.trim() !== "") {
      this.logger.error("Repository has pending changes:");
      console.log(statusResult.stdout);
      this.logger.error("Please commit or stash all changes before running git-compress");
      process.exit(1);
    }

    // Check if we're in sync with remote
    const branchResult = await this.shell.exec({
      command: "git rev-parse --abbrev-ref HEAD",
      silent: true,
    });

    const branchName = branchResult.stdout.trim();
    if (branchName !== "HEAD") {
      this.logger.info(`Checking if branch '${branchName}' is in sync with remote...`);

      // Check if remote exists and we're tracking it
      const trackingResult = await this.shell.exec({
        command: `git config branch.${branchName}.remote`,
        silent: true,
      });

      if (trackingResult.success && trackingResult.stdout.trim()) {
        const trackingRemote = trackingResult.stdout.trim();
        const aheadBehindResult = await this.shell.exec({
          command: `git rev-list --count --left-right ${trackingRemote}/${branchName}...${branchName}`,
          silent: true,
        });

        if (aheadBehindResult.success) {
          const [behindStr, aheadStr] = aheadBehindResult.stdout.trim().split("\t");
          const behindCount = parseInt(behindStr);
          const aheadCount = parseInt(aheadStr);

          if (behindCount > 0) {
            this.logger.warn(`Your branch is ${behindCount} commit(s) behind remote.`);
            this.logger.warn("Please pull latest changes before running git-compress");
            if (!ctx.args.force) {
              process.exit(1);
            }
          }

          if (aheadCount > 0) {
            this.logger.warn(`Your branch is ${aheadCount} commit(s) ahead of remote.`);
            this.logger.warn("These changes will be lost if you continue!");

            if (!ctx.args.force) {
              const proceed = await confirm({
                message: "Continue despite having unpushed commits?",
                initialValue: false,
              });

              if (typeof proceed === "symbol" || !proceed) {
                process.exit(1);
              }
            }
          }
        }
      }
    }

    this.logger.success("Repository is clean and in sync with remote");
  }

  private async getRemoteUrl(): Promise<string | null> {
    this.logger.info("Getting remote URL...");

    // Try origin first
    let remoteResult = await this.shell.exec({
      command: "git config remote.origin.url",
      silent: true,
    });

    if (remoteResult.success && remoteResult.stdout.trim()) {
      const url = remoteResult.stdout.trim();
      this.logger.info(`Using origin remote: ${url}`);
      return url;
    }

    // Try any remote
    this.logger.warn("No origin remote found, looking for any remote...");
    const remotesResult = await this.shell.exec({
      command: "git remote",
      silent: true,
    });

    const remotes = remotesResult.stdout.trim().split("\n").filter(r => r);
    if (remotes.length === 0) {
      this.logger.error("No remote found in this repository");
      this.logger.error("git-compress requires a remote to restore from");
      return null;
    }

    remoteResult = await this.shell.exec({
      command: `git config remote.${remotes[0]}.url`,
      silent: true,
    });

    const url = remoteResult.stdout.trim();
    this.logger.info(`Using remote '${remotes[0]}': ${url}`);
    return url;
  }

  private async showRepositoryInfo(): Promise<void> {
    this.logger.section("Repository Information");

    // Show current commit info
    const commitHash = await this.shell.exec({ command: "git rev-parse HEAD", silent: true });
    const commitMsg = await this.shell.exec({ command: 'git log -1 --pretty=format:"%s"', silent: true });
    const commitDate = await this.shell.exec({ command: 'git log -1 --pretty=format:"%ad" --date=short', silent: true });
    const commitAuthor = await this.shell.exec({ command: 'git log -1 --pretty=format:"%an"', silent: true });

    console.log(`  Current HEAD: ${commitHash.stdout.trim()}`);
    console.log(`  Commit: ${commitMsg.stdout.trim()}`);
    console.log(`  Author: ${commitAuthor.stdout.trim()}`);
    console.log(`  Date: ${commitDate.stdout.trim()}`);

    // Show total commit count
    const countResult = await this.shell.exec({ command: "git rev-list --count HEAD", silent: true });
    console.log(`  Total commits: ${countResult.stdout.trim()}`);

    // Show branch info
    const branchResult = await this.shell.exec({ command: "git rev-parse --abbrev-ref HEAD", silent: true });
    console.log(`  Current branch: ${branchResult.stdout.trim()}`);

    // Show repository size
    const sizeResult = await this.shell.exec({ command: "du -sh .git", silent: true });
    if (sizeResult.success) {
      console.log(`  Git directory size: ${sizeResult.stdout.trim()}`);
    }

    // Show submodule information
    await this.showSubmoduleInfo();

    console.log();
  }

  private async showSubmoduleInfo(): Promise<void> {
    this.submodules = await this.getSubmodules();

    if (this.submodules.length === 0) {
      this.logger.info("No submodules found");
      return;
    }

    this.logger.section(`Submodules (${this.submodules.length} found)`);

    for (let i = 0; i < this.submodules.length; i++) {
      const submodule = this.submodules[i];
      const status = await this.getSubmoduleStatus(submodule);
      console.log(`  ${i + 1}. ${submodule.name} (${status})`);
    }
  }

  private async getSubmodules(): Promise<SubmoduleInfo[]> {
    const statusResult = await this.shell.exec({
      command: "git submodule status",
      silent: true,
    });

    if (!statusResult.success || !statusResult.stdout.trim()) {
      return [];
    }

    const submodules: SubmoduleInfo[] = [];

    for (const line of statusResult.stdout.trim().split("\n")) {
      if (!line.trim()) continue;

      const parts = line.trim().split(/\s+/, 3);
      if (parts.length < 2) continue;

      const commit = parts[0].replace(/^[+-]/, "");
      const path = parts[1];
      const description = parts[2] || path;

      const urlResult = await this.shell.exec({
        command: `git config submodule.${path}.url`,
        silent: true,
      });

      submodules.push({
        name: path,
        path,
        commit,
        description,
        url: urlResult.stdout.trim(),
      });
    }

    return submodules;
  }

  private async getSubmoduleStatus(submodule: SubmoduleInfo): Promise<string> {
    const { path: subPath } = submodule;

    // Check if submodule directory exists
    try {
      await fs.access(subPath);
    } catch {
      return "missing";
    }

    // Check for uncommitted changes in submodule
    const statusResult = await this.shell.exec({
      command: "git status --porcelain",
      cwd: subPath,
      silent: true,
    });

    if (statusResult.success && statusResult.stdout.trim()) {
      const fileCount = statusResult.stdout.trim().split("\n").length;
      return `dirty - ${fileCount} uncommitted files`;
    }

    // Check if submodule is on different commit
    const submoduleStatusResult = await this.shell.exec({
      command: `git submodule status ${subPath}`,
      silent: true,
    });

    if (submoduleStatusResult.stdout.startsWith("+")) {
      return "different commit";
    } else if (submoduleStatusResult.stdout.startsWith("-")) {
      return "not initialized";
    }

    return "clean";
  }

  private async handleSubmodules(): Promise<void> {
    this.logger.section("Submodule Handling");

    console.log(`This repository contains ${this.submodules.length} submodule(s):`);
    console.log();

    for (let i = 0; i < this.submodules.length; i++) {
      const submodule = this.submodules[i];
      const status = await this.getSubmoduleStatus(submodule);
      console.log(`  ${i + 1}. ${submodule.name} (${status})`);
    }

    console.log();
    console.log("How would you like to handle these submodules?");
    console.log("  1) Preserve all submodules (backup and restore after compression)");
    console.log("  2) Convert to regular directories (include as normal folders)");
    console.log("  3) Remove all submodules (exclude from compressed repository)");
    console.log();

    const choice = await select({
      message: "Choose option:",
      options: [
        { label: "1) Preserve all submodules", value: "1" },
        { label: "2) Convert to regular directories", value: "2" },
        { label: "3) Remove all submodules", value: "3" },
      ],
    });

    if (typeof choice === "symbol") {
      process.exit(0);
    }

    switch (choice) {
      case "1":
        this.preserveAllSubmodules();
        break;
      case "2":
        this.convertAllSubmodules();
        break;
      case "3":
        this.removeAllSubmodules();
        break;
    }

    console.log();
  }

  private preserveAllSubmodules(): void {
    this.logger.info("Preserving all submodules...");
    for (const submodule of this.submodules) {
      this.submoduleActions.set(submodule.name, "preserve");
    }
    this.logger.success(`All ${this.submodules.length} submodules will be preserved`);
  }

  private convertAllSubmodules(): void {
    this.logger.info("Converting all submodules to regular directories...");
    for (const submodule of this.submodules) {
      this.submoduleActions.set(submodule.name, "convert");
    }
    this.logger.success(`All ${this.submodules.length} submodules will be converted`);
  }

  private removeAllSubmodules(): void {
    this.logger.warn("Removing all submodules...");
    for (const submodule of this.submodules) {
      this.submoduleActions.set(submodule.name, "remove");
    }
    this.logger.warn(`All ${this.submodules.length} submodules will be removed`);
  }

  private async confirmCompression(ctx: Context): Promise<boolean> {
    this.logger.section("⚠️  WARNING - IRREVERSIBLE OPERATION");

    console.log("This operation will:");
    console.log("  1. DELETE the .git folder (all history will be lost)");
    console.log("  2. CREATE a new git repository");
    console.log("  3. COMMIT all current files as a single initial commit");
    console.log("  4. ADD the remote URL back");

    // Add submodule information to warning
    if (this.submoduleActions.size > 0) {
      console.log();
      console.log("Submodule handling:");
      for (const [name, action] of this.submoduleActions.entries()) {
        switch (action) {
          case "preserve":
            console.log(`  • ${name}: Will be preserved (backup and restore)`);
            break;
          case "convert":
            console.log(`  • ${name}: Will be converted to regular directory`);
            break;
          case "remove":
            console.log(`  • ${name}: Will be removed from repository`);
            break;
        }
      }
    }

    console.log();
    console.log("After completion, you will need to:");
    console.log("  • Run 'git push --force-with-lease' to overwrite remote history");
    console.log();
    console.log("To restore your repository if something goes wrong:");
    console.log("  • Clone the repository again from the remote URL");
    console.log();

    if (ctx.args.force) {
      this.logger.warn("Force flag detected - skipping confirmation");
      return true;
    }

    const result = await confirm({
      message: "Are you absolutely sure you want to compress the git history? This cannot be undone.",
      initialValue: false,
    });

    if (typeof result === "symbol") {
      return false;
    }

    return result as boolean;
  }

  private async performCompression(remoteUrl: string, ctx: Context): Promise<void> {
    this.logger.section("Compressing Git History");

    // Store current commit info for potential restoration
    const currentCommitResult = await this.shell.exec({
      command: "git rev-parse HEAD",
      silent: true,
    });
    const currentCommit = currentCommitResult.stdout.trim();
    this.logger.info(`Current commit saved for reference: ${currentCommit}`);

    // Step 1: Handle submodules before compression
    await this.handleSubmodulesBeforeCompression();

    // Step 2: Remove .git directory
    this.logger.progress("Removing .git directory...");
    const rmResult = await this.shell.exec({
      command: "rm -rf .git",
      silent: true,
    });

    if (!rmResult.success) {
      this.logger.error("Failed to remove .git directory");
      process.exit(1);
    }
    this.logger.success(".git directory removed");

    // Step 3: Initialize new repository
    this.logger.progress("Initializing new git repository...");
    const initResult = await this.shell.exec({
      command: "git init",
      silent: false,
    });

    if (!initResult.success) {
      this.logger.error("Failed to initialize new git repository");
      process.exit(1);
    }
    this.logger.success("New git repository initialized");

    // Step 4: Add all files
    this.logger.progress("Adding all files...");
    const addResult = await this.shell.exec({
      command: "git add .",
      silent: false,
    });

    if (!addResult.success) {
      this.logger.error("Failed to add files");
      process.exit(1);
    }
    this.logger.success("All files added to staging");

    // Step 5: Create initial commit
    const commitMessage = ctx.args.message;
    this.logger.progress(`Creating initial commit: '${commitMessage}'`);

    let commitCommand = `git commit -m "${commitMessage.replace(/"/g, '\\"')}"`;
    if (ctx.args.force) {
      commitCommand += " --no-verify";
      this.logger.info("Force flag detected, skipping pre-commit hooks with --no-verify.");
    }

    const commitResult = await this.shell.exec({
      command: commitCommand,
      silent: false,
    });

    if (!commitResult.success) {
      this.logger.error("Failed to create initial commit");
      process.exit(1);
    }
    this.logger.success("Initial commit created");

    // Step 6: Handle submodules after compression
    await this.handleSubmodulesAfterCompression();

    // Step 7: Add remote URL
    this.logger.progress(`Adding remote URL: ${remoteUrl}`);
    const remoteResult = await this.shell.exec({
      command: `git remote add origin '${remoteUrl}'`,
      silent: true,
    });

    if (!remoteResult.success) {
      this.logger.error("Failed to add remote URL");
      process.exit(1);
    }
    this.logger.success("Remote URL added");

    // Step 8: Show final status
    this.logger.section("Compression Complete");
    console.log("✅ Git history has been compressed to a single commit");
    console.log();
    console.log("Next steps:");
    console.log("  1. Review the repository: git status");
    console.log("  2. Push to remote (WARNING: This will overwrite remote history):");
    const branchResult = await this.shell.exec({ command: "git rev-parse --abbrev-ref HEAD", silent: true });
    console.log(`     git push --force-with-lease origin ${branchResult.stdout.trim()}`);
    console.log();
    console.log("To restore original repository if needed:");
    console.log(`  1. Note the remote URL: ${remoteUrl}`);
    console.log(`  2. Clone again: git clone ${remoteUrl} temp-repo`);
    console.log("  3. Move files as needed");
    console.log();

    // Save recovery info
    await this.saveRecoveryInfo(remoteUrl, currentCommit);
  }

  private async saveRecoveryInfo(remoteUrl: string, originalCommit: string): Promise<void> {
    const recoveryFile = ".git-compress-recovery.txt";

    const content = `# Git Compress Recovery Information
# Generated on: ${new Date().toLocaleString()}

Remote URL: ${remoteUrl}
Original Commit: ${originalCommit}
Compression Date: ${new Date().toISOString()}

# To restore original repository:
# 1. Clone: git clone ${remoteUrl} original-repo
# 2. Your files are safe in the current directory
# 3. Remove this recovery file when done
`;

    await fs.writeFile(recoveryFile, content);
    this.logger.info("Recovery information saved to .git-compress-recovery.txt");
  }

  private async handleSubmodulesBeforeCompression(): Promise<void> {
    if (this.submoduleActions.size === 0) return;

    this.logger.section("Handling Submodules Before Compression");

    // Create temporary backup directory
    this.backupDir = await fs.mkdtemp(path.join(os.tmpdir(), "git-compress-"));
    this.logger.info(`Created backup directory: ${this.backupDir}`);

    // Handle each submodule according to its action
    for (const [name, action] of this.submoduleActions.entries()) {
      switch (action) {
        case "preserve":
          await this.backupSubmodule(name);
          break;
        case "remove":
          await this.removeSubmoduleDirectory(name);
          break;
        case "convert":
          // No action needed - just leave it as regular directory
          this.logger.info(`📁 ${name}: Converting to regular directory (no action needed)`);
          break;
      }
    }

    this.logger.success("Submodule pre-compression handling completed");
  }

  private async handleSubmodulesAfterCompression(): Promise<void> {
    if (this.submoduleActions.size === 0) return;

    this.logger.section("Handling Submodules After Compression");

    let restoredCount = 0;

    for (const [name, action] of this.submoduleActions.entries()) {
      if (action === "preserve") {
        await this.restoreSubmodule(name);
        restoredCount++;
      }
    }

    // Commit restored submodules if any were restored
    if (restoredCount > 0) {
      this.logger.progress("Committing restored submodules...");
      const amendResult = await this.shell.exec({
        command: "git commit --amend --no-edit --no-verify",
        silent: false,
      });

      if (!amendResult.success) {
        this.logger.warn("Failed to amend commit with restored submodules");
      } else {
        this.logger.success(`Restored ${restoredCount} submodule(s) and amended initial commit`);
      }
    }

    // Clean up backup directory
    if (this.backupDir) {
      this.logger.progress("Cleaning up backup directory...");
      await fs.rm(this.backupDir, { recursive: true, force: true });
      this.logger.success("Backup directory cleaned up");
    }

    this.logger.success("Submodule post-compression handling completed");
  }

  private async backupSubmodule(name: string): Promise<void> {
    try {
      await fs.access(name);
    } catch {
      this.logger.warn(`⚠️  ${name}: Submodule directory not found, skipping backup`);
      return;
    }

    const backupPath = path.join(this.backupDir!, name);
    this.logger.progress(`📦 Backing up ${name}...`);

    try {
      await this.shell.exec({
        command: `cp -r '${name}' '${backupPath}'`,
        silent: true,
      });

      try {
        await fs.access(backupPath);
        this.logger.success(`✅ ${name}: Backed up successfully`);
      } catch {
        this.logger.error(`❌ ${name}: Backup failed`);
      }
    } catch (error) {
      this.logger.error(`❌ ${name}: Backup failed - ${(error as Error).message}`);
    }
  }

  private async restoreSubmodule(name: string): Promise<void> {
    const backupPath = path.join(this.backupDir!, name);

    try {
      await fs.access(backupPath);
    } catch {
      this.logger.warn(`⚠️  ${name}: Backup not found, skipping restore`);
      return;
    }

    this.logger.progress(`🔄 Restoring ${name}...`);

    try {
      // Remove the empty directory that was committed
      try {
        await fs.rm(name, { recursive: true, force: true });
      } catch {
        // Ignore errors
      }

      // Restore from backup
      await this.shell.exec({
        command: `cp -r '${backupPath}' '${name}'`,
        silent: true,
      });

      try {
        await fs.access(name);
        // Add restored submodule to git
        await this.shell.exec({
          command: `git add '${name}'`,
          silent: true,
        });
        this.logger.success(`✅ ${name}: Restored successfully`);
      } catch {
        this.logger.error(`❌ ${name}: Restore failed`);
      }
    } catch (error) {
      this.logger.error(`❌ ${name}: Restore failed - ${(error as Error).message}`);
    }
  }

  private async removeSubmoduleDirectory(name: string): Promise<void> {
    try {
      await fs.access(name);
    } catch {
      this.logger.warn(`⚠️  ${name}: Directory not found, skipping removal`);
      return;
    }

    this.logger.progress(`🗑️  Removing ${name}...`);

    try {
      await fs.rm(name, { recursive: true, force: true });
      this.logger.success(`✅ ${name}: Removed successfully`);
    } catch (error) {
      this.logger.error(`❌ ${name}: Removal failed - ${(error as Error).message}`);
    }
  }
}
