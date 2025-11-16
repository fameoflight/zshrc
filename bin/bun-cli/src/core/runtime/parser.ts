import type { ArgumentConfig } from "../types";

/**
 * Parse command-line arguments based on script configuration
 *
 * Handles:
 * - Positional arguments (position: 0, 1, 2, ...)
 * - Flag arguments (-f, --flag)
 * - Boolean flags (--verbose)
 * - Default values
 * - Type coercion
 */
export function parseArguments(
  argv: string[],
  argsConfig: Record<string, ArgumentConfig>
): Record<string, any> {
  const result: Record<string, any> = {};

  // Initialize with defaults
  for (const [name, config] of Object.entries(argsConfig)) {
    if (config.default !== undefined) {
      result[name] = config.default;
    }
  }

  // Build positional args map (position -> name)
  const positionalArgs = Object.entries(argsConfig)
    .filter(([_, config]) => config.position !== undefined)
    .sort(([_, a], [__, b]) => (a.position || 0) - (b.position || 0))
    .map(([name]) => name);

  // Build flag map (flag -> name)
  const flagMap = new Map<string, string>();
  for (const [name, config] of Object.entries(argsConfig)) {
    if (config.flag) {
      // Support both -f and --flag formats
      const flags = config.flag.split(",").map((f) => f.trim());
      for (const flag of flags) {
        flagMap.set(flag, name);
      }
    }
  }

  // Parse argv
  let positionalIndex = 0;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    // Check if it's a flag
    if (arg.startsWith("-")) {
      const { name, value, consumed } = parseFlag(arg, argv.slice(i + 1), flagMap, argsConfig);

      if (name) {
        result[name] = value;
        i += consumed;
      } else {
        throw new Error(`Unknown flag: ${arg}`);
      }
    } else {
      // Positional argument
      if (positionalIndex < positionalArgs.length) {
        const name = positionalArgs[positionalIndex];
        const config = argsConfig[name];
        result[name] = coerceValue(arg, config.type);
        positionalIndex++;
      } else {
        throw new Error(`Unexpected positional argument: ${arg}`);
      }
    }
  }

  // Check required arguments
  for (const [name, config] of Object.entries(argsConfig)) {
    if (config.required && result[name] === undefined) {
      throw new Error(`Required argument missing: ${name}`);
    }
  }

  return result;
}

/**
 * Parse a flag argument
 */
function parseFlag(
  flag: string,
  nextArgs: string[],
  flagMap: Map<string, string>,
  argsConfig: Record<string, ArgumentConfig>
): { name: string | null; value: any; consumed: number } {
  // Find the argument name for this flag
  const name = flagMap.get(flag);
  if (!name) {
    return { name: null, value: undefined, consumed: 0 };
  }

  const config = argsConfig[name];

  // Boolean flags don't consume next argument
  if (config.type === "boolean") {
    return { name, value: true, consumed: 0 };
  }

  // Other flags consume next argument
  if (nextArgs.length === 0) {
    throw new Error(`Flag ${flag} requires a value`);
  }

  const value = coerceValue(nextArgs[0], config.type);
  return { name, value, consumed: 1 };
}

/**
 * Coerce string value to proper type
 */
function coerceValue(value: string, type: ArgumentConfig["type"]): any {
  switch (type) {
    case "string":
      return value;

    case "integer":
      const int = parseInt(value, 10);
      if (isNaN(int)) {
        throw new Error(`Invalid integer: ${value}`);
      }
      return int;

    case "number":
      const num = parseFloat(value);
      if (isNaN(num)) {
        throw new Error(`Invalid number: ${value}`);
      }
      return num;

    case "boolean":
      return value.toLowerCase() === "true";

    case "array":
      // Simple comma-separated array
      return value.split(",").map((s) => s.trim());

    default:
      return value;
  }
}
