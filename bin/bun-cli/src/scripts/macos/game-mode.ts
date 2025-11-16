import { Script } from '../../core/decorators/Script';
import { Script as BaseScript } from '../../core/base/Script';
import type { Context } from '../../core/types';
import { SystemService } from '../../core/services/SystemService';
import { execSilent } from '../../core/utils/shell';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import * as clack from '@clack/prompts';

interface DisplayInfo {
  persistentId: string;
  contextualId?: string;
  main: boolean;
  type: string;
  resolution: string;
  hertz: string;
  colorDepth: string;
  scaling: string;
  origin?: string;
  rotation: string;
  enabled: boolean;
}

interface SavedConfig {
  timestamp: string;
  displayIds: string[];
  displays: Array<{
    id: string;
    type: string;
    resolution: string;
    hertz: string;
    scaling: string;
    rotation: string;
    origin?: string;
  }>;
  totalDisplays: number;
  version: string;
}

/**
 * Toggle game mode - single display gaming vs multi-display setup
 *
 * Manages display configuration for gaming: enables a single gaming display
 * (auto-detected LG OLED or specified), disables others, enables HDR, and
 * disables hot corners. Can restore all displays and settings.
 *
 * @example
 * game-mode              # Toggle between game mode and multi-display
 * game-mode on           # Enable game mode (auto-detect gaming display)
 * game-mode off          # Restore all displays
 * game-mode --display 1  # Use display #1 for game mode
 */
@Script({
  emoji: '🎮',
  tags: ['macos', 'display', 'gaming'],
  args: {
    mode: {
      type: 'string',
      position: 0,
      description: 'Mode: "on" to enable game mode, "off" to restore all displays',
      enum: ['on', 'off'],
    },
    display: {
      type: 'number',
      flag: '--display <index>',
      description: 'Use specific display by index (1-based)',
    },
    restore: {
      type: 'boolean',
      flag: '-r, --restore',
      description: 'Restore all displays',
    },
    dryRun: {
      type: 'boolean',
      flag: '--dry-run',
      description: 'Preview configuration without applying',
    },
  },
})
export class GameModeScript extends BaseScript {
  private configFile = join(
    SystemService.getHomeDir(),
    '.config/zsh/.game_mode_saved_displays.json'
  );

  async validate(ctx: Context): Promise<void> {
    // Validate macOS
    if (!SystemService.isMacOS()) {
      throw new Error('This script requires macOS');
    }

    // Check for displayplacer
    if (!(await SystemService.commandExists('displayplacer'))) {
      throw new Error(
        'displayplacer is not installed. Install with: brew install jakehilborn/jakehilborn/displayplacer'
      );
    }
  }

  async run(ctx: Context): Promise<void> {
    const { mode, restore, dryRun } = ctx.args;

    this.logger.section('Game Mode Setup');

    const displaysInfo = await this.getDisplayInfo();

    // Determine action
    let shouldEnableGameMode: boolean;

    if (restore || mode === 'off') {
      shouldEnableGameMode = false;
    } else if (mode === 'on') {
      shouldEnableGameMode = true;
    } else {
      // Toggle mode: check current state
      const gameModeActive = this.isGameModeActive(displaysInfo);
      this.logger.info(
        gameModeActive
          ? '🔄 Game mode is currently active - disabling...'
          : '🔄 Game mode is currently inactive - enabling...'
      );
      shouldEnableGameMode = !gameModeActive;
    }

    if (shouldEnableGameMode) {
      await this.enableGameMode(displaysInfo, ctx, dryRun);
    } else {
      await this.restoreAllDisplays(displaysInfo, dryRun);
    }

    this.logger.success('Game Mode Setup Complete');
  }

  private isGameModeActive(displaysInfo: DisplayInfo[]): boolean {
    const enabledDisplays = displaysInfo.filter((d) => d.enabled);

    if (enabledDisplays.length === 1) {
      return true;
    }

    const mainDisplay = enabledDisplays.find((d) => d.main);
    if (mainDisplay && enabledDisplays.length === 1) {
      return true;
    }

    return false;
  }

  private async getDisplayInfo(): Promise<DisplayInfo[]> {
    try {
      const output = await execSilent('displayplacer list');
      const displayBlocks = output
        .split('\n\n')
        .filter((block) => block.includes('Persistent screen id:'));

      return displayBlocks.map((block) => this.parseDisplayInfo(block));
    } catch (error: any) {
      this.logger.error(`Failed to get display list: ${error.message}`);
      return [];
    }
  }

  private parseDisplayInfo(display: string): DisplayInfo {
    const typeMatch = display.match(/Type: (.+)/);
    const type = typeMatch ? typeMatch[1] : 'Unknown';

    return {
      persistentId: display.match(/Persistent screen id: (.+)/)?.[1] || '',
      contextualId: display.match(/Contextual screen id: (.+)/)?.[1],
      main: display.includes(' - main display'),
      type,
      resolution: display.match(/Resolution: (.+)/)?.[1] || '1920x1080',
      hertz: display.match(/Hertz: (.+)/)?.[1] || '60',
      colorDepth: display.match(/Color Depth: (.+)/)?.[1] || '8',
      scaling: display.match(/Scaling: (.+)/)?.[1] || 'on',
      origin: display.match(/Origin: \(([^)]+)\)/)?.[1],
      rotation: display.match(/Rotation: (.+)/)?.[1] || '0',
      enabled: display.includes('Enabled: true'),
    };
  }

  private async enableGameMode(
    displaysInfo: DisplayInfo[],
    ctx: Context,
    dryRun?: boolean
  ): Promise<void> {
    this.logger.info('🎮 Enabling Game Mode - Single Display Mode');
    this.displayCurrentConfig(displaysInfo);

    // Find target display
    const targetDisplay = this.findTargetDisplay(displaysInfo, ctx.args.display);
    const otherDisplays = displaysInfo.filter((d) => d !== targetDisplay);

    if (!targetDisplay) {
      this.logger.error('❌ Target display not found!');
      this.logger.info('Available displays:');
      displaysInfo.forEach((display, i) => {
        const status = display.enabled ? '✅' : '❌';
        const mainIndicator = display.main ? '👑' : '  ';
        console.log(
          `  ${i + 1}. ${mainIndicator} ${status} ${display.type} - ${display.resolution}`
        );
      });
      this.logger.info('Use --display <index> to specify which display to use');
      process.exit(1);
    }

    const displayName = ctx.args.display
      ? `Display #${ctx.args.display}`
      : 'Auto-detected display';

    this.logger.success(
      `✅ Using ${displayName}: ${targetDisplay.type} (${targetDisplay.resolution})`
    );

    if (dryRun) {
      this.showDryRun(targetDisplay, otherDisplays, 'Game Mode');
      return;
    }

    // Disable other displays
    this.logger.info('🔄 Disabling other displays...');
    for (const display of otherDisplays) {
      const command = this.buildDisableCommand(display);
      try {
        await execSilent(command);
      } catch {
        // Ignore errors
      }
    }

    // Configure target display
    const command = this.buildTargetDisplayCommand(targetDisplay);
    await this.executeDisplayCommand(command, 'Game Mode');

    // Enable HDR
    await this.enableHDR(dryRun);

    // Disable hot corners
    await this.disableHotCorners(dryRun);

    this.logger.success(`🎮 Game Mode Active: ${targetDisplay.type}`);
  }

  private async restoreAllDisplays(
    displaysInfo: DisplayInfo[],
    dryRun?: boolean
  ): Promise<void> {
    this.logger.info('🔄 Restoring all displays');
    this.displayCurrentConfig(displaysInfo);

    if (dryRun) {
      this.logger.info('[Dry Run] Would restore all displays');
      return;
    }

    // Check for Python enable script
    const enableScript = join(__dirname, '..', '..', '..', 'enable_displays.py');

    if (existsSync(enableScript)) {
      this.logger.info('🔄 Using Python script to enable all displays...');
      try {
        await execSilent(`python3 ${enableScript}`);
        await execSilent('sleep 3');
      } catch (error: any) {
        this.logger.warn(`Python script failed: ${error.message}`);
      }
    }

    // Disable HDR
    await this.disableHDR(dryRun);

    // Restore hot corners
    await this.restoreHotCorners(dryRun);

    // Try to run stacked-monitor if available
    const stackedMonitorScript = join(
      __dirname,
      '..',
      '..',
      '..',
      'ruby-cli',
      'bin',
      'stacked-monitor.rb'
    );

    if (existsSync(stackedMonitorScript)) {
      this.logger.info('🖥️  Running stack-monitors to arrange monitors...');
      try {
        const gemfilePath = join(
          SystemService.getHomeDir(),
          'zshrc',
          'Gemfile'
        );
        const cmd = `BUNDLE_GEMFILE=${gemfilePath} bundle exec ruby ${stackedMonitorScript}`;
        await execSilent(cmd);
        this.logger.success('✅ Stack monitors configuration applied');
      } catch {
        this.logger.warn('⚠️  Could not run stack-monitors automatically');
      }
    }

    // Show final configuration
    await execSilent('sleep 1');
    const finalDisplays = await this.getDisplayInfo();
    this.displayCurrentConfig(finalDisplays);
  }

  private findTargetDisplay(
    displaysInfo: DisplayInfo[],
    displayIndex?: number
  ): DisplayInfo | null {
    // If display index is specified, use that
    if (displayIndex !== undefined) {
      const index = displayIndex - 1; // Convert to 0-based
      if (index >= 0 && index < displaysInfo.length) {
        return displaysInfo[index];
      }
      this.logger.error(`Display index ${displayIndex} is out of range`);
      return null;
    }

    // Auto-detect: Find LG OLED/Ultrafine
    const byName = displaysInfo.find((display) => {
      const type = display.type.toLowerCase();
      return type.includes('lg') && (type.includes('oled') || type.includes('ultrafine'));
    });

    if (byName) return byName;

    // Fallback: Identify by resolution patterns
    const gamingResolutions = [
      '3200x1800',
      '3840x2160',
      '4096x2304',
      '5120x2880',
      '3840x1600',
      '3440x1440',
      '2560x1440',
    ];

    const gamingCandidates = displaysInfo.filter((display) => {
      return (
        gamingResolutions.includes(display.resolution) ||
        (display.resolution.includes('3840') && display.resolution.includes('2160')) ||
        (display.resolution.includes('5120') && display.resolution.includes('2880'))
      );
    });

    // Prefer main display
    const mainCandidate = gamingCandidates.find((d) => d.main);
    if (mainCandidate) return mainCandidate;

    // Otherwise, largest resolution
    return (
      gamingCandidates.sort((a, b) => {
        const [aWidth, aHeight] = a.resolution.split('x').map(Number);
        const [bWidth, bHeight] = b.resolution.split('x').map(Number);
        return bWidth * bHeight - aWidth * aHeight;
      })[0] || null
    );
  }

  private buildDisableCommand(display: DisplayInfo): string {
    return `displayplacer "id:${display.persistentId} enabled:false"`;
  }

  private buildTargetDisplayCommand(targetDisplay: DisplayInfo): string {
    const origin = '0,0'; // Position at origin

    return (
      `displayplacer "id:${targetDisplay.persistentId} ` +
      `res:${targetDisplay.resolution} ` +
      `hz:${targetDisplay.hertz} ` +
      `color_depth:${targetDisplay.colorDepth} ` +
      `scaling:${targetDisplay.scaling} ` +
      `origin:(${origin}) ` +
      `degree:${targetDisplay.rotation} ` +
      `enabled:true"`
    );
  }

  private async executeDisplayCommand(
    command: string,
    modeName: string
  ): Promise<void> {
    this.logger.info(`🔄 ${modeName} - Applying configuration...`);

    try {
      await execSilent(command);
      this.logger.success(`${modeName} completed successfully!`);
    } catch (error: any) {
      this.logger.error(`Failed to execute ${modeName} configuration: ${error.message}`);
      process.exit(1);
    }
  }

  private displayCurrentConfig(displaysInfo: DisplayInfo[]): void {
    console.log();
    console.log('🖥️  Current Display Configuration:');
    console.log('┌' + '─'.repeat(78) + '┐');

    displaysInfo.forEach((display, index) => {
      const label = (index + 1).toString();
      const name = display.type || 'Unknown Display';
      const resolution = display.resolution || 'Unknown';
      const status = display.enabled ? '✅ ON ' : '❌ OFF';
      const mainIndicator = display.main ? '👑' : '  ';
      const position = display.origin ? ` at (${display.origin})` : '';

      const lineContent = `${label}. ${mainIndicator} ${status} ${name} - ${resolution}${position}`;
      const padding = Math.max(0, 76 - lineContent.length);

      console.log(`│ ${lineContent}${' '.repeat(padding)} │`);
    });

    console.log('└' + '─'.repeat(78) + '┘');
  }

  private showDryRun(
    enabledDisplay: DisplayInfo,
    disabledDisplays: DisplayInfo[],
    modeName: string
  ): void {
    console.log();
    console.log(`🔍 Dry Run Mode - ${modeName}`);
    console.log('='.repeat(50));

    console.log();
    console.log('✅ Display to enable:');
    console.log(`  📺 ${enabledDisplay.type} (${enabledDisplay.resolution})`);
    console.log('  📍 Position: (0,0)');

    if (disabledDisplays.length > 0) {
      console.log();
      console.log('❌ Displays to disable:');
      disabledDisplays.forEach((display, i) => {
        console.log(`  ${i + 1}. ${display.type} (${display.resolution})`);
      });
    }

    console.log();
    console.log('🚀 Command to execute:');
    console.log(this.buildTargetDisplayCommand(enabledDisplay));
    console.log();
    console.log('Run without --dry-run to execute automatically');
  }

  private async enableHDR(dryRun?: boolean): Promise<void> {
    this.logger.info('🌟 Enabling HDR...');

    if (!(await SystemService.commandExists('toggle-hdr'))) {
      this.logger.warn('⚠️  toggle-hdr command not found');
      return;
    }

    if (dryRun) {
      this.logger.info('[Dry Run] Would run: toggle-hdr all on');
      return;
    }

    try {
      const result = await execSilent('toggle-hdr all on');
      if (
        result.includes('Enabling HDR') ||
        result.includes('HDR is already enabled') ||
        result.includes('true')
      ) {
        this.logger.success('✅ HDR enabled successfully');
      } else {
        this.logger.warn('⚠️  Could not enable HDR automatically');
      }
    } catch {
      this.logger.warn('⚠️  Could not enable HDR');
    }
  }

  private async disableHDR(dryRun?: boolean): Promise<void> {
    this.logger.info('🌟 Disabling HDR...');

    if (!(await SystemService.commandExists('toggle-hdr'))) {
      this.logger.warn('⚠️  toggle-hdr command not found');
      return;
    }

    if (dryRun) {
      this.logger.info('[Dry Run] Would run: toggle-hdr all off');
      return;
    }

    try {
      const result = await execSilent('toggle-hdr all off');
      if (
        result.includes('Disabling HDR') ||
        result.includes('HDR is already disabled') ||
        result.includes('false')
      ) {
        this.logger.success('✅ HDR disabled successfully');
      } else {
        this.logger.warn('⚠️  Could not disable HDR automatically');
      }
    } catch {
      this.logger.warn('⚠️  Could not disable HDR');
    }
  }

  private async disableHotCorners(dryRun?: boolean): Promise<void> {
    this.logger.info('🎮 Disabling hot corners for gaming...');

    if (dryRun) {
      this.logger.info(
        '[Dry Run] Would save current hot corners configuration and disable all hot corners'
      );
      return;
    }

    const macUtilsFile = join(
      __dirname,
      '..',
      '..',
      '..',
      '.common',
      'mac.zsh'
    );

    if (!existsSync(macUtilsFile)) {
      this.logger.warn('⚠️  macOS utilities not found - cannot disable hot corners');
      return;
    }

    try {
      // Save current config
      this.logger.info('💾 Saving current hot corners configuration...');
      await execSilent(`source '${macUtilsFile}' && mac_save_hot_corners_config`);

      // Disable hot corners
      this.logger.info('🔧 Disabling all hot corners for gaming...');
      await execSilent(`source '${macUtilsFile}' && mac_disable_hot_corners`);
      this.logger.success('✅ Hot corners disabled for gaming');
    } catch {
      this.logger.warn('⚠️  Could not disable hot corners automatically');
    }
  }

  private async restoreHotCorners(dryRun?: boolean): Promise<void> {
    this.logger.info('🔄 Restoring hot corners configuration...');

    if (dryRun) {
      this.logger.info('[Dry Run] Would restore hot corners configuration');
      return;
    }

    const macUtilsFile = join(
      __dirname,
      '..',
      '..',
      '..',
      '.common',
      'mac.zsh'
    );

    if (!existsSync(macUtilsFile)) {
      this.logger.warn('⚠️  macOS utilities not found - cannot restore hot corners');
      return;
    }

    try {
      await execSilent(`source '${macUtilsFile}' && mac_restore_hot_corners_config`);
      this.logger.success('✅ Hot corners configuration restored');
    } catch {
      this.logger.warn('⚠️  Could not restore hot corners automatically');
    }
  }
}
