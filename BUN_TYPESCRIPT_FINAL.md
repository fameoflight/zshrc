# Bun + TypeScript Architecture - FINAL

**Design Principles:**
- ✅ Static metadata in JSDoc comments (readable, no runtime cost)
- ✅ Decorators ONLY for syntactic sugar (no complex logic)
- ✅ Auto-discovery via file system (no registry BS)
- ✅ Colocation (everything defined with the script)
- ✅ Good conventions (automate what can be automated)
- ✅ Follows all engineering rules (5-param law, options objects, helpers)

---

## Architecture Overview

### Convention-Based Structure

```
src/
├── scripts/                    # Auto-discovered by directory traversal
│   ├── git/                   # Category = "git" (from directory)
│   │   ├── commit-dir.ts      # Command = "commit-dir" (from filename)
│   │   ├── commit-deletes.ts  # Command = "commit-deletes"
│   │   └── smart-rebase.ts
│   ├── xcode/                 # Category = "xcode"
│   │   ├── icon-generator.ts
│   │   └── add-file.ts
│   └── system/                # Category = "system"
│       ├── largest-files.ts
│       └── game-mode.ts
├── core/
│   ├── base/
│   │   ├── Script.ts          # Base class
│   │   ├── GitScript.ts       # Git-specific base
│   │   └── XcodeScript.ts     # Xcode-specific base
│   ├── decorators/
│   │   └── Argument.ts        # @Argument decorator (sugar only)
│   ├── services/
│   │   ├── GitService.ts
│   │   └── XcodeService.ts
│   └── utils/
│       ├── logger.ts
│       └── shell.ts
└── cli.ts                     # Auto-discovers scripts from src/scripts/
```

**Conventions (Auto-detected):**
- **Category**: Directory name (`git/`, `xcode/`, `system/`)
- **Command**: Filename (`commit-dir.ts` → `commit-dir`)
- **Registration**: Automatic (traverse `src/scripts/**/*.ts`)

---

## Complete Example Script

```typescript
// src/scripts/git/commit-dir.ts

// @description: Commit files in a specific directory
// @emoji: 📁
// @tags: git, automation, commit
//
// Stages and commits all changes within a specified directory,
// with optional custom commit message.
//
// Examples:
//   commit-dir src
//   commit-dir src -m "Update source files"
//   commit-dir . --no-verify

export class CommitDirectoryScript extends GitScript {
  /**
   * Directory to commit
   */
  @Argument({
    type: String,
    position: 0,
    required: true,
    description: "Directory to stage and commit changes from",
    validate: async (value, ctx) => {
      if (!await ctx.fs.isDirectory(value)) {
        throw new Error(`Not a directory: ${value}`);
      }
    }
  })
  directory!: string;

  /**
   * Commit message
   */
  @Argument({
    type: String,
    flag: "-m, --message",
    required: false,
    description: "Commit message (prompts if not provided)",
  })
  message?: string;

  /**
   * Skip pre-commit hooks
   */
  @Argument({
    type: Boolean,
    flag: "--no-verify",
    required: false,
    defaultValue: false,
    description: "Skip pre-commit hooks"
  })
  noVerify!: boolean;

  /**
   * Main execution logic
   */
  async run(context: ScriptContext): Promise<void> {
    const files = await this.getChangedFiles(context);

    if (files.length === 0) {
      return this.handleNoChanges();
    }

    this.displayChanges(files);

    const message = await this.getCommitMessage(context);

    if (await context.confirm("Commit these changes?")) {
      await this.performCommit({ files, message, context });
    }
  }

  /**
   * Get changed files in directory
   */
  private async getChangedFiles(context: ScriptContext): Promise<GitFile[]> {
    return context.git.getChangedFiles({
      directory: this.directory
    });
  }

  /**
   * Display changed files to user
   */
  private displayChanges(files: GitFile[]): void {
    this.logger.info(`Found ${files.length} changed files in ${this.directory}:`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));
  }

  /**
   * Get commit message (from flag or prompt)
   */
  private async getCommitMessage(context: ScriptContext): Promise<string> {
    if (this.message) {
      this.logger.info(`Using provided message: ${this.message}`);
      return this.message;
    }

    return context.prompt({
      message: "Enter commit message:",
      default: `Update ${this.directory}`
    });
  }

  /**
   * Perform the commit operation
   */
  private async performCommit(params: {
    files: GitFile[];
    message: string;
    context: ScriptContext;
  }): Promise<void> {
    const { files, message, context } = params;

    await context.git.stageFiles({
      paths: files.map(f => f.path)
    });

    await context.git.commit({
      message,
      noVerify: this.noVerify
    });

    this.logger.success(`Committed ${files.length} files!`);
  }

  /**
   * Handle case with no changes
   */
  private handleNoChanges(): void {
    this.logger.warn(`No changes in ${this.directory}`);
  }
}
```

**That's it! No registration, no imports, just the script.**

---

## The @Argument Decorator (Sugar Only)

```typescript
// src/core/decorators/Argument.ts

/**
 * Argument decorator - syntactic sugar for argument metadata
 *
 * Metadata is stored statically, extracted at build time.
 * NO complex runtime logic - just metadata storage.
 */
export interface ArgumentOptions {
  // Type information
  type: StringConstructor | NumberConstructor | BooleanConstructor | ArrayConstructor;

  // Position (for positional args)
  position?: number;

  // Flag (for named options)
  flag?: string; // e.g., "-m, --message"

  // Validation
  required?: boolean;
  defaultValue?: any;

  // Constraints (optional)
  min?: number;        // For Number/Array types
  max?: number;        // For Number/Array types
  choices?: string[];  // For String types
  pattern?: RegExp;    // For String types

  // Documentation
  description: string;

  // Custom validation (simple function, no complex logic)
  validate?: (value: any, context: ScriptContext) => Promise<void> | void;
}

/**
 * Decorator implementation - JUST stores metadata
 */
export function Argument(options: ArgumentOptions) {
  return function (target: any, propertyKey: string) {
    // Store metadata on the class (static, no runtime logic)
    if (!target.constructor.__arguments) {
      target.constructor.__arguments = new Map();
    }

    target.constructor.__arguments.set(propertyKey, {
      propertyName: propertyKey,
      ...options
    });
  };
}
```

**Why this works:**
- ✅ **Syntactic sugar only** - Just stores metadata
- ✅ **No complex logic** - Metadata extraction happens at parse time
- ✅ **Colocation** - Arguments defined with the script
- ✅ **Type-safe** - TypeScript checks the decorator usage
- ✅ **Self-documenting** - Clear what each argument does

---

## Auto-Discovery System

```typescript
// src/cli.ts

import { discoverScripts } from "./core/discovery";
import { createCLI } from "./core/cli";

/**
 * Auto-discover all scripts from src/scripts/
 *
 * Convention:
 * - Directory name = category (git/, xcode/, system/)
 * - Filename = command name (commit-dir.ts → commit-dir)
 * - Class extending Script = script implementation
 */
async function main() {
  // Traverse src/scripts/ and find all Script classes
  const scripts = await discoverScripts({
    baseDir: "./src/scripts",
    pattern: "**/*.ts"
  });

  // Create CLI with discovered scripts
  const cli = createCLI({ scripts });

  // Run
  await cli.run(process.argv.slice(2));
}

main().catch(console.error);
```

```typescript
// src/core/discovery.ts

import { glob } from "glob";
import path from "path";

/**
 * Discover scripts via file system traversal
 *
 * NO REGISTRY - just scan the directory
 */
export async function discoverScripts(params: {
  baseDir: string;
  pattern: string;
}): Promise<ScriptDefinition[]> {
  const { baseDir, pattern } = params;

  // Find all TypeScript files
  const files = await glob(pattern, { cwd: baseDir });

  const scripts: ScriptDefinition[] = [];

  for (const file of files) {
    const fullPath = path.join(baseDir, file);

    // Import the module
    const module = await import(fullPath);

    // Find classes extending Script
    for (const [exportName, exportValue] of Object.entries(module)) {
      if (isScriptClass(exportValue)) {
        // Extract metadata from the class
        const definition = extractScriptMetadata({
          scriptClass: exportValue as any,
          filePath: file
        });

        scripts.push(definition);
      }
    }
  }

  return scripts;
}

/**
 * Check if a class extends Script
 */
function isScriptClass(value: any): boolean {
  if (typeof value !== "function") return false;

  let proto = value.prototype;
  while (proto) {
    if (proto.constructor.name === "Script") return true;
    proto = Object.getPrototypeOf(proto);
  }

  return false;
}

/**
 * Extract metadata from script class
 *
 * Convention-based extraction:
 * - Category: from directory (src/scripts/git/foo.ts → "git")
 * - Command: from filename (commit-dir.ts → "commit-dir")
 * - Description: from JSDoc comment
 * - Arguments: from @Argument decorators
 */
function extractScriptMetadata(params: {
  scriptClass: ScriptClass;
  filePath: string;
}): ScriptDefinition {
  const { scriptClass, filePath } = params;

  // Extract category from directory
  // src/scripts/git/commit-dir.ts → "git"
  const category = path.dirname(filePath).split(path.sep).pop() || "general";

  // Extract command from filename
  // commit-dir.ts → "commit-dir"
  const command = path.basename(filePath, ".ts");

  // Extract JSDoc metadata
  const jsDocMetadata = extractJSDocMetadata(scriptClass);

  // Extract @Argument metadata
  const arguments = extractArgumentMetadata(scriptClass);

  return {
    category,
    command,
    description: jsDocMetadata.description,
    emoji: jsDocMetadata.emoji,
    tags: jsDocMetadata.tags,
    examples: jsDocMetadata.examples,
    arguments,
    scriptClass
  };
}

/**
 * Extract metadata from simple comment syntax
 *
 * Parses comments like:
 *   // @description: My script description
 *   // @emoji: 🔧
 *   // @tags: tag1, tag2, tag3
 */
function extractCommentMetadata(scriptClass: ScriptClass): CommentMetadata {
  // Read the source file (simple text parsing)
  const sourceFile = readSourceFile(scriptClass);

  // Parse // @key: value comments
  const description = extractCommentTag(sourceFile, "description") || "";
  const emoji = extractCommentTag(sourceFile, "emoji") || "🔧";
  const tags = extractCommentTag(sourceFile, "tags")?.split(",").map(t => t.trim()) || [];

  return { description, emoji, tags };
}

/**
 * Extract a comment tag value
 *
 * Pattern: // @tagName: value
 */
function extractCommentTag(source: string, tagName: string): string | null {
  const pattern = new RegExp(`// @${tagName}:\\s*(.+)$`, "m");
  const match = source.match(pattern);
  return match ? match[1].trim() : null;
}

/**
 * Extract @Argument metadata from class
 */
function extractArgumentMetadata(scriptClass: ScriptClass): ArgumentMetadata[] {
  // Metadata stored by @Argument decorator
  const argumentsMap = (scriptClass as any).__arguments;

  if (!argumentsMap) return [];

  return Array.from(argumentsMap.values());
}
```

**Why auto-discovery works:**
- ✅ **Convention over configuration** - No manual registry
- ✅ **File system = source of truth** - Just add a file
- ✅ **Automatic categorization** - Directory name = category
- ✅ **Zero registration** - Drop file in `src/scripts/git/`, it appears in CLI

---

## Base Classes

```typescript
// src/core/base/Script.ts

/**
 * Base class for all scripts
 *
 * Provides:
 * - Lifecycle management
 * - Dependency injection
 * - Helper methods
 */
export abstract class Script {
  protected logger: Logger;
  protected shell: ShellExecutor;
  protected fs: FileSystem;

  /**
   * Constructor - dependencies injected
   * Max 1 parameter (options object)
   */
  constructor(protected deps: ScriptDependencies) {
    this.logger = deps.logger;
    this.shell = deps.shell;
    this.fs = deps.fs;
  }

  /**
   * Main execution - override in subclass
   */
  abstract run(context: ScriptContext): Promise<void>;

  /**
   * Validation - override to add custom validation
   */
  async validate(context: ScriptContext): Promise<void> {
    // Base validation (if any)
  }

  /**
   * Helper: Prompt user for input
   */
  protected async prompt(params: {
    message: string;
    default?: string;
    type?: "text" | "password" | "number";
  }): Promise<string> {
    return this.deps.prompt.ask(params);
  }

  /**
   * Helper: Confirm action
   */
  protected async confirm(message: string): Promise<boolean> {
    return this.deps.prompt.confirm({ message });
  }

  /**
   * Helper: Select from list
   */
  protected async select<T>(params: {
    message: string;
    choices: T[];
    display?: (item: T) => string;
  }): Promise<T> {
    return this.deps.selection.selectOne(params);
  }
}
```

```typescript
// src/core/base/GitScript.ts

/**
 * Base class for git-related scripts
 *
 * Provides:
 * - Git repository validation
 * - GitService injection
 */
export abstract class GitScript extends Script {
  protected git: GitService;

  constructor(deps: GitScriptDependencies) {
    super(deps);
    this.git = deps.git;
  }

  /**
   * Validate git repository exists
   */
  async validate(context: ScriptContext): Promise<void> {
    await super.validate(context);
    await this.git.validateRepository();
  }
}
```

---

## Services (Following 5-Parameter Law)

```typescript
// src/core/services/GitService.ts

/**
 * Git operations service
 *
 * All methods follow the 5-parameter law:
 * - Max 2 direct parameters
 * - Options object for 3+ parameters
 */
export class GitService {
  constructor(private deps: GitServiceDeps) {}

  /**
   * Get changed files
   *
   * @param params Options object (follows 5-param law)
   */
  async getChangedFiles(params: {
    directory?: string;
    staged?: boolean;
    includeUntracked?: boolean;
  }): Promise<GitFile[]> {
    const { directory, staged, includeUntracked } = params;

    const flags = this.buildStatusFlags({ staged, includeUntracked });
    const path = directory ? `"${directory}"` : "";

    const result = await this.deps.shell.exec({
      command: `git status --porcelain ${flags} ${path}`,
      silent: true
    });

    return this.parseGitStatus(result.stdout);
  }

  /**
   * Stage files
   *
   * @param params Options object
   */
  async stageFiles(params: {
    paths: string[];
  }): Promise<void> {
    const { paths } = params;

    const pathList = paths.map(p => `"${p}"`).join(" ");

    await this.deps.shell.exec({
      command: `git add ${pathList}`,
      description: `Staging ${paths.length} files`
    });
  }

  /**
   * Create commit
   *
   * @param params Options object (extensible)
   */
  async commit(params: {
    message: string;
    noVerify?: boolean;
    amend?: boolean;
    allowEmpty?: boolean;
    author?: string;
  }): Promise<CommitInfo> {
    const { message, noVerify, amend, allowEmpty, author } = params;

    const flags = this.buildCommitFlags({
      noVerify,
      amend,
      allowEmpty,
      author
    });

    await this.deps.shell.exec({
      command: `git commit -m "${message}" ${flags}`,
      description: "Creating commit"
    });

    return this.getCommitInfo({ ref: "HEAD" });
  }

  /**
   * Get commit information
   *
   * @param params Options object
   */
  async getCommitInfo(params: {
    ref: string;
  }): Promise<CommitInfo> {
    const { ref } = params;

    const format = "%H|%an|%ae|%s|%ct";
    const result = await this.deps.shell.exec({
      command: `git log -1 --format="${format}" ${ref}`,
      silent: true
    });

    return this.parseCommitInfo(result.stdout);
  }

  /**
   * Validate repository exists
   */
  async validateRepository(): Promise<void> {
    const result = await this.deps.shell.exec({
      command: "git rev-parse --git-dir",
      silent: true
    });

    if (!result.success) {
      throw new Error("Not in a git repository");
    }
  }

  // ===================================================================
  // Private helpers - single responsibility, <20 lines each
  // ===================================================================

  private buildStatusFlags(params: {
    staged?: boolean;
    includeUntracked?: boolean;
  }): string {
    const flags: string[] = [];

    if (params.staged) {
      flags.push("--cached");
    }

    if (params.includeUntracked) {
      flags.push("--untracked-files");
    }

    return flags.join(" ");
  }

  private buildCommitFlags(params: {
    noVerify?: boolean;
    amend?: boolean;
    allowEmpty?: boolean;
    author?: string;
  }): string {
    const flags: string[] = [];

    if (params.noVerify) flags.push("--no-verify");
    if (params.amend) flags.push("--amend");
    if (params.allowEmpty) flags.push("--allow-empty");
    if (params.author) flags.push(`--author="${params.author}"`);

    return flags.join(" ");
  }

  private parseGitStatus(output: string): GitFile[] {
    return output
      .split("\n")
      .filter(Boolean)
      .map(line => this.parseGitStatusLine(line));
  }

  private parseGitStatusLine(line: string): GitFile {
    const status = line.substring(0, 2);
    const path = line.substring(3);

    return {
      path,
      status: this.normalizeStatus(status),
      staged: status[0] !== " " && status[0] !== "?"
    };
  }

  private parseCommitInfo(output: string): CommitInfo {
    const [hash, author, email, subject, timestamp] = output.split("|");

    return {
      hash,
      author,
      email,
      subject,
      date: new Date(parseInt(timestamp) * 1000)
    };
  }

  private normalizeStatus(status: string): GitFileStatus {
    const statusMap: Record<string, GitFileStatus> = {
      "M ": "modified",
      " M": "modified",
      "MM": "modified",
      "A ": "added",
      " A": "added",
      "D ": "deleted",
      " D": "deleted",
      "R ": "renamed",
      " R": "renamed",
      "C ": "copied",
      " C": "copied",
      "??": "untracked"
    };

    return statusMap[status] || "unknown";
  }
}
```

---

## Example: Another Script (Largest Files)

```typescript
// src/scripts/system/largest-files.ts

// @description: Find largest files in directory
// @emoji: 📊
// @tags: files, analysis, disk
//
// Scans directory and finds largest files by size or line count,
// respecting .gitignore patterns.
//
// Examples:
//   largest-files
//   largest-files --count 50
//   largest-files --sort-by size --min-size 1M
//   largest-files src --sort-by lines

export class LargestFilesScript extends Script {
  /**
   * Directory to scan
   */
  @Argument({
    type: String,
    position: 0,
    required: false,
    defaultValue: ".",
    description: "Directory to scan (default: current directory)"
  })
  directory!: string;

  /**
   * Number of files to show
   */
  @Argument({
    type: Number,
    flag: "-n, --count",
    required: false,
    defaultValue: 20,
    min: 1,
    max: 1000,
    description: "Number of files to show"
  })
  count!: number;

  /**
   * Sort by size or lines
   */
  @Argument({
    type: String,
    flag: "-s, --sort-by",
    required: false,
    defaultValue: "lines",
    choices: ["size", "lines"],
    description: "Sort by file size or line count"
  })
  sortBy!: "size" | "lines";

  /**
   * Minimum file size
   */
  @Argument({
    type: String,
    flag: "--min-size",
    required: false,
    description: "Minimum file size (e.g., 1M, 100K)"
  })
  minSize?: string;

  /**
   * Include hidden files
   */
  @Argument({
    type: Boolean,
    flag: "--hidden",
    required: false,
    defaultValue: false,
    description: "Include hidden files and directories"
  })
  includeHidden!: boolean;

  async run(context: ScriptContext): Promise<void> {
    this.logger.banner("Finding Largest Files");

    this.displayConfiguration();

    const files = await this.scanFiles();

    const analyzed = await this.analyzeFiles({ files, context });

    const filtered = this.filterAndSort(analyzed);

    this.displayResults(filtered);
  }

  private displayConfiguration(): void {
    this.logger.info(`Directory: ${this.directory}`);
    this.logger.info(`Showing top ${this.count} files`);
    this.logger.info(`Sorting by: ${this.sortBy}`);

    if (this.minSize) {
      this.logger.info(`Minimum size: ${this.minSize}`);
    }
  }

  private async scanFiles(): Promise<string[]> {
    this.logger.progress("Scanning for files...");

    const patterns = this.buildScanPatterns();

    return this.fs.glob({
      pattern: patterns,
      cwd: this.directory,
      ignore: this.buildIgnorePatterns()
    });
  }

  private async analyzeFiles(params: {
    files: string[];
    context: ScriptContext;
  }): Promise<FileAnalysis[]> {
    const { files } = params;

    this.logger.progress(`Analyzing ${files.length} files...`);

    if (this.sortBy === "size") {
      return this.analyzeBySize(files);
    } else {
      return this.analyzeByLines(files);
    }
  }

  private filterAndSort(files: FileAnalysis[]): FileAnalysis[] {
    let filtered = files;

    if (this.minSize) {
      const minBytes = this.parseSize(this.minSize);
      filtered = filtered.filter(f => f.size >= minBytes);
    }

    return filtered
      .sort((a, b) => b.metric - a.metric)
      .slice(0, this.count);
  }

  private displayResults(files: FileAnalysis[]): void {
    if (files.length === 0) {
      this.logger.warn("No files found matching criteria");
      return;
    }

    this.logger.success(`Found ${files.length} files:\n`);

    files.forEach((file, i) => {
      const metric = this.sortBy === "size"
        ? this.formatSize(file.metric)
        : `${file.metric} lines`;

      console.log(`${i + 1}. ${file.path} - ${metric}`);
    });
  }

  // ===================================================================
  // Private helpers
  // ===================================================================

  private buildScanPatterns(): string {
    return this.includeHidden ? "**/*" : "**/*";
  }

  private buildIgnorePatterns(): string[] {
    const patterns = ["**/node_modules/**", "**/.git/**"];

    if (!this.includeHidden) {
      patterns.push("**/.*/**");
    }

    return patterns;
  }

  private async analyzeBySize(files: string[]): Promise<FileAnalysis[]> {
    const results: FileAnalysis[] = [];

    for (const file of files) {
      const stats = await this.fs.stat(file);
      results.push({
        path: file,
        size: stats.size,
        metric: stats.size
      });
    }

    return results;
  }

  private async analyzeByLines(files: string[]): Promise<FileAnalysis[]> {
    const results: FileAnalysis[] = [];

    for (const file of files) {
      const content = await this.fs.readFile(file);
      const lines = content.split("\n").length;
      const stats = await this.fs.stat(file);

      results.push({
        path: file,
        size: stats.size,
        metric: lines
      });
    }

    return results;
  }

  private parseSize(sizeStr: string): number {
    const units: Record<string, number> = {
      B: 1,
      K: 1024,
      M: 1024 * 1024,
      G: 1024 * 1024 * 1024
    };

    const match = sizeStr.match(/^(\d+)([BKMG])?$/i);

    if (!match) {
      throw new Error(`Invalid size format: ${sizeStr}`);
    }

    const value = parseInt(match[1]);
    const unit = (match[2] || "B").toUpperCase();

    return value * units[unit];
  }

  private formatSize(bytes: number): string {
    const units = ["B", "KB", "MB", "GB"];
    let size = bytes;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return `${size.toFixed(2)} ${units[unitIndex]}`;
  }
}
```

---

## CLI Usage

```bash
# All commands auto-discovered from src/scripts/

# Git commands (from src/scripts/git/)
zsh-utils git-commit-dir src -m "Update source"
zsh-utils git-commit-deletes
zsh-utils git-smart-rebase main

# Xcode commands (from src/scripts/xcode/)
zsh-utils xcode-icon-generator icon.png
zsh-utils xcode-add-file NewFile.swift

# System commands (from src/scripts/system/)
zsh-utils largest-files --count 50 --sort-by size
zsh-utils game-mode enable

# Help is auto-generated from JSDoc and @Argument metadata
zsh-utils git-commit-dir --help
```

---

## Build & Compilation

```json
// package.json
{
  "name": "zsh-utils",
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run src/cli.ts",
    "build": "bun build src/cli.ts --compile --outfile dist/zsh-utils",
    "build:release": "bun build src/cli.ts --compile --minify --outfile dist/zsh-utils",
    "test": "bun test",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "zod": "^3.22.4",
    "glob": "^10.3.10"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.3.3"
  }
}
```

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "types": ["bun-types"],
    "lib": ["ESNext"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

---

## Key Features

### 1. Auto-Discovery (No Registry)

✅ **Add script → It appears in CLI**

```bash
# Create new script
touch src/scripts/git/commit-renames.ts

# Implement CommitRenamesScript class

# That's it! Command is now available:
zsh-utils git-commit-renames
```

### 2. Convention-Based

✅ **File system = source of truth**

- Directory → Category
- Filename → Command
- Class → Implementation
- JSDoc → Documentation
- @Argument → CLI parsing

### 3. Colocation

✅ **Everything in one place**

```typescript
/**
 * Script documentation here
 * @category git
 * @emoji 📁
 */
export class MyScript extends GitScript {
  @Argument({ /* argument config */ })
  myArg!: string;

  async run() {
    // Implementation
  }

  // Helpers
  private helper() {}
}
```

### 4. Follows All Engineering Rules

✅ **5-Parameter Law**
- All methods use options objects
- Max 2 direct parameters

✅ **Helper Methods**
- Private methods for clarity
- Single responsibility
- <20 lines each

✅ **Base Classes**
- Script → Universal base
- GitScript → Git operations
- XcodeScript → Xcode operations

✅ **Simple Over Clever**
- Decorators only for metadata
- No complex runtime logic
- Boring code wins

---

## Summary: What You Get

**Adding a new script:**

1. Create file in `src/scripts/category/command-name.ts`
2. Add JSDoc comment with metadata
3. Define class extending appropriate base
4. Add @Argument decorators for CLI arguments
5. Implement `run()` method with helpers

**That's it. No registration. No imports. Just works.**

**What's automated:**
- ✅ Script discovery (file system traversal)
- ✅ Category extraction (from directory)
- ✅ Command extraction (from filename)
- ✅ CLI parsing (from @Argument decorators)
- ✅ Help generation (from JSDoc + @Argument)
- ✅ Validation (from @Argument options)

**What's explicit:**
- ✅ Business logic (in run() method)
- ✅ Helper methods (private methods)
- ✅ Validation logic (in @Argument.validate)
- ✅ Dependencies (via base class)

---

## Next Steps

1. **Build prototype?** - See real working code
2. **Refine something?** - Adjust any part
3. **Start implementation?** - Begin Phase 1

**Does this match your vision?**
