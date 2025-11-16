import { exec, execSilent } from '../utils/shell';
import { SystemService } from './SystemService';

/**
 * Service for Homebrew package manager operations
 */

export interface BrewService {
  name: string;
  status: string;
  user: string;
  file: string;
}

export class HomebrewService {
  /**
   * Check if Homebrew is installed
   */
  static async isInstalled(): Promise<boolean> {
    return SystemService.commandExists('brew');
  }

  /**
   * List installed formulae (command-line tools)
   */
  static async listFormulae(): Promise<string[]> {
    if (!(await this.isInstalled())) {
      return [];
    }

    try {
      const output = await execSilent('brew list --formula 2>/dev/null || true');
      return output
        .split('\n')
        .map((line) => line.trim())
        .filter((line) => line.length > 0);
    } catch {
      return [];
    }
  }

  /**
   * List installed casks (GUI applications)
   */
  static async listCasks(): Promise<string[]> {
    if (!(await this.isInstalled())) {
      return [];
    }

    try {
      const output = await execSilent('brew list --cask 2>/dev/null || true');
      return output
        .split('\n')
        .map((line) => line.trim())
        .filter((line) => line.length > 0);
    } catch {
      return [];
    }
  }

  /**
   * List running Homebrew services
   */
  static async listServices(): Promise<BrewService[]> {
    if (!(await this.isInstalled())) {
      return [];
    }

    try {
      const output = await execSilent('brew services list 2>/dev/null || true');
      const lines = output.split('\n').filter((line) => line.trim());

      // Skip header line
      const dataLines = lines.slice(1);

      return dataLines
        .map((line) => {
          const parts = line.trim().split(/\s+/);
          if (parts.length < 4) {
            return null;
          }

          return {
            name: parts[0],
            status: parts[1],
            user: parts[2],
            file: parts.slice(3).join(' '),
          };
        })
        .filter((service): service is BrewService => service !== null);
    } catch {
      return [];
    }
  }

  /**
   * Get running services (just the names)
   */
  static async getRunningServices(): Promise<string[]> {
    const services = await this.listServices();
    return services
      .filter((service) => service.status === 'started')
      .map((service) => service.name);
  }

  /**
   * Search for formulae matching a pattern
   */
  static async searchFormulae(pattern: string): Promise<string[]> {
    const formulae = await this.listFormulae();
    const lowerPattern = pattern.toLowerCase();
    return formulae.filter((formula) =>
      formula.toLowerCase().includes(lowerPattern)
    );
  }

  /**
   * Search for casks matching a pattern
   */
  static async searchCasks(pattern: string): Promise<string[]> {
    const casks = await this.listCasks();
    const lowerPattern = pattern.toLowerCase();
    return casks.filter((cask) => cask.toLowerCase().includes(lowerPattern));
  }

  /**
   * Stop a Homebrew service
   */
  static async stopService(service: string): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec(`brew services stop '${service}'`, {
        description: `Stopping service: ${service}`,
      });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Uninstall a formula
   */
  static async uninstallFormula(formula: string): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec(`brew uninstall '${formula}'`, {
        description: `Removing Homebrew formula: ${formula}`,
      });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Uninstall a cask
   */
  static async uninstallCask(cask: string, options?: { force?: boolean }): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      const forceFlag = options?.force ? '--force' : '';
      await exec(`brew uninstall --cask ${forceFlag} '${cask}'`, {
        description: `Removing Homebrew cask: ${cask}`,
      });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Get info about a formula
   */
  static async getFormulaInfo(formula: string): Promise<string> {
    if (!(await this.isInstalled())) {
      return '';
    }

    try {
      return await execSilent(`brew info --formula '${formula}' 2>/dev/null || true`);
    } catch {
      return '';
    }
  }

  /**
   * Get info about a cask
   */
  static async getCaskInfo(cask: string): Promise<string> {
    if (!(await this.isInstalled())) {
      return '';
    }

    try {
      return await execSilent(`brew info --cask '${cask}' 2>/dev/null || true`);
    } catch {
      return '';
    }
  }

  /**
   * Check if a formula is installed
   */
  static async isFormulaInstalled(formula: string): Promise<boolean> {
    const formulae = await this.listFormulae();
    return formulae.includes(formula);
  }

  /**
   * Check if a cask is installed
   */
  static async isCaskInstalled(cask: string): Promise<boolean> {
    const casks = await this.listCasks();
    return casks.includes(cask);
  }

  /**
   * Update Homebrew
   */
  static async update(): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec('brew update', { description: 'Updating Homebrew' });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Upgrade all packages
   */
  static async upgrade(): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec('brew upgrade', { description: 'Upgrading Homebrew packages' });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Clean up old versions
   */
  static async cleanup(): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec('brew cleanup', { description: 'Cleaning up Homebrew' });
      return true;
    } catch {
      return false;
    }
  }
}
