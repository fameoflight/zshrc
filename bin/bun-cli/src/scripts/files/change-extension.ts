import { Script } from "../../core/decorators/Script";
import { BaseScript } from "../../core/base/Script";
import { logger } from "../../core/utils/logger";
import { exec } from "../../core/utils/shell";
import { readdir } from "node:fs/promises";
import { join } from "node:path";
import { existsSync } from "node:fs";
import * as readline from "node:readline/promises";

interface AppInfo {
  name: string;
  bundleId: string | null;
  path: string;
}

/**
 * Easy-to-use wrapper for duti with fuzzy application matching
 */
@Script({
  name: "change-extension",
  description: "Easy-to-use wrapper for duti with fuzzy application matching",
  emoji: "📄",
  arguments: "<extension> <app_name>",
  examples: [
    "change-extension .log vscode          # Set .log files to open with VSCode",
    "change-extension .md text            # Set .md files to open with TextEdit",
    "change-extension .pdf preview        # Set .pdf files to open with Preview",
    'change-extension .jpg "photo"        # Fuzzy match for Photo editor',
    "change-extension .rb code             # Set .rb files to open with code editor",
    "change-extension --list              # List current associations",
    "change-extension --show .pdf         # Show current association for .pdf",
  ],
  options: [
    {
      flag: "-l, --list",
      description: "List current file extension associations",
    },
    {
      flag: "-s, --show",
      description: "Show current association for extension",
    },
  ],
})
export class ChangeExtensionScript extends BaseScript {
  async run(args: string[], options: Record<string, any>): Promise<void> {
    logger.banner("Change Extension");

    if (options.list) {
      await this.listAssociations();
      logger.completion("Change Extension");
      return;
    }

    if (options.show) {
      if (args.length === 0) {
        logger.error("Extension is required for --show option");
        process.exit(1);
      }
      await this.showAssociation(args[0]);
      logger.completion("Change Extension");
      return;
    }

    if (args.length < 2) {
      logger.error("Extension and app name are required");
      console.log();
      this.showExamples();
      process.exit(1);
    }

    let extension = args[0];
    const appPattern = args[1];

    // Normalize extension (ensure it starts with dot)
    if (!extension.startsWith(".")) {
      extension = `.${extension}`;
    }

    logger.info(`Setting ${extension} files to open with: ${appPattern}`);

    // Find best matching application
    const appBundleId = await this.findApplication(appPattern);

    if (!appBundleId) {
      logger.error(`No application found matching: ${appPattern}`);
      logger.info("Try a more specific name or check installed applications");
      process.exit(1);
    }

    // Apply the change using duti
    await this.applyAssociation(extension, appBundleId, options.dryRun);

    logger.completion("Change Extension");
  }

  private showExamples(): void {
    console.log("Examples:");
    console.log("  change-extension .log vscode          # Set .log files to open with VSCode");
    console.log("  change-extension .md text            # Set .md files to open with TextEdit");
    console.log("  change-extension .pdf preview        # Set .pdf files to open with Preview");
    console.log('  change-extension .jpg "photo"        # Fuzzy match for Photo editor');
    console.log("  change-extension .rb code             # Set .rb files to open with code editor");
    console.log("  change-extension --list              # List current associations");
    console.log("  change-extension --show .pdf         # Show current association for .pdf");
  }

  private async listAssociations(): Promise<void> {
    logger.info("Current file extension associations:");
    console.log();

    const commonExtensions = [
      ".txt", ".md", ".rtf", ".doc", ".docx", ".pdf",
      ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".webp",
      ".mp4", ".mov", ".avi", ".mkv", ".mp3", ".wav", ".flac",
      ".zip", ".rar", ".7z", ".tar", ".gz",
      ".html", ".htm", ".css", ".js", ".json", ".xml", ".yaml", ".yml",
      ".py", ".rb", ".js", ".ts", ".java", ".c", ".cpp", ".h", ".php",
      ".xlsx", ".xls", ".csv", ".key", ".pages", ".numbers",
    ];

    console.log("Extension → Application");
    console.log("───────────────────────");

    for (const ext of commonExtensions) {
      try {
        const result = await exec(`duti -x ${ext} 2>/dev/null`);
        if (result.stdout.trim()) {
          const match = result.stdout.match(/\(([^)]+)\)/);
          const appName = match ? match[1] : result.stdout.trim();
          console.log(`${ext.padEnd(12)} → ${appName}`);
        } else {
          console.log(`${ext.padEnd(12)} → (not set)`);
        }
      } catch {
        console.log(`${ext.padEnd(12)} → (not set)`);
      }
    }

    console.log();
    logger.info("Showing common extensions only. Use --show <extension> for specific files.");
  }

  private async showAssociation(extension: string): Promise<void> {
    if (!extension.startsWith(".")) {
      extension = `.${extension}`;
    }

    logger.info(`Current association for ${extension}:`);

    try {
      const result = await exec(`duti -x ${extension} 2>&1`);
      console.log(result.stdout);
    } catch (error) {
      logger.warning(`No association found for ${extension}`);
    }
  }

  private async findApplication(pattern: string): Promise<string | null> {
    logger.info(`Searching for applications matching: ${pattern}`);

    // Get list of installed applications
    const apps = await this.getInstalledApplications();

    // Fuzzy match against the pattern
    const matches = this.fuzzyMatchApplications(apps, pattern);

    if (matches.length === 0) {
      logger.warning(`No applications found matching: ${pattern}`);
      return null;
    }

    if (matches.length === 1) {
      const app = matches[0];
      logger.success(`Found application: ${app.name} (${app.bundleId})`);
      return app.bundleId;
    }

    // Multiple matches - let user choose
    logger.info("Multiple applications found. Please choose:");

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    console.log();
    matches.forEach((app, index) => {
      console.log(`  ${index + 1}. ${app.name} (${app.bundleId})`);
    });
    console.log();

    const answer = await rl.question("Enter number (1-" + matches.length + "): ");
    rl.close();

    const choice = parseInt(answer.trim(), 10);
    if (isNaN(choice) || choice < 1 || choice > matches.length) {
      logger.error("Invalid choice");
      return null;
    }

    return matches[choice - 1].bundleId;
  }

  private async getInstalledApplications(): Promise<AppInfo[]> {
    const apps: AppInfo[] = [];

    const appDirs = [
      "/Applications",
      "/System/Applications",
      `${process.env.HOME}/Applications`,
    ];

    for (const dir of appDirs) {
      if (!existsSync(dir)) continue;

      const entries = await readdir(dir);
      for (const entry of entries) {
        if (entry.endsWith(".app")) {
          const appPath = join(dir, entry);
          const appInfo = await this.getAppInfo(appPath);
          if (appInfo) {
            apps.push(appInfo);
          }
        }
      }
    }

    return apps.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
  }

  private async getAppInfo(appPath: string): Promise<AppInfo | null> {
    const appName = appPath.split("/").pop()?.replace(".app", "") || "";
    const infoPlist = join(appPath, "Contents", "Info.plist");

    if (!existsSync(infoPlist)) {
      return { name: appName, bundleId: null, path: appPath };
    }

    try {
      const result = await exec(`defaults read "${infoPlist}" CFBundleIdentifier 2>/dev/null`);
      const bundleId = result.stdout.trim() || null;
      return { name: appName, bundleId, path: appPath };
    } catch {
      return { name: appName, bundleId: null, path: appPath };
    }
  }

  private fuzzyMatchApplications(apps: AppInfo[], pattern: string): AppInfo[] {
    const patternLower = pattern.toLowerCase();

    // Calculate similarity scores for each app
    const scoredApps = apps
      .map((app) => ({
        score: this.calculateSimilarity(app.name, patternLower),
        app,
      }))
      .filter(({ score }) => score > 0);

    // Sort by score (descending) and return just the apps
    return scoredApps.sort((a, b) => b.score - a.score).map(({ app }) => app);
  }

  private calculateSimilarity(text: string, pattern: string): number {
    const textLower = text.toLowerCase();

    // Exact match gets highest score
    if (textLower === pattern) return 100;

    // Starts with pattern gets high score
    if (textLower.startsWith(pattern)) return 80;

    // Contains pattern gets medium score
    if (textLower.includes(pattern)) return 60;

    // Contains any word from pattern gets lower score
    const patternWords = pattern.split(/\s+/);
    const textWords = textLower.split(/\s+/);

    const matches = patternWords.reduce((count, pWord) => {
      return (
        count +
        textWords.filter((tWord) => tWord.includes(pWord) || pWord.includes(tWord)).length
      );
    }, 0);

    if (matches > 0) return 40;

    // Partial character matching
    const sharedChars = textLower.split("").filter((char) => pattern.includes(char)).length;
    if (sharedChars >= pattern.length / 2) return 20;

    return 0;
  }

  private async applyAssociation(
    extension: string,
    bundleId: string,
    dryRun: boolean = false
  ): Promise<void> {
    logger.info(`Setting ${extension} → ${bundleId}`);

    const cmd = `duti -s ${bundleId} ${extension} all`;

    if (dryRun) {
      logger.info(`[DRY-RUN] Would execute: ${cmd}`);
    } else {
      try {
        await exec(cmd);
        logger.success("File association updated successfully!");
        logger.info("You may need to restart affected applications for changes to take effect.");
      } catch (error) {
        logger.error("Failed to set file association");
        logger.info("Make sure duti is installed: brew install duti");
        process.exit(1);
      }
    }
  }
}
