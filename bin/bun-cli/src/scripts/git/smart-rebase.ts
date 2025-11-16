import { Script } from "../../core/decorators/Script";
import { GitScript } from "../../core/base/GitScript";
import type { Context } from "../../core/types";
import { confirm, text } from "@clack/prompts";

interface ChangeAnalysis {
  hasChanges: boolean;
  hasRealChanges: boolean;
  permissionChanges: boolean;
  whitespaceChanges: boolean;
  changes: ChangeInfo[];
}

interface ChangeInfo {
  status: string;
  path: string;
  type: "permission" | "whitespace" | "content";
}

interface ConflictCheck {
  hasConflicts: boolean;
  conflictFiles: string[];
}

/**
 * Smart Git Rebase - Automatically handles permission/whitespace conflicts during rebase
 *
 * Features:
 * - Auto-detects main/master branch
 * - Creates backup branch before rebasing
 * - Analyzes changes (permission-only, whitespace-only, or content changes)
 * - Auto-resolves permission and whitespace conflicts
 * - Can squash commits after rebase
 * - Dry-run mode
 *
 * @example
 * smart-rebase                    # Rebase current branch onto detected main/master
 * smart-rebase main              # Rebase current branch onto main
 * smart-rebase develop           # Rebase current branch onto develop
 * smart-rebase --force main      # Skip confirmations and auto-resolve
 * smart-rebase --dry-run main    # Show what would be done
 * smart-rebase --squash main     # Rebase and squash all commits into one
 * smart-rebase -s -m 'Fix bug' main  # Squash with custom message
 */
@Script({
  emoji: "🔄",
  tags: ["git", "rebase"],
  args: {
    targetBranch: {
      type: "string",
      position: 0,
      required: false,
      description: "Target branch to rebase onto (defaults to main/master)",
    },
    force: {
      type: "boolean",
      flag: "-f, --force",
      description: "Skip confirmation prompts and auto-resolve conflicts",
    },
    dryRun: {
      type: "boolean",
      flag: "-d, --dry-run",
      description: "Show what would be done without making changes",
    },
    keepBackup: {
      type: "boolean",
      flag: "-k, --keep-backup",
      description: "Keep backup branch after successful rebase",
    },
    squash: {
      type: "boolean",
      flag: "-s, --squash",
      description: "Squash all commits into one after rebase",
    },
    message: {
      type: "string",
      flag: "-m, --message",
      description: "Commit message for squashed commit",
    },
  },
})
export class SmartRebase extends GitScript {
  private targetBranch!: string;
  private currentBranch!: string;
  private backupBranch!: string;
  private commitCount: number = 0;

  async validate(ctx: Context): Promise<void> {
    // First validate we're in a git repo
    await super.validate(ctx);

    // Get current branch
    this.currentBranch = await this.getCurrentBranch();

    // Get target branch from argument or detect main/master
    this.targetBranch = ctx.args.targetBranch || (await this.detectMainBranch());

    // Validate target branch exists
    const branchExists = await this.shell.exec({
      command: `git rev-parse --verify ${this.targetBranch}`,
      silent: true,
    });

    if (!branchExists.success) {
      throw new Error(`Target branch '${this.targetBranch}' not found`);
    }

    // Cannot rebase branch onto itself
    if (this.currentBranch === this.targetBranch) {
      throw new Error(`Cannot rebase ${this.currentBranch} onto itself`);
    }

    this.logger.debug(`Target branch: ${this.targetBranch}`);
    this.logger.debug(`Current branch: ${this.currentBranch}`);
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Git Smart Rebase");

    // Pre-flight checks
    await this.preFlightChecks(ctx);

    // Analyze changes if any exist
    const changeAnalysis = await this.analyzeLocalChanges();

    if (changeAnalysis.hasRealChanges && !ctx.args.force) {
      this.logger.error("Found real content changes that would be lost.");
      this.logger.error("Commit or stash these changes first, or use --force to proceed anyway.");
      process.exit(1);
    }

    // Show rebase plan
    await this.showRebasePlan(changeAnalysis, ctx);

    // Get confirmation unless forced
    if (!ctx.args.force && !ctx.args.dryRun) {
      const proceed = await this.confirmRebase();
      if (!proceed) {
        this.logger.info("Rebase cancelled");
        return;
      }
    }

    // Perform smart rebase
    await this.performSmartRebase(changeAnalysis, ctx);

    this.logger.success("🎉 Smart rebase completed successfully!");
  }

  private async detectMainBranch(): Promise<string> {
    // Try to detect main/master branch
    const branches = [
      "origin/main",
      "origin/master",
      "main",
      "master",
    ];

    for (const branch of branches) {
      const result = await this.shell.exec({
        command: `git rev-parse --verify ${branch}`,
        silent: true,
      });

      if (result.success) {
        return branch.replace("origin/", "");
      }
    }

    throw new Error("Could not detect main/master branch. Please specify target branch.");
  }

  private async preFlightChecks(ctx: Context): Promise<void> {
    this.logger.section("Pre-flight Checks");

    // Check if working directory is clean
    const statusResult = await this.shell.exec({
      command: "git status --porcelain",
      silent: true,
    });

    if (statusResult.stdout.trim() === "") {
      this.logger.success("✅ Working directory is clean");
    } else {
      this.logger.info("📋 Working directory has changes:");
      const lines = statusResult.stdout.trim().split("\n");
      lines.forEach(line => console.log(`  ${line}`));
    }

    // Check for unpushed commits
    const unpushedResult = await this.shell.exec({
      command: `git log ${this.targetBranch}..${this.currentBranch} --oneline`,
      silent: true,
    });

    if (unpushedResult.stdout.trim() === "") {
      this.logger.success("✅ Branch is up to date with remote");
      this.commitCount = 0;
    } else {
      this.commitCount = unpushedResult.stdout.trim().split("\n").length;
      this.logger.warn(`⚠️  Branch has ${this.commitCount} unpushed commits`);

      if (ctx.args.squash) {
        if (this.commitCount === 1) {
          this.logger.info("📝 Only 1 commit to squash (no squashing needed)");
          ctx.args.squash = false;
        } else {
          this.logger.success(`📝 Will squash ${this.commitCount} commits into one`);
        }
      }

      if (this.commitCount > 5) {
        this.logger.warn("Consider pushing before rebasing large number of commits");
      }
    }

    // Check for potential conflicts
    this.logger.progress("Checking for potential merge conflicts...");
    const conflictCheck = await this.checkRebaseConflicts();
    if (conflictCheck.hasConflicts) {
      this.logger.warn(`⚠️  Potential conflicts detected in ${conflictCheck.conflictFiles.length} files:`);
      conflictCheck.conflictFiles.forEach(file => console.log(`  🔥 ${file}`));
    } else {
      this.logger.success("✅ No obvious conflicts detected");
    }
  }

  private async analyzeLocalChanges(): Promise<ChangeAnalysis> {
    this.logger.progress("Analyzing local changes...");

    const statusResult = await this.shell.exec({
      command: "git status --porcelain",
      silent: true,
    });

    if (statusResult.stdout.trim() === "") {
      return {
        hasChanges: false,
        hasRealChanges: false,
        permissionChanges: false,
        whitespaceChanges: false,
        changes: [],
      };
    }

    const changes: ChangeInfo[] = [];
    let hasRealChanges = false;
    let permissionChanges = false;
    let whitespaceChanges = false;

    const lines = statusResult.stdout.trim().split("\n");
    for (const line of lines) {
      const parts = line.trim().split(/\s+/, 2);
      if (parts.length < 2) continue;

      const [status, path] = parts;
      const type = await this.categorizeChange(path);

      changes.push({ status, path, type });

      if (type === "permission") {
        permissionChanges = true;
      } else if (type === "whitespace") {
        whitespaceChanges = true;
      } else if (type === "content") {
        hasRealChanges = true;
      }
    }

    return {
      hasChanges: true,
      hasRealChanges,
      permissionChanges,
      whitespaceChanges,
      changes,
    };
  }

  private async categorizeChange(path: string): Promise<"permission" | "whitespace" | "content"> {
    // Check if it's a permission change
    const diffResult = await this.shell.exec({
      command: `git diff --name-only -p "${path}"`,
      silent: true,
    });

    if (diffResult.stdout.includes("old mode") || diffResult.stdout.includes("new mode")) {
      return "permission";
    }

    // Check if it's only whitespace changes
    const contentDiff = await this.shell.exec({
      command: `git diff --ignore-space-change --ignore-all-space "${path}"`,
      silent: true,
    });

    if (contentDiff.stdout.trim() === "") {
      return "whitespace";
    }

    return "content";
  }

  private async checkRebaseConflicts(): Promise<ConflictCheck> {
    // Use merge-tree to check for potential conflicts
    const mergeBase = await this.shell.exec({
      command: `git merge-base ${this.targetBranch} ${this.currentBranch}`,
      silent: true,
    });

    if (!mergeBase.success) {
      return { hasConflicts: false, conflictFiles: [] };
    }

    const base = mergeBase.stdout.trim();
    const mergeTreeResult = await this.shell.exec({
      command: `git merge-tree ${base} ${this.targetBranch} ${this.currentBranch}`,
      silent: true,
    });

    const hasConflicts =
      mergeTreeResult.stdout.includes("CONFLICT") ||
      mergeTreeResult.stdout.includes("<<<<<<<");

    const conflictFiles: string[] = [];
    if (hasConflicts) {
      // Extract conflicted files
      const matches = mergeTreeResult.stdout.matchAll(/^diff --cc (.+)$/gm);
      for (const match of matches) {
        conflictFiles.push(match[1]);
      }
    }

    return { hasConflicts, conflictFiles };
  }

  private async showRebasePlan(changeAnalysis: ChangeAnalysis, ctx: Context): Promise<void> {
    this.logger.section("Rebase Plan");

    console.log(`Current branch: ${this.currentBranch}`);
    console.log(`Target branch:  ${this.targetBranch}`);

    if (changeAnalysis.hasChanges) {
      console.log();
      this.logger.info("📋 Local changes analysis:");

      if (changeAnalysis.permissionChanges) {
        const count = changeAnalysis.changes.filter(c => c.type === "permission").length;
        console.log(`  🔧 Permission-only changes: ${count}`);
      }

      if (changeAnalysis.whitespaceChanges) {
        const count = changeAnalysis.changes.filter(c => c.type === "whitespace").length;
        console.log(`  ␣ Whitespace-only changes: ${count}`);
      }

      if (changeAnalysis.hasRealChanges) {
        const count = changeAnalysis.changes.filter(c => c.type === "content").length;
        console.log(`  📝 Content changes: ${count}`);
      }
    }

    console.log();
    if (ctx.args.dryRun) {
      this.logger.info("🔍 DRY RUN MODE - No changes will be made");
    }

    // Show squashing info if requested
    if (ctx.args.squash && this.commitCount > 1) {
      console.log();
      this.logger.info("📝 Squash configuration:");
      if (ctx.args.message) {
        console.log(`  📋 Squash message: ${ctx.args.message}`);
      } else {
        console.log("  📋 Squash message: Will be prompted after rebase");
      }
    }

    console.log();
    this.logger.info("📋 Planned actions:");
    console.log("  1. Save current state to backup branch");
    if (changeAnalysis.hasChanges) {
      console.log("  2. Stash permission/whitespace changes if needed");
    }
    console.log(`  3. Rebase ${this.currentBranch} onto ${this.targetBranch}`);
    console.log("  4. Auto-resolve with -Xignore-space-change -Xtheirs");

    let step = 5;
    if (ctx.args.squash && this.commitCount > 1) {
      console.log(`  ${step++}. Squash ${this.commitCount} commits into one`);
    }
    if (changeAnalysis.hasChanges) {
      console.log(`  ${step++}. Restore stashed changes`);
    }
    if (!ctx.args.keepBackup) {
      console.log(`  ${step++}. Clean up backup branch`);
    }
  }

  private async confirmRebase(): Promise<boolean> {
    console.log();
    const result = await confirm({
      message: "🤔 Proceed with this rebase plan?",
      initialValue: false,
    });

    // Handle cancellation
    if (typeof result === "symbol") {
      return false;
    }

    return result as boolean;
  }

  private async performSmartRebase(changeAnalysis: ChangeAnalysis, ctx: Context): Promise<void> {
    this.logger.section("Executing Smart Rebase");

    this.backupBranch = `smart-rebase-backup-${this.currentBranch}-${Date.now()}`;

    try {
      // Step 1: Create backup branch
      this.logger.info(`Creating backup branch: ${this.backupBranch}`);
      const backupResult = await this.shell.exec({
        command: `git branch ${this.backupBranch}`,
        silent: true,
      });

      if (!backupResult.success) {
        throw new Error("Failed to create backup branch");
      }

      // Step 2: Handle local changes if needed
      let stashCreated = false;
      if (changeAnalysis.hasChanges && !changeAnalysis.hasRealChanges) {
        this.logger.info("Stashing permission/whitespace changes...");
        await this.shell.exec({
          command: 'git stash push -m "Smart rebase temporary stash" --include-untracked',
          silent: true,
        });
        stashCreated = true;
      }

      if (ctx.args.dryRun) {
        this.logger.info("🔍 Dry run complete - no changes made");
        return;
      }

      // Step 3: Perform the smart rebase
      this.logger.progress(`Rebasing ${this.currentBranch} onto ${this.targetBranch}...`);

      const rebaseCommand = `git rebase -X ignore-space-change -X theirs ${this.targetBranch}`;
      this.logger.info(`Running: ${rebaseCommand}`);

      const rebaseResult = await this.shell.exec({
        command: rebaseCommand,
        silent: false,
      });

      if (!rebaseResult.success) {
        this.logger.error("Rebase failed. Attempting to resolve automatically...");

        const resolved = await this.resolveRebaseConflicts();
        if (resolved) {
          this.logger.success("✅ Conflicts resolved successfully");
        } else {
          this.logger.error("❌ Unable to resolve conflicts automatically");
          this.logger.info(`You can restore from backup: git checkout ${this.backupBranch}`);
          process.exit(1);
        }
      }

      // Step 4: Squash commits if requested
      if (ctx.args.squash && this.commitCount > 1) {
        await this.performSquashOperation(ctx);
      }

      // Step 5: Restore stashed changes
      if (stashCreated) {
        this.logger.info("Restoring stashed changes...");
        await this.shell.exec({
          command: "git stash pop",
          silent: true,
        });

        // Clean up any remaining permission changes
        if (changeAnalysis.permissionChanges) {
          await this.cleanupPermissionChanges();
        }
      }

      // Step 6: Cleanup
      if (!ctx.args.keepBackup) {
        this.logger.info("Cleaning up backup branch...");
        await this.shell.exec({
          command: `git branch -D ${this.backupBranch}`,
          silent: true,
        });
      }

      this.logger.info("Branch status after rebase:");
      await this.shell.exec({
        command: "git log --oneline -5",
        silent: false,
      });
    } catch (error: any) {
      this.logger.error(`Smart rebase failed: ${error.message}`);
      this.logger.info(`You can restore from backup: git checkout ${this.backupBranch}`);
      process.exit(1);
    }
  }

  private async resolveRebaseConflicts(): Promise<boolean> {
    this.logger.progress("Attempting to resolve conflicts automatically...");

    // Check for conflict files
    const conflictResult = await this.shell.exec({
      command: "git diff --name-only --diff-filter=U",
      silent: true,
    });

    const conflictFiles = conflictResult.stdout.trim().split("\n").filter(f => f);

    if (conflictFiles.length === 0) {
      this.logger.success("No conflicts found");
      return true;
    }

    this.logger.info(`Found conflicts in ${conflictFiles.length} files:`);
    conflictFiles.forEach(file => console.log(`  🔥 ${file}`));

    // Try to resolve each conflict automatically
    for (const file of conflictFiles) {
      this.logger.info(`Resolving conflicts in ${file}...`);

      // Check if this is a permission-only conflict
      const diffResult = await this.shell.exec({
        command: `git diff --name-only -p "${file}"`,
        silent: true,
      });

      if (diffResult.stdout.includes("old mode") || diffResult.stdout.includes("new mode")) {
        this.logger.info("  → Permission conflict detected, accepting 'theirs'");
        await this.shell.exec({ command: `git checkout --theirs "${file}"`, silent: true });
        await this.shell.exec({ command: `git add "${file}"`, silent: true });
        continue;
      }

      // Check if this is a whitespace-only conflict
      const oursResult = await this.shell.exec({
        command: `git show :2:"${file}"`,
        silent: true,
      });
      const theirsResult = await this.shell.exec({
        command: `git show :3:"${file}"`,
        silent: true,
      });

      if (
        oursResult.success &&
        theirsResult.success &&
        oursResult.stdout.replace(/\s+/g, "") === theirsResult.stdout.replace(/\s+/g, "")
      ) {
        this.logger.info("  → Whitespace-only conflict detected, accepting 'theirs'");
        await this.shell.exec({ command: `git checkout --theirs "${file}"`, silent: true });
        await this.shell.exec({ command: `git add "${file}"`, silent: true });
        continue;
      }

      // For other conflicts, prefer 'theirs' as specified
      this.logger.warn("  → Content conflict detected, accepting 'theirs' (may lose local changes)");
      await this.shell.exec({ command: `git checkout --theirs "${file}"`, silent: true });
      await this.shell.exec({ command: `git add "${file}"`, silent: true });
    }

    // Continue the rebase
    this.logger.info("Continuing rebase...");
    const continueResult = await this.shell.exec({
      command: "git rebase --continue",
      silent: false,
    });

    return continueResult.success;
  }

  private async cleanupPermissionChanges(): Promise<void> {
    this.logger.progress("Cleaning up permission changes...");

    await this.shell.exec({
      command: "git diff --name-only | xargs -I {} git checkout -- {}",
      silent: true,
    });
  }

  private async performSquashOperation(ctx: Context): Promise<void> {
    this.logger.progress(`Squashing ${this.commitCount} commits into one...`);

    // Show commits that will be squashed
    this.logger.info("Commits to be squashed:");
    await this.shell.exec({
      command: `git log --oneline ${this.targetBranch}..${this.currentBranch}`,
      silent: false,
    });

    // Get the squash message
    let squashMessage = ctx.args.message;

    if (!squashMessage) {
      if (ctx.args.force) {
        // Generate default message for force mode
        const oldestResult = await this.shell.exec({
          command: `git rev-list --max-parents=0 ${this.targetBranch}..${this.currentBranch} | tail -1`,
          silent: true,
        });
        const newestResult = await this.shell.exec({
          command: `git rev-list ${this.targetBranch}..${this.currentBranch} | head -1`,
          silent: true,
        });

        const oldest = oldestResult.stdout.trim().slice(0, 7);
        const newest = newestResult.stdout.trim().slice(0, 7);
        squashMessage = `Squashed commits from ${oldest} to ${newest}`;
      } else {
        // Interactive prompt for squash message
        const oldestResult = await this.shell.exec({
          command: `git rev-list --max-parents=0 ${this.targetBranch}..${this.currentBranch} | tail -1`,
          silent: true,
        });
        const newestResult = await this.shell.exec({
          command: `git rev-list ${this.targetBranch}..${this.currentBranch} | head -1`,
          silent: true,
        });

        const oldest = oldestResult.stdout.trim().slice(0, 7);
        const newest = newestResult.stdout.trim().slice(0, 7);
        const defaultMessage = `Squashed commits from ${oldest} to ${newest}`;

        const result = await text({
          message: "📝 Enter squash commit message:",
          initialValue: defaultMessage,
          placeholder: defaultMessage,
        });

        // Handle cancellation
        if (typeof result === "symbol") {
          this.logger.warn("Squash operation cancelled by user");
          return;
        }

        squashMessage = (result as string).trim() || defaultMessage;
      }
    }

    // Perform the squash using reset and commit
    this.logger.info(`Creating squashed commit with message: ${squashMessage}`);

    // Reset to target branch but keep changes staged
    await this.shell.exec({
      command: `git reset --soft ${this.targetBranch}`,
      silent: true,
    });

    // Create the squashed commit
    const commitResult = await this.shell.exec({
      command: `git commit -m "${squashMessage.replace(/"/g, '\\"')}"`,
      silent: false,
    });

    if (!commitResult.success) {
      this.logger.error("Failed to create squashed commit");
      this.logger.info("You may need to complete the squash manually");
      return;
    }

    this.logger.success("✅ Successfully squashed commits");
  }
}
