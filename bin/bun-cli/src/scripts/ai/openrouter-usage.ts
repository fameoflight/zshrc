import { Script } from '../../core/decorators/Script';
import { BaseScript } from '../../core/base/Script';
import { ConfigService } from '../../core/services/ConfigService';
import { logger } from '../../core/utils/logger';
import * as clack from '@clack/prompts';

interface OpenRouterUsageData {
  data: {
    label?: string;
    is_free_tier?: boolean;
    limit?: number;
    limit_remaining?: number;
    limit_reset?: string;
    include_byok_in_limit?: boolean;
    usage?: number;
    usage_daily?: number;
    usage_weekly?: number;
    usage_monthly?: number;
    byok_usage?: number;
    byok_usage_daily?: number;
    byok_usage_weekly?: number;
    byok_usage_monthly?: number;
  };
}

@Script({
  name: 'openrouter-usage',
  description: 'Check OpenRouter API usage and account statistics',
  emoji: '📊',
  category: 'ai',
  arguments: '[OPTIONS]',
  options: [
    { flags: '-k, --set-key', description: 'Set OpenRouter API key' },
    { flags: '--show-key', description: 'Show current API key (truncated)' },
    { flags: '--reset-key', description: 'Remove saved API key' },
    { flags: '-j, --json', description: 'Output usage data in JSON format' },
  ],
  examples: [
    { command: 'openrouter-usage', description: 'Show current usage' },
    { command: 'openrouter-usage --set-key', description: 'Set API key' },
    { command: 'openrouter-usage --show-key', description: 'Show saved API key' },
    { command: 'openrouter-usage --json', description: 'Output in JSON format' },
    {
      command: 'openrouter-usage --reset-key',
      description: 'Remove saved API key',
    },
  ],
})
export default class OpenRouterUsageScript extends BaseScript {
  private configManager: ConfigService;
  private apiBaseUrl = 'https://openrouter.ai/api/v1';

  constructor() {
    super();
    this.configManager = new ConfigService('openrouter-usage');
  }

  async run(): Promise<void> {
    logger.section('OpenRouter Usage Checker');

    // Handle key management options first
    const shouldContinue = await this.handleKeyManagement();
    if (!shouldContinue) {
      return;
    }

    // Ensure we have an API key
    if (!this.configManager.hasApiKey()) {
      logger.error('No API key found. Please set one using --set-key option');
      this.showUsageExample();
      return;
    }

    // Fetch and display usage data
    await this.fetchAndDisplayUsage();

    logger.success('OpenRouter Usage Checker');
  }

  private async handleKeyManagement(): Promise<boolean> {
    if (this.options.setKey) {
      logger.info('Setting OpenRouter API key');
      const success = await this.configManager.promptAndSaveApiKey('OpenRouter');
      if (success) {
        console.log(`API key saved to: ${this.configManager.getConfigPath()}`);
      }
      return false;
    }

    if (this.options.showKey) {
      const apiKey = this.configManager.getApiKey();
      if (apiKey && apiKey.length > 0) {
        console.log(`Current API key: ***${apiKey.slice(-4)}`);
        console.log(`Config file: ${this.configManager.getConfigPath()}`);
      } else {
        logger.warning('No API key found');
      }
      return false;
    }

    if (this.options.resetKey) {
      const shouldRemove = await clack.confirm({
        message: 'Remove saved OpenRouter API key?',
      });

      if (clack.isCancel(shouldRemove) || !shouldRemove) {
        logger.info('Operation cancelled');
        return false;
      }

      this.configManager.deleteConfig();
      logger.success('API key removed');
      return false;
    }

    // If no key management options, validate API key before proceeding
    return this.validateApiKey();
  }

  private async validateApiKey(): Promise<boolean> {
    // First check if we have an API key
    if (!this.configManager.hasApiKey()) {
      logger.error('No API key found. Please set your OpenRouter API key.');
      await this.promptForApiKey();
      return this.configManager.hasApiKey();
    }

    // Try to validate the API key with a quick API call
    try {
      logger.info('Validating API key');
      await this.fetchUsageData();
      return true;
    } catch (error: any) {
      logger.error(`API key validation failed: ${error.message}`);
      logger.info('Please check your API key or set a new one');

      const shouldSetNew = await clack.confirm({
        message: 'Would you like to set a new API key?',
      });

      if (clack.isCancel(shouldSetNew) || !shouldSetNew) {
        return false;
      }

      await this.promptForApiKey();
      return this.configManager.hasApiKey();
    }
  }

  private async promptForApiKey(): Promise<void> {
    logger.info('You can get your API key from: https://openrouter.ai/keys');

    const shouldSet = await clack.confirm({
      message: 'Set OpenRouter API key now?',
    });

    if (clack.isCancel(shouldSet) || !shouldSet) {
      return;
    }

    const success = await this.configManager.promptAndSaveApiKey('OpenRouter');
    if (success) {
      logger.success('API key saved successfully');
    } else {
      logger.error('Failed to save API key');
    }
  }

  private async fetchAndDisplayUsage(): Promise<void> {
    logger.info('Fetching OpenRouter usage data');

    try {
      const usageData = await this.fetchUsageData();
      this.displayUsageData(usageData);
    } catch (error: any) {
      logger.error(`Failed to fetch usage data: ${error.message}`);
      logger.info('Please check your API key and try again');
    }
  }

  private async fetchUsageData(): Promise<OpenRouterUsageData> {
    const apiKey = this.configManager.getApiKey();
    const url = `${this.apiBaseUrl}/auth/key`;

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    });

    if (response.status === 200) {
      return await response.json();
    } else if (response.status === 401) {
      throw new Error('Invalid API key');
    } else if (response.status === 403) {
      throw new Error('Access forbidden - check API permissions');
    } else if (response.status === 429) {
      throw new Error('Rate limit exceeded - please try again later');
    } else {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
  }

  private displayUsageData(data: OpenRouterUsageData): void {
    if (this.options.json) {
      console.log(JSON.stringify(data, null, 2));
      return;
    }

    if (!data || !data.data) {
      logger.warning('No usage data available');
      return;
    }

    const usage = data.data;

    // Account Information
    logger.section('OpenRouter Account Information');
    console.log(`Label: ${usage.label || 'N/A'}`);
    console.log(`Free Tier: ${usage.is_free_tier ? 'Yes' : 'No'}`);

    if (usage.limit) {
      console.log(`Credit Limit: $${this.formatNumber(usage.limit)}`);
      if (usage.limit_remaining !== undefined) {
        console.log(
          `Remaining Credits: $${this.formatNumber(usage.limit_remaining)}`
        );
      }
      if (usage.limit_reset) {
        console.log(`Limit Reset: ${usage.limit_reset}`);
      }
    } else {
      console.log('Credit Limit: Unlimited');
    }

    console.log(
      `Include BYOK in Limit: ${usage.include_byok_in_limit ? 'Yes' : 'No'}`
    );

    // Usage Statistics
    logger.section('Usage Statistics');
    console.log(`All-time Usage: ${this.formatCredits(usage.usage)} credits`);
    console.log(`Daily Usage: ${this.formatCredits(usage.usage_daily)} credits`);
    console.log(`Weekly Usage: ${this.formatCredits(usage.usage_weekly)} credits`);
    console.log(`Monthly Usage: ${this.formatCredits(usage.usage_monthly)} credits`);

    // BYOK Usage
    logger.section('BYOK (Bring Your Own Key) Usage');
    console.log(
      `BYOK All-time Usage: ${this.formatCredits(usage.byok_usage)} credits`
    );
    console.log(
      `BYOK Daily Usage: ${this.formatCredits(usage.byok_usage_daily)} credits`
    );
    console.log(
      `BYOK Weekly Usage: ${this.formatCredits(usage.byok_usage_weekly)} credits`
    );
    console.log(
      `BYOK Monthly Usage: ${this.formatCredits(usage.byok_usage_monthly)} credits`
    );

    // Rate Limits & Free Tier Information
    logger.section('Rate Limits & Free Tier Information');
    console.log(
      `Account Type: ${usage.is_free_tier ? 'Free Tier' : 'Paid Account'}`
    );

    if (usage.is_free_tier) {
      console.log('Free Model Limits:');
      console.log('  • Rate Limit: 20 requests per minute');

      const totalUsage = usage.usage || 0;
      if (totalUsage < 10) {
        console.log('  • Daily Limit: 50 :free model requests per day');
      } else {
        console.log(
          '  • Daily Limit: 1000 :free model requests per day (requires 10+ credits purchased)'
        );
      }
    } else {
      console.log('No free model daily limits - paid account');
    }

    // Show usage percentage if there's a limit
    if (
      usage.limit &&
      usage.limit > 0 &&
      usage.limit_remaining !== undefined
    ) {
      const usedPercentage = parseFloat(
        (((usage.limit - usage.limit_remaining) / usage.limit) * 100).toFixed(2)
      );
      console.log();
      console.log(`Usage: ${usedPercentage}% of limit`);

      // Visual progress bar
      const barLength = 30;
      const usedLength = Math.floor((barLength * usedPercentage) / 100);
      const remainingLength = barLength - usedLength;

      const bar = '█'.repeat(usedLength) + '░'.repeat(remainingLength);
      console.log(`┌${'─'.repeat(barLength)}┐`);
      console.log(`│${bar}│ ${usedPercentage}%`);
      console.log(`└${'─'.repeat(barLength)}┘`);
    }
  }

  private formatCredits(value?: number): string {
    if (value === undefined || value === null) {
      return '0.000000';
    }
    return value.toFixed(6);
  }

  private formatNumber(value?: number): string {
    if (value === undefined || value === null) {
      return '0';
    }
    return value.toFixed(2);
  }

  private showUsageExample(): void {
    console.log();
    console.log('To set your API key:');
    console.log('  openrouter-usage --set-key');
    console.log();
    console.log('Get your API key from: https://openrouter.ai/keys');
  }
}
