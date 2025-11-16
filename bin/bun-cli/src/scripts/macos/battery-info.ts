import { Script } from '../../core/decorators/Script';
import { BaseScript } from '../../core/base/Script';
import { SystemProfilerService } from '../../core/services/SystemProfilerService';
import { SystemService, PmsetBatteryData, PmsetSettings } from '../../core/services/SystemService';
import { logger } from '../../core/utils/logger';

interface BatteryData {
  systemProfiler: any;
  pmset: PmsetBatteryData;
  powerSettings: PmsetSettings;
  timestamp: string;
}

@Script({
  name: 'battery-info',
  description: 'Shows detailed battery and power charger information for macOS systems',
  emoji: '🔋',
  category: 'macos',
  arguments: '[OPTIONS]',
  options: [
    { flags: '-j, --json', description: 'Output information in JSON format' },
    { flags: '-s, --simple', description: 'Show simplified view without detailed hardware info' },
    { flags: '--no-color', description: 'Disable colored output' },
    { flags: '--refresh <seconds>', description: 'Continuously refresh every N seconds' },
  ],
  examples: [
    { command: 'battery-info', description: 'Show battery and power information' },
    { command: 'battery-info --simple', description: 'Show simplified view' },
    { command: 'battery-info --json', description: 'Output in JSON format' },
    { command: 'battery-info --refresh 30', description: 'Continuously refresh every 30 seconds' },
    { command: 'battery-info --no-color', description: 'Disable colored output' },
  ],
})
export default class BatteryInfoScript extends BaseScript {
  private jsonOutput = false;
  private simpleView = false;
  private refreshInterval?: number;
  private systemProfilerService?: SystemProfilerService;

  async run(): Promise<void> {
    // Validate macOS
    if (!SystemService.isMacOS()) {
      logger.error('This script is designed for macOS systems only');
      process.exit(1);
    }

    // Parse options
    this.jsonOutput = this.options.json || false;
    this.simpleView = this.options.simple || false;
    this.refreshInterval = this.options.refresh
      ? parseInt(this.options.refresh, 10)
      : undefined;

    // Validate refresh interval
    if (this.refreshInterval !== undefined && this.refreshInterval < 1) {
      logger.error('Refresh interval must be at least 1 second');
      process.exit(1);
    }

    // Initialize service
    this.systemProfilerService = new SystemProfilerService({
      cacheTTL: 300,
      debug: this.options.verbose,
    });

    if (this.refreshInterval) {
      logger.info(
        `Continuously refreshing every ${this.refreshInterval} seconds. Press Ctrl+C to stop.`
      );
      console.log();

      try {
        while (true) {
          SystemService.clearScreen();
          await this.displayBatteryInfo();
          await new Promise((resolve) =>
            setTimeout(resolve, this.refreshInterval! * 1000)
          );
        }
      } catch (error) {
        console.log('\n');
        logger.info('Stopped refreshing');
      }
    } else {
      logger.section('Battery & Power Information');
      await this.displayBatteryInfo();
      logger.success('Battery information display');
    }
  }

  private async displayBatteryInfo(): Promise<void> {
    const batteryData = await this.collectBatteryData();

    if (this.jsonOutput) {
      console.log(JSON.stringify(batteryData, null, 2));
      return;
    }

    this.displayOverview(batteryData);
    if (!this.simpleView) {
      this.displayBatteryDetails(batteryData);
    }
    this.displayChargerInfo(batteryData);
    if (!this.simpleView) {
      this.displayPowerSettings(batteryData);
    }
  }

  private async collectBatteryData(): Promise<BatteryData> {
    const data: BatteryData = {
      systemProfiler: {},
      pmset: {
        powerSource: 'Unknown',
        batteryId: null,
        chargePercent: 0,
        chargingState: 'Unknown',
        timeRemaining: 'Unknown',
      },
      powerSettings: {},
      timestamp: new Date().toISOString().replace('T', ' ').substring(0, 19),
    };

    // Get battery information from system profiler service
    const powerData = await this.systemProfilerService!.powerInfo(true);
    data.systemProfiler.power = powerData;

    // Get current battery status from pmset
    data.pmset = await SystemService.getPmsetBatteryStatus();

    // Get power management settings
    data.powerSettings = await SystemService.getPmsetSettings();

    return data;
  }

  private displayOverview(data: BatteryData): void {
    const pmset = data.pmset;
    const powerData = data.systemProfiler.power || {};
    const healthInfo = powerData.health_information || {};
    const chargeInfo = powerData.charge_information || {};

    console.log(`${this.batteryEmoji(pmset.chargingState)} Battery Status`);
    console.log('='.repeat(50));
    console.log();

    // Power source
    const powerSourceIcon = pmset.powerSource === 'AC Power' ? '🔌' : '🔋';
    console.log(`${powerSourceIcon} Power Source: ${pmset.powerSource}`);

    // Battery percentage with color
    const percentage = pmset.chargePercent;
    console.log(
      `${this.getPercentageEmoji(percentage)} Charge: ${percentage}% ${this.getBatteryStatusIndicator(percentage)}`
    );

    // Charging status
    const chargingIcon = this.chargingEmoji(pmset.chargingState);
    console.log(
      `${chargingIcon} Status: ${this.formatChargingState(pmset.chargingState)}`
    );

    // Time remaining
    const timeIcon = pmset.chargingState === 'charging' ? '⏱️' : '⏰';
    console.log(`${timeIcon} Time: ${pmset.timeRemaining}`);

    // Health information
    const maxCapacity = healthInfo.maximum_capacity;
    if (maxCapacity) {
      console.log(`${this.healthEmoji(maxCapacity)} Health: ${maxCapacity}`);
    }

    const cycleCount = healthInfo.cycle_count;
    if (cycleCount) {
      console.log(`${this.cycleEmoji(cycleCount)} Cycles: ${cycleCount}`);
    }

    const condition = healthInfo.condition;
    if (condition) {
      console.log(
        `${this.conditionEmoji(condition)} Condition: ${condition}`
      );
    }

    // Additional charge info
    const stateOfCharge = chargeInfo.state_of_charge;
    if (stateOfCharge !== undefined) {
      console.log(`📊 State of Charge: ${stateOfCharge}%`);
    }

    const fullyCharged = chargeInfo.fully_charged;
    if (fullyCharged !== undefined) {
      console.log(
        `${fullyCharged ? '✅' : '⏳'} Fully Charged: ${fullyCharged ? 'Yes' : 'No'}`
      );
    }

    console.log();
  }

  private displayBatteryDetails(battery: BatteryData): void {
    const powerData = battery.systemProfiler.power || {};
    const modelInfo = powerData.model_information || {};
    const chargeInfo = powerData.charge_information || {};

    logger.section('Battery Details');
    console.log();

    // Model Information
    console.log('📱 Model Information:');
    let hasModelInfo = false;

    for (const [key, value] of Object.entries(modelInfo)) {
      if (value === null || value === undefined || value === '') {
        continue;
      }

      const displayKey = key
        .split('_')
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');
      console.log(`  ${displayKey}: ${value}`);
      hasModelInfo = true;
    }

    if (!hasModelInfo) {
      console.log('  No detailed model information available');
    }
    console.log();

    // Detailed Charge Information
    console.log('⚡ Charge Information:');
    let hasChargeInfo = false;

    for (const [key, value] of Object.entries(chargeInfo)) {
      if (value === null || value === undefined || key === 'state_of_charge') {
        continue;
      }

      const displayKey = key
        .split('_')
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');

      if (typeof value === 'boolean') {
        console.log(`  ${displayKey}: ${value ? 'Yes' : 'No'}`);
      } else {
        console.log(`  ${displayKey}: ${value}`);
      }
      hasChargeInfo = true;
    }

    if (!hasChargeInfo) {
      console.log('  No detailed charge information available');
    }
    console.log();
  }

  private displayChargerInfo(battery: BatteryData): void {
    const powerData = battery.systemProfiler.power || {};
    const chargerInfo = powerData.ac_charger_information || {};
    const pmset = battery.pmset;

    logger.section('Charger Information');
    console.log();

    if (Object.keys(chargerInfo).length === 0) {
      console.log('ℹ️  No charger connected');
    } else {
      const connected = chargerInfo.connected === true;
      console.log(`🔌 Connected: ${connected ? 'Yes' : 'No'}`);

      if (connected) {
        console.log('⚡ Charger Specifications:');

        const wattage = chargerInfo.wattage_w;
        if (wattage) {
          console.log(`  🔋 Power: ${wattage}W`);
        }

        const id = chargerInfo.id;
        if (id) {
          console.log(`  ID: ${id}`);
        }

        const family = chargerInfo.family;
        if (family) {
          console.log(`  Family: ${family}`);
        }

        if (
          pmset.chargingState === 'charging' &&
          pmset.timeRemaining !== 'Calculating...'
        ) {
          console.log(`  ⏱️  Until Full: ${pmset.timeRemaining}`);
        }
      } else {
        console.log('ℹ️  Charger not connected or not detected');
      }
    }

    console.log();
  }

  private displayPowerSettings(battery: BatteryData): void {
    const powerData = battery.systemProfiler.power || {};
    const acPowerSettings = powerData.ac_power || {};
    const batteryPowerSettings = powerData.battery_power || {};

    logger.section('Power Management Settings');
    console.log();

    // AC Power Settings
    if (Object.keys(acPowerSettings).length > 0) {
      console.log('🔌 AC Power Settings:');
      for (const [key, value] of Object.entries(acPowerSettings)) {
        if (value === null || value === undefined) {
          continue;
        }

        const displayKey = key
          .split('_')
          .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
          .join(' ');

        if (typeof value === 'boolean') {
          console.log(`  ${displayKey}: ${value ? 'Yes' : 'No'}`);
        } else if (
          (key.includes('_minutes') || key.includes('_timer')) &&
          typeof value === 'number'
        ) {
          console.log(`  ${displayKey}: ${value} minutes`);
        } else {
          console.log(`  ${displayKey}: ${value}`);
        }
      }
      console.log();
    } else {
      console.log('ℹ️  No AC power settings available');
      console.log();
    }

    // Battery Power Settings
    if (Object.keys(batteryPowerSettings).length > 0) {
      console.log('🔋 Battery Power Settings:');
      for (const [key, value] of Object.entries(batteryPowerSettings)) {
        if (value === null || value === undefined) {
          continue;
        }

        const displayKey = key
          .split('_')
          .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
          .join(' ');

        if (typeof value === 'boolean') {
          console.log(`  ${displayKey}: ${value ? 'Yes' : 'No'}`);
        } else if (
          (key.includes('_minutes') || key.includes('_timer')) &&
          typeof value === 'number'
        ) {
          console.log(`  ${displayKey}: ${value} minutes`);
        } else {
          console.log(`  ${displayKey}: ${value}`);
        }
      }
      console.log();
    } else {
      console.log('ℹ️  No battery power settings available');
      console.log();
    }
  }

  // Helper methods for emojis and formatting
  private getBatteryStatusIndicator(percentage: number): string {
    if (percentage >= 80) return '🟢';
    if (percentage >= 50) return '🟡';
    if (percentage >= 20) return '🟠';
    return '🔴';
  }

  private getPercentageEmoji(percentage: number): string {
    if (percentage >= 10) return '🔋';
    return '🪫';
  }

  private batteryEmoji(chargingState: string): string {
    if (chargingState === 'charging' || chargingState === 'finishing charge')
      return '⚡';
    if (chargingState === 'charged') return '🔋';
    return '🪫';
  }

  private chargingEmoji(chargingState: string): string {
    switch (chargingState) {
      case 'charging':
        return '⚡';
      case 'discharging':
        return '📉';
      case 'finishing charge':
        return '🔋';
      case 'charged':
        return '✅';
      default:
        return '❓';
    }
  }

  private healthEmoji(maxCapacity: any): string {
    if (!maxCapacity) return '❓';

    let capacity: number;
    if (typeof maxCapacity === 'string') {
      const match = maxCapacity.match(/(\d+)%?/);
      capacity = match ? parseInt(match[1], 10) : parseInt(maxCapacity, 10);
    } else {
      capacity = parseInt(maxCapacity, 10);
    }

    if (capacity >= 90) return '🟢';
    if (capacity >= 80) return '🟡';
    if (capacity >= 70) return '🟠';
    return '🔴';
  }

  private conditionEmoji(condition: any): string {
    const cond = condition?.toLowerCase();
    switch (cond) {
      case 'normal':
      case 'good':
        return '🟢';
      case 'fair':
        return '🟡';
      case 'poor':
        return '🟠';
      case 'replace soon':
      case 'replace now':
      case 'service battery':
        return '🔴';
      default:
        return '❓';
    }
  }

  private cycleEmoji(cycleCount: any): string {
    if (!cycleCount) return '❓';

    let cycles: number;
    if (typeof cycleCount === 'string') {
      const match = cycleCount.match(/(\d+)/);
      cycles = match ? parseInt(match[1], 10) : parseInt(cycleCount, 10);
    } else {
      cycles = parseInt(cycleCount, 10);
    }

    if (cycles <= 300) return '🟢';
    if (cycles <= 600) return '🟡';
    if (cycles <= 1000) return '🟠';
    return '🔴';
  }

  private formatChargingState(state: string): string {
    switch (state) {
      case 'charging':
        return 'Charging ⚡';
      case 'discharging':
        return 'Discharging 📉';
      case 'finishing charge':
        return 'Finishing Charge 🔋';
      case 'charged':
        return 'Fully Charged ✅';
      default:
        return state.charAt(0).toUpperCase() + state.slice(1);
    }
  }
}
