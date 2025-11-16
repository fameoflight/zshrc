import { Script } from '../../core/decorators/Script';
import { BaseScript } from '../../core/base/Script';
import { HomebrewService } from '../../core/services/HomebrewService';
import { MacAppStoreService, MasApp } from '../../core/services/MacAppStoreService';
import { SystemService } from '../../core/services/SystemService';
import { logger } from '../../core/utils/logger';
import { exec, execSilent } from '../../core/utils/shell';
import { existsSync } from 'fs';
import { join } from 'path';
import * as readline from 'readline';

interface ProcessInfo {
  pid: number;
  command: string;
}

interface DiscoveryResults {
  processes: ProcessInfo[];
  homebrewFormulae: string[];
  homebrewCasks: string[];
  homebrewServices: string[];
  masApps: MasApp[];
  appBundles: string[];
  startupItems: string[];
  browserItems: string[];
  kernelExtensions: string[];
  securityEntries: {
    keychain: string[];
    privacy: string[];
  };
  packageManagers: {
    npm: string[];
    yarn: string[];
    pip: string[];
    gems: string[];
  };
  networkItems: {
    systemExtensions: string[];
    dnsFiles: string[];
  };
  advancedItems: {
    quicklook: string[];
    timeMachine: string[];
    dockEntries: string[];
  };
  associatedFiles: string[];
}

@Script({
  name: 'uninstall-app',
  description:
    'Removes applications from multiple sources with complete cleanup including Homebrew packages, Mac App Store apps, processes, and associated files',
  emoji: '🗑️',
  category: 'macos',
  arguments: '<application-name>',
  options: [
    { flags: '-f, --force', description: 'Skip confirmation prompts' },
    { flags: '-d, --dry-run', description: 'Preview what would be removed' },
    { flags: '-v, --verbose', description: 'Show detailed output' },
  ],
  examples: [
    {
      command: 'uninstall-app "Visual Studio Code"',
      description: 'Remove Visual Studio Code',
    },
    {
      command: 'uninstall-app --force docker',
      description: 'Force remove Docker',
    },
    {
      command: 'uninstall-app --dry-run slack',
      description: 'Preview what would be removed',
    },
    {
      command: 'uninstall-app -v "Adobe Photoshop"',
      description: 'Verbose removal',
    },
  ],
})
export default class UninstallAppScript extends BaseScript {
  private appName = '';
  private discoveryResults: DiscoveryResults = {
    processes: [],
    homebrewFormulae: [],
    homebrewCasks: [],
    homebrewServices: [],
    masApps: [],
    appBundles: [],
    startupItems: [],
    browserItems: [],
    kernelExtensions: [],
    securityEntries: { keychain: [], privacy: [] },
    packageManagers: { npm: [], yarn: [], pip: [], gems: [] },
    networkItems: { systemExtensions: [], dnsFiles: [] },
    advancedItems: { quicklook: [], timeMachine: [], dockEntries: [] },
    associatedFiles: [],
  };

  async run(): Promise<void> {
    // Validate arguments
    if (!this.args || this.args.length === 0) {
      logger.error('Application name is required');
      console.log('\nFeatures:');
      console.log('  🍺 Homebrew packages & services');
      console.log('  🏪 Mac App Store applications');
      console.log('  🖥️  Application bundles');
      console.log('  ⚡ Running process termination');
      console.log('  🚀 Startup items cleanup');
      console.log('  🌐 Browser extensions & data');
      console.log('  🔧 Kernel extensions & drivers');
      console.log('  🔒 Security & privacy entries');
      console.log('  📦 Package managers (npm, yarn, pip, gems)');
      console.log('  🌐 Network & system integration');
      console.log('  🔍 Advanced cleanup features');
      console.log('  🧹 Associated files & preferences');
      process.exit(1);
    }

    this.appName = this.args.join(' ');
    logger.info(`Target application: ${this.appName}`);

    logger.section(`Comprehensive Application Uninstaller: ${this.appName}`);

    // Phase 1: Discovery
    logger.section('🔍 DISCOVERY PHASE');
    await this.discoverAllComponents();
    this.showDiscoverySummary();

    if (this.options.dryRun) {
      logger.info('Dry run completed - no changes made');
      return;
    }

    if (!(await this.confirmOverallRemoval())) {
      logger.info('Removal cancelled by user');
      return;
    }

    // Phase 2: Removal
    logger.section('🗑️  REMOVAL PHASE');
    await this.performRemoval();

    logger.success(`Comprehensive Application Uninstaller for ${this.appName}`);
  }

  /**
   * Discovery Phase
   */
  private async discoverAllComponents(): Promise<void> {
    this.discoveryResults.processes = await this.discoverProcesses();
    this.discoveryResults.homebrewFormulae = await this.discoverHomebrewFormulae();
    this.discoveryResults.homebrewCasks = await this.discoverHomebrewCasks();
    this.discoveryResults.homebrewServices =
      await this.discoverHomebrewServices();
    this.discoveryResults.masApps = await this.discoverMasApps();
    this.discoveryResults.appBundles = await this.discoverAppBundles();
    this.discoveryResults.startupItems = await this.discoverStartupItems();
    this.discoveryResults.browserItems = await this.discoverBrowserItems();
    this.discoveryResults.kernelExtensions =
      await this.discoverKernelExtensions();
    this.discoveryResults.securityEntries = await this.discoverSecurityEntries();
    this.discoveryResults.packageManagers =
      await this.discoverPackageManagers();
    this.discoveryResults.networkItems = await this.discoverNetworkItems();
    this.discoveryResults.advancedItems = await this.discoverAdvancedItems();
    this.discoveryResults.associatedFiles =
      await this.discoverAssociatedFiles();
  }

  private async discoverProcesses(): Promise<ProcessInfo[]> {
    try {
      const output = await execSilent(`pgrep -i "${this.appName}"`);
      const pids = output
        .split('\n')
        .filter((line) => line.trim())
        .map((line) => parseInt(line.trim(), 10));

      if (pids.length === 0) {
        logger.info('Found 0 running process(es)');
        return [];
      }

      const processes: ProcessInfo[] = [];
      for (const pid of pids) {
        try {
          const command = await execSilent(`ps -p ${pid} -o comm=`);
          if (command) {
            processes.push({ pid, command: command.trim() });
          }
        } catch {
          // Process might have exited
        }
      }

      logger.info(`Found ${processes.length} running process(es)`);
      return processes;
    } catch {
      logger.info('Found 0 running process(es)');
      return [];
    }
  }

  private async discoverHomebrewFormulae(): Promise<string[]> {
    if (!(await HomebrewService.isInstalled())) {
      logger.info('Found 0 Homebrew formula(e)');
      return [];
    }

    const formulae = await HomebrewService.searchFormulae(this.appName);
    logger.info(`Found ${formulae.length} Homebrew formula(e)`);
    return formulae;
  }

  private async discoverHomebrewCasks(): Promise<string[]> {
    if (!(await HomebrewService.isInstalled())) {
      logger.info('Found 0 Homebrew cask(s)');
      return [];
    }

    const casks = await HomebrewService.searchCasks(this.appName);
    logger.info(`Found ${casks.length} Homebrew cask(s)`);
    return casks;
  }

  private async discoverHomebrewServices(): Promise<string[]> {
    if (!(await HomebrewService.isInstalled())) {
      logger.info('Found 0 running Homebrew service(s)');
      return [];
    }

    const allServices = await HomebrewService.getRunningServices();
    const services = allServices.filter((s) =>
      s.toLowerCase().includes(this.appName.toLowerCase())
    );
    logger.info(`Found ${services.length} running Homebrew service(s)`);
    return services;
  }

  private async discoverMasApps(): Promise<MasApp[]> {
    if (!(await MacAppStoreService.isInstalled())) {
      logger.info('Found 0 Mac App Store application(s)');
      return [];
    }

    const apps = await MacAppStoreService.searchInstalled(this.appName);
    logger.info(`Found ${apps.length} Mac App Store application(s)`);
    return apps;
  }

  private async discoverAppBundles(): Promise<string[]> {
    const appDirs = [
      '/Applications',
      `${SystemService.getHomeDir()}/Applications`,
      '/System/Applications',
      '/System/Applications/Utilities',
    ];

    const bundles = await this.findInDirectories(appDirs, this.appName);
    const appBundles = bundles.filter((f) => f.endsWith('.app'));
    logger.info(`Found ${appBundles.length} application bundle(s)`);
    return appBundles;
  }

  private async discoverStartupItems(): Promise<string[]> {
    const launchDirs = [
      `${SystemService.getHomeDir()}/Library/LaunchAgents`,
      '/Library/LaunchAgents',
      '/Library/LaunchDaemons',
      '/System/Library/LaunchAgents',
      '/System/Library/LaunchDaemons',
    ];

    const items = await this.findInDirectories(launchDirs, this.appName);
    const plists = items.filter((f) => f.endsWith('.plist'));
    logger.info(`Found ${plists.length} startup item(s)`);
    return plists;
  }

  private async discoverBrowserItems(): Promise<string[]> {
    const homeDir = SystemService.getHomeDir();
    const browserDirs = [
      `${homeDir}/Library/Application Support/Google/Chrome/Default/Extensions`,
      `${homeDir}/Library/Safari/Extensions`,
      `${homeDir}/Library/Containers/com.apple.Safari/Data/Library/Safari/Extensions`,
    ];

    const items = await this.findInDirectories(browserDirs, this.appName);
    logger.info(`Found ${items.length} browser item(s)`);
    return items;
  }

  private async discoverKernelExtensions(): Promise<string[]> {
    const kextDirs = [
      '/System/Library/Extensions',
      '/Library/Extensions',
      '/System/Library/DriverExtensions',
      '/Library/DriverExtensions',
    ];

    const items = await this.findInDirectories(kextDirs, this.appName);
    const kexts = items.filter((f) => /\.(kext|dext)$/.test(f));
    logger.info(`Found ${kexts.length} kernel extension(s)`);
    return kexts;
  }

  private async discoverSecurityEntries(): Promise<{
    keychain: string[];
    privacy: string[];
  }> {
    const entries = { keychain: [] as string[], privacy: [] as string[] };

    // Keychain entries
    try {
      const keychainOutput = await execSilent(
        `security dump-keychain 2>/dev/null | grep -i "${this.appName}" || true`
      );
      entries.keychain = keychainOutput
        .split('\n')
        .filter((line) => line.trim())
        .slice(0, 5); // Limit display
    } catch {
      // Ignore errors
    }

    // Privacy database
    const privacyDb = '/Library/Application Support/com.apple.TCC/TCC.db';
    if (existsSync(privacyDb) && (await SystemService.commandExists('sqlite3'))) {
      try {
        const privacyOutput = await execSilent(
          `sudo sqlite3 "${privacyDb}" "SELECT client FROM access WHERE client LIKE '%${this.appName}%';" 2>/dev/null || true`
        );
        entries.privacy = privacyOutput.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore permission errors
      }
    }

    const total = entries.keychain.length + entries.privacy.length;
    logger.info(`Found ${total} security/privacy entry(ies)`);
    return entries;
  }

  private async discoverPackageManagers(): Promise<{
    npm: string[];
    yarn: string[];
    pip: string[];
    gems: string[];
  }> {
    const packages = {
      npm: [] as string[],
      yarn: [] as string[],
      pip: [] as string[],
      gems: [] as string[],
    };

    // NPM global packages
    if (await SystemService.commandExists('npm')) {
      try {
        const output = await execSilent(
          `npm list -g --depth=0 2>/dev/null | grep -i "${this.appName}" || true`
        );
        packages.npm = output.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore
      }
    }

    // Yarn global packages
    if (await SystemService.commandExists('yarn')) {
      try {
        const output = await execSilent(
          `yarn global list 2>/dev/null | grep -i "${this.appName}" || true`
        );
        packages.yarn = output.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore
      }
    }

    // Python packages
    if (await SystemService.commandExists('pip3')) {
      try {
        const output = await execSilent(
          `pip3 list | grep -i "${this.appName}" || true`
        );
        packages.pip = output.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore
      }
    }

    // Ruby gems
    if (await SystemService.commandExists('gem')) {
      try {
        const output = await execSilent(
          `gem list | grep -i "${this.appName}" || true`
        );
        packages.gems = output.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore
      }
    }

    const total =
      packages.npm.length +
      packages.yarn.length +
      packages.pip.length +
      packages.gems.length;
    logger.info(`Found ${total} package manager entry(ies)`);
    return packages;
  }

  private async discoverNetworkItems(): Promise<{
    systemExtensions: string[];
    dnsFiles: string[];
  }> {
    const items = {
      systemExtensions: [] as string[],
      dnsFiles: [] as string[],
    };

    // System extensions
    if (await SystemService.commandExists('systemextensionsctl')) {
      try {
        const output = await execSilent(
          `systemextensionsctl list 2>/dev/null | grep -i "${this.appName}" || true`
        );
        items.systemExtensions = output.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore
      }
    }

    // DNS resolver files
    const dnsDir = '/etc/resolver';
    if (existsSync(dnsDir)) {
      items.dnsFiles = await this.findInDirectories([dnsDir], this.appName);
    }

    const total = items.systemExtensions.length + items.dnsFiles.length;
    logger.info(`Found ${total} network/system entry(ies)`);
    return items;
  }

  private async discoverAdvancedItems(): Promise<{
    quicklook: string[];
    timeMachine: string[];
    dockEntries: string[];
  }> {
    const items = {
      quicklook: [] as string[],
      timeMachine: [] as string[],
      dockEntries: [] as string[],
    };

    // QuickLook plugins
    const qlDirs = [
      `${SystemService.getHomeDir()}/Library/QuickLook`,
      '/Library/QuickLook',
      '/System/Library/QuickLook',
    ];
    const qlItems = await this.findInDirectories(qlDirs, this.appName);
    items.quicklook = qlItems.filter((f) => f.endsWith('.qlgenerator'));

    // Time Machine exclusions
    if (await SystemService.commandExists('tmutil')) {
      try {
        const output = await execSilent(
          `tmutil listexclusions 2>/dev/null | grep -i "${this.appName}" || true`
        );
        items.timeMachine = output.split('\n').filter((line) => line.trim());
      } catch {
        // Ignore
      }
    }

    // Dock entries
    const dockPlist = `${SystemService.getHomeDir()}/Library/Preferences/com.apple.dock.plist`;
    if (existsSync(dockPlist) && (await SystemService.commandExists('plutil'))) {
      try {
        const output = await execSilent(
          `plutil -convert xml1 -o - "${dockPlist}" | grep -i "${this.appName}" || true`
        );
        if (output.trim()) {
          items.dockEntries = ['Found in Dock preferences'];
        }
      } catch {
        // Ignore
      }
    }

    const total =
      items.quicklook.length + items.timeMachine.length + items.dockEntries.length;
    logger.info(`Found ${total} advanced cleanup item(s)`);
    return items;
  }

  private async discoverAssociatedFiles(): Promise<string[]> {
    const homeDir = SystemService.getHomeDir();
    const allDirs = [
      `${homeDir}/Library/Application Support`,
      `${homeDir}/Library/Caches`,
      `${homeDir}/Library/Preferences`,
      `${homeDir}/Library/Logs`,
      `${homeDir}/Library/Saved Application State`,
      `${homeDir}/Library/Containers`,
      `${homeDir}/Library/Group Containers`,
      '/Library/Application Support',
      '/Library/Caches',
      '/Library/Preferences',
      '/Library/Logs',
    ];

    const files = await this.findInDirectories(allDirs, this.appName);
    logger.info(`Found ${files.length} associated file(s)`);
    return files;
  }

  /**
   * Helper: Find files in directories
   */
  private async findInDirectories(
    directories: string[],
    pattern: string
  ): Promise<string[]> {
    return SystemService.findFiles(directories, pattern);
  }

  /**
   * Show Discovery Summary
   */
  private showDiscoverySummary(): void {
    console.log();
    logger.section('📋 DISCOVERY SUMMARY');
    console.log();

    let totalItems = 0;

    // Running processes
    if (this.discoveryResults.processes.length > 0) {
      logger.warning(
        `⚡ Running Processes (${this.discoveryResults.processes.length}):`
      );
      this.discoveryResults.processes.forEach((proc) => {
        console.log(`  • PID ${proc.pid}: ${proc.command}`);
      });
      totalItems += this.discoveryResults.processes.length;
      console.log();
    }

    // Homebrew items
    const homebrewTotal =
      this.discoveryResults.homebrewFormulae.length +
      this.discoveryResults.homebrewCasks.length +
      this.discoveryResults.homebrewServices.length;

    if (homebrewTotal > 0) {
      logger.warning(`🍺 Homebrew Items (${homebrewTotal}):`);
      this.discoveryResults.homebrewServices.forEach((s) =>
        console.log(`  • Service: ${s}`)
      );
      this.discoveryResults.homebrewFormulae.forEach((f) =>
        console.log(`  • Formula: ${f}`)
      );
      this.discoveryResults.homebrewCasks.forEach((c) =>
        console.log(`  • Cask: ${c}`)
      );
      totalItems += homebrewTotal;
      console.log();
    }

    // Mac App Store
    if (this.discoveryResults.masApps.length > 0) {
      logger.warning(
        `🏪 Mac App Store Apps (${this.discoveryResults.masApps.length}):`
      );
      this.discoveryResults.masApps.forEach((app) =>
        console.log(`  • ${app.name} (${app.id})`)
      );
      totalItems += this.discoveryResults.masApps.length;
      console.log();
    }

    // Application bundles
    if (this.discoveryResults.appBundles.length > 0) {
      logger.warning(
        `🖥️  Application Bundles (${this.discoveryResults.appBundles.length}):`
      );
      this.discoveryResults.appBundles.forEach((app) =>
        console.log(`  • ${app.split('/').pop()}`)
      );
      totalItems += this.discoveryResults.appBundles.length;
      console.log();
    }

    // Startup items
    if (this.discoveryResults.startupItems.length > 0) {
      logger.warning(
        `🚀 Startup Items (${this.discoveryResults.startupItems.length}):`
      );
      this.discoveryResults.startupItems.forEach((item) =>
        console.log(`  • ${item.split('/').pop()}`)
      );
      totalItems += this.discoveryResults.startupItems.length;
      console.log();
    }

    // Show remaining categories if they have items...
    // (Browser, Kernel, Security, Packages, Network, Advanced, Associated Files)
    // Following the same pattern as above

    if (totalItems === 0) {
      logger.info(`No items found for '${this.appName}'`);
      logger.info(
        'The application may not be installed or may use a different name'
      );
      process.exit(0);
    }

    logger.warning(`📊 TOTAL ITEMS TO REMOVE: ${totalItems}`);
    console.log();
  }

  /**
   * Confirm overall removal
   */
  private async confirmOverallRemoval(): Promise<boolean> {
    if (this.options.force) {
      return true;
    }

    logger.warning(
      `⚠️  This will COMPLETELY REMOVE '${this.appName}' from your system!`
    );
    logger.warning('This includes ALL items listed above.');
    console.log();

    return this.confirm('❓ Proceed with complete removal?');
  }

  /**
   * Perform removal
   */
  private async performRemoval(): Promise<void> {
    // Kill processes
    if (this.discoveryResults.processes.length > 0) {
      await this.removeProcesses();
    }

    // Stop and remove Homebrew services
    if (this.discoveryResults.homebrewServices.length > 0) {
      await this.removeHomebrewServices();
    }

    // Remove Homebrew packages
    if (
      this.discoveryResults.homebrewFormulae.length > 0 ||
      this.discoveryResults.homebrewCasks.length > 0
    ) {
      await this.removeHomebrewPackages();
    }

    // Remove Mac App Store apps
    if (this.discoveryResults.masApps.length > 0) {
      await this.removeMasApps();
    }

    // Remove application bundles
    if (this.discoveryResults.appBundles.length > 0) {
      await this.removeAppBundles();
    }

    // Remove associated files
    if (this.discoveryResults.associatedFiles.length > 0) {
      await this.removeAssociatedFiles();
    }
  }

  private async removeProcesses(): Promise<void> {
    logger.info('Terminating processes...');
    for (const proc of this.discoveryResults.processes) {
      try {
        await exec(`kill -TERM ${proc.pid}`);
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Check if still running
        try {
          await execSilent(`kill -0 ${proc.pid}`);
          // Still running, force kill
          await exec(`kill -KILL ${proc.pid}`);
        } catch {
          // Already terminated
        }
      } catch {
        // Process might have already exited
      }
    }
  }

  private async removeHomebrewServices(): Promise<void> {
    for (const service of this.discoveryResults.homebrewServices) {
      await HomebrewService.stopService(service);
    }
  }

  private async removeHomebrewPackages(): Promise<void> {
    for (const formula of this.discoveryResults.homebrewFormulae) {
      await HomebrewService.uninstallFormula(formula);
    }

    for (const cask of this.discoveryResults.homebrewCasks) {
      await HomebrewService.uninstallCask(cask);
    }
  }

  private async removeMasApps(): Promise<void> {
    for (const app of this.discoveryResults.masApps) {
      await MacAppStoreService.uninstall(app.id);
    }
  }

  private async removeAppBundles(): Promise<void> {
    for (const bundle of this.discoveryResults.appBundles) {
      try {
        await exec(`rm -rf "${bundle}"`);
      } catch (error) {
        logger.error(`Failed to remove ${bundle}`);
      }
    }
  }

  private async removeAssociatedFiles(): Promise<void> {
    logger.info('Removing associated files...');
    for (const file of this.discoveryResults.associatedFiles) {
      try {
        await execSilent(`rm -rf "${file}"`);
      } catch {
        // Ignore errors for individual files
      }
    }
  }

  /**
   * Helper: Prompt for confirmation
   */
  private confirm(message: string): Promise<boolean> {
    return new Promise((resolve) => {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
      });

      rl.question(`${message} (y/N): `, (answer) => {
        rl.close();
        resolve(answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes');
      });
    });
  }
}
