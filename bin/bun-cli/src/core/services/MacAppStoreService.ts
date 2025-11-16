import { exec, execSilent } from '../utils/shell';
import { SystemService } from './SystemService';

/**
 * Service for Mac App Store (mas) operations
 */

export interface MasApp {
  id: string;
  name: string;
}

export class MacAppStoreService {
  /**
   * Check if mas (Mac App Store CLI) is installed
   */
  static async isInstalled(): Promise<boolean> {
    return SystemService.commandExists('mas');
  }

  /**
   * List all installed Mac App Store applications
   */
  static async listInstalled(): Promise<MasApp[]> {
    if (!(await this.isInstalled())) {
      return [];
    }

    try {
      const output = await execSilent('mas list 2>/dev/null || true');
      const lines = output.split('\n').filter((line) => line.trim());

      return lines
        .map((line) => {
          const parts = line.split(' ', 2);
          if (parts.length < 2) {
            return null;
          }

          return {
            id: parts[0],
            name: parts[1],
          };
        })
        .filter((app): app is MasApp => app !== null);
    } catch {
      return [];
    }
  }

  /**
   * Search for apps matching a pattern
   */
  static async searchInstalled(pattern: string): Promise<MasApp[]> {
    const apps = await this.listInstalled();
    const lowerPattern = pattern.toLowerCase();

    return apps.filter(
      (app) =>
        app.name.toLowerCase().includes(lowerPattern) ||
        app.id.includes(pattern)
    );
  }

  /**
   * Uninstall a Mac App Store application by ID
   */
  static async uninstall(appId: string): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec(`mas uninstall '${appId}'`, {
        description: `Removing Mac App Store app: ${appId}`,
      });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Get app info by ID
   */
  static async getAppInfo(appId: string): Promise<string> {
    if (!(await this.isInstalled())) {
      return '';
    }

    try {
      return await execSilent(`mas info '${appId}' 2>/dev/null || true`);
    } catch {
      return '';
    }
  }

  /**
   * Check if an app is installed by ID
   */
  static async isAppInstalled(appId: string): Promise<boolean> {
    const apps = await this.listInstalled();
    return apps.some((app) => app.id === appId);
  }

  /**
   * Check if an app is installed by name
   */
  static async isAppInstalledByName(name: string): Promise<boolean> {
    const apps = await this.searchInstalled(name);
    return apps.length > 0;
  }

  /**
   * Search the App Store for available apps
   */
  static async search(query: string): Promise<string> {
    if (!(await this.isInstalled())) {
      return '';
    }

    try {
      return await execSilent(`mas search '${query}' 2>/dev/null || true`);
    } catch {
      return '';
    }
  }

  /**
   * Get outdated apps
   */
  static async getOutdated(): Promise<MasApp[]> {
    if (!(await this.isInstalled())) {
      return [];
    }

    try {
      const output = await execSilent('mas outdated 2>/dev/null || true');
      const lines = output.split('\n').filter((line) => line.trim());

      return lines
        .map((line) => {
          const parts = line.split(' ', 2);
          if (parts.length < 2) {
            return null;
          }

          return {
            id: parts[0],
            name: parts[1],
          };
        })
        .filter((app): app is MasApp => app !== null);
    } catch {
      return [];
    }
  }

  /**
   * Update all Mac App Store apps
   */
  static async upgradeAll(): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec('mas upgrade', { description: 'Updating all Mac App Store apps' });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Install an app by ID
   */
  static async install(appId: string): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec(`mas install '${appId}'`, {
        description: `Installing Mac App Store app: ${appId}`,
      });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Sign in to the Mac App Store
   */
  static async signIn(appleId: string, password?: string): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      if (password) {
        await exec(`mas signin '${appleId}' '${password}'`, {
          description: 'Signing in to Mac App Store',
        });
      } else {
        await exec(`mas signin '${appleId}'`, {
          description: 'Signing in to Mac App Store',
        });
      }
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Sign out from the Mac App Store
   */
  static async signOut(): Promise<boolean> {
    if (!(await this.isInstalled())) {
      return false;
    }

    try {
      await exec('mas signout', { description: 'Signing out from Mac App Store' });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Get the currently signed-in account
   */
  static async getAccount(): Promise<string> {
    if (!(await this.isInstalled())) {
      return '';
    }

    try {
      return await execSilent('mas account 2>/dev/null || true');
    } catch {
      return '';
    }
  }
}
