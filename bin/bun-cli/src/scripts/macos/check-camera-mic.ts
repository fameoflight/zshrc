import { Script } from '../../core/decorators/Script';
import { BaseScript } from '../../core/base/Script';
import { SystemService } from '../../core/services/SystemService';
import { logger } from '../../core/utils/logger';
import { execSilent } from '../../core/utils/shell';

interface ProcessInfo {
  pid: string;
  name: string;
}

@Script({
  name: 'check-camera-mic',
  description:
    'Check which applications are currently using the camera or microphone on macOS',
  emoji: '📹🎤',
  category: 'macos',
  arguments: '[OPTIONS]',
  examples: [
    {
      command: 'check-camera-mic',
      description: 'Check camera and microphone usage',
    },
  ],
})
export default class CheckCameraMicScript extends BaseScript {
  async run(): Promise<void> {
    // Validate macOS
    if (!SystemService.isMacOS()) {
      logger.error('This script requires macOS');
      process.exit(1);
    }

    // Check for required commands
    if (!(await SystemService.commandExists('lsof'))) {
      logger.error('Required command not found: lsof');
      process.exit(1);
    }

    if (!(await SystemService.commandExists('sqlite3'))) {
      logger.error('Required command not found: sqlite3');
      process.exit(1);
    }

    logger.section('Camera & Microphone Usage Checker');

    await this.checkCameraUsage();
    await this.checkMicrophoneUsage();
    await this.checkTCCPermissions('kTCCServiceCamera', 'Camera');
    await this.checkTCCPermissions('kTCCServiceMicrophone', 'Microphone');

    this.showTips();
    logger.success('Camera & Microphone Check');
  }

  private async checkCameraUsage(): Promise<void> {
    logger.section('Camera Usage');

    const processes = await this.findProcessesUsingLsof(
      'AppleCamera|AVCapture|Camera'
    );

    if (processes.length === 0) {
      logger.success('No camera usage detected');
    } else {
      logger.warning('Camera is in use by:');
      processes.forEach((proc) => {
        console.log(`  📹 ${proc.name} (PID: ${proc.pid})`);
      });
    }
  }

  private async checkMicrophoneUsage(): Promise<void> {
    logger.section('Microphone Usage');

    const systemProcessesToIgnore = [
      'loginwindow',
      'coreservicesd',
      'controlcenter',
      'corelocationd',
      'callservicesd',
      'wifiagent',
      'assistant',
      'bird',
      'sirittsd',
      'siri',
      'appssoauthagent',
      'siriinferenced',
      'accessibilityd',
      'avconferenced',
      'audiocomponentsd',
      'audioaccessoryd',
      'shortcuts',
      'textinputmenuagent',
      'spotlight',
      'heards',
      'imklaunchagent',
      'sizeup',
      'lms',
      'audiovisuald',
      'usernoted',
      'universalaccess',
      'finder',
      'systemuiserver',
      'notificationcenter',
      'applespell',
      'safari',
      'dockhelperd',
      'nbagent',
    ];

    const micProcesses = await this.findProcessesUsingLsof(
      'audio|microphone|input',
      systemProcessesToIgnore
    );
    const coreaudioProcesses = await this.findProcessesUsingLsof(
      'coreaudio',
      systemProcessesToIgnore
    );

    // Merge the two sets of processes
    const allProcesses = new Map<string, ProcessInfo>();
    [...micProcesses, ...coreaudioProcesses].forEach((proc) => {
      allProcesses.set(proc.pid, proc);
    });

    if (allProcesses.size === 0) {
      logger.success('No microphone usage detected');
    } else {
      logger.warning('Microphone may be in use by:');
      allProcesses.forEach((proc) => {
        console.log(`  🎤 ${proc.name} (PID: ${proc.pid})`);
      });
    }
  }

  private async checkTCCPermissions(
    service: string,
    serviceName: string
  ): Promise<void> {
    logger.section(`${serviceName} Permissions (TCC Database)`);

    const tccDb = '/Library/Application Support/com.apple.TCC/TCC.db';
    const userTccDb = `${SystemService.getHomeDir()}/Library/Application Support/com.apple.TCC/TCC.db`;

    // Try user TCC database first
    let apps = await this.queryTCCDatabase(userTccDb, service);

    // If no results, try system database (requires sudo)
    if (apps.length === 0 && SystemService.pathExists(tccDb)) {
      try {
        apps = await this.queryTCCDatabaseWithSudo(tccDb, service);
      } catch {
        // Ignore errors if we can't read system database
      }
    }

    if (apps.length === 0) {
      logger.info(`No apps with ${serviceName.toLowerCase()} permissions found`);
    } else {
      logger.info(`Apps with ${serviceName.toLowerCase()} access:`);
      apps.forEach((app) => {
        const status = app.allowed ? '✅ Allowed' : '❌ Denied';
        console.log(`  ${status} - ${app.client}`);
      });
    }
  }

  private async queryTCCDatabase(
    dbPath: string,
    service: string
  ): Promise<Array<{ client: string; allowed: boolean }>> {
    if (!SystemService.pathExists(dbPath)) {
      return [];
    }

    try {
      const query = `SELECT client, allowed FROM access WHERE service='${service}' ORDER BY client;`;
      const output = await execSilent(`sqlite3 "${dbPath}" "${query}"`);

      return output
        .split('\n')
        .filter((line) => line.trim())
        .map((line) => {
          const [client, allowed] = line.split('|');
          return {
            client: client || 'unknown',
            allowed: allowed === '1',
          };
        });
    } catch {
      return [];
    }
  }

  private async queryTCCDatabaseWithSudo(
    dbPath: string,
    service: string
  ): Promise<Array<{ client: string; allowed: boolean }>> {
    try {
      const query = `SELECT client, allowed FROM access WHERE service='${service}' ORDER BY client;`;
      const output = await execSilent(
        `sudo sqlite3 "${dbPath}" "${query}" 2>/dev/null`
      );

      return output
        .split('\n')
        .filter((line) => line.trim())
        .map((line) => {
          const [client, allowed] = line.split('|');
          return {
            client: client || 'unknown',
            allowed: allowed === '1',
          };
        });
    } catch {
      return [];
    }
  }

  private async findProcessesUsingLsof(
    pattern: string,
    ignoreList: string[] = []
  ): Promise<ProcessInfo[]> {
    try {
      // Use lsof to find processes using the pattern
      const output = await execSilent(
        `lsof 2>/dev/null | grep -iE "${pattern}" | awk '{print $2" "$1}' | sort -u`
      );

      const processes = new Map<string, ProcessInfo>();

      output
        .split('\n')
        .filter((line) => line.trim())
        .forEach((line) => {
          const parts = line.trim().split(/\s+/);
          if (parts.length >= 2) {
            const pid = parts[0];
            const name = parts[1];

            // Skip if in ignore list
            const lowerName = name.toLowerCase();
            if (
              ignoreList.some((ignored) => lowerName.includes(ignored.toLowerCase()))
            ) {
              return;
            }

            processes.set(pid, { pid, name });
          }
        });

      return Array.from(processes.values());
    } catch {
      return [];
    }
  }

  private showTips(): void {
    console.log();
    logger.info(
      '💡 Tip: Use Activity Monitor to monitor real-time camera/mic usage'
    );
    logger.info(
      '💡 Tip: Check System Settings > Privacy & Security for app permissions'
    );
    logger.info(
      '💡 Tip: Use Control Center to quickly see active camera/mic indicators'
    );
  }
}
