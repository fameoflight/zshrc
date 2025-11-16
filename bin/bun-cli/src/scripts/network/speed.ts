import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";

/**
 * Network speed test - test download/upload speeds and latency
 *
 * @example
 * speed
 * speed --simple
 * speed --json
 * speed --tool speedtest-cli
 */
@Script({
  emoji: "🌐",
  tags: ["network", "diagnostics"],
  args: {
    tool: {
      type: "string",
      flag: "--tool",
      enum: ["speedtest-cli", "fast", "curl"],
      default: "curl",
      description: "Tool to use for testing",
    },
    server: {
      type: "string",
      flag: "-s, --server",
      description: "Speed test server ID",
    },
    timeout: {
      type: "integer",
      flag: "-t, --timeout",
      min: 5,
      max: 300,
      default: 30,
      description: "Timeout in seconds",
    },
    noPing: {
      type: "boolean",
      flag: "--no-ping",
      description: "Skip ping test",
    },
    noDownload: {
      type: "boolean",
      flag: "--no-download",
      description: "Skip download test",
    },
    noUpload: {
      type: "boolean",
      flag: "--no-upload",
      description: "Skip upload test",
    },
    simple: {
      type: "boolean",
      flag: "--simple",
      description: "Simple output format",
    },
    json: {
      type: "boolean",
      flag: "--json",
      description: "JSON output format",
    },
  },
})
export class NetworkSpeedScript extends ScriptBase {
  private availableTools: Record<string, boolean> = {};
  private selectedTool: string = "curl";

  async run(ctx: Context): Promise<void> {
    const { json, simple, noPing, noDownload, noUpload } = ctx.args;

    if (!json) {
      this.logger.banner("Network Speed Test");
    }

    // Check available tools
    await this.checkAvailableTools(ctx);

    const results: any = {};

    // Get network info
    if (!json && !simple) {
      const networkInfo = await this.getNetworkInfo(ctx);
      this.displayNetworkInfo(networkInfo);
    }

    // Ping test
    if (!noPing) {
      this.logger.progress("Testing ping/latency...");
      results.ping = await this.testPing(ctx);
      if (!json) {
        this.displayPingResults(results.ping);
      }
    }

    // Speed test
    if (!noDownload || !noUpload) {
      this.logger.progress("Testing bandwidth...");
      const speedResults = await this.testBandwidth(ctx);
      Object.assign(results, speedResults);
      if (!json) {
        this.displaySpeedResults(speedResults);
      }
    }

    // Output
    if (json) {
      console.log(JSON.stringify(results, null, 2));
    } else if (!simple) {
      this.displaySummary(results);
    }

    this.logger.success("Test completed!");
  }

  /**
   * Check which speed test tools are available
   */
  private async checkAvailableTools(ctx: Context): Promise<void> {
    const { tool } = ctx.args;

    // Check for available tools
    this.availableTools.speedtest = this.shell.commandExists("speedtest-cli");
    this.availableTools.fast = this.shell.commandExists("fast");
    this.availableTools.curl = this.shell.commandExists("curl");
    this.availableTools.ping = this.shell.commandExists("ping");

    // Select tool
    if (tool) {
      const toolName = tool === "speedtest-cli" ? "speedtest" : tool;
      if (!this.availableTools[toolName]) {
        throw new Error(`Tool not found: ${tool}`);
      }
      this.selectedTool = tool;
    } else {
      // Auto-select best available tool
      if (this.availableTools.speedtest) {
        this.selectedTool = "speedtest-cli";
      } else if (this.availableTools.fast) {
        this.selectedTool = "fast";
      } else {
        this.selectedTool = "curl";
      }
    }

    this.logger.info(`Using tool: ${this.selectedTool}`);
  }

  /**
   * Get network information
   */
  private async getNetworkInfo(ctx: Context): Promise<any> {
    const info: any = {};

    // Get public IP info
    if (this.availableTools.curl) {
      try {
        const result = await this.shell.exec({
          command: "curl -s https://ipinfo.io/json",
          silent: true,
        });

        if (result.success) {
          const data = JSON.parse(result.stdout);
          info.publicIp = data.ip;
          info.location = `${data.city}, ${data.region}, ${data.country}`;
          info.isp = data.org;
          info.hostname = data.hostname;
        }
      } catch (e) {
        // Ignore errors
      }
    }

    // Get local interfaces (macOS/Linux)
    const ifResult = await this.shell.exec({
      command: "ifconfig",
      silent: true,
    });

    if (ifResult.success) {
      info.interfaces = this.parseIfconfig(ifResult.stdout);
    }

    return info;
  }

  /**
   * Parse ifconfig output
   */
  private parseIfconfig(output: string): any[] {
    const interfaces: any[] = [];
    let current: any = null;

    for (const line of output.split("\n")) {
      if (line.match(/^[a-z0-9]+:/)) {
        // New interface
        current = {
          name: line.split(":")[0].trim(),
          status: "down",
        };
        interfaces.push(current);
      } else if (current) {
        // Parse IP
        const ipMatch = line.match(/inet (\d+\.\d+\.\d+\.\d+)/);
        if (ipMatch) {
          current.ip = ipMatch[1];
        }

        // Parse status
        const statusMatch = line.match(/status: (\w+)/);
        if (statusMatch) {
          current.status = statusMatch[1];
        }
      }
    }

    return interfaces.filter((i) => i.ip && i.status === "active");
  }

  /**
   * Test ping to multiple hosts
   */
  private async testPing(ctx: Context): Promise<any> {
    const hosts = ["8.8.8.8", "1.1.1.1", "google.com"];
    const results: any = {};

    for (const host of hosts) {
      const result = await this.shell.exec({
        command: `ping -c 4 ${host}`,
        silent: true,
      });

      if (result.success) {
        results[host] = this.parsePingOutput(result.stdout);
      } else {
        results[host] = { error: "Ping failed", status: "failed" };
      }
    }

    return results;
  }

  /**
   * Parse ping output
   */
  private parsePingOutput(output: string): any {
    const stats: any = {};

    // Extract packet loss
    const lossMatch = output.match(/(\d+)% packet loss/);
    if (lossMatch) {
      stats.packetLoss = parseFloat(lossMatch[1]);
    }

    // Extract min/avg/max/stddev
    const statsMatch = output.match(
      /min\/avg\/max\/stddev = ([\d.]+)\/([\d.]+)\/([\d.]+)\/([\d.]+)/
    );
    if (statsMatch) {
      stats.minMs = parseFloat(statsMatch[1]);
      stats.avgMs = parseFloat(statsMatch[2]);
      stats.maxMs = parseFloat(statsMatch[3]);
      stats.stddevMs = parseFloat(statsMatch[4]);
    }

    stats.status = "success";
    return stats;
  }

  /**
   * Test bandwidth
   */
  private async testBandwidth(ctx: Context): Promise<any> {
    switch (this.selectedTool) {
      case "speedtest-cli":
        return this.testWithSpeedtestCli(ctx);
      case "fast":
        return this.testWithFast(ctx);
      default:
        return this.testWithCurl(ctx);
    }
  }

  /**
   * Test with speedtest-cli
   */
  private async testWithSpeedtestCli(ctx: Context): Promise<any> {
    const { timeout, server } = ctx.args;
    const results: any = {};

    let cmd = `speedtest-cli --json --timeout ${timeout}`;
    if (server) {
      cmd += ` --server ${server}`;
    }

    try {
      const result = await this.shell.exec({ command: cmd, silent: true });

      if (result.success) {
        const data = JSON.parse(result.stdout);
        results.downloadMbps = data.download / 1_000_000;
        results.uploadMbps = data.upload / 1_000_000;
        results.pingMs = data.ping;
        results.server = data.server;
        results.tool = "speedtest-cli";
        results.status = "success";
      } else {
        results.error = "Speedtest failed";
        results.status = "failed";
      }
    } catch (e: any) {
      results.error = e.message;
      results.status = "error";
    }

    return results;
  }

  /**
   * Test with fast.com CLI
   */
  private async testWithFast(ctx: Context): Promise<any> {
    const results: any = {};

    try {
      const result = await this.shell.exec({ command: "fast", silent: true });

      if (result.success) {
        // Parse output like "100 Mbps"
        const match = result.stdout.match(/(\d+(?:\.\d+)?)\s*(\w+)/);
        if (match) {
          let speed = parseFloat(match[1]);
          const unit = match[2].toUpperCase();

          if (unit === "GBPS") {
            speed *= 1000;
          }

          results.downloadMbps = speed;
          results.tool = "fast";
          results.status = "success";
        } else {
          results.error = "Could not parse output";
          results.status = "parse_error";
        }
      } else {
        results.error = "Fast test failed";
        results.status = "failed";
      }
    } catch (e: any) {
      results.error = e.message;
      results.status = "error";
    }

    return results;
  }

  /**
   * Test with curl (fallback)
   */
  private async testWithCurl(ctx: Context): Promise<any> {
    const results: any = {};
    const testUrl = "http://speedtest.tele2.net/10MB.zip";

    try {
      const result = await this.shell.exec({
        command: `curl -o /dev/null -r 0-10485760 -w '%{speed_download}' -s ${testUrl}`,
        silent: true,
      });

      if (result.success && result.stdout.match(/\d+/)) {
        const bytesPerSec = parseFloat(result.stdout.trim());
        results.downloadMbps = (bytesPerSec * 8) / 1_000_000;
        results.tool = "curl";
        results.status = "success";
      } else {
        results.status = "failed";
      }
    } catch (e: any) {
      results.error = e.message;
      results.status = "error";
    }

    return results;
  }

  /**
   * Display network info
   */
  private displayNetworkInfo(info: any): void {
    console.log("\n🌍 Network Information");
    console.log("─".repeat(50));

    if (info.publicIp) {
      console.log(`  Public IP:  ${info.publicIp}`);
      if (info.location) console.log(`  Location:   ${info.location}`);
      if (info.isp) console.log(`  ISP:        ${info.isp}`);
    }

    if (info.interfaces?.length > 0) {
      console.log("\n📡 Active Interfaces:");
      for (const iface of info.interfaces) {
        console.log(`  ${iface.name}: ${iface.ip} (${iface.status})`);
      }
    }

    console.log();
  }

  /**
   * Display ping results
   */
  private displayPingResults(results: any): void {
    console.log("\n🏓 Ping/Latency Test");
    console.log("─".repeat(50));

    for (const [host, stats] of Object.entries(results)) {
      const s = stats as any;
      if (s.status === "success") {
        console.log(`  ${host}:`);
        console.log(`    Average: ${s.avgMs.toFixed(1)}ms`);
        console.log(`    Min/Max: ${s.minMs.toFixed(1)}ms / ${s.maxMs.toFixed(1)}ms`);
        if (s.packetLoss) console.log(`    Loss: ${s.packetLoss}%`);
      } else {
        console.log(`  ${host}: ❌ ${s.error}`);
      }
    }

    console.log();
  }

  /**
   * Display speed results
   */
  private displaySpeedResults(results: any): void {
    console.log("\n⚡ Bandwidth Test");
    console.log("─".repeat(50));

    if (results.status === "success") {
      if (results.downloadMbps) {
        const mbps = results.downloadMbps.toFixed(2);
        const mbytes = (results.downloadMbps / 8).toFixed(2);
        console.log(`  ⬇️  Download: ${mbps} Mbps (${mbytes} MB/s)`);
      }

      if (results.uploadMbps) {
        const mbps = results.uploadMbps.toFixed(2);
        const mbytes = (results.uploadMbps / 8).toFixed(2);
        console.log(`  ⬆️  Upload: ${mbps} Mbps (${mbytes} MB/s)`);
      }

      if (results.pingMs) {
        console.log(`  🏓 Ping: ${results.pingMs.toFixed(1)}ms`);
      }

      if (results.server) {
        console.log(`\n  🌐 Server: ${results.server.name || results.server.sponsor}`);
      }
    } else {
      console.log(`  ❌ Test failed: ${results.error}`);
    }

    console.log();
  }

  /**
   * Display summary
   */
  private displaySummary(results: any): void {
    console.log("📊 Summary");
    console.log("─".repeat(50));

    // Best ping
    if (results.ping) {
      const successful = Object.values(results.ping).filter(
        (p: any) => p.status === "success"
      ) as any[];
      if (successful.length > 0) {
        const best = successful.reduce((a: any, b: any) =>
          a.avgMs < b.avgMs ? a : b
        ) as any;
        console.log(`  🏓 Best Latency: ${best.avgMs.toFixed(1)}ms`);
      }
    }

    // Speeds
    if (results.downloadMbps) {
      console.log(`  ⬇️  Download: ${results.downloadMbps.toFixed(2)} Mbps`);
    }
    if (results.uploadMbps) {
      console.log(`  ⬆️  Upload: ${results.uploadMbps.toFixed(2)} Mbps`);
    }

    console.log(`\n  Tool: ${results.tool || "multiple tools"}`);
    console.log();
  }
}
