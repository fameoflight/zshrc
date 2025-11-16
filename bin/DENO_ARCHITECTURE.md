# Deno + TypeScript Architecture Design

**Decision**: Migrate Ruby scripts to Deno + TypeScript
**Date**: 2025-11-16
**Status**: Design Phase

## Why Deno?

✅ **Native TypeScript** - No build step, runs `.ts` files directly
✅ **Secure by default** - Explicit permissions (--allow-read, --allow-write, etc.)
✅ **Standard library** - High-quality modules for common tasks
✅ **Modern APIs** - Web standards (fetch, WebSocket, etc.)
✅ **Built-in tooling** - Formatter, linter, test runner, bundler
✅ **Single executable** - No node_modules, faster installs

## Architecture Principles

### 1. Layered Architecture
```
┌─────────────────────────────────────────┐
│         CLI Scripts (Presentation)       │  ← User-facing commands
├─────────────────────────────────────────┤
│      Base Classes & Decorators           │  ← Validation, lifecycle
├─────────────────────────────────────────┤
│           Services (Business)            │  ← Git, Xcode, File ops
├─────────────────────────────────────────┤
│        Utilities & Helpers               │  ← Logging, formatting
├─────────────────────────────────────────┤
│          Deno Standard Library           │  ← OS, file system
└─────────────────────────────────────────┘
```

### 2. Dependency Injection
- Services injected via constructor
- Easy to test and mock
- Explicit dependencies

### 3. Decorator-Based Validation
- Declarative validation rules
- TypeScript decorators for metadata
- Clean, readable code

### 4. Strong Typing
- No `any` types (except edge cases)
- Strict TypeScript configuration
- Runtime validation where needed

### 5. Functional Core, Imperative Shell
- Services are pure functions where possible
- Side effects isolated to edges
- Easier to test

## Directory Structure

```
bin/deno-cli/
├── mod.ts                          # Main entry point
├── deno.json                       # Deno configuration
├── import_map.json                 # Dependency management
│
├── scripts/                        # CLI Scripts (user-facing)
│   ├── git/
│   │   ├── commit-dir.ts
│   │   ├── commit-deletes.ts
│   │   ├── commit-splitter.ts
│   │   ├── smart-rebase.ts
│   │   └── compress.ts
│   ├── xcode/
│   │   ├── icon-generator.ts
│   │   ├── add-file.ts
│   │   └── delete-file.ts
│   ├── files/
│   │   ├── merge-pdf.ts
│   │   ├── merge-markdown.ts
│   │   └── change-extension.ts
│   └── system/
│       ├── battery-info.ts
│       └── network-speed.ts
│
├── core/                           # Core framework
│   ├── base/
│   │   ├── Script.ts              # Base script class
│   │   ├── GitScript.ts           # Git-specific base
│   │   ├── XcodeScript.ts         # Xcode-specific base
│   │   └── InteractiveScript.ts   # Interactive prompts
│   │
│   ├── decorators/
│   │   ├── validates.ts           # Validation decorators
│   │   ├── options.ts             # CLI option decorators
│   │   ├── memoize.ts             # Caching decorator
│   │   └── retry.ts               # Retry decorator
│   │
│   ├── types/
│   │   ├── script.types.ts        # Script interfaces
│   │   ├── git.types.ts           # Git types
│   │   ├── validation.types.ts    # Validation types
│   │   └── options.types.ts       # CLI option types
│   │
│   └── registry/
│       ├── ScriptRegistry.ts      # Script discovery
│       └── ServiceRegistry.ts     # DI container
│
├── services/                       # Business logic
│   ├── git/
│   │   ├── GitService.ts          # Core git operations
│   │   ├── CommitService.ts       # Commit-specific
│   │   ├── BranchService.ts       # Branch operations
│   │   └── RebaseService.ts       # Rebase logic
│   │
│   ├── xcode/
│   │   ├── XcodeProjectService.ts # Project file parsing
│   │   ├── AssetService.ts        # Asset catalog ops
│   │   └── IconService.ts         # Icon generation
│   │
│   ├── file/
│   │   ├── FileService.ts         # File operations
│   │   ├── PDFService.ts          # PDF manipulation
│   │   └── ImageService.ts        # Image processing
│   │
│   └── interactive/
│       ├── SelectionService.ts    # fzf/peco integration
│       ├── PromptService.ts       # User prompts
│       └── ProgressService.ts     # Progress bars
│
├── utils/                          # Utilities
│   ├── logger/
│   │   ├── Logger.ts              # Structured logging
│   │   └── colors.ts              # Terminal colors
│   │
│   ├── validation/
│   │   ├── validators.ts          # Common validators
│   │   └── schemas.ts             # Zod schemas
│   │
│   ├── shell/
│   │   ├── exec.ts                # Command execution
│   │   └── permissions.ts         # Permission helpers
│   │
│   └── format/
│       ├── bytes.ts               # File size formatting
│       ├── time.ts                # Time formatting
│       └── templates.ts           # String templates
│
└── tests/                          # Test files
    ├── services/
    ├── scripts/
    └── utils/
```

## Core Components

### 1. Base Script Class

**`core/base/Script.ts`**
```typescript
import { Logger } from "@/utils/logger/Logger.ts";
import type { ScriptConfig, ScriptMetadata, ValidationRule } from "@/core/types/script.types.ts";

export abstract class Script {
  protected logger: Logger;
  protected config: ScriptConfig;
  private validationRules: ValidationRule[] = [];

  constructor(config: ScriptConfig = {}) {
    this.config = config;
    this.logger = new Logger({
      name: this.constructor.name,
      level: config.logLevel ?? "info",
    });
  }

  // Lifecycle methods
  async execute(args: string[]): Promise<void> {
    try {
      await this.beforeValidation();
      await this.validate(args);
      await this.afterValidation();

      await this.beforeRun();
      await this.run(args);
      await this.afterRun();
    } catch (error) {
      await this.handleError(error as Error);
      throw error;
    } finally {
      await this.cleanup();
    }
  }

  // Abstract methods (must implement)
  abstract run(args: string[]): Promise<void>;

  // Optional lifecycle hooks
  protected async beforeValidation(): Promise<void> {}
  protected async afterValidation(): Promise<void> {}
  protected async beforeRun(): Promise<void> {}
  protected async afterRun(): Promise<void> {}
  protected async cleanup(): Promise<void> {}
  protected async handleError(error: Error): Promise<void> {
    this.logger.error(`Script failed: ${error.message}`);
  }

  // Validation system
  protected async validate(args: string[]): Promise<void> {
    // Collect validation rules from decorators
    const metadata = Reflect.getMetadata("validations", this) || [];

    for (const rule of metadata) {
      await this.runValidation(rule, args);
    }
  }

  private async runValidation(rule: ValidationRule, args: string[]): Promise<void> {
    switch (rule.type) {
      case "file-exists":
        await this.validateFileExists(args[rule.argIndex], rule.optional);
        break;
      case "directory-exists":
        await this.validateDirectoryExists(args[rule.argIndex], rule.optional);
        break;
      case "not-empty":
        this.validateNotEmpty(args[rule.argIndex], rule.name);
        break;
      case "custom":
        await rule.validator(args);
        break;
    }
  }

  private async validateFileExists(path: string, optional = false): Promise<void> {
    if (!path && optional) return;
    if (!path) throw new Error("File path required");

    try {
      const stat = await Deno.stat(path);
      if (!stat.isFile) throw new Error(`Not a file: ${path}`);
    } catch {
      throw new Error(`File not found: ${path}`);
    }
  }

  private async validateDirectoryExists(path: string, optional = false): Promise<void> {
    if (!path && optional) return;
    if (!path) throw new Error("Directory path required");

    try {
      const stat = await Deno.stat(path);
      if (!stat.isDirectory) throw new Error(`Not a directory: ${path}`);
    } catch {
      throw new Error(`Directory not found: ${path}`);
    }
  }

  private validateNotEmpty(value: string, fieldName: string): void {
    if (!value || value.trim() === "") {
      throw new Error(`${fieldName} cannot be empty`);
    }
  }

  // Metadata
  static getMetadata(): ScriptMetadata {
    return {
      name: this.name,
      category: Reflect.getMetadata("category", this) ?? "uncategorized",
      description: Reflect.getMetadata("description", this) ?? "",
      tags: Reflect.getMetadata("tags", this) ?? [],
    };
  }
}
```

### 2. Validation Decorators

**`core/decorators/validates.ts`**
```typescript
import "https://deno.land/x/reflect_metadata@v0.1.12/mod.ts";

export function ValidatesFileExists(argIndex: number, optional = false) {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const existingValidations = Reflect.getMetadata("validations", target) || [];
    Reflect.defineMetadata(
      "validations",
      [...existingValidations, { type: "file-exists", argIndex, optional }],
      target
    );
  };
}

export function ValidatesDirectoryExists(argIndex: number, optional = false) {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const existingValidations = Reflect.getMetadata("validations", target) || [];
    Reflect.defineMetadata(
      "validations",
      [...existingValidations, { type: "directory-exists", argIndex, optional }],
      target
    );
  };
}

export function ValidatesNotEmpty(argIndex: number, name: string) {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const existingValidations = Reflect.getMetadata("validations", target) || [];
    Reflect.defineMetadata(
      "validations",
      [...existingValidations, { type: "not-empty", argIndex, name }],
      target
    );
  };
}

export function ValidatesGitRepository() {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const existingValidations = Reflect.getMetadata("validations", target) || [];
    Reflect.defineMetadata(
      "validations",
      [...existingValidations, { type: "git-repository" }],
      target
    );
  };
}

// Custom validation
export function ValidatesWith(validator: (args: string[]) => Promise<void>) {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const existingValidations = Reflect.getMetadata("validations", target) || [];
    Reflect.defineMetadata(
      "validations",
      [...existingValidations, { type: "custom", validator }],
      target
    );
  };
}
```

### 3. Metadata Decorators

**`core/decorators/metadata.ts`**
```typescript
export function Category(category: string) {
  return function (target: any) {
    Reflect.defineMetadata("category", category, target);
  };
}

export function Description(description: string) {
  return function (target: any) {
    Reflect.defineMetadata("description", description, target);
  };
}

export function Tags(...tags: string[]) {
  return function (target: any) {
    Reflect.defineMetadata("tags", tags, target);
  };
}
```

### 4. GitService

**`services/git/GitService.ts`**
```typescript
import { exec, execCapture } from "@/utils/shell/exec.ts";

export class GitError extends Error {
  constructor(message: string, public readonly command?: string) {
    super(message);
    this.name = "GitError";
  }
}

export class NotInRepositoryError extends GitError {
  constructor() {
    super("Not in a git repository");
    this.name = "NotInRepositoryError";
  }
}

export interface GitCommitInfo {
  hash: string;
  shortHash: string;
  subject: string;
  body: string;
  author: string;
  date: Date;
}

export interface GitServiceConfig {
  workingDirectory?: string;
}

export class GitService {
  private workingDirectory: string;

  constructor(config: GitServiceConfig = {}) {
    this.workingDirectory = config.workingDirectory ?? Deno.cwd();
  }

  // Validation
  async isRepository(): Promise<boolean> {
    try {
      await this.execute("rev-parse --git-dir", { silent: true });
      return true;
    } catch {
      return false;
    }
  }

  async validateRepository(): Promise<void> {
    if (!await this.isRepository()) {
      throw new NotInRepositoryError();
    }
  }

  async commitExists(ref: string): Promise<boolean> {
    try {
      await this.execute(`rev-parse --verify ${ref}`, { silent: true });
      return true;
    } catch {
      return false;
    }
  }

  // Information retrieval
  async getCommitInfo(ref: string): Promise<GitCommitInfo> {
    const format = "%H%n%h%n%s%n%b%n%an%n%ai";
    const output = await this.execute(`log -1 --format="${format}" ${ref}`);
    const lines = output.trim().split("\n");

    return {
      hash: lines[0],
      shortHash: lines[1],
      subject: lines[2],
      body: lines.slice(3, -2).join("\n"),
      author: lines[lines.length - 2],
      date: new Date(lines[lines.length - 1]),
    };
  }

  async getCommitFiles(ref: string): Promise<string[]> {
    const output = await this.execute(`ls-tree -r --name-only ${ref}`);
    return output.trim().split("\n").filter(f => f.length > 0);
  }

  async getCurrentBranch(): Promise<string> {
    return await this.execute("rev-parse --abbrev-ref HEAD");
  }

  async getUnpushedCommits(baseBranch: string): Promise<GitCommitInfo[]> {
    const currentBranch = await this.getCurrentBranch();
    const output = await this.execute(
      `log ${baseBranch}..${currentBranch} --format="%H"`
    );

    const hashes = output.trim().split("\n").filter(h => h.length > 0);
    return await Promise.all(
      hashes.map(hash => this.getCommitInfo(hash))
    );
  }

  async isClean(): Promise<boolean> {
    const status = await this.execute("status --porcelain");
    return status.trim().length === 0;
  }

  // Operations
  async createCommit(options: {
    message: string;
    files?: string[];
    noVerify?: boolean;
  }): Promise<string> {
    const args = ["commit", `-m "${this.escapeMessage(options.message)}"`];

    if (options.noVerify) {
      args.push("--no-verify");
    }

    if (options.files && options.files.length > 0) {
      // Stage files first
      await this.execute(`add ${options.files.join(" ")}`);
    }

    await this.execute(args.join(" "));

    // Return the commit hash
    return await this.execute("rev-parse HEAD");
  }

  async createBackupBranch(name?: string): Promise<string> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const currentBranch = await this.getCurrentBranch();
    const branchName = name ?? `backup/${currentBranch}_${timestamp}`;

    await this.execute(`branch ${branchName}`);
    return branchName;
  }

  async cherryPick(commit: string, options: {
    noCommit?: boolean;
    recordOrigin?: boolean;
  } = {}): Promise<void> {
    const args = ["cherry-pick"];

    if (options.noCommit) args.push("--no-commit");
    if (options.recordOrigin) args.push("-x");

    args.push(commit);
    await this.execute(args.join(" "));
  }

  async rebase(options: {
    onto?: string;
    interactive?: boolean;
    autosquash?: boolean;
  }): Promise<void> {
    const args = ["rebase"];

    if (options.interactive) args.push("-i");
    if (options.autosquash) args.push("--autosquash");
    if (options.onto) args.push(options.onto);

    await this.execute(args.join(" "));
  }

  // Private helpers
  private async execute(command: string, options: { silent?: boolean } = {}): Promise<string> {
    try {
      const result = await execCapture(
        `git ${command}`,
        { cwd: this.workingDirectory }
      );

      if (!result.success && !options.silent) {
        throw new GitError(
          `Git command failed: ${command}\n${result.stderr}`,
          command
        );
      }

      return result.stdout.trim();
    } catch (error) {
      if (options.silent) throw error;
      throw new GitError(
        `Git execution error: ${error.message}`,
        command
      );
    }
  }

  private escapeMessage(message: string): string {
    return message.replace(/"/g, '\\"');
  }
}
```

### 5. GitScript Base Class

**`core/base/GitScript.ts`**
```typescript
import { Script } from "./Script.ts";
import { GitService } from "@/services/git/GitService.ts";
import type { ScriptConfig } from "@/core/types/script.types.ts";

export interface GitScriptConfig extends ScriptConfig {
  gitWorkingDirectory?: string;
}

export abstract class GitScript extends Script {
  protected git: GitService;

  constructor(config: GitScriptConfig = {}) {
    super(config);
    this.git = new GitService({
      workingDirectory: config.gitWorkingDirectory ?? Deno.cwd(),
    });
  }

  // Automatically validate git repository before running
  protected override async beforeValidation(): Promise<void> {
    await this.git.validateRepository();
  }

  // Helper: Get commit message with validation
  protected async getCommitMessage(options: {
    defaultMessage?: string;
    required?: boolean;
  } = {}): Promise<string> {
    let message = options.defaultMessage;

    if (!message && options.required !== false) {
      message = prompt("Enter commit message:");
    }

    if (!message && options.required !== false) {
      throw new Error("Commit message is required");
    }

    this.validateCommitMessage(message!);
    return message!;
  }

  private validateCommitMessage(message: string): void {
    if (message.length === 0) {
      throw new Error("Commit message cannot be empty");
    }

    if (message.length > 72) {
      this.logger.warn("Commit message exceeds 72 characters");
    }
  }
}
```

### 6. Example Script Implementation

**`scripts/git/commit-dir.ts`**
```typescript
#!/usr/bin/env -S deno run --allow-read --allow-write --allow-run

import { GitScript } from "@/core/base/GitScript.ts";
import { Category, Description, Tags } from "@/core/decorators/metadata.ts";
import { ValidatesDirectoryExists } from "@/core/decorators/validates.ts";
import { parse } from "https://deno.land/std@0.208.0/flags/mod.ts";

@Category("git")
@Description("Commit all files in a directory with optional message")
@Tags("git", "automation", "commit")
export class CommitDirectoryScript extends GitScript {
  @ValidatesDirectoryExists(0)
  async run(args: string[]): Promise<void> {
    const flags = parse(args, {
      string: ["message", "m"],
      boolean: ["force", "f", "no-verify"],
      alias: { m: "message", f: "force" },
    });

    const directory = flags._[0] as string;

    // Get all files in directory
    const files: string[] = [];
    for await (const entry of Deno.readDir(directory)) {
      if (entry.isFile) {
        files.push(`${directory}/${entry.name}`);
      }
    }

    this.logger.info(`Found ${files.length} files in ${directory}`);

    // Get commit message
    const message = await this.getCommitMessage({
      defaultMessage: flags.message,
      required: true,
    });

    // Create commit
    try {
      const hash = await this.git.createCommit({
        message,
        files,
        noVerify: flags["no-verify"] || flags.force,
      });

      this.logger.success(`✅ Committed ${files.length} files`);
      this.logger.info(`Commit: ${hash.substring(0, 7)}`);
    } catch (error) {
      this.logger.error(`Failed to create commit: ${error.message}`);
      throw error;
    }
  }
}

// CLI entry point
if (import.meta.main) {
  const script = new CommitDirectoryScript();
  await script.execute(Deno.args);
}
```

### 7. Interactive Selection Service

**`services/interactive/SelectionService.ts`**
```typescript
export interface SelectionOptions<T> {
  prompt?: string;
  multi?: boolean;
  formatter?: (item: T) => string;
}

type SelectionTool = "fzf" | "peco" | "selecta";

export class SelectionService {
  private availableTool?: SelectionTool;

  constructor() {
    this.detectTool();
  }

  async select<T>(items: T[], options: SelectionOptions<T> = {}): Promise<T[]> {
    const prompt = options.prompt ?? "Select items";
    const formatter = options.formatter ?? ((item: T) => String(item));

    if (!this.availableTool) {
      return await this.fallbackSelect(items, prompt, options.multi ?? false, formatter);
    }

    return await this.selectWithTool(
      this.availableTool,
      items,
      prompt,
      options.multi ?? false,
      formatter
    );
  }

  async selectOne<T>(items: T[], options: Omit<SelectionOptions<T>, "multi"> = {}): Promise<T | null> {
    const result = await this.select(items, { ...options, multi: false });
    return result[0] ?? null;
  }

  private async detectTool(): Promise<void> {
    const tools: SelectionTool[] = ["fzf", "peco", "selecta"];

    for (const tool of tools) {
      if (await this.isCommandAvailable(tool)) {
        this.availableTool = tool;
        return;
      }
    }
  }

  private async isCommandAvailable(command: string): Promise<boolean> {
    try {
      const process = new Deno.Command("which", {
        args: [command],
        stdout: "null",
        stderr: "null",
      });
      const status = await process.output();
      return status.success;
    } catch {
      return false;
    }
  }

  private async selectWithTool<T>(
    tool: SelectionTool,
    items: T[],
    prompt: string,
    multi: boolean,
    formatter: (item: T) => string
  ): Promise<T[]> {
    const formatted = items.map((item, idx) => `${formatter(item)}|${idx}`);

    const args = this.getToolArgs(tool, prompt, multi);

    const process = new Deno.Command(tool, {
      args,
      stdin: "piped",
      stdout: "piped",
    });

    const child = process.spawn();

    // Write items to stdin
    const writer = child.stdin.getWriter();
    await writer.write(new TextEncoder().encode(formatted.join("\n")));
    await writer.close();

    // Read selection from stdout
    const output = await child.output();
    const selection = new TextDecoder().decode(output.stdout).trim();

    if (!selection) return [];

    const indices = selection.split("\n").map(line => {
      const idx = line.split("|").pop();
      return parseInt(idx!, 10);
    });

    return indices.map(idx => items[idx]).filter(Boolean);
  }

  private getToolArgs(tool: SelectionTool, prompt: string, multi: boolean): string[] {
    switch (tool) {
      case "fzf":
        const args = ["--ansi", "--no-sort", "--tac", `--prompt=${prompt}: `];
        if (multi) args.push("--multi");
        return args;
      case "peco":
        return multi ? ["--prompt", prompt] : [];
      case "selecta":
        return [];
    }
  }

  private async fallbackSelect<T>(
    items: T[],
    prompt: string,
    multi: boolean,
    formatter: (item: T) => string
  ): Promise<T[]> {
    console.log(`\n${prompt}:`);
    items.forEach((item, idx) => {
      console.log(`  ${idx + 1}. ${formatter(item)}`);
    });

    const input = prompt(multi ? "Enter numbers (comma-separated):" : "Enter number:");
    if (!input) return [];

    const indices = input.split(/[,\s]+/).map(n => parseInt(n, 10) - 1);
    return indices.map(idx => items[idx]).filter(Boolean);
  }
}
```

## Configuration

### `deno.json`
```json
{
  "compilerOptions": {
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true
  },
  "imports": {
    "@/": "./",
    "@/core/": "./core/",
    "@/services/": "./services/",
    "@/utils/": "./utils/",
    "@/scripts/": "./scripts/"
  },
  "tasks": {
    "test": "deno test --allow-all",
    "fmt": "deno fmt",
    "lint": "deno lint",
    "check": "deno check **/*.ts"
  },
  "fmt": {
    "useTabs": false,
    "lineWidth": 100,
    "indentWidth": 2,
    "semiColons": true,
    "singleQuote": false,
    "proseWrap": "preserve"
  },
  "lint": {
    "rules": {
      "tags": ["recommended"],
      "include": ["ban-untagged-todo"]
    }
  }
}
```

### `import_map.json`
```json
{
  "imports": {
    "std/": "https://deno.land/std@0.208.0/",
    "zod": "https://deno.land/x/zod@v3.22.4/mod.ts",
    "cliffy/": "https://deno.land/x/cliffy@v1.0.0-rc.3/"
  }
}
```

## ZSH Integration

**Wrapper function** (`bin/scripts.zsh`):
```bash
# Deno CLI Scripts
_execute_deno_script() {
  local script_name="$1"
  local script_path="$ZSH_CONFIG/bin/deno-cli/scripts/${script_name}.ts"
  shift

  if [[ ! -f "$script_path" ]]; then
    log_error "Deno script not found: $script_name"
    return 1
  fi

  # Deno with common permissions
  deno run \
    --allow-read \
    --allow-write \
    --allow-run \
    --allow-env \
    "$script_path" "$@"
}

# Git scripts
git-commit-dir() {
  _execute_deno_script "git/commit-dir" "$@"
}

git-commit-deletes() {
  _execute_deno_script "git/commit-deletes" "$@"
}

# ... etc
```

## Advantages Over Ruby

### Type Safety
```typescript
// Compile-time error if commitInfo doesn't match interface
const info: GitCommitInfo = await git.getCommitInfo("HEAD");
console.log(info.hash);  // ✅ Autocomplete works
console.log(info.invalid); // ❌ Compile error
```

### Better IDE Support
- Full IntelliSense/autocomplete
- Inline documentation
- Refactoring tools
- Go-to-definition

### Testing
```typescript
// services/git/GitService.test.ts
import { assertEquals } from "std/testing/asserts.ts";
import { GitService } from "./GitService.ts";

Deno.test("GitService - gets current branch", async () => {
  const git = new GitService();
  const branch = await git.getCurrentBranch();
  assertEquals(typeof branch, "string");
});
```

### No Build Step
```bash
# Run directly
deno run --allow-all scripts/git/commit-dir.ts /path/to/dir

# Or with shebang
./scripts/git/commit-dir.ts /path/to/dir
```

## Migration Strategy

### Phase 1: Foundation (Week 1)
1. Set up directory structure
2. Implement base classes (Script, GitScript)
3. Create decorators (validates, metadata)
4. Build GitService with tests
5. Implement Logger and utilities

### Phase 2: High-Priority Scripts (Week 2-3)
1. Port 3 git scripts (commit-dir, commit-deletes, commit-splitter)
2. Add SelectionService
3. Port git-history (most complex)
4. Test and refine patterns

### Phase 3: Remaining Scripts (Week 4-5)
1. Xcode scripts with XcodeService
2. File utilities with FileService
3. System scripts
4. Update ZSH wrappers

### Phase 4: Polish (Week 6)
1. Comprehensive testing
2. Documentation
3. Performance optimization
4. Deprecate Ruby scripts

## Key Design Decisions

### 1. Services vs Utilities
- **Services**: Stateful, business logic (GitService, XcodeService)
- **Utilities**: Stateless, pure functions (logger, formatters)

### 2. Dependency Injection
- Constructor injection for services
- Easy to mock in tests
- Explicit dependencies

### 3. Decorators for Cross-Cutting Concerns
- Validation: `@ValidatesFileExists(0)`
- Metadata: `@Category("git")`, `@Description("...")`
- Retry logic: `@Retry({ attempts: 3 })`
- Memoization: `@Memoize()`

### 4. Async/Await Throughout
- All I/O operations are async
- Proper error handling
- Better than Ruby's blocking I/O

### 5. Permissions Model
- Explicit `--allow-*` flags
- Security by default
- Documents what each script needs

## Next Steps

1. **Review this architecture** - Does it align with your vision?
2. **Prototype** - I can implement GitService + one full script to prove the pattern
3. **Evaluate** - Compare to Ruby in practice
4. **Commit** - If satisfied, proceed with full migration

Want me to build the prototype (GitService + commit-dir script + tests) to validate this design?
