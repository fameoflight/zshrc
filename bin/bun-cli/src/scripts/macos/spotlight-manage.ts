import { Script } from '../../core/decorators/Script';
import { Script as BaseScript } from '../../core/base/Script';
import type { Context } from '../../core/types';
import { SystemService } from '../../core/services/SystemService';
import { execSilent } from '../../core/utils/shell';
import * as clack from '@clack/prompts';

interface VolumeInfo {
  path: string;
  indexing: 'Enabled' | 'Disabled';
  status?: string;
}

/**
 * Manage macOS Spotlight indexing
 *
 * Control Spotlight indexing on volumes, rebuild indices, and manage
 * privacy exclusions for improved performance and privacy.
 *
 * @example
 * spotlight-manage
 * spotlight-manage --status
 * spotlight-manage --disable /Volumes/External
 * spotlight-manage --rebuild
 */
@Script({
  emoji: '🔍',
  tags: ['macos', 'spotlight', 'privacy'],
  args: {
    status: {
      type: 'boolean',
      flag: '--status',
      description: 'Show current Spotlight indexing status',
    },
    enable: {
      type: 'string',
      flag: '--enable <volume>',
      description: 'Enable Spotlight indexing on volume',
    },
    disable: {
      type: 'string',
      flag: '--disable <volume>',
      description: 'Disable Spotlight indexing on volume',
    },
    rebuild: {
      type: 'boolean',
      flag: '--rebuild',
      description: 'Rebuild Spotlight index',
    },
    privacy: {
      type: 'boolean',
      flag: '--privacy',
      description: 'Add common privacy exclusions',
    },
  },
})
export class SpotlightManageScript extends BaseScript {
  private readonly commonExclusions = [
    '~/Library/Application Support/com.apple.TCC',
    '~/Library/Application Support/Google/Chrome',
    '~/Library/Application Support/Slack',
    '~/Library/Caches',
    '~/Library/Logs',
    '~/.Trash',
    '~/Downloads',
    '~/node_modules',
    '~/.npm',
    '~/.cache',
    '~/.docker',
  ];

  async validate(ctx: Context): Promise<void> {
    // Validate macOS
    if (!SystemService.isMacOS()) {
      throw new Error('This script requires macOS');
    }

    // Check for required commands
    if (!(await SystemService.commandExists('mdutil'))) {
      throw new Error('Required command not found: mdutil');
    }
  }

  async run(ctx: Context): Promise<void> {
    const { status, enable, disable, rebuild, privacy } = ctx.args;

    this.logger.section('Spotlight Management');

    // Handle specific actions
    if (status) {
      await this.showStatus();
      return;
    }

    if (enable) {
      await this.enableIndexing(enable);
      return;
    }

    if (disable) {
      await this.disableIndexing(disable);
      return;
    }

    if (rebuild) {
      await this.rebuildIndex();
      return;
    }

    if (privacy) {
      await this.addPrivacyExclusions();
      return;
    }

    // Interactive mode
    await this.interactiveMode();
  }

  private async interactiveMode(): Promise<void> {
    const action = await clack.select({
      message: 'What would you like to do?',
      options: [
        { value: 'status', label: 'Show Spotlight status' },
        { value: 'enable', label: 'Enable indexing on volume' },
        { value: 'disable', label: 'Disable indexing on volume' },
        { value: 'rebuild', label: 'Rebuild Spotlight index' },
        { value: 'privacy', label: 'Add privacy exclusions' },
        { value: 'exit', label: 'Exit' },
      ],
    });

    if (clack.isCancel(action) || action === 'exit') {
      this.logger.info('Exiting');
      return;
    }

    switch (action) {
      case 'status':
        await this.showStatus();
        break;
      case 'enable':
        await this.enableIndexingInteractive();
        break;
      case 'disable':
        await this.disableIndexingInteractive();
        break;
      case 'rebuild':
        await this.rebuildIndex();
        break;
      case 'privacy':
        await this.addPrivacyExclusions();
        break;
    }
  }

  private async showStatus(): Promise<void> {
    this.logger.info('Checking Spotlight status on all volumes...');

    const volumes = await this.getVolumes();

    if (volumes.length === 0) {
      this.logger.warn('No volumes found');
      return;
    }

    console.log();
    console.log('Spotlight Indexing Status:');
    console.log('─'.repeat(60));

    for (const volume of volumes) {
      const statusIcon = volume.indexing === 'Enabled' ? '✅' : '❌';
      console.log(`${statusIcon} ${volume.path}`);
      console.log(`   Indexing: ${volume.indexing}`);
      if (volume.status) {
        console.log(`   Status: ${volume.status}`);
      }
      console.log();
    }

    this.logger.success('Spotlight status check complete');
  }

  private async getVolumes(): Promise<VolumeInfo[]> {
    try {
      const output = await execSilent('mdutil -a -s');
      const volumes: VolumeInfo[] = [];
      const lines = output.split('\n').filter((line) => line.trim());

      let currentVolume: Partial<VolumeInfo> | null = null;

      for (const line of lines) {
        if (line.includes(':')) {
          // Save previous volume if exists
          if (currentVolume && currentVolume.path && currentVolume.indexing) {
            volumes.push(currentVolume as VolumeInfo);
          }

          // Start new volume
          currentVolume = {
            path: line.replace(':', '').trim(),
          };
        } else if (currentVolume && line.includes('Indexing')) {
          const match = line.match(/Indexing\s+(enabled|disabled)/i);
          if (match) {
            currentVolume.indexing = match[1].charAt(0).toUpperCase() + match[1].slice(1).toLowerCase() as 'Enabled' | 'Disabled';
          }
        } else if (currentVolume && line.includes('Status:')) {
          currentVolume.status = line.replace('Status:', '').trim();
        }
      }

      // Save last volume
      if (currentVolume && currentVolume.path && currentVolume.indexing) {
        volumes.push(currentVolume as VolumeInfo);
      }

      return volumes;
    } catch (error: any) {
      this.logger.error(`Failed to get volumes: ${error.message}`);
      return [];
    }
  }

  private async enableIndexing(volumePath: string): Promise<void> {
    this.logger.info(`Enabling Spotlight indexing on ${volumePath}...`);

    try {
      const output = await execSilent(`sudo mdutil -i on "${volumePath}"`);
      this.logger.success(`Indexing enabled on ${volumePath}`);

      if (output.includes('will continue')) {
        this.logger.info('Index will be rebuilt automatically');
      }
    } catch (error: any) {
      this.logger.error(`Failed to enable indexing: ${error.message}`);
      process.exit(1);
    }
  }

  private async disableIndexing(volumePath: string): Promise<void> {
    this.logger.info(`Disabling Spotlight indexing on ${volumePath}...`);

    try {
      await execSilent(`sudo mdutil -i off "${volumePath}"`);
      this.logger.success(`Indexing disabled on ${volumePath}`);
    } catch (error: any) {
      this.logger.error(`Failed to disable indexing: ${error.message}`);
      process.exit(1);
    }
  }

  private async enableIndexingInteractive(): Promise<void> {
    const volumes = await this.getVolumes();
    const disabledVolumes = volumes.filter((v) => v.indexing === 'Disabled');

    if (disabledVolumes.length === 0) {
      this.logger.info('All volumes already have indexing enabled');
      return;
    }

    const selected = await clack.select({
      message: 'Select volume to enable indexing:',
      options: disabledVolumes.map((v) => ({
        value: v.path,
        label: v.path,
      })),
    });

    if (clack.isCancel(selected)) {
      this.logger.info('Operation cancelled');
      return;
    }

    await this.enableIndexing(selected as string);
  }

  private async disableIndexingInteractive(): Promise<void> {
    const volumes = await this.getVolumes();
    const enabledVolumes = volumes.filter((v) => v.indexing === 'Enabled');

    if (enabledVolumes.length === 0) {
      this.logger.info('All volumes already have indexing disabled');
      return;
    }

    const selected = await clack.select({
      message: 'Select volume to disable indexing:',
      options: enabledVolumes.map((v) => ({
        value: v.path,
        label: v.path,
      })),
    });

    if (clack.isCancel(selected)) {
      this.logger.info('Operation cancelled');
      return;
    }

    const selectedPath = selected as string;

    const confirm = await clack.confirm({
      message: `Disable Spotlight indexing on ${selectedPath}?`,
    });

    if (clack.isCancel(confirm) || !confirm) {
      this.logger.info('Operation cancelled');
      return;
    }

    await this.disableIndexing(selectedPath);
  }

  private async rebuildIndex(): Promise<void> {
    const volumes = await this.getVolumes();
    const enabledVolumes = volumes.filter((v) => v.indexing === 'Enabled');

    if (enabledVolumes.length === 0) {
      this.logger.warn('No volumes with indexing enabled');
      return;
    }

    let volumePath: string;

    if (enabledVolumes.length === 1) {
      volumePath = enabledVolumes[0].path;
    } else {
      const selected = await clack.select({
        message: 'Select volume to rebuild index:',
        options: enabledVolumes.map((v) => ({
          value: v.path,
          label: v.path,
        })),
      });

      if (clack.isCancel(selected)) {
        this.logger.info('Operation cancelled');
        return;
      }

      volumePath = selected as string;
    }

    const confirm = await clack.confirm({
      message: `Rebuild Spotlight index on ${volumePath}? This may take some time.`,
    });

    if (clack.isCancel(confirm) || !confirm) {
      this.logger.info('Operation cancelled');
      return;
    }

    this.logger.info(`Erasing current index on ${volumePath}...`);

    try {
      await execSilent(`sudo mdutil -E "${volumePath}"`);
      this.logger.success('Index erased');
      this.logger.info('Spotlight will rebuild the index automatically');
      this.logger.info('This process may take several minutes to hours depending on volume size');
    } catch (error: any) {
      this.logger.error(`Failed to rebuild index: ${error.message}`);
      process.exit(1);
    }
  }

  private async addPrivacyExclusions(): Promise<void> {
    this.logger.section('Privacy Exclusions');
    this.logger.info('Adding common privacy exclusions to Spotlight...');

    const homeDir = SystemService.getHomeDir();
    const exclusionsToAdd: string[] = [];

    // Expand ~ to home directory and check if paths exist
    for (const exclusion of this.commonExclusions) {
      const expandedPath = exclusion.replace('~', homeDir);

      if (await this.fs.exists(expandedPath)) {
        exclusionsToAdd.push(expandedPath);
      }
    }

    if (exclusionsToAdd.length === 0) {
      this.logger.warn('No common exclusion paths found on this system');
      return;
    }

    console.log();
    console.log('Paths to exclude from Spotlight:');
    for (const path of exclusionsToAdd) {
      console.log(`  • ${path}`);
    }
    console.log();

    const confirm = await clack.confirm({
      message: `Add ${exclusionsToAdd.length} privacy exclusions?`,
    });

    if (clack.isCancel(confirm) || !confirm) {
      this.logger.info('Operation cancelled');
      return;
    }

    this.logger.info('Adding exclusions...');
    this.logger.warn(
      'Note: You will need to manually add these to System Settings > Spotlight > Privacy'
    );
    this.logger.info('This script will open System Settings for you');

    console.log();
    console.log('Copy these paths and add them manually:');
    console.log('─'.repeat(60));
    for (const path of exclusionsToAdd) {
      console.log(path);
    }
    console.log('─'.repeat(60));

    const shouldOpen = await clack.confirm({
      message: 'Open System Settings > Spotlight > Privacy?',
    });

    if (!clack.isCancel(shouldOpen) && shouldOpen) {
      try {
        await execSilent('open "x-apple.systempreferences:com.apple.Spotlight-Settings.extension"');
        this.logger.success('System Settings opened');
      } catch (error: any) {
        this.logger.error(`Failed to open System Settings: ${error.message}`);
      }
    }

    this.logger.success('Privacy exclusions ready to add');
  }
}
