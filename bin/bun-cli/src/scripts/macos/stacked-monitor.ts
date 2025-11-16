import { Script } from '../../core/decorators/Script';
import { Script as BaseScript } from '../../core/base/Script';
import type { Context } from '../../core/types';
import { SystemService } from '../../core/services/SystemService';
import { execSilent } from '../../core/utils/shell';

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
  sizeInches: number;
}

interface MonitorPosition {
  monitor: DisplayInfo;
  x: number;
  y: number;
  width: number;
  height: number;
  right: number;
  bottom: number;
  rotation: number;
}

/**
 * Configure stacked external monitors
 *
 * Stacks two 1920x1080 16-inch external monitors vertically on the left or
 * right side of your main display. Shows ASCII visualization of layout.
 *
 * @example
 * stacked-monitor         # Stack on right side (default)
 * stacked-monitor left    # Stack on left side
 * stacked-monitor right   # Stack on right side
 */
@Script({
  emoji: '📺',
  tags: ['macos', 'display', 'monitors'],
  args: {
    direction: {
      type: 'string',
      position: 0,
      description: 'Stack direction: left or right (default: right)',
      enum: ['left', 'right'],
      default: 'right',
    },
    dryRun: {
      type: 'boolean',
      flag: '--dry-run',
      description: 'Preview configuration without applying',
    },
    debug: {
      type: 'boolean',
      flag: '--debug',
      description: 'Show detailed debug information',
    },
  },
})
export class StackedMonitorScript extends BaseScript {
  private readonly SPACING = 20;

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
    const { direction, dryRun, debug } = ctx.args;

    this.logger.section('Stacked Monitor Setup');

    const displaysInfo = await this.getDisplayInfo();

    const externalMonitors = this.findExternalMonitors(displaysInfo);
    this.validateExternalMonitors(externalMonitors);

    // Show current configuration
    this.displayMonitorConfigBox(
      '🖥️  Current Monitor Configuration:',
      displaysInfo,
      true
    );
    this.displaySpatialLayout(displaysInfo, '📍 Current Monitor Layout');

    if (debug) {
      this.showCurrentSetup(displaysInfo);
    }

    // Configure external monitors
    this.configureExternalMonitors(externalMonitors, displaysInfo, direction);

    // Build command
    const command = await this.buildExternalCommand(displaysInfo, externalMonitors);

    if (!command) {
      this.logger.error('Failed to build displayplacer command');
      process.exit(1);
    }

    if (dryRun) {
      this.showDryRun(command, externalMonitors, displaysInfo, direction);
    } else {
      await this.executeMonitorSetup(command, externalMonitors, displaysInfo, direction);
    }

    this.logger.success('Stacked Monitor Setup Complete');
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
      process.exit(1);
    }
  }

  private parseDisplayInfo(display: string): DisplayInfo {
    const typeMatch = display.match(/Type: (.+)/);
    const typeStr = typeMatch ? typeMatch[1] : 'Unknown';
    const sizeMatch = typeStr.match(/(\d+)\s*inch/);
    const sizeInches = sizeMatch ? parseInt(sizeMatch[1]) : 0;

    return {
      persistentId: display.match(/Persistent screen id: (.+)/)?.[1] || '',
      contextualId: display.match(/Contextual screen id: (.+)/)?.[1],
      main: display.includes(' - main display'),
      type: typeStr,
      resolution: display.match(/Resolution: (.+)/)?.[1] || '1920x1080',
      hertz: display.match(/Hertz: (.+)/)?.[1] || '60',
      colorDepth: display.match(/Color Depth: (.+)/)?.[1] || '8',
      scaling: display.match(/Scaling: (.+)/)?.[1] || 'on',
      origin: display.match(/Origin: \(([^)]+)\)/)?.[1],
      rotation: display.match(/Rotation: (.+)/)?.[1] || '0',
      sizeInches,
    };
  }

  private findExternalMonitors(displaysInfo: DisplayInfo[]): DisplayInfo[] {
    const externalMonitors = displaysInfo.filter(
      (d) => d.resolution === '1920x1080' && !d.type.includes('MacBook')
    );
    return externalMonitors;
  }

  private validateExternalMonitors(externalMonitors: DisplayInfo[]): void {
    if (externalMonitors.length !== 2) {
      this.logger.error(
        `Found ${externalMonitors.length} external 1920x1080 monitors, expected 2`
      );
      this.logger.info(
        'This script only works with two 16-inch external monitors (1920x1080).'
      );
      process.exit(1);
    }
  }

  private configureExternalMonitors(
    externalMonitors: DisplayInfo[],
    allDisplays: DisplayInfo[],
    direction: string
  ): void {
    const [width, height] = this.parseResolution(externalMonitors[0].resolution);

    // Find main display
    const mainDisplay = allDisplays.find((d) => d.main || d.type.includes('MacBook'));
    let referenceX = 0;
    let referenceY = 0;

    if (mainDisplay && mainDisplay.origin) {
      [referenceX, referenceY] = mainDisplay.origin.split(',').map(Number);
    }

    // Calculate stack position
    let stackX: number;
    if (direction === 'right') {
      stackX = referenceX + 2056 + this.SPACING; // MacBook width is 2056
    } else {
      stackX = referenceX - width;
    }

    // Stack monitors vertically
    const mainHeight = 1329; // MacBook height
    const bottomY = referenceY + Math.floor(mainHeight / 3);
    externalMonitors[0].origin = `${stackX},${bottomY}`;

    // Top monitor directly above bottom
    const topY = bottomY - height;
    externalMonitors[1].origin = `${stackX},${topY}`;
  }

  private parseResolution(resolution: string): [number, number] {
    const [width, height] = resolution.split('x').map(Number);
    return [width, height];
  }

  private async buildExternalCommand(
    allDisplays: DisplayInfo[],
    externalMonitors: DisplayInfo[]
  ): Promise<string | null> {
    try {
      const output = await execSilent('displayplacer list');
      const displayBlocks = output
        .split('\n\n')
        .filter((block) => block.includes('Persistent screen id:'));

      const commandParts: string[] = [];

      for (const block of displayBlocks) {
        const persistentId = block.match(/Persistent screen id: (.+)/)?.[1];
        const externalMonitor = externalMonitors.find(
          (ext) => ext.persistentId === persistentId
        );

        if (externalMonitor && externalMonitor.origin) {
          const config = this.buildDisplayConfigFromBlock(block, externalMonitor.origin);
          if (config) {
            commandParts.push(config);
          }
        }
      }

      if (commandParts.length === 0) {
        return null;
      }

      return 'displayplacer ' + commandParts.map((part) => `"${part}"`).join(' ');
    } catch (error: any) {
      this.logger.error(`Failed to build command: ${error.message}`);
      return null;
    }
  }

  private buildDisplayConfigFromBlock(
    displayBlock: string,
    newOrigin: string
  ): string | null {
    const persistentId = displayBlock.match(/Persistent screen id: (.+)/)?.[1];
    const resolution = displayBlock.match(/Resolution: (.+)/)?.[1];
    const hertz = displayBlock.match(/Hertz: (.+)/)?.[1];
    const colorDepth = displayBlock.match(/Color Depth: (.+)/)?.[1];
    const scaling = displayBlock.match(/Scaling: (.+)/)?.[1];
    const rotation = displayBlock.match(/Rotation: (.+)/)?.[1];

    if (!persistentId || !resolution || !hertz || !colorDepth || !scaling || !rotation) {
      return null;
    }

    return (
      `id:${persistentId} res:${resolution} hz:${hertz} color_depth:${colorDepth} ` +
      `scaling:${scaling} origin:(${newOrigin}) degree:${rotation}`
    );
  }

  private displayMonitorConfigBox(
    title: string,
    monitors: DisplayInfo[],
    showCurrentPositions: boolean = false
  ): void {
    console.log();
    console.log(title);
    console.log('┌' + '─'.repeat(78) + '┐');

    monitors.forEach((monitor, index) => {
      const label = (index + 1).toString();
      const name = monitor.type || 'Unknown Monitor';
      const resolution = monitor.resolution || 'Unknown';
      const rotation = parseInt(monitor.rotation || '0');

      let rotationIndicator = '';
      if (rotation === 90) rotationIndicator = ' ↻90°';
      else if (rotation === 180) rotationIndicator = ' ↻180°';
      else if (rotation === 270) rotationIndicator = ' ↻270°';

      const positionInfo =
        showCurrentPositions && monitor.origin ? ` at (${monitor.origin})` : '';

      const lineContent = `${label}. ${name} - ${resolution}${rotationIndicator}${positionInfo}`;
      const padding = Math.max(0, 76 - lineContent.length);

      console.log(`│ ${lineContent}${' '.repeat(padding)} │`);
    });

    console.log('└' + '─'.repeat(78) + '┘');
  }

  private displaySpatialLayout(monitors: DisplayInfo[], title: string): void {
    console.log();
    console.log(title);

    const monitorPositions: MonitorPosition[] = monitors.map((monitor) => {
      const [x, y] = monitor.origin ? monitor.origin.split(',').map(Number) : [0, 0];
      const [width, height] = this.parseResolution(monitor.resolution);
      const rotation = parseInt(monitor.rotation || '0');

      return {
        monitor,
        x,
        y,
        width,
        height,
        right: x + width,
        bottom: y + height,
        rotation,
      };
    });

    // Find layout bounds
    const minX = Math.min(...monitorPositions.map((m) => m.x));
    const maxX = Math.max(...monitorPositions.map((m) => m.right));
    const minY = Math.min(...monitorPositions.map((m) => m.y));
    const maxY = Math.max(...monitorPositions.map((m) => m.bottom));

    // Scale factor for ASCII representation
    const scaleX = Math.max((maxX - minX) / 60.0, 1);
    const scaleY = Math.max((maxY - minY) / 20.0, 1);

    // Create ASCII grid
    const gridWidth = 70;
    const gridHeight = 25;
    const grid: string[][] = Array.from({ length: gridHeight }, () =>
      Array(gridWidth).fill(' ')
    );

    // Draw each monitor
    monitorPositions.forEach((pos, index) => {
      const gridX = Math.round((pos.x - minX) / scaleX);
      const gridY = Math.round((pos.y - minY) / scaleY);
      const gridWidthM = Math.max(Math.round(pos.width / scaleX), 1);
      const gridHeightM = Math.max(Math.round(pos.height / scaleY), 1);

      const label = (index + 1).toString();
      let rotationChar = label;

      if (pos.rotation === 90 || pos.rotation === 270) rotationChar = '↻';
      else if (pos.rotation === 180) rotationChar = '↺';

      // Draw monitor box
      for (let dy = 0; dy < gridHeightM; dy++) {
        for (let dx = 0; dx < gridWidthM; dx++) {
          const gx = gridX + dx;
          const gy = gridY + dy;

          if (gx >= 0 && gx < gridWidth && gy >= 0 && gy < gridHeight) {
            if (dy === 0 || dy === gridHeightM - 1) {
              grid[gy][gx] = '─';
            } else if (dx === 0 || dx === gridWidthM - 1) {
              grid[gy][gx] = '│';
            } else if (
              dy === Math.floor(gridHeightM / 2) &&
              dx === Math.floor(gridWidthM / 2)
            ) {
              grid[gy][gx] = rotationChar;
            }
          }
        }
      }

      // Draw corners
      const corners: Array<[number, number, string]> = [
        [gridX, gridY, '┌'],
        [gridX + gridWidthM - 1, gridY, '┐'],
        [gridX, gridY + gridHeightM - 1, '└'],
        [gridX + gridWidthM - 1, gridY + gridHeightM - 1, '┘'],
      ];

      corners.forEach(([x, y, char]) => {
        if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
          grid[y][x] = char;
        }
      });
    });

    // Print grid
    console.log('┌' + '─'.repeat(gridWidth) + '┐');
    grid.forEach((row) => {
      console.log('│' + row.join('') + '│');
    });
    console.log('└' + '─'.repeat(gridWidth) + '┘');

    // Print legend
    console.log('\nLegend:');
    monitors.forEach((monitor, index) => {
      const name = monitor.type || 'Unknown Monitor';
      const resolution = monitor.resolution || 'Unknown';
      const rotation = parseInt(monitor.rotation || '0');

      let rotationInfo = ' - Landscape';
      if (rotation === 90) rotationInfo = ' - Portrait 90° ↻';
      else if (rotation === 180) rotationInfo = ' - Inverted 180° ↺';
      else if (rotation === 270) rotationInfo = ' - Portrait 270° ↻';

      console.log(`  ${index + 1}. ${name} (${resolution})${rotationInfo}`);
    });
  }

  private showCurrentSetup(displaysInfo: DisplayInfo[]): void {
    console.log();
    console.log('🔍 DETAILED MONITOR DEBUG INFO');
    console.log('='.repeat(50));

    console.log();
    console.log('📊 Detailed Display Information:');
    displaysInfo.forEach((display, i) => {
      console.log();
      console.log(`Display ${i + 1}:`);
      console.log(`  Type: ${display.type}`);
      console.log(
        `  Size: ${display.sizeInches}" ${display.sizeInches === 16 ? '(16-inch monitor)' : ''}`
      );
      console.log(`  Resolution: ${display.resolution}`);
      console.log(`  Current Position: ${display.origin || 'Unknown'}`);
      console.log(`  Persistent ID: ${display.persistentId}`);
      console.log(`  Main Display: ${display.main ? '✅ Yes' : '❌ No'}`);
      console.log(`  Hertz: ${display.hertz}`);
      console.log(`  Color Depth: ${display.colorDepth}`);
      console.log(`  Scaling: ${display.scaling}`);
      console.log(`  Rotation: ${display.rotation}`);
    });

    console.log();
    console.log('='.repeat(50));
  }

  private showDryRun(
    command: string,
    externalMonitors: DisplayInfo[],
    allDisplays: DisplayInfo[],
    direction: string
  ): void {
    this.showExternalConfiguration(externalMonitors, direction);

    console.log();
    console.log('📍 Target Monitor Layout (After Configuration):');
    const targetDisplays = this.getTargetDisplayLayout(externalMonitors, allDisplays);
    this.displaySpatialLayout(targetDisplays, '📍 Complete Target Layout');

    console.log();
    console.log('🚀 Command to execute:');
    console.log(command);
    console.log();
    console.log('Run without --dry-run to execute automatically');
  }

  private showExternalConfiguration(
    externalMonitors: DisplayInfo[],
    direction: string
  ): void {
    console.log();
    console.log('📺 External Monitor Configuration:');

    console.log();
    console.log('📍 Configuration Description:');
    const stackSide = direction === 'right' ? 'Right' : 'Left';
    console.log(`  Stack Direction: ${stackSide} side`);
    console.log(`  Stack Top: Upper external monitor (${externalMonitors[1].resolution})`);
    console.log(
      `  Stack Bottom: Lower external monitor (${externalMonitors[0].resolution})`
    );
    console.log('  Other monitors: Will remain in current positions');
  }

  private getTargetDisplayLayout(
    externalMonitors: DisplayInfo[],
    allDisplays: DisplayInfo[]
  ): DisplayInfo[] {
    return allDisplays.map((display) => {
      const externalMonitor = externalMonitors.find(
        (ext) => ext.persistentId === display.persistentId
      );
      if (externalMonitor && externalMonitor.origin) {
        return { ...display, origin: externalMonitor.origin };
      }
      return display;
    });
  }

  private async executeMonitorSetup(
    command: string,
    externalMonitors: DisplayInfo[],
    allDisplays: DisplayInfo[],
    direction: string
  ): Promise<void> {
    this.showExternalConfiguration(externalMonitors, direction);

    this.logger.progress('🔄 Executing monitor setup...');

    try {
      await execSilent(command);
      this.logger.success('Monitor arrangement completed successfully!');

      console.log();
      console.log('🎯 Final Monitor Layout Applied:');
      const finalDisplays = this.getTargetDisplayLayout(externalMonitors, allDisplays);
      this.displaySpatialLayout(finalDisplays, '📍 Complete Final Layout');
    } catch (error: any) {
      this.logger.error(`Failed to execute displayplacer command: ${error.message}`);
      process.exit(1);
    }
  }
}
