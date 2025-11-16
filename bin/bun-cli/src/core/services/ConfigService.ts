import { existsSync, readFileSync, writeFileSync, mkdirSync, unlinkSync } from 'fs';
import { join } from 'path';
import { SystemService } from './SystemService';

/**
 * ConfigService for handling API keys and configuration storage
 * Stores configuration in ~/.config/bun-cli/{commandName}.json
 */
export class ConfigService {
  private commandName: string;
  private configDir: string;
  private configFile: string;

  constructor(commandName: string) {
    this.commandName = commandName;
    const homeDir = SystemService.getHomeDir();
    this.configDir = join(homeDir, '.config', 'bun-cli');
    this.configFile = join(this.configDir, `${commandName}.json`);
    this.ensureConfigDirectory();
  }

  /**
   * Load configuration from file, returning empty object if file doesn't exist
   */
  loadConfig(): Record<string, any> {
    if (!existsSync(this.configFile)) {
      return {};
    }

    try {
      const content = readFileSync(this.configFile, 'utf-8');
      return JSON.parse(content);
    } catch (error: any) {
      console.warn(
        `Failed to parse config file ${this.configFile}: ${error.message}`
      );
      return {};
    }
  }

  /**
   * Save configuration to file
   */
  saveConfig(config: Record<string, any>): boolean {
    try {
      writeFileSync(this.configFile, JSON.stringify(config, null, 2), 'utf-8');
      return true;
    } catch (error: any) {
      console.warn(`Failed to save config to ${this.configFile}: ${error.message}`);
      return false;
    }
  }

  /**
   * Get a specific configuration value with optional default
   */
  get<T = any>(key: string, defaultValue?: T): T | undefined {
    const config = this.loadConfig();
    return config[key] !== undefined ? config[key] : defaultValue;
  }

  /**
   * Set a specific configuration value
   */
  set(key: string, value: any): boolean {
    const config = this.loadConfig();
    config[key] = value;
    return this.saveConfig(config);
  }

  /**
   * Get API key for the command
   */
  getApiKey(): string | undefined {
    return this.get<string>('api_key');
  }

  /**
   * Set API key for the command
   */
  setApiKey(apiKey: string): boolean {
    return this.set('api_key', apiKey);
  }

  /**
   * Check if API key exists
   */
  hasApiKey(): boolean {
    const apiKey = this.getApiKey();
    return !!apiKey && apiKey.length > 0;
  }

  /**
   * Prompt user for API key and save it
   */
  async promptAndSaveApiKey(serviceName?: string): Promise<boolean> {
    const serviceLabel = serviceName || this.commandName.toUpperCase();

    // Use Bun's password prompt (hidden input)
    const password = await Bun.password(`Please enter your ${serviceLabel} API key: `);

    if (password && password.length > 0) {
      this.setApiKey(password);
      console.log('✅ API key saved successfully');
      return true;
    } else {
      console.error('❌ API key cannot be empty');
      return false;
    }
  }

  /**
   * Delete configuration file
   */
  deleteConfig(): boolean {
    if (!existsSync(this.configFile)) {
      return true;
    }

    try {
      unlinkSync(this.configFile);
      return true;
    } catch (error: any) {
      console.warn(
        `Failed to delete config file ${this.configFile}: ${error.message}`
      );
      return false;
    }
  }

  /**
   * Check if config file exists
   */
  configExists(): boolean {
    return existsSync(this.configFile);
  }

  /**
   * Get config file path for debugging
   */
  getConfigPath(): string {
    return this.configFile;
  }

  /**
   * Display configuration summary
   */
  configSummary(): void {
    const config = this.loadConfig();

    if (Object.keys(config).length === 0) {
      console.log(`No configuration found for ${this.commandName}`);
    } else {
      console.log(`Configuration for ${this.commandName}:`);
      for (const [key, value] of Object.entries(config)) {
        // Hide API keys in output
        const displayValue = key.toLowerCase().includes('key')
          ? '***' + String(value).slice(-4)
          : value;
        console.log(`  ${key}: ${displayValue}`);
      }
    }
  }

  /**
   * Ensure config directory exists
   */
  private ensureConfigDirectory(): void {
    if (!existsSync(this.configDir)) {
      mkdirSync(this.configDir, { recursive: true });
    }
  }
}
