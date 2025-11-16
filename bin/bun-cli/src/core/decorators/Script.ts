import "reflect-metadata";
import type { ScriptConfig, ArgumentConfig, Context } from "../types";

/**
 * @Script decorator - Single decorator for script configuration
 *
 * Stores metadata for runtime use
 *
 * @example
 * @Script({
 *   emoji: "📁",
 *   args: {
 *     directory: { type: "string", position: 0, required: true }
 *   }
 * })
 * export class MyScript extends Script {
 *   async run(ctx: Context) { }
 * }
 */
export function Script(config: ScriptConfig) {
  return function <T extends { new (...args: any[]): {} }>(constructor: T) {
    // Store metadata for runtime access
    Reflect.defineMetadata("script:config", config, constructor);
    return constructor;
  };
}

/**
 * Get script configuration from class
 */
export function getScriptConfig(target: any): ScriptConfig | undefined {
  return Reflect.getMetadata("script:config", target);
}

/**
 * Validate script arguments
 *
 * Two-step validation:
 * 1. Run built-in validators (type, constraints)
 * 2. Run custom validators (if provided)
 */
export async function validateArguments(
  scriptClass: any,
  args: Record<string, any>,
  ctx: Context
): Promise<void> {
  const config = getScriptConfig(scriptClass);
  if (!config) {
    throw new Error("Script configuration not found");
  }

  const errors: string[] = [];

  // Step 1: Run built-in validation for each argument
  for (const [name, argConfig] of Object.entries(config.args)) {
    const value = args[name];

    // Skip validation if value is undefined and not required
    if (value === undefined) {
      if (argConfig.required) {
        errors.push(`${name}: is required`);
      }
      continue;
    }

    // Type validation
    const typeError = validateType(name, value, argConfig);
    if (typeError) {
      errors.push(typeError);
      continue; // Skip constraint validation if type is wrong
    }

    // Constraint validation
    const constraintErrors = validateConstraints(name, value, argConfig);
    errors.push(...constraintErrors);
  }

  // Throw if there are built-in validation errors
  if (errors.length > 0) {
    throw new Error(`Validation failed:\n${errors.map((e) => `  - ${e}`).join("\n")}`);
  }

  // Step 2: Run custom validators
  for (const [name, argConfig] of Object.entries(config.args)) {
    if (argConfig.validate && args[name] !== undefined) {
      try {
        await argConfig.validate(args[name], ctx);
      } catch (error: any) {
        throw new Error(`Validation failed for '${name}': ${error.message}`);
      }
    }
  }
}

/**
 * Validate argument type
 */
function validateType(
  name: string,
  value: any,
  config: ArgumentConfig
): string | null {
  switch (config.type) {
    case "string":
      if (typeof value !== "string") {
        return `${name}: must be a string`;
      }
      break;

    case "integer":
      if (!Number.isInteger(value)) {
        return `${name}: must be an integer`;
      }
      break;

    case "number":
      if (typeof value !== "number" || isNaN(value)) {
        return `${name}: must be a number`;
      }
      break;

    case "boolean":
      if (typeof value !== "boolean") {
        return `${name}: must be a boolean`;
      }
      break;

    case "array":
      if (!Array.isArray(value)) {
        return `${name}: must be an array`;
      }
      break;
  }

  return null;
}

/**
 * Validate argument constraints
 */
function validateConstraints(
  name: string,
  value: any,
  config: ArgumentConfig
): string[] {
  const errors: string[] = [];

  // Numeric constraints
  if (typeof value === "number") {
    if (config.min !== undefined && value < config.min) {
      errors.push(`${name}: must be at least ${config.min}`);
    }
    if (config.max !== undefined && value > config.max) {
      errors.push(`${name}: must be at most ${config.max}`);
    }
  }

  // String constraints
  if (typeof value === "string") {
    if (config.minLength !== undefined && value.length < config.minLength) {
      errors.push(`${name}: must be at least ${config.minLength} characters`);
    }
    if (config.maxLength !== undefined && value.length > config.maxLength) {
      errors.push(`${name}: must be at most ${config.maxLength} characters`);
    }
    if (config.pattern && !config.pattern.test(value)) {
      errors.push(`${name}: does not match required pattern`);
    }
    if (config.email && !isValidEmail(value)) {
      errors.push(`${name}: must be a valid email`);
    }
    if (config.url && !isValidUrl(value)) {
      errors.push(`${name}: must be a valid URL`);
    }
  }

  // Enum constraint
  if (config.enum && !config.enum.includes(value)) {
    errors.push(`${name}: must be one of: ${config.enum.join(", ")}`);
  }

  return errors;
}

/**
 * Simple email validation
 */
function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Simple URL validation
 */
function isValidUrl(url: string): boolean {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}
