import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";

/**
 * Display network information
 *
 * @example
 * info
 * info --interface en0
 * info --verbose
 */
@Script({
  emoji: "🌐",
  tags: ["network", "system"],
  args: {
    interface: {
      type: "string",
      flag: "-i, --interface",
      description: "Specific network interface to show",
    },
    verbose: {
      type: "boolean",
      flag: "-v, --verbose",
      description: "Show detailed information",
    },
  },
})
export class NetworkInfoScript extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const { interface: iface, verbose } = ctx.args;

    this.logger.banner("Network Information");

    // Get network interfaces
    if (iface) {
      await this.showInterface(iface, verbose);
    } else {
      await this.showAllInterfaces(verbose);
    }

    this.logger.success("Done!");
  }

  /**
   * Show all network interfaces
   */
  private async showAllInterfaces(verbose: boolean): Promise<void> {
    // Get list of interfaces (macOS/Linux)
    const result = await this.shell.exec({
      command: "ifconfig -l",
      silent: true,
    });

    if (!result.success) {
      this.logger.error("Failed to get network interfaces");
      return;
    }

    const interfaces = result.stdout.split(/\s+/).filter((i) => i.length > 0);

    this.logger.info(`Found ${interfaces.length} interface(s)\n`);

    for (const iface of interfaces) {
      await this.showInterface(iface, verbose);
      console.log();
    }
  }

  /**
   * Show specific interface
   */
  private async showInterface(iface: string, verbose: boolean): Promise<void> {
    const result = await this.shell.exec({
      command: `ifconfig ${iface}`,
      silent: true,
    });

    if (!result.success) {
      this.logger.warn(`Interface not found: ${iface}`);
      return;
    }

    console.log(`\n📡 ${iface}`);
    console.log("─".repeat(50));

    if (verbose) {
      // Show full output
      console.log(result.stdout);
    } else {
      // Show summary
      this.showSummary(result.stdout);
    }
  }

  /**
   * Show interface summary (IPv4, IPv6, status)
   */
  private showSummary(output: string): void {
    const lines = output.split("\n");

    // Extract key information
    const ipv4 = this.extractPattern(lines, /inet\s+(\d+\.\d+\.\d+\.\d+)/);
    const ipv6 = this.extractPattern(lines, /inet6\s+([a-f0-9:]+)/);
    const status = this.extractPattern(lines, /status:\s+(.+)/);
    const ether = this.extractPattern(lines, /ether\s+([a-f0-9:]+)/);

    if (status) console.log(`  Status:  ${status}`);
    if (ipv4) console.log(`  IPv4:    ${ipv4}`);
    if (ipv6) console.log(`  IPv6:    ${ipv6}`);
    if (ether) console.log(`  MAC:     ${ether}`);
  }

  /**
   * Extract pattern from lines
   */
  private extractPattern(lines: string[], pattern: RegExp): string | null {
    for (const line of lines) {
      const match = line.match(pattern);
      if (match) {
        return match[1];
      }
    }
    return null;
  }
}
