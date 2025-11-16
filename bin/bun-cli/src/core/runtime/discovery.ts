import { Glob } from "bun";
import { join, dirname, basename } from "path";
import { getScriptConfig } from "../decorators/Script";
import type { ScriptMetadata, ScriptClass } from "../types";

/**
 * Discovered script information
 */
export interface DiscoveredScript {
  metadata: ScriptMetadata;
  scriptClass: ScriptClass;
  filePath: string;
}

/**
 * Auto-discover scripts from directory
 *
 * Convention:
 * - Directory name = category (e.g., "git", "xcode")
 * - File name = command (e.g., "commit-dir.ts" -> "commit-dir")
 *
 * @example
 * src/scripts/git/commit-dir.ts -> category: "git", command: "commit-dir"
 */
export async function discoverScripts(scriptsDir: string): Promise<DiscoveredScript[]> {
  const scripts: DiscoveredScript[] = [];

  // Find all TypeScript files in scripts directory
  const glob = new Glob("**/*.ts");
  const scanner = glob.scan({
    cwd: scriptsDir,
    onlyFiles: true,
  });

  for await (const file of scanner) {
    const filePath = join(scriptsDir, file);

    try {
      const discovered = await loadScript(filePath, scriptsDir);
      if (discovered) {
        scripts.push(discovered);
      }
    } catch (error: any) {
      console.error(`Failed to load script ${file}: ${error.message}`);
    }
  }

  return scripts;
}

/**
 * Load a single script file
 */
async function loadScript(
  filePath: string,
  scriptsDir: string
): Promise<DiscoveredScript | null> {
  // Import the module
  const module = await import(filePath);

  // Find the exported script class
  const scriptClass = findScriptClass(module);
  if (!scriptClass) {
    return null;
  }

  // Get configuration from decorator
  const config = getScriptConfig(scriptClass);
  if (!config) {
    console.warn(`Script ${filePath} has no @Script decorator`);
    return null;
  }

  // Extract category and command from file path
  const { category, command } = extractConventions(filePath, scriptsDir);

  // Extract JSDoc information
  const { description, examples } = await extractJSDoc(filePath);

  // Build metadata
  const metadata: ScriptMetadata = {
    ...config,
    category,
    command,
    description,
    examples,
  };

  return {
    metadata,
    scriptClass,
    filePath,
  };
}

/**
 * Find script class in module exports
 *
 * Looks for a class that has the @Script decorator
 */
function findScriptClass(module: any): ScriptClass | null {
  // Check default export
  if (module.default && getScriptConfig(module.default)) {
    return module.default;
  }

  // Check named exports
  for (const key of Object.keys(module)) {
    const exported = module[key];
    if (typeof exported === "function" && getScriptConfig(exported)) {
      return exported;
    }
  }

  return null;
}

/**
 * Extract category and command from file path
 *
 * Examples:
 * - src/scripts/git/commit-dir.ts -> category: "git", command: "commit-dir"
 * - src/scripts/system/largest-files.ts -> category: "system", command: "largest-files"
 */
function extractConventions(
  filePath: string,
  scriptsDir: string
): { category: string; command: string } {
  // Get relative path from scripts directory
  const relative = filePath.replace(scriptsDir, "").replace(/^\//, "");

  // Split into parts
  const parts = relative.split("/");

  // Category is the first directory
  const category = parts.length > 1 ? parts[0] : "general";

  // Command is the filename without extension
  const filename = parts[parts.length - 1];
  const command = filename.replace(/\.ts$/, "");

  return { category, command };
}

/**
 * Extract JSDoc information from file
 *
 * Looks for the class-level JSDoc comment
 */
async function extractJSDoc(
  filePath: string
): Promise<{ description?: string; examples?: string[] }> {
  const file = Bun.file(filePath);
  const content = await file.text();

  // Find JSDoc comment before class declaration
  const jsDocMatch = content.match(/\/\*\*\s*([\s\S]*?)\s*\*\/\s*@Script/);
  if (!jsDocMatch) {
    return {};
  }

  const jsDoc = jsDocMatch[1];

  // Extract description (first non-empty line)
  const descriptionMatch = jsDoc.match(/^\s*\*\s*(.+?)$/m);
  const description = descriptionMatch ? descriptionMatch[1].trim() : undefined;

  // Extract @example blocks
  const examples: string[] = [];
  const exampleMatches = jsDoc.matchAll(/@example\s*\n\s*\*\s*(.+?)$/gm);
  for (const match of exampleMatches) {
    examples.push(match[1].trim());
  }

  return { description, examples };
}

/**
 * Get script by category and command
 */
export function findScript(
  scripts: DiscoveredScript[],
  category: string,
  command: string
): DiscoveredScript | null {
  return (
    scripts.find(
      (s) => s.metadata.category === category && s.metadata.command === command
    ) || null
  );
}

/**
 * List all available scripts
 */
export function listScripts(scripts: DiscoveredScript[]): void {
  // Group by category
  const byCategory = new Map<string, DiscoveredScript[]>();

  for (const script of scripts) {
    const category = script.metadata.category;
    if (!byCategory.has(category)) {
      byCategory.set(category, []);
    }
    byCategory.get(category)!.push(script);
  }

  // Print by category
  console.log("\nAvailable scripts:\n");

  for (const [category, categoryScripts] of byCategory.entries()) {
    console.log(`📁 ${category}`);

    for (const script of categoryScripts) {
      const emoji = script.metadata.emoji || "  ";
      const description = script.metadata.description || "";
      console.log(`  ${emoji} ${script.metadata.command} - ${description}`);
    }

    console.log();
  }
}
