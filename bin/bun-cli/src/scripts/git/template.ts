import { Script } from '../../core/decorators/Script';
import { BaseScript } from '../../core/base/Script';
import { logger } from '../../core/utils/logger';
import { exec, execSilent } from '../../core/utils/shell';
import { SystemService } from '../../core/services/SystemService';
import * as clack from '@clack/prompts';
import { existsSync, statSync, readdirSync } from 'fs';
import { join } from 'path';
import { rm } from 'fs/promises';

interface RepoInfo {
  name: string;
  path: string;
  remoteUrl: string;
  branch: string;
  lastModified: Date;
}

@Script({
  name: 'git-template',
  description: 'Interactive tool to create private repos from public templates',
  emoji: '🔧',
  category: 'git',
  arguments: '[OPTIONS]',
  options: [
    { flags: '-l, --list', description: 'List all git repositories in workspace' },
    {
      flags: '-d, --depth <number>',
      description: 'Search depth for git repositories (default: unlimited)',
    },
    {
      flags: '-w, --workspace <path>',
      description: 'Workspace path (default: ~/workspace)',
    },
    { flags: '--workflow', description: 'Show daily workflow guide' },
  ],
  examples: [
    { command: 'git-template', description: 'Interactive mode' },
    { command: 'git-template --list', description: 'List all repositories' },
    { command: 'git-template --depth 2', description: 'Search 2 levels deep' },
    { command: 'git-template --workflow', description: 'Show workflow guide' },
    {
      command: 'git-template --workspace ~/projects',
      description: 'Use different workspace',
    },
  ],
})
export default class GitTemplateScript extends BaseScript {
  private repositories: RepoInfo[] = [];

  async run(): Promise<void> {
    if (this.options.list) {
      await this.listRepositories();
      logger.success('Git Template Manager');
      return;
    }

    if (this.options.workflow) {
      this.showWorkflowGuide();
      logger.success('Git Template Manager');
      return;
    }

    await this.startInteractiveMode();
  }

  private async startInteractiveMode(): Promise<void> {
    clack.intro('🔧 Git Template Manager');

    while (true) {
      const choice = await clack.select({
        message: 'What would you like to do?',
        options: [
          {
            value: 'select_template',
            label: '🔍 Find and select template repo',
          },
          { value: 'workflow', label: '📋 Show daily workflow guide' },
          { value: 'list_repos', label: '📁 List all git repositories' },
          { value: 'refresh', label: '🔄 Refresh repository cache' },
          { value: 'exit', label: '👋 Exit' },
        ],
      });

      if (clack.isCancel(choice) || choice === 'exit') {
        clack.outro('Goodbye! 👋');
        return;
      }

      switch (choice) {
        case 'select_template':
          await this.selectAndSetupTemplate();
          break;
        case 'workflow':
          this.showWorkflowGuide();
          break;
        case 'list_repos':
          await this.listRepositories();
          break;
        case 'refresh':
          this.repositories = [];
          logger.success('Repository cache cleared');
          break;
      }

      console.log(); // Add spacing between iterations
    }
  }

  private async findGitRepositories(): Promise<RepoInfo[]> {
    if (this.repositories.length > 0) {
      return this.repositories;
    }

    const workspacePath =
      this.options.workspace || join(SystemService.getHomeDir(), 'workspace');
    const maxDepth = this.options.depth ? parseInt(this.options.depth, 10) : null;

    logger.info(`Searching for git repositories in: ${workspacePath}`);

    const spinner = clack.spinner();
    spinner.start('Scanning directories...');

    try {
      this.repositories = await this.scanForRepos(workspacePath, maxDepth);
      this.repositories.sort((a, b) =>
        a.name.toLowerCase().localeCompare(b.name.toLowerCase())
      );

      spinner.stop(`Found ${this.repositories.length} git repositories`);
    } catch (error: any) {
      spinner.stop(`Error: ${error.message}`);
      logger.error(`Error searching repositories: ${error.message}`);
    }

    return this.repositories;
  }

  private async scanForRepos(
    basePath: string,
    maxDepth: number | null,
    currentDepth: number = 0
  ): Promise<RepoInfo[]> {
    const repos: RepoInfo[] = [];

    if (!existsSync(basePath)) {
      return repos;
    }

    try {
      const entries = readdirSync(basePath, { withFileTypes: true });

      for (const entry of entries) {
        if (!entry.isDirectory()) continue;

        const fullPath = join(basePath, entry.name);
        const gitPath = join(fullPath, '.git');

        // Check if this directory is a git repository
        if (existsSync(gitPath)) {
          const info = await this.getRepoInfo(fullPath);
          repos.push(info);
        }

        // Recurse into subdirectories if depth allows
        if (maxDepth === null || currentDepth < maxDepth - 1) {
          try {
            const subRepos = await this.scanForRepos(
              fullPath,
              maxDepth,
              currentDepth + 1
            );
            repos.push(...subRepos);
          } catch {
            // Skip directories we can't access
          }
        }
      }
    } catch (error) {
      // Skip directories we can't read
    }

    return repos;
  }

  private async getRepoInfo(repoPath: string): Promise<RepoInfo> {
    const name = repoPath.split('/').pop() || 'unknown';
    const remoteUrl = await this.getRemoteUrl(repoPath);
    const branch = await this.getCurrentBranch(repoPath);
    const lastModified = statSync(repoPath).mtime;

    return {
      name,
      path: repoPath,
      remoteUrl,
      branch,
      lastModified,
    };
  }

  private async getRemoteUrl(repoPath: string): Promise<string> {
    try {
      const url = await execSilent(
        `cd "${repoPath}" && git config --get remote.origin.url 2>/dev/null`
      );
      return url || 'No remote';
    } catch {
      return 'Unknown';
    }
  }

  private async getCurrentBranch(repoPath: string): Promise<string> {
    try {
      const branch = await execSilent(
        `cd "${repoPath}" && git rev-parse --abbrev-ref HEAD 2>/dev/null`
      );
      return branch || 'unknown';
    } catch {
      return 'unknown';
    }
  }

  private async selectAndSetupTemplate(): Promise<void> {
    const repositories = await this.findGitRepositories();

    if (repositories.length === 0) {
      logger.error('No git repositories found in workspace');
      logger.info('Try specifying a different workspace with --workspace PATH');
      return;
    }

    const selectedRepo = await clack.select({
      message: 'Select template repository:',
      options: repositories.map((repo) => ({
        value: repo,
        label: `${repo.name}`,
        hint: repo.remoteUrl,
      })),
    });

    if (clack.isCancel(selectedRepo)) {
      return;
    }

    await this.setupTemplateWorkflow(selectedRepo as RepoInfo);
  }

  private async setupTemplateWorkflow(templateRepo: RepoInfo): Promise<void> {
    logger.section('Template Setup Workflow');
    console.log();
    logger.info(`Selected template: ${templateRepo.name}`);
    logger.info(`Path: ${templateRepo.path}`);
    logger.info(`Remote: ${templateRepo.remoteUrl}`);
    console.log();

    // Get user inputs
    const appName = await clack.text({
      message: 'Enter name for your new app:',
      validate: (value) => {
        if (!value) return 'App name is required';
      },
    });

    if (clack.isCancel(appName)) {
      return;
    }

    const githubUsername = await clack.text({
      message: 'Enter your GitHub username:',
      validate: (value) => {
        if (!value) return 'GitHub username is required';
      },
    });

    if (clack.isCancel(githubUsername)) {
      return;
    }

    console.log();
    logger.section('Setup Configuration');
    console.log(`Template: ${templateRepo.name}`);
    console.log(`New app name: ${appName}`);
    console.log(`GitHub username: ${githubUsername}`);
    console.log();

    const shouldProceed = await clack.confirm({
      message: 'Proceed with this configuration?',
    });

    if (clack.isCancel(shouldProceed) || !shouldProceed) {
      return;
    }

    await this.executeSetupProcess(
      templateRepo,
      appName as string,
      githubUsername as string
    );
  }

  private async executeSetupProcess(
    templateRepo: RepoInfo,
    appName: string,
    githubUsername: string
  ): Promise<void> {
    const workspace = join(SystemService.getHomeDir(), 'workspace');

    try {
      // Step 1: Create bare clone
      logger.info('Step 1: Creating bare clone of template repository');
      const bareCloneCmd = `git clone --bare ${templateRepo.remoteUrl}`;
      await exec(bareCloneCmd, { description: 'Creating bare clone', cwd: workspace });

      const bareRepoDir = join(workspace, `${templateRepo.name}.git`);
      logger.success(`Bare clone created: ${bareRepoDir}`);

      // Step 2: Handle private repository creation
      logger.info('Step 2: Creating private repository on GitHub');
      const privateRepoUrl = await this.handlePrivateRepoCreation(
        appName,
        githubUsername
      );

      if (!privateRepoUrl) {
        logger.error('Private repository setup cancelled');
        await this.cleanupBareClone(bareRepoDir);
        return;
      }

      // Step 3: Mirror push to private repo
      logger.info('Step 3: Mirroring to private repository');
      const mirrorCmd = `git push --mirror ${privateRepoUrl}`;
      await exec(mirrorCmd, {
        description: 'Mirroring to private repo',
        cwd: bareRepoDir,
      });

      // Step 4: Clean up bare clone
      logger.info('Step 4: Cleaning up bare clone');
      await this.cleanupBareClone(bareRepoDir);

      // Step 5: Clone private repository
      logger.info('Step 5: Cloning private repository');
      const appDir = join(workspace, appName);
      const cloneCmd = `git clone ${privateRepoUrl} ${appDir}`;
      await exec(cloneCmd, { description: 'Cloning private repository', cwd: workspace });

      // Step 6: Add template as upstream remote
      logger.info('Step 6: Adding template as upstream remote');
      const upstreamCmd = `git remote add template ${templateRepo.remoteUrl}`;
      try {
        await exec(upstreamCmd, {
          description: 'Adding template remote',
          cwd: appDir,
        });
      } catch {
        logger.warning(
          'Failed to add template remote (you can add it manually later)'
        );
      }

      // Step 7: Verify setup
      logger.info('Step 7: Verifying repository setup');
      await exec('git remote -v', { description: 'Showing remotes', cwd: appDir });

      console.log();
      logger.success('✅ Template setup completed successfully!');
      logger.info(`Your new app is ready at: ${appDir}`);
      console.log();
      this.showWorkflowSummary();
    } catch (error: any) {
      logger.error(`Setup failed: ${error.message}`);
    }
  }

  private async handlePrivateRepoCreation(
    appName: string,
    githubUsername: string
  ): Promise<string | null> {
    const privateRepoUrl = `git@github.com:${githubUsername}/${appName}.git`;

    // Check if GitHub CLI is available
    if (await SystemService.commandExists('gh')) {
      logger.success('GitHub CLI detected! Creating private repository automatically...');

      try {
        const createCmd = `gh repo create ${githubUsername}/${appName} --private`;
        await exec(createCmd, { description: 'Creating private GitHub repository' });
        logger.success('Private repository created on GitHub');
        return privateRepoUrl;
      } catch {
        logger.warning(
          'Failed to create repository with GitHub CLI, falling back to manual setup'
        );
      }
    }

    // Manual setup instructions
    logger.warning('Please create the private repository manually:');
    console.log();
    console.log('1. Go to: https://github.com/new');
    console.log(`2. Repository name: ${appName}`);
    console.log('3. Set to Private');
    console.log("4. Don't initialize with README, gitignore, or license");
    console.log("5. Click 'Create repository'");
    console.log();
    console.log('After creating the repository, your clone URL will be:');
    console.log(`  ${privateRepoUrl}`);
    console.log();

    const created = await clack.confirm({
      message: 'Have you created the private repository?',
    });

    if (clack.isCancel(created) || !created) {
      return null;
    }

    return privateRepoUrl;
  }

  private async cleanupBareClone(bareRepoDir: string): Promise<void> {
    if (existsSync(bareRepoDir)) {
      logger.info(`Removing bare clone: ${bareRepoDir}`);
      await rm(bareRepoDir, { recursive: true, force: true });
    }
  }

  private showWorkflowGuide(): void {
    logger.section('Daily Workflow Guide');
    console.log(`
Normal Development (90% of your time)
──────────────────────────────────
# Just work in master as usual
git checkout master
# ... make changes ...
git add .
git commit -m "Add private feature"
git push origin master  # Goes to your private repo

Contributing Back to Template (when you want)
──────────────────────────────────────────────

Option A: Cherry-pick specific commits
──────────────────────────────────
git checkout -b template/feature-name
git cherry-pick <commit-hash>  # Pick the commit you want to share
git push template template/feature-name
# Create PR on GitHub from this branch

Option B: Create feature branch from scratch
───────────────────────────────────────────
git checkout master
git checkout -b template/improvement
# ... make ONLY the changes for template ...
git commit -m "Add: template improvement"
git push template template/improvement
# Create PR on GitHub

Syncing Template Updates into Your Private Repo
──────────────────────────────────────────────────

# Pull updates from public template
git fetch template
git checkout master
git merge template/master  # Or rebase if you prefer
git push origin master

Key Points
──────────
✅ Your master = your main branch - commit everything here, stays private
✅ Feature branches only for contributions - create when ready to share
✅ Cherry-pick is your friend - select specific improvements to contribute
✅ Two remotes:
   - origin → private repo (your daily work)
   - template → public template (pull updates, push contributions)
    `);
  }

  private showWorkflowSummary(): void {
    logger.section('Quick Workflow Summary');
    console.log('🔄 To pull template updates:');
    console.log('   git fetch template && git merge template/master');
    console.log();
    console.log('🤝 To contribute back:');
    console.log('   git checkout -b template/your-feature');
    console.log('   # make changes, then:');
    console.log('   git push template template/your-feature');
    console.log('   # Create PR on GitHub');
    console.log();
    console.log('📚 For full workflow guide, run: git-template --workflow');
  }

  private async listRepositories(): Promise<void> {
    const repositories = await this.findGitRepositories();

    if (repositories.length === 0) {
      logger.warning('No git repositories found');
      return;
    }

    logger.section('Git Repositories');
    console.log();

    repositories.forEach((repo, index) => {
      console.log(`${(index + 1).toString().padStart(3)}. ${repo.name}`);
      console.log(`     Path: ${repo.path}`);
      console.log(`     Remote: ${repo.remoteUrl}`);
      console.log(`     Branch: ${repo.branch}`);
      console.log(
        `     Modified: ${repo.lastModified.toISOString().substring(0, 16).replace('T', ' ')}`
      );
      console.log();
    });
  }
}
