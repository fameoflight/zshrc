# Bun + TypeScript Architecture - Compact & Flexible

**Design Philosophy:**
- ✅ JSDoc for metadata (excellent extraction, standard tooling)
- ✅ class-validator for validation (powerful, declarative)
- ✅ Single `@Script` decorator (compact, all-in-one)
- ✅ Simple cases stay simple, complex cases stay possible
- ✅ Auto-discovery (no registry)
- ✅ Convention-based (directory = category, filename = command)

---

## Complete Example - Simple Script

```typescript
// src/scripts/git/commit-dir.ts

/**
 * Commit files in a specific directory
 *
 * @example
 * commit-dir src
 * commit-dir src -m "Update source files"
 */
@Script({
  emoji: "📁",
  tags: ["git", "automation"],
  args: {
    directory: {
      type: "string",
      position: 0,
      required: true,
      description: "Directory to commit",
      validate: async (value, ctx) => {
        if (!await ctx.fs.isDirectory(value)) {
          throw new Error(`Not a directory: ${value}`);
        }
      }
    },
    message: {
      type: "string",
      flag: "-m, --message",
      description: "Commit message"
    },
    noVerify: {
      type: "boolean",
      flag: "--no-verify",
      description: "Skip pre-commit hooks"
    }
  }
})
export class CommitDirectoryScript extends GitScript {
  async run(ctx: Context): Promise<void> {
    const { directory, message, noVerify } = ctx.args;

    const files = await this.getChangedFiles(ctx, directory);
    if (files.length === 0) return this.noChanges();

    this.showChanges(files);
    const msg = await this.getMessage(ctx, message);

    if (await ctx.confirm("Commit these changes?")) {
      await this.commit({ files, message: msg, noVerify, ctx });
    }
  }

  private async getChangedFiles(ctx: Context, dir: string) {
    return ctx.git.getChangedFiles({ directory: dir });
  }

  private showChanges(files: GitFile[]) {
    this.logger.info(`${files.length} files changed`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));
  }

  private async getMessage(ctx: Context, msg?: string) {
    return msg || ctx.prompt("Commit message:", `Update ${ctx.args.directory}`);
  }

  private async commit(params: {
    files: GitFile[];
    message: string;
    noVerify: boolean;
    ctx: Context;
  }) {
    const { files, message, noVerify, ctx } = params;
    await ctx.git.stageFiles({ paths: files.map(f => f.path) });
    await ctx.git.commit({ message, noVerify });
    this.logger.success("Committed!");
  }

  private noChanges() {
    this.logger.warn("No changes");
  }
}
```

**~50 lines total** - Compact, clear, follows all rules.

---

## Complete Example - With class-validator

```typescript
// src/scripts/system/largest-files.ts

/**
 * Find largest files in directory
 *
 * @example
 * largest-files
 * largest-files --count 50 --sort-by size
 */
@Script({
  emoji: "📊",
  tags: ["files", "analysis"],
  args: {
    directory: {
      type: "string",
      position: 0,
      default: ".",
      description: "Directory to scan"
    },
    count: {
      type: "integer",
      flag: "-n, --count",
      default: 20,
      min: 1,              // class-validator constraint
      max: 1000,           // class-validator constraint
      description: "Number of files to show"
    },
    sortBy: {
      type: "string",
      flag: "-s, --sort-by",
      default: "lines",
      enum: ["size", "lines"],  // class-validator @IsEnum
      description: "Sort by size or lines"
    },
    minSize: {
      type: "string",
      flag: "--min-size",
      pattern: /^\d+[BKMG]$/,  // class-validator @Matches
      description: "Minimum size (e.g., 1M, 100K)"
    },
    hidden: {
      type: "boolean",
      flag: "--hidden",
      description: "Include hidden files"
    }
  }
})
export class LargestFilesScript extends Script {
  async run(ctx: Context): Promise<void> {
    this.logger.banner("Finding Largest Files");

    const files = await this.scanFiles(ctx);
    const analyzed = await this.analyzeFiles(ctx, files);
    const top = this.filterAndSort(ctx, analyzed);

    this.displayResults(top);
  }

  private async scanFiles(ctx: Context): Promise<string[]> {
    const { directory, hidden } = ctx.args;

    this.logger.progress("Scanning files...");

    return ctx.fs.glob({
      pattern: "**/*",
      cwd: directory,
      ignore: this.buildIgnorePatterns(hidden)
    });
  }

  private async analyzeFiles(ctx: Context, files: string[]) {
    this.logger.progress(`Analyzing ${files.length} files...`);

    return ctx.args.sortBy === "size"
      ? this.analyzeBySize(files)
      : this.analyzeByLines(files);
  }

  private filterAndSort(ctx: Context, files: FileAnalysis[]) {
    const { count, minSize } = ctx.args;

    let filtered = files;
    if (minSize) {
      const bytes = this.parseSize(minSize);
      filtered = filtered.filter(f => f.size >= bytes);
    }

    return filtered
      .sort((a, b) => b.metric - a.metric)
      .slice(0, count);
  }

  private displayResults(files: FileAnalysis[]) {
    if (files.length === 0) {
      this.logger.warn("No files found");
      return;
    }

    this.logger.success(`Found ${files.length} files:\n`);
    files.forEach((f, i) => {
      const metric = this.formatMetric(f);
      console.log(`${i + 1}. ${f.path} - ${metric}`);
    });
  }

  // Helper methods...
  private buildIgnorePatterns(hidden: boolean): string[] {
    const patterns = ["**/node_modules/**", "**/.git/**"];
    if (!hidden) patterns.push("**/.*/**");
    return patterns;
  }

  private async analyzeBySize(files: string[]) {
    // Implementation
  }

  private async analyzeByLines(files: string[]) {
    // Implementation
  }

  private parseSize(size: string): number {
    // Parse 1M, 100K, etc.
  }

  private formatMetric(file: FileAnalysis): string {
    // Format based on sortBy
  }
}
```

---

## The @Script Decorator

```typescript
// src/core/decorators/Script.ts

import { validate, ValidationError } from "class-validator";

/**
 * Script configuration
 */
export interface ScriptConfig {
  // Metadata
  emoji?: string;
  tags?: string[];

  // Arguments definition (inline)
  args: Record<string, ArgumentConfig>;
}

/**
 * Argument configuration
 */
export interface ArgumentConfig {
  // Type
  type: "string" | "integer" | "number" | "boolean" | "array";

  // Position or flag
  position?: number;
  flag?: string;

  // Basic config
  required?: boolean;
  default?: any;
  description?: string;

  // class-validator constraints (auto-applied)
  min?: number;           // @Min(n) for numbers
  max?: number;           // @Max(n) for numbers
  minLength?: number;     // @MinLength(n) for strings
  maxLength?: number;     // @MaxLength(n) for strings
  enum?: string[];        // @IsEnum(enum)
  pattern?: RegExp;       // @Matches(pattern)
  email?: boolean;        // @IsEmail()
  url?: boolean;          // @IsUrl()

  // Custom validator (when class-validator isn't enough)
  validate?: (value: any, ctx: Context) => Promise<void> | void;
}

/**
 * @Script decorator - single decorator for everything
 *
 * Stores metadata + generates class-validator decorators automatically
 */
export function Script(config: ScriptConfig) {
  return function <T extends { new(...args: any[]): {} }>(constructor: T) {
    // Store metadata
    Reflect.defineMetadata("script:config", config, constructor);

    // Generate class-validator decorators from args config
    generateValidators(constructor, config.args);

    return constructor;
  };
}

/**
 * Generate class-validator decorators from arg config
 *
 * This converts:
 *   { count: { type: "integer", min: 1, max: 100 } }
 *
 * Into class-validator decorators:
 *   @IsInt() @Min(1) @Max(100)
 */
function generateValidators(
  target: any,
  args: Record<string, ArgumentConfig>
) {
  for (const [name, config] of Object.entries(args)) {
    const decorators = buildValidatorDecorators(config);

    // Apply decorators to a virtual property (for validation)
    decorators.forEach(decorator => {
      decorator(target.prototype, `_arg_${name}`);
    });
  }
}

/**
 * Build class-validator decorators from config
 */
function buildValidatorDecorators(config: ArgumentConfig): PropertyDecorator[] {
  const decorators: PropertyDecorator[] = [];

  // Type validators
  switch (config.type) {
    case "string":
      decorators.push(IsString());
      break;
    case "integer":
      decorators.push(IsInt());
      break;
    case "number":
      decorators.push(IsNumber());
      break;
    case "boolean":
      decorators.push(IsBoolean());
      break;
    case "array":
      decorators.push(IsArray());
      break;
  }

  // Constraint validators
  if (config.min !== undefined) decorators.push(Min(config.min));
  if (config.max !== undefined) decorators.push(Max(config.max));
  if (config.minLength) decorators.push(MinLength(config.minLength));
  if (config.maxLength) decorators.push(MaxLength(config.maxLength));
  if (config.enum) decorators.push(IsEnum(config.enum));
  if (config.pattern) decorators.push(Matches(config.pattern));
  if (config.email) decorators.push(IsEmail());
  if (config.url) decorators.push(IsUrl());
  if (config.required) decorators.push(IsDefined());

  return decorators;
}
```

---

## Validation Flow

```typescript
// src/core/runtime/validator.ts

/**
 * Validate script arguments
 *
 * 1. Run class-validator (generated decorators)
 * 2. Run custom validators (if provided)
 */
export async function validateArguments(
  script: Script,
  args: Record<string, any>,
  ctx: Context
): Promise<void> {
  const config = Reflect.getMetadata("script:config", script.constructor);

  // Create validation object
  const validationObject = createValidationObject(args, config.args);

  // 1. Run class-validator
  const errors = await validate(validationObject);

  if (errors.length > 0) {
    throw new ValidationError(formatValidationErrors(errors));
  }

  // 2. Run custom validators
  for (const [name, argConfig] of Object.entries(config.args)) {
    if (argConfig.validate) {
      await argConfig.validate(args[name], ctx);
    }
  }
}

/**
 * Create object for class-validator to validate
 */
function createValidationObject(
  args: Record<string, any>,
  argsConfig: Record<string, ArgumentConfig>
): any {
  const obj: any = {};

  for (const [name, value] of Object.entries(args)) {
    obj[`_arg_${name}`] = value;
  }

  return obj;
}
```

---

## Auto-Discovery (Same as Before)

```typescript
// src/cli.ts

import { discoverScripts } from "./core/discovery";
import { createCLI } from "./core/cli";

async function main() {
  // Auto-discover from src/scripts/**/*.ts
  const scripts = await discoverScripts("./src/scripts");

  // Create CLI
  const cli = createCLI({ scripts });

  // Run
  await cli.run(process.argv.slice(2));
}

main().catch(console.error);
```

---

## Directory Structure

```
src/
├── scripts/              # Auto-discovered
│   ├── git/
│   │   ├── commit-dir.ts
│   │   ├── commit-deletes.ts
│   │   └── smart-rebase.ts
│   ├── xcode/
│   │   └── icon-generator.ts
│   └── system/
│       └── largest-files.ts
├── core/
│   ├── decorators/
│   │   └── Script.ts    # Single decorator
│   ├── base/
│   │   ├── Script.ts
│   │   ├── GitScript.ts
│   │   └── XcodeScript.ts
│   ├── services/
│   │   ├── GitService.ts
│   │   └── XcodeService.ts
│   ├── utils/
│   │   ├── logger.ts
│   │   └── shell.ts
│   └── runtime/
│       ├── discovery.ts
│       ├── validator.ts
│       └── cli.ts
└── cli.ts
```

---

## Benefits

### Simple Cases Stay Simple

```typescript
@Script({
  emoji: "🔧",
  args: {
    file: {
      type: "string",
      position: 0,
      required: true,
      description: "File to process"
    }
  }
})
export class SimpleScript extends Script {
  async run(ctx: Context) {
    console.log(`Processing ${ctx.args.file}`);
  }
}
```

**~10 lines for a simple script.**

### Complex Cases Stay Possible

```typescript
@Script({
  emoji: "⚙️",
  tags: ["advanced", "config"],
  args: {
    config: {
      type: "string",
      position: 0,
      required: true,
      pattern: /^[\w-]+\.json$/,  // class-validator
      description: "Config file (JSON)",
      validate: async (value, ctx) => {
        // Custom validation
        if (!await ctx.fs.exists(value)) {
          throw new Error(`Config not found: ${value}`);
        }

        const content = await ctx.fs.readFile(value);
        try {
          JSON.parse(content);
        } catch (e) {
          throw new Error(`Invalid JSON in ${value}`);
        }
      }
    },
    port: {
      type: "integer",
      flag: "-p, --port",
      min: 1000,      // class-validator
      max: 65535,     // class-validator
      default: 3000,
      description: "Server port"
    },
    hosts: {
      type: "array",
      flag: "--hosts",
      description: "Allowed hosts",
      validate: (value, ctx) => {
        // Custom array validation
        if (!value.every(h => /^[\w.-]+$/.test(h))) {
          throw new Error("Invalid host format");
        }
      }
    }
  }
})
export class AdvancedScript extends Script {
  async run(ctx: Context) {
    // Full power when needed
  }
}
```

---

## Comparison: Before vs After

### Before (Multiple Decorators)

```typescript
export class MyScript extends GitScript {
  @Argument({ type: String, position: 0, required: true })
  directory!: string;

  @Argument({ type: String, flag: "-m" })
  message?: string;

  @Argument({ type: Boolean, flag: "--no-verify" })
  noVerify!: boolean;

  async run(ctx: Context) { }
}
```

### After (Single @Script Decorator)

```typescript
@Script({
  args: {
    directory: { type: "string", position: 0, required: true },
    message: { type: "string", flag: "-m" },
    noVerify: { type: "boolean", flag: "--no-verify" }
  }
})
export class MyScript extends GitScript {
  async run(ctx: Context) {
    const { directory, message, noVerify } = ctx.args;
  }
}
```

**More compact, less noise, all in one place.**

---

## Context Object (Everything You Need)

```typescript
export interface Context {
  // Parsed arguments (typed from @Script config)
  args: Record<string, any>;

  // Services (injected based on base class)
  git: GitService;      // If extends GitScript
  xcode: XcodeService;  // If extends XcodeScript
  fs: FileSystem;
  shell: ShellExecutor;
  logger: Logger;

  // Helpers
  prompt(message: string, defaultValue?: string): Promise<string>;
  confirm(message: string): Promise<boolean>;
  select<T>(options: T[], display?: (t: T) => string): Promise<T>;
}
```

---

## Dependencies

```json
{
  "dependencies": {
    "class-validator": "^0.14.0",
    "reflect-metadata": "^0.2.1"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.3.3"
  }
}
```

---

## Summary

**What Changed:**
- ✅ Single `@Script` decorator (not multiple `@Argument`)
- ✅ Args defined inline with decorator
- ✅ class-validator for standard validation (min/max/enum/pattern)
- ✅ Custom validators when needed
- ✅ JSDoc for documentation
- ✅ Auto-discovery from file system
- ✅ Compact syntax (simple cases ~10-20 lines)

**What Stayed:**
- ✅ Convention-based (directory = category, filename = command)
- ✅ Base classes for shared behavior
- ✅ Options objects everywhere (5-parameter law)
- ✅ Helper methods for clarity
- ✅ Auto-discovery (no registry)

**Result:**
- Simple scripts: ~10-20 lines
- Medium scripts: ~50 lines
- Complex scripts: ~100 lines (vs 200+ in Ruby)

---

## Next Steps?

**A)** Build prototype with this compact architecture
**B)** Refine something specific
**C)** Start full migration

**Does this feel right?**
