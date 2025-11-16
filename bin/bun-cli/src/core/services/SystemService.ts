import { exec, execSilent } from '../utils/shell';
import { existsSync, readFileSync } from 'fs';

/**
 * Service for macOS system utilities
 * Provides utilities for pmset, plist parsing, platform detection, etc.
 */

export interface PmsetBatteryData {
  powerSource: string;
  batteryId: string | null;
  chargePercent: number;
  chargingState: string;
  timeRemaining: string;
}

export interface PmsetSettings {
  [key: string]: string;
}

export interface ProcessInfo {
  pid: number;
  name: string;
  command: string;
}

export class SystemService {
  /**
   * Platform detection
   */
  static isMacOS(): boolean {
    return process.platform === 'darwin';
  }

  static isLinux(): boolean {
    return process.platform === 'linux';
  }

  static isWindows(): boolean {
    return process.platform === 'win32';
  }

  /**
   * Get current user
   */
  static getCurrentUser(): string {
    return (
      process.env.USER || process.env.USERNAME || process.env.LOGNAME || 'user'
    );
  }

  /**
   * Get home directory
   */
  static getHomeDir(): string {
    return process.env.HOME || process.env.USERPROFILE || '';
  }

  /**
   * Check if running as administrator/root
   */
  static isAdmin(): boolean {
    return process.getuid?.() === 0;
  }

  /**
   * Check if a command exists in PATH
   */
  static async commandExists(command: string): Promise<boolean> {
    try {
      if (SystemService.isWindows()) {
        await execSilent(`where ${command}`);
      } else {
        await execSilent(`which ${command}`);
      }
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Parse pmset battery status output
   */
  static async getPmsetBatteryStatus(): Promise<PmsetBatteryData> {
    const output = await exec('pmset -g batt', {
      description: 'Getting battery status',
    });

    const data: PmsetBatteryData = {
      powerSource: 'Unknown',
      batteryId: null,
      chargePercent: 0,
      chargingState: 'Unknown',
      timeRemaining: 'Unknown',
    };

    const lines = output.split('\n');
    for (const line of lines) {
      if (!line.includes('Battery') && !line.includes('drawing from')) {
        continue;
      }

      // Check power source
      if (line.includes("drawing from 'AC Power'")) {
        data.powerSource = 'AC Power';
      } else if (line.includes("drawing from 'Battery Power'")) {
        data.powerSource = 'Battery Power';
      }

      // Parse battery line like: -InternalBattery-0 (id=34013283)	7%; charging; (no estimate) present: true
      const batteryMatch = line.match(
        /-InternalBattery-\d+ \(id=(\d+)\)\s+(\d+)%;\s*(charging|discharging|finishing charge|charged);\s*(.*?)(?:\s+present: (true|false))?$/
      );

      if (batteryMatch) {
        data.batteryId = batteryMatch[1];
        data.chargePercent = parseInt(batteryMatch[2], 10);
        data.chargingState = batteryMatch[3];
        const timeStr = batteryMatch[4].trim();
        data.timeRemaining = timeStr.length === 0 ? 'Calculating...' : timeStr;
      }
    }

    return data;
  }

  /**
   * Parse pmset power management settings
   */
  static async getPmsetSettings(): Promise<PmsetSettings> {
    const output = await exec('pmset -g', {
      description: 'Getting power settings',
    });

    const settings: PmsetSettings = {};
    let currentPowerSource: string | null = null;

    const lines = output.split('\n');
    for (const line of lines) {
      const trimmedLine = line.trim();

      if (trimmedLine.includes('AC Power:')) {
        currentPowerSource = 'ac';
      } else if (trimmedLine.includes('Battery Power:')) {
        currentPowerSource = 'battery';
      } else if (trimmedLine.includes('Currently in use:')) {
        currentPowerSource = 'current';
      } else if (currentPowerSource && trimmedLine.includes(' ')) {
        const parts = trimmedLine.split(' ', 2);
        if (parts.length === 2) {
          const key = parts[0];
          const value = parts[1].trim();
          const normalizedKey = this.normalizeKey(key);
          settings[`${currentPowerSource}_${normalizedKey}`] = value;
        }
      }
    }

    return settings;
  }

  /**
   * Normalize keys (convert to snake_case)
   */
  private static normalizeKey(key: string): string {
    return key
      .toLowerCase()
      .replace(/[^\w]/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_|_$/g, '');
  }

  /**
   * Parse plist file (simple key-value extraction)
   * Note: For complex plist parsing, consider using a plist library
   */
  static parsePlist(filePath: string): Record<string, any> {
    if (!existsSync(filePath)) {
      return {};
    }

    try {
      const content = readFileSync(filePath, 'utf-8');
      // Simple plist parsing - for production use, consider using 'plist' npm package
      const result: Record<string, any> = {};

      // Extract simple key-value pairs
      const keyRegex = /<key>(.*?)<\/key>/g;
      const stringRegex = /<string>(.*?)<\/string>/g;
      const integerRegex = /<integer>(.*?)<\/integer>/g;
      const trueRegex = /<true\/>/g;
      const falseRegex = /<false\/>/g;

      const keys: string[] = [];
      let match;

      while ((match = keyRegex.exec(content)) !== null) {
        keys.push(match[1]);
      }

      // This is a simplified parser - for production, use a proper plist library
      // Return the raw content for now
      return { _raw: content, _keys: keys };
    } catch (error) {
      return {};
    }
  }

  /**
   * Find running processes by name
   */
  static async findProcesses(pattern: string): Promise<ProcessInfo[]> {
    try {
      const output = await execSilent(`pgrep -fl "${pattern}"`);
      const lines = output.split('\n').filter((line) => line.trim());

      return lines.map((line) => {
        const parts = line.trim().split(/\s+/, 2);
        return {
          pid: parseInt(parts[0], 10),
          name: pattern,
          command: parts[1] || '',
        };
      });
    } catch {
      return [];
    }
  }

  /**
   * Kill processes by name with optional signal
   */
  static async killProcesses(
    name: string,
    signal: 'TERM' | 'KILL' = 'TERM'
  ): Promise<boolean> {
    const processes = await this.findProcesses(name);

    if (processes.length === 0) {
      return false;
    }

    for (const proc of processes) {
      try {
        await execSilent(`kill -${signal} ${proc.pid}`);

        // If TERM, wait and check if still running
        if (signal === 'TERM') {
          await new Promise((resolve) => setTimeout(resolve, 1000));

          // Check if still running
          try {
            await execSilent(`kill -0 ${proc.pid}`);
            // Still running, force kill
            await execSilent(`kill -KILL ${proc.pid}`);
          } catch {
            // Process already terminated
          }
        }
      } catch {
        // Process might have already exited
      }
    }

    return true;
  }

  /**
   * Find files matching pattern in directories
   */
  static async findFiles(
    directories: string[],
    pattern: string,
    type?: 'f' | 'd'
  ): Promise<string[]> {
    const foundFiles: string[] = [];

    for (const dir of directories) {
      if (!existsSync(dir)) {
        continue;
      }

      try {
        let cmd = `find "${dir}" -maxdepth 2 -iname '*${pattern}*'`;
        if (type) {
          cmd += ` -type ${type}`;
        }
        cmd += ' 2>/dev/null || true';

        const output = await execSilent(cmd);
        const files = output
          .split('\n')
          .filter((f) => f.trim())
          .map((f) => f.trim());

        foundFiles.push(...files);
      } catch {
        // Directory might not be accessible
      }
    }

    return foundFiles.sort();
  }

  /**
   * Execute a command with sudo privileges
   */
  static async execSudo(command: string, description?: string): Promise<string> {
    return exec(`sudo ${command}`, { description });
  }

  /**
   * Check if a path exists
   */
  static pathExists(path: string): boolean {
    return existsSync(path);
  }

  /**
   * Clear screen (ANSI escape codes)
   */
  static clearScreen(): void {
    process.stdout.write('\x1b[2J\x1b[H');
  }
}
