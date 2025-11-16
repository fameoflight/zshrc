# Bun + TypeScript Architecture Options V2

**Designed around your engineering rules:**
- Max 5 parameters (options objects for 3+)
- Simple over clever (boring code wins)
- Inheritance when it makes sense
- Helper methods remove friction
- One responsibility per unit

---

## Option 4: **Pragmatic Mix** ⭐ RECOMMENDED

**Philosophy**: Use the right tool for each job. Decorators for metadata, Zod for validation, inheritance for shared behavior.

### Structure

```typescript
// bin/scripts/git/commit-dir.ts
import { GitScript } from "@core/base/GitScript";
import { z } from "zod";

// Metadata decorators (read-only, declarative) - reduces boilerplate
@Category("git")
@Description("Commit files in a specific directory")
@Tags("git", "automation")
export class CommitDirectoryScript extends GitScript {
  emoji = "📁";

  // Zod for runtime validation (type-safe)
  schema = {
    args: z.tuple([z.string()]),
    options: z.object({
      message: z.string().optional(),
      noVerify: z.boolean().default(false)
    })
  };

  // Simple validation with clear error messages
  async validate(context: ScriptContext): Promise<void> {
    await super.validate(context); // Validates git repo

    const dir = context.args[0];
    if (!(await context.fs.isDirectory(dir))) {
      throw new Error(`Not a directory: ${dir}`);
    }
  }

  // Main logic - single responsibility
  async run(context: ScriptContext): Promise<void> {
    const { args, options, git, logger } = context;
    const directory = args[0];

    // Get changed files
    const files = await git.getChangedFiles({ directory });

    if (files.length === 0) {
      logger.warn(`No changes in ${directory}`);
      return;
    }

    // Show changes
    this.showChanges(files);

    // Get commit message
    const message = await this.getCommitMessage(options);

    // Confirm and commit
    if (await context.confirm("Commit these changes?")) {
      await this.commitFiles({ files, message, options, git, logger });
    }
  }

  // Helper methods - remove friction, single responsibility
  private showChanges(files: GitFile[]): void {
    this.logger.info(`Found ${files.length} changed files:`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));
  }

  private async getCommitMessage(options: CommitOptions): Promise<string> {
    if (options.message) {
      this.logger.info(`Using provided message: ${options.message}`);
      return options.message;
    }
    return this.prompt("Enter commit message:");
  }

  private async commitFiles(params: {
    files: GitFile[];
    message: string;
    options: CommitOptions;
    git: GitService;
    logger: Logger;
  }): Promise<void> {
    const { files, message, options, git, logger } = params;

    await git.stageFiles({ paths: files.map(f => f.path) });
    await git.commit({ message, noVerify: options.noVerify });

    logger.success("Changes committed!");
  }
}

// Type inference from Zod
type CommitOptions = z.infer<typeof CommitDirectoryScript.prototype.schema.options>;
```

### Base Class Architecture

```typescript
// core/base/Script.ts
export abstract class Script {
  protected logger: Logger;
  protected shell: ShellExecutor;

  abstract emoji: string;
  abstract schema: {
    args: z.ZodSchema;
    options: z.ZodSchema;
  };

  // Options object pattern - never more than 2 parameters
  constructor(deps: ScriptDependencies) {
    this.logger = deps.logger;
    this.shell = deps.shell;
  }

  // Main lifecycle - template method pattern
  async execute(params: ExecuteParams): Promise<void> {
    const context = await this.buildContext(params);

    await this.validate(context);
    await this.run(context);
  }

  // Subclasses override these
  abstract run(context: ScriptContext): Promise<void>;

  async validate(context: ScriptContext): Promise<void> {
    // Base validation - can be extended
  }

  // Helper methods - remove friction
  protected async prompt(message: string): Promise<string> {
    return this.deps.prompt.ask(message);
  }

  protected async confirm(message: string): Promise<boolean> {
    return this.deps.prompt.confirm(message);
  }

  private async buildContext(params: ExecuteParams): Promise<ScriptContext> {
    // Parse and validate with Zod
    const args = this.schema.args.parse(params.args);
    const options = this.schema.options.parse(params.options);

    return {
      args,
      options,
      ...this.deps // Inject all dependencies
    };
  }
}

// Git-specific base - single responsibility (git operations)
export abstract class GitScript extends Script {
  protected git: GitService;

  constructor(deps: GitScriptDependencies) {
    super(deps);
    this.git = deps.git;
  }

  async validate(context: ScriptContext): Promise<void> {
    await super.validate(context);
    await this.git.validateRepository();
  }
}

// Xcode-specific base
export abstract class XcodeScript extends Script {
  protected xcode: XcodeService;

  constructor(deps: XcodeScriptDependencies) {
    super(deps);
    this.xcode = deps.xcode;
  }

  async validate(context: ScriptContext): Promise<void> {
    await super.validate(context);
    await this.xcode.validateProject();
  }
}
```

### Services - Single Responsibility, Options Objects

```typescript
// core/services/GitService.ts
export class GitService {
  // Constructor: max 1-2 parameters, options object pattern
  constructor(private deps: GitServiceDeps) {}

  // All methods follow 5-parameter rule with options objects
  async getChangedFiles(params: {
    directory?: string;
    staged?: boolean;
    includeUntracked?: boolean;
  }): Promise<GitFile[]> {
    const { directory, staged, includeUntracked } = params;

    const flags = this.buildFlags({ staged, includeUntracked });
    const path = directory ? `"${directory}"` : "";

    const result = await this.deps.shell.exec(`git status --porcelain ${flags} ${path}`);
    return this.parseGitStatus(result.stdout);
  }

  async stageFiles(params: { paths: string[] }): Promise<void> {
    const { paths } = params;
    const pathList = paths.map(p => `"${p}"`).join(" ");
    await this.deps.shell.exec(`git add ${pathList}`);
  }

  async commit(params: {
    message: string;
    noVerify?: boolean;
    amend?: boolean;
    allowEmpty?: boolean;
  }): Promise<CommitInfo> {
    const { message, noVerify, amend, allowEmpty } = params;

    const flags = this.buildCommitFlags({ noVerify, amend, allowEmpty });
    await this.deps.shell.exec(`git commit -m "${message}" ${flags}`);

    return this.getCommitInfo({ ref: "HEAD" });
  }

  async getCommitInfo(params: { ref: string }): Promise<CommitInfo> {
    const { ref } = params;
    const format = "%H|%an|%ae|%s";
    const result = await this.deps.shell.exec(`git log -1 --format="${format}" ${ref}`);

    return this.parseCommitInfo(result.stdout);
  }

  // Helper methods - single responsibility
  private buildFlags(params: { staged?: boolean; includeUntracked?: boolean }): string {
    const flags: string[] = [];
    if (params.staged) flags.push("--cached");
    if (params.includeUntracked) flags.push("--untracked-files");
    return flags.join(" ");
  }

  private buildCommitFlags(params: {
    noVerify?: boolean;
    amend?: boolean;
    allowEmpty?: boolean;
  }): string {
    const flags: string[] = [];
    if (params.noVerify) flags.push("--no-verify");
    if (params.amend) flags.push("--amend");
    if (params.allowEmpty) flags.push("--allow-empty");
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
    return { path, status: this.normalizeStatus(status), staged: status[0] !== " " };
  }

  private parseCommitInfo(output: string): CommitInfo {
    const [hash, author, email, subject] = output.split("|");
    return { hash, author, email, subject };
  }

  private normalizeStatus(status: string): GitFileStatus {
    // Single responsibility - just status normalization
    // ...
  }
}
```

### Why This Works

**Follows Your Rules:**

✅ **5-Parameter Law**: Every method uses options objects
```typescript
// Never: commit(message, noVerify, amend, allowEmpty, author, date)
// Always: commit({ message, noVerify, amend, allowEmpty })
```

✅ **Simple Over Clever**: No magic, clear data flow
```typescript
// Context is explicit, dependencies injected
async run(context: ScriptContext): Promise<void> {
  const { args, options, git, logger } = context;
  // Everything is visible and clear
}
```

✅ **Helper Methods Remove Friction**:
```typescript
private showChanges(files: GitFile[]): void { }
private async getCommitMessage(options: CommitOptions): Promise<string> { }
private async commitFiles(params: CommitFileParams): Promise<void> { }
```

✅ **One Responsibility**: Each class/method does ONE thing
- `GitService` → Git operations
- `CommitDirectoryScript` → Commit directory logic
- `showChanges()` → Display changes
- `commitFiles()` → Commit workflow

✅ **DRY**: Shared behavior in base classes
- `Script` → Common lifecycle
- `GitScript` → Git validation
- `XcodeScript` → Xcode validation

✅ **Encapsulation**: Private helpers, public API
```typescript
// Public API - clean
async getChangedFiles(params: GetChangedFilesParams): Promise<GitFile[]>
async commit(params: CommitParams): Promise<CommitInfo>

// Private implementation - hidden
private buildFlags(params: BuildFlagsParams): string
private parseGitStatus(output: string): GitFile[]
```

### Adding a New Script (Effortless)

```typescript
// bin/scripts/git/commit-renames.ts
import { GitScript } from "@core/base/GitScript";
import { z } from "zod";

@Category("git")
@Description("Commit renamed files")
export class CommitRenamesScript extends GitScript {
  emoji = "📝";

  schema = {
    args: z.tuple([]), // No args
    options: z.object({
      message: z.string().optional()
    })
  };

  async run(context: ScriptContext): Promise<void> {
    const { git, logger } = context;

    const renamed = await git.getRenamedFiles();

    if (renamed.length === 0) {
      logger.warn("No renamed files");
      return;
    }

    this.showRenames(renamed);

    if (await context.confirm("Commit renames?")) {
      const message = await this.getCommitMessage(context.options);
      await this.commitRenames({ renamed, message, git, logger });
    }
  }

  private showRenames(files: GitRenamedFile[]): void {
    this.logger.info(`Found ${files.length} renames:`);
    files.forEach(f => console.log(`  ${f.oldPath} → ${f.newPath}`));
  }

  private async getCommitMessage(options: { message?: string }): Promise<string> {
    return options.message || this.prompt("Commit message:");
  }

  private async commitRenames(params: {
    renamed: GitRenamedFile[];
    message: string;
    git: GitService;
    logger: Logger;
  }): Promise<void> {
    const { renamed, message, git, logger } = params;

    await git.stageFiles({ paths: renamed.map(f => f.newPath) });
    await git.commit({ message });

    logger.success("Renames committed!");
  }
}
```

**That's it! ~40 lines.**

---

## Option 5: **Builder Pattern** (Zero Decorators)

**Philosophy**: Fluent API, no decorators, explicit everything.

### Example

```typescript
// bin/scripts/git/commit-dir.ts
import { defineGitScript } from "@core/builders/defineGitScript";
import { z } from "zod";

export const commitDirectoryScript = defineGitScript()
  .name("git-commit-dir")
  .category("git")
  .description("Commit files in a specific directory")
  .emoji("📁")
  .schema({
    args: z.tuple([z.string()]),
    options: z.object({
      message: z.string().optional()
    })
  })
  .validate(async (context) => {
    const dir = context.args[0];
    if (!(await context.fs.isDirectory(dir))) {
      throw new Error(`Not a directory: ${dir}`);
    }
  })
  .run(async (context) => {
    const { args, options, git, logger } = context;
    const directory = args[0];

    const files = await git.getChangedFiles({ directory });

    if (files.length === 0) {
      logger.warn(`No changes in ${directory}`);
      return;
    }

    logger.info(`Found ${files.length} changed files:`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));

    const message = options.message || await context.prompt("Enter commit message:");

    if (await context.confirm("Commit these changes?")) {
      await git.stageFiles({ paths: files.map(f => f.path) });
      await git.commit({ message });
      logger.success("Changes committed!");
    }
  })
  .build();
```

### Builder Implementation

```typescript
// core/builders/defineGitScript.ts
export function defineGitScript() {
  return new GitScriptBuilder();
}

class GitScriptBuilder {
  private config: Partial<GitScriptConfig> = {};

  name(value: string): this {
    this.config.name = value;
    return this;
  }

  category(value: string): this {
    this.config.category = value;
    return this;
  }

  description(value: string): this {
    this.config.description = value;
    return this;
  }

  emoji(value: string): this {
    this.config.emoji = value;
    return this;
  }

  schema(value: ScriptSchema): this {
    this.config.schema = value;
    return this;
  }

  validate(fn: ValidateFn): this {
    this.config.validate = fn;
    return this;
  }

  run(fn: RunFn): this {
    this.config.run = fn;
    return this;
  }

  build(): GitScriptDefinition {
    // Validate all required fields are present
    if (!this.config.name || !this.config.run) {
      throw new Error("name and run are required");
    }

    return new GitScriptDefinition(this.config as GitScriptConfig);
  }
}
```

**Pros:**
- ✅ No decorators (stable TypeScript)
- ✅ Very explicit (clear what's being defined)
- ✅ Fluent API (nice to write)
- ✅ Type-safe (builder enforces structure)
- ✅ Follows all rules (options objects, single responsibility)

**Cons:**
- ⚠️ More verbose than decorators
- ⚠️ Manual registration still needed
- ⚠️ Less OOP (harder to share methods via inheritance)

---

## Option 6: **Minimal Magic** (Boring is Good)

**Philosophy**: Zero decorators, zero magic. Just classes, Zod, and explicit registration.

### Example

```typescript
// bin/scripts/git/commit-dir.ts
import { GitScript } from "@core/base/GitScript";
import { z } from "zod";

export class CommitDirectoryScript extends GitScript {
  // Metadata (plain properties)
  readonly name = "git-commit-dir";
  readonly category = "git";
  readonly description = "Commit files in a specific directory";
  readonly emoji = "📁";
  readonly tags = ["git", "automation"];

  // Zod schemas
  readonly argsSchema = z.tuple([z.string()]);
  readonly optionsSchema = z.object({
    message: z.string().optional(),
    noVerify: z.boolean().default(false)
  });

  // Validation
  async validate(context: ScriptContext): Promise<void> {
    await super.validate(context); // Git repo check

    const dir = context.args[0];
    if (!(await context.fs.isDirectory(dir))) {
      throw new Error(`Not a directory: ${dir}`);
    }
  }

  // Main logic
  async run(context: ScriptContext): Promise<void> {
    const { args, options, git, logger } = context;
    const directory = args[0];

    const files = await git.getChangedFiles({ directory });

    if (files.length === 0) {
      logger.warn(`No changes in ${directory}`);
      return;
    }

    this.showChanges(files);

    const message = await this.getCommitMessage(options);

    if (await context.confirm("Commit these changes?")) {
      await this.commitFiles({ files, message, options, git, logger });
    }
  }

  // Helpers
  private showChanges(files: GitFile[]): void {
    this.logger.info(`Found ${files.length} changed files:`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));
  }

  private async getCommitMessage(options: CommitOptions): Promise<string> {
    if (options.message) {
      this.logger.info(`Using provided message: ${options.message}`);
      return options.message;
    }
    return this.prompt("Enter commit message:");
  }

  private async commitFiles(params: {
    files: GitFile[];
    message: string;
    options: CommitOptions;
    git: GitService;
    logger: Logger;
  }): Promise<void> {
    const { files, message, options, git, logger } = params;

    await git.stageFiles({ paths: files.map(f => f.path) });
    await git.commit({ message, noVerify: options.noVerify });

    logger.success("Changes committed!");
  }
}
```

### Registration (Explicit)

```typescript
// bin/registry.ts
import { CommitDirectoryScript } from "@scripts/git/commit-dir";
import { CommitDeletesScript } from "@scripts/git/commit-deletes";
import { LargestFilesScript } from "@scripts/system/largest-files";

export const SCRIPTS = [
  CommitDirectoryScript,
  CommitDeletesScript,
  LargestFilesScript,
  // Add new scripts here - one line each
];
```

**Pros:**
- ✅ Zero magic (easiest to understand)
- ✅ Zero experimental features
- ✅ Explicit registration (clear what's available)
- ✅ Full OOP benefits (inheritance works naturally)
- ✅ Follows all rules perfectly

**Cons:**
- ⚠️ Manual registration (must add to registry)
- ⚠️ More boilerplate for metadata (but explicit)
- ⚠️ No auto-discovery

---

## Comparison: Following Your Rules

| Rule | Option 4 (Pragmatic) | Option 5 (Builder) | Option 6 (Minimal) |
|------|---------------------|-------------------|-------------------|
| **5-Parameter Law** | ✅ Options everywhere | ✅ Options everywhere | ✅ Options everywhere |
| **Simple Over Clever** | ⭐⭐⭐⭐ (Decorators = mild magic) | ⭐⭐⭐⭐⭐ (Very explicit) | ⭐⭐⭐⭐⭐ (Zero magic) |
| **Helper Methods** | ✅ Encouraged | ⚠️ Harder (no class) | ✅ Natural (OOP) |
| **Base Classes** | ✅ Natural inheritance | ⚠️ Composition only | ✅ Natural inheritance |
| **DRY** | ✅ Base classes + helpers | ⚠️ Must extract manually | ✅ Base classes + helpers |
| **One Responsibility** | ✅ Enforced | ✅ Enforced | ✅ Enforced |
| **Small Functions** | ✅ <50 lines each | ✅ <50 lines each | ✅ <50 lines each |
| **Encapsulation** | ✅ Private methods | ⚠️ Harder | ✅ Private methods |
| **Lines per Script** | ~45 | ~40 | ~50 |
| **Boring Code** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## Detailed Rule Compliance

### 5-Parameter Law (ALL OPTIONS)

```typescript
// ✅ GOOD - Options object
async commit(params: {
  message: string;
  noVerify?: boolean;
  amend?: boolean;
  allowEmpty?: boolean;
}): Promise<CommitInfo>

// ❌ BAD - Too many parameters
async commit(
  message: string,
  noVerify: boolean,
  amend: boolean,
  allowEmpty: boolean,
  author?: string,
  date?: string
): Promise<CommitInfo>
```

### Helper Methods (ALL OPTIONS)

```typescript
// Main method uses helpers - single responsibility each
async run(context: ScriptContext): Promise<void> {
  const files = await this.getFiles(context);
  this.showFiles(files);
  const message = await this.getMessage(context);
  await this.commitFiles({ files, message, context });
}

// Each helper: <10 lines, one thing
private showFiles(files: GitFile[]): void {
  this.logger.info(`Found ${files.length} files:`);
  files.forEach(f => console.log(`  ${f.status} ${f.path}`));
}

private async getMessage(context: ScriptContext): Promise<string> {
  return context.options.message || this.prompt("Enter message:");
}
```

### Base Classes (Options 4 & 6)

```typescript
// Script - Universal base (logging, prompts, lifecycle)
// GitScript extends Script - Adds git validation + git service
// XcodeScript extends Script - Adds xcode validation + xcode service

// Each base class: Single responsibility, <50 lines
```

---

## My Recommendation: **Option 4 (Pragmatic Mix)**

### Why It's the Best for Your Rules

1. **Follows 5-Parameter Law**: Every method uses options objects
2. **Simple Over Clever**: Decorators only for metadata (not behavior)
3. **Helper Methods Natural**: Private methods in classes
4. **Base Classes Work**: Inheritance for shared behavior (DRY)
5. **Small Functions**: Each method <50 lines, single responsibility
6. **Encapsulation**: Private implementation, clean public API
7. **Boring Where It Counts**: Business logic is plain TypeScript
8. **Magic Only Where It Helps**: Auto-discovery via decorators

### The "Feels Effortless" Factor

**Adding a new script:**
```typescript
@Category("git")
@Description("Commit renames")
export class CommitRenamesScript extends GitScript {
  emoji = "📝";
  schema = { args: z.tuple([]), options: z.object({}) };

  async run(context: ScriptContext): Promise<void> {
    // Just your business logic
    // Base class handles: git validation, logging, prompts
    // Decorators handle: registration, categorization
    // Zod handles: runtime validation
  }
}
```

**That's it. No registration. No boilerplate. Just logic.**

### What Makes It "Pragmatic"

- Decorators for metadata: Reduces boilerplate, doesn't affect logic
- Zod for validation: Runtime safety, great errors
- Inheritance for behavior: DRY, natural code reuse
- Options objects: Future-proof, clear intent
- Private helpers: Clean up main logic

---

## Example: Complete Script Comparison

### Option 4 (Pragmatic)
```typescript
@Category("git")
@Description("Commit directory")
export class CommitDirScript extends GitScript {
  emoji = "📁";
  schema = {
    args: z.tuple([z.string()]),
    options: z.object({ message: z.string().optional() })
  };

  async run(context: ScriptContext): Promise<void> {
    const files = await this.getFiles(context);
    if (files.length === 0) return this.noChanges();

    this.showFiles(files);
    const message = await this.getMessage(context);
    await this.commit({ files, message, context });
  }

  private async getFiles(ctx: ScriptContext) {
    return ctx.git.getChangedFiles({ directory: ctx.args[0] });
  }

  private showFiles(files: GitFile[]) {
    this.logger.info(`${files.length} files changed`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));
  }

  private async getMessage(ctx: ScriptContext) {
    return ctx.options.message || this.prompt("Message:");
  }

  private async commit(params: CommitParams) {
    const { files, message, context } = params;
    await context.git.stageFiles({ paths: files.map(f => f.path) });
    await context.git.commit({ message });
    this.logger.success("Committed!");
  }

  private noChanges() {
    this.logger.warn("No changes");
  }
}
```

**Lines: 35 | Boilerplate: 5 lines | Business logic: 30 lines**

---

## Next Steps

**Choose your path:**

A) **Option 4 (Pragmatic)** - Decorators + Zod + Inheritance
   - Best balance of brevity and clarity
   - Follows all your rules
   - "Feels effortless"

B) **Option 6 (Minimal)** - Zero magic, explicit everything
   - Maximum boring code (good thing!)
   - No decorators, just classes
   - Manual registration

C) **Build prototype** - See real code for both options

D) **Custom mix** - Tell me what you'd change

**What feels right to you?**
