import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";

interface TargetInfo {
  lineNumber: number;
  dependencies: string[];
}

const ENTRY_POINTS = new Set([
  "all",
  "install",
  "help",
  "clean",
  "default",
  "setup",
  "update",
  "mac",
  "linux",
  "doctor",
  "find-orphans",
]);

/**
 * Find Makefile targets that are never referenced as dependencies
 *
 * Scans target definitions in a Makefile, tracks dependencies, and reports
 * defined targets that appear to be unreferenced entrypoints or dead targets.
 *
 * @example
 * find-orphaned-targets
 * find-orphaned-targets Makefile
 */
@Script({
  emoji: "🔍",
  tags: ["utils", "maintenance", "makefile"],
  args: {
    makefile: {
      type: "string",
      position: 0,
      required: false,
      default: "Makefile",
      description: "Path to the Makefile to inspect",
    },
  },
})
export class FindOrphanedTargets extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const makefilePath = ctx.args.makefile || "Makefile";

    this.logger.banner("Find Orphaned Makefile Targets");
    this.logger.info("Starting analysis...");

    await this.requireFile(makefilePath, `Makefile not found: ${makefilePath}`);

    const content = await this.fs.readFile(makefilePath);
    const lines = content.split("\n");
    const targets = new Map<string, TargetInfo>();
    const referencedTargets = new Set<string>();

    lines.forEach((line, index) => {
      const parsed = this.parseTargetLine(line, index + 1);
      if (!parsed) {
        return;
      }

      targets.set(parsed.name, {
        lineNumber: parsed.lineNumber,
        dependencies: parsed.dependencies,
      });

      for (const dependency of parsed.dependencies) {
        referencedTargets.add(dependency);
      }
    });

    const orphanedTargets = [...targets.keys()]
      .filter((target) => !referencedTargets.has(target))
      .filter((target) => !ENTRY_POINTS.has(target))
      .sort((a, b) => a.localeCompare(b));

    if (orphanedTargets.length === 0) {
      this.logger.success("No orphaned targets found! All targets are properly referenced.");
      return;
    }

    this.logger.warn(`Found ${orphanedTargets.length} potentially orphaned target(s):`);
    console.log("");

    for (const target of orphanedTargets) {
      const targetInfo = targets.get(target);
      if (!targetInfo) {
        continue;
      }

      console.log(`  ${target} (line ${targetInfo.lineNumber})`);
      if (targetInfo.dependencies.length > 0) {
        console.log(`    Dependencies: ${targetInfo.dependencies.join(", ")}`);
      }
    }

    console.log("");
    this.logger.info(
      "Note: Entry points like 'all', 'install', 'help', etc. are excluded from orphan detection"
    );
    this.logger.success("Analysis complete");
  }

  private parseTargetLine(
    originalLine: string,
    lineNumber: number
  ): { name: string; lineNumber: number; dependencies: string[] } | null {
    const trimmed = originalLine.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      return null;
    }

    if (originalLine.startsWith("\t") || originalLine.startsWith(" ")) {
      return null;
    }

    const match = originalLine.match(/^([^\s][^:]*):(.*)$/);
    if (!match) {
      return null;
    }

    const targetName = match[1].trim();
    const dependencySource = match[2].trim();

    if (targetName.includes("=") || dependencySource.startsWith("=")) {
      return null;
    }

    if (targetName.includes(" ")) {
      return null;
    }

    if (targetName.startsWith(".")) {
      return null;
    }

    if (
      targetName.includes("$") ||
      targetName.includes("(") ||
      targetName.includes("|") ||
      targetName.includes("&")
    ) {
      return null;
    }

    const dependencies = dependencySource
      .split(/\s+/)
      .map((dependency) => dependency.trim())
      .filter((dependency) => this.isValidDependency(dependency));

    return {
      name: targetName,
      lineNumber,
      dependencies,
    };
  }

  private isValidDependency(dependency: string): boolean {
    if (!dependency) {
      return false;
    }

    if (dependency.startsWith("$") || dependency.includes("(") || dependency.includes("|")) {
      return false;
    }

    return true;
  }
}
