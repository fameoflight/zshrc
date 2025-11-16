# Bun + TypeScript Migration Architecture Proposal

## Executive Summary

**Migration Scope**: 145 files (40+ Ruby scripts, 20+ Python scripts, Rust CLI) → Unified Bun + TypeScript
**Current State**: Mature Ruby infrastructure with base classes, services, 20+ utilities
**Goal**: Rock-solid, easy-to-extend, easy-to-maintain TypeScript architecture

---

## 🎯 Architecture Options

### Option 1: **Decorator-Driven Architecture** (RECOMMENDED)

**Philosophy**: TypeScript decorators + Class-based + Auto-validation

#### Structure
```
bin/
├── cli.ts                    # Main CLI entry point (single compiled binary)
├── scripts/                  # All script implementations
│   ├── git/
│   │   ├── commit-dir.ts
│   │   ├── commit-deletes.ts
│   │   └── smart-rebase.ts
│   ├── xcode/
│   │   ├── icon-generator.ts
│   │   └── view-files.ts
│   └── system/
│       ├── largest-files.ts
│       └── game-mode.ts
├── core/                     # Infrastructure
│   ├── base/
│   │   ├── Script.ts         # Base class with lifecycle
│   │   ├── GitScript.ts      # Git-specific base
│   │   ├── XcodeScript.ts    # Xcode-specific base
│   │   └── InteractiveScript.ts
│   ├── decorators/
│   │   ├── validation.ts     # @ValidateFile, @ValidateGit, etc.
│   │   ├── metadata.ts       # @Category, @Description, @Tags
│   │   └── lifecycle.ts      # @Before, @After, @Cache
│   ├── services/             # Business logic (stateful)
│   │   ├── GitService.ts
│   │   ├── XcodeService.ts
│   │   ├── SelectionService.ts (fzf/peco/fallback)
│   │   ├── LLMService.ts
│   │   └── SettingsService.ts
│   └── utils/                # Utilities (stateless)
│       ├── logger.ts
│       ├── shell.ts
│       ├── format.ts
│       └── errors.ts
└── types/                    # TypeScript interfaces
    ├── git.ts
    ├── xcode.ts
    └── common.ts
```

#### Example Script
```typescript
import { GitScript } from "../core/base/GitScript";
import { ValidatesDirectoryExists, ValidatesGitRepository } from "../core/decorators/validation";
import { Category, Description, Tags } from "../core/decorators/metadata";

@Category("git")
@Description("Commit files in a specific directory")
@Tags("git", "automation", "commit")
@ValidatesGitRepository()
export class CommitDirectoryScript extends GitScript {
  emoji = "📁";

  defineOptions() {
    return {
      message: {
        type: "string",
        short: "m",
        description: "Commit message (skip interactive prompt)"
      }
    } as const;
  }

  @ValidatesDirectoryExists(0) // Validates args[0] is a directory
  async run(args: string[], options: { message?: string }) {
    const directory = args[0];

    // Get files changed in directory
    const files = await this.git.getChangedFiles(directory);

    if (files.length === 0) {
      this.logger.warn(`No changes in ${directory}`);
      return;
    }

    // Show changes
    this.logger.info(`Changes in ${directory}:`);
    files.forEach(f => console.log(`  ${f.status} ${f.path}`));

    // Get commit message
    const message = options.message || await this.prompt("Enter commit message:");

    // Confirm and commit
    if (await this.confirm("Commit these changes?")) {
      await this.git.stageFiles(files.map(f => f.path));
      await this.git.commit(message);
      this.logger.success("Changes committed!");
    }
  }
}
```

#### CLI Registration (Automatic)
```typescript
// bin/cli.ts
import { createCLI } from "./core/cli";
import { autoDiscoverScripts } from "./core/discovery";

// Automatically discovers all @Category decorated scripts
const scripts = autoDiscoverScripts("./scripts");

const cli = createCLI({
  name: "zsh-utils",
  version: "2.0.0",
  scripts
});

cli.run();
```

#### Pros
- ✅ **Easiest to add new scripts** - just create class with decorators
- ✅ **Automatic validation** - decorators handle all validation
- ✅ **Auto-discovery** - no manual registration needed
- ✅ **Clean, declarative code** - decorators make intent clear
- ✅ **Great IDE support** - full autocomplete and type checking
- ✅ **Minimal boilerplate** - ~20-30 lines per simple script

#### Cons
- ⚠️ TypeScript decorators still experimental (Stage 3 proposal)
- ⚠️ Need `experimentalDecorators: true` in tsconfig
- ⚠️ Slight learning curve for decorator patterns

#### Migration Effort
- **Foundation**: 2-3 weeks (base classes, decorators, core services)
- **Scripts**: 4-6 weeks (40+ scripts, can parallelize)
- **Total**: ~8 weeks

---

### Option 2: **Functional + Zod Validation Architecture**

**Philosophy**: Functional programming + Runtime validation with Zod

#### Structure
```
bin/
├── cli.ts                    # Main entry point
├── scripts/                  # Script definitions (pure functions)
│   ├── git-commit-dir.ts
│   ├── largest-files.ts
│   └── xcode-icon-generator.ts
├── core/
│   ├── script.ts             # Script builder functions
│   ├── validation/
│   │   ├── schemas.ts        # Zod schemas
│   │   └── validators.ts     # Validation helpers
│   ├── services/             # Same as Option 1
│   └── utils/                # Same as Option 1
└── registry.ts               # Script registry
```

#### Example Script
```typescript
import { defineScript } from "../core/script";
import { z } from "zod";
import { createGitService } from "../core/services/GitService";

export const commitDirectoryScript = defineScript({
  name: "git-commit-dir",
  category: "git",
  description: "Commit files in a specific directory",
  emoji: "📁",

  // Zod schema for validation
  args: z.tuple([z.string().refine(isDirectory, "Must be a directory")]),
  options: z.object({
    message: z.string().optional()
  }),

  // Setup function (runs once)
  setup: async (ctx) => {
    ctx.git = createGitService();
    await ctx.git.validateRepository();
  },

  // Main function
  run: async (ctx, args, options) => {
    const [directory] = args;
    const files = await ctx.git.getChangedFiles(directory);

    if (files.length === 0) {
      ctx.logger.warn(`No changes in ${directory}`);
      return;
    }

    const message = options.message || await ctx.prompt("Enter commit message:");

    if (await ctx.confirm("Commit these changes?")) {
      await ctx.git.stageFiles(files.map(f => f.path));
      await ctx.git.commit(message);
      ctx.logger.success("Changes committed!");
    }
  }
});
```

#### Registration
```typescript
// registry.ts
import { commitDirectoryScript } from "./scripts/git-commit-dir";
import { largestFilesScript } from "./scripts/largest-files";

export const scripts = [
  commitDirectoryScript,
  largestFilesScript,
  // ... add new scripts here
];
```

#### Pros
- ✅ **No experimental features** - uses stable TypeScript/Zod
- ✅ **Excellent runtime validation** - Zod provides great error messages
- ✅ **Functional and testable** - pure functions easy to test
- ✅ **Simple mental model** - just functions and data
- ✅ **Great type inference** - Zod infers types automatically

#### Cons
- ⚠️ Less OOP-friendly - harder to share behavior via inheritance
- ⚠️ More verbose setup - need to manually wire dependencies
- ⚠️ Manual registration - need to import and register each script
- ⚠️ Larger bundle size - Zod adds ~12KB minified

#### Migration Effort
- **Foundation**: 2 weeks (script builder, validation, core)
- **Scripts**: 5-7 weeks (more manual wiring needed)
- **Total**: ~7-9 weeks

---

### Option 3: **Hybrid: Best of Both Worlds**

**Philosophy**: Classes for scripts + Zod for validation + Services pattern

#### Structure
Same as Option 1, but:
- Use classes WITHOUT decorators
- Use Zod for runtime validation
- Keep inheritance hierarchy for code reuse

#### Example Script
```typescript
import { GitScript } from "../core/base/GitScript";
import { z } from "zod";

export class CommitDirectoryScript extends GitScript {
  emoji = "📁";
  name = "git-commit-dir";
  description = "Commit files in a specific directory";

  // Zod schema for validation
  argsSchema = z.tuple([z.string()]);
  optionsSchema = z.object({
    message: z.string().optional()
  });

  async validate(args: string[]) {
    await super.validate(args); // Checks git repo
    const dir = args[0];
    if (!await this.fs.isDirectory(dir)) {
      throw new Error(`Not a directory: ${dir}`);
    }
  }

  async run(args: string[], options: { message?: string }) {
    const directory = args[0];
    const files = await this.git.getChangedFiles(directory);
    // ... rest of implementation
  }
}
```

#### Pros
- ✅ **No experimental features** - stable TypeScript + Zod
- ✅ **OOP benefits** - inheritance, polymorphism
- ✅ **Runtime validation** - Zod schemas
- ✅ **Flexible** - can use classes or functions as needed

#### Cons
- ⚠️ More boilerplate than Option 1 (no decorators)
- ⚠️ Manual registration still needed
- ⚠️ Less "magic" but also less automation

#### Migration Effort
- **Foundation**: 2-3 weeks
- **Scripts**: 5-6 weeks
- **Total**: ~7-9 weeks

---

## 📊 Detailed Comparison

| Feature | Option 1 (Decorators) | Option 2 (Functional) | Option 3 (Hybrid) |
|---------|----------------------|---------------------|------------------|
| **Ease of Adding Scripts** | ⭐⭐⭐⭐⭐ (Just add class) | ⭐⭐⭐ (Function + register) | ⭐⭐⭐⭐ (Class + register) |
| **Maintainability** | ⭐⭐⭐⭐⭐ (Self-documenting) | ⭐⭐⭐⭐ (Clear flow) | ⭐⭐⭐⭐ (Familiar OOP) |
| **Type Safety** | ⭐⭐⭐⭐ (Compile time) | ⭐⭐⭐⭐⭐ (Runtime + compile) | ⭐⭐⭐⭐⭐ (Runtime + compile) |
| **Learning Curve** | ⭐⭐⭐ (Decorators new) | ⭐⭐⭐⭐ (Just functions) | ⭐⭐⭐⭐ (Standard OOP) |
| **Bundle Size** | ⭐⭐⭐⭐⭐ (Smallest) | ⭐⭐⭐⭐ (+12KB Zod) | ⭐⭐⭐⭐ (+12KB Zod) |
| **IDE Support** | ⭐⭐⭐⭐⭐ (Excellent) | ⭐⭐⭐⭐⭐ (Excellent) | ⭐⭐⭐⭐⭐ (Excellent) |
| **Stability** | ⭐⭐⭐ (Stage 3) | ⭐⭐⭐⭐⭐ (Stable) | ⭐⭐⭐⭐⭐ (Stable) |
| **Testability** | ⭐⭐⭐⭐ (Good) | ⭐⭐⭐⭐⭐ (Pure functions) | ⭐⭐⭐⭐ (Good) |

---

## 🏗️ Core Infrastructure (Common to All Options)

### Services Layer (Stateful Business Logic)

```typescript
// core/services/GitService.ts
export class GitService {
  constructor(private shell: ShellExecutor, private logger: Logger) {}

  async validateRepository(): Promise<void> {
    const result = await this.shell.exec("git rev-parse --git-dir");
    if (!result.success) {
      throw new Error("Not in a git repository");
    }
  }

  async getChangedFiles(directory?: string): Promise<GitFile[]> {
    const path = directory ? `"${directory}"` : "";
    const result = await this.shell.exec(`git status --porcelain ${path}`);
    return this.parseGitStatus(result.stdout);
  }

  async stageFiles(files: string[]): Promise<void> {
    await this.shell.exec(`git add ${files.map(f => `"${f}"`).join(" ")}`);
  }

  async commit(message: string, options?: CommitOptions): Promise<CommitInfo> {
    const flags = options?.noVerify ? "--no-verify" : "";
    await this.shell.exec(`git commit -m "${message}" ${flags}`);
    return this.getCommitInfo("HEAD");
  }

  async getCommitInfo(ref: string): Promise<CommitInfo> {
    const result = await this.shell.exec(`git log -1 --format="%H|%an|%ae|%s" ${ref}`);
    const [hash, author, email, subject] = result.stdout.split("|");
    return { hash, author, email, subject, ref };
  }

  // ... more git operations
}

// All types are strongly typed
export interface GitFile {
  path: string;
  status: "M" | "A" | "D" | "R" | "C" | "U" | "??";
  staged: boolean;
}

export interface CommitInfo {
  hash: string;
  author: string;
  email: string;
  subject: string;
  ref: string;
}

export interface CommitOptions {
  noVerify?: boolean;
  amend?: boolean;
  allowEmpty?: boolean;
}
```

### Utilities Layer (Stateless Helpers)

```typescript
// core/utils/logger.ts
export class Logger {
  info(message: string) {
    console.log(`ℹ️  ${this.blue(message)}`);
  }

  success(message: string) {
    console.log(`✅ ${this.green(message)}`);
  }

  warn(message: string) {
    console.log(`⚠️  ${this.yellow(message)}`);
  }

  error(message: string) {
    console.error(`❌ ${this.red(message)}`);
  }

  progress(message: string) {
    console.log(`🔄 ${this.cyan(message)}`);
  }

  section(title: string) {
    console.log(`\n🔧 ${this.magenta(title)}`);
  }

  banner(title: string) {
    const line = "=".repeat(60);
    console.log(`\n${line}\n  ${title}\n${line}\n`);
  }

  private blue(s: string) { return `\x1b[34m${s}\x1b[0m`; }
  private green(s: string) { return `\x1b[32m${s}\x1b[0m`; }
  private yellow(s: string) { return `\x1b[33m${s}\x1b[0m`; }
  private red(s: string) { return `\x1b[31m${s}\x1b[0m`; }
  private cyan(s: string) { return `\x1b[36m${s}\x1b[0m`; }
  private magenta(s: string) { return `\x1b[35m${s}\x1b[0m`; }
}
```

```typescript
// core/utils/shell.ts
import { $ } from "bun";

export interface ExecResult {
  success: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
}

export class ShellExecutor {
  constructor(private logger: Logger, private dryRun = false) {}

  async exec(command: string, options?: {
    description?: string;
    cwd?: string;
    silent?: boolean;
  }): Promise<ExecResult> {
    if (options?.description) {
      this.logger.progress(options.description);
    }

    if (this.dryRun) {
      if (!options?.silent) {
        console.log(`[DRY RUN] ${command}`);
      }
      return { success: true, stdout: "", stderr: "", exitCode: 0 };
    }

    try {
      const proc = await $`${command}`.cwd(options?.cwd || process.cwd());
      return {
        success: proc.exitCode === 0,
        stdout: proc.stdout.toString().trim(),
        stderr: proc.stderr.toString().trim(),
        exitCode: proc.exitCode
      };
    } catch (error: any) {
      return {
        success: false,
        stdout: error.stdout?.toString().trim() || "",
        stderr: error.stderr?.toString().trim() || error.message,
        exitCode: error.exitCode || 1
      };
    }
  }

  async execOrThrow(command: string, errorMessage?: string): Promise<string> {
    const result = await this.exec(command, { silent: true });
    if (!result.success) {
      throw new Error(errorMessage || result.stderr || "Command failed");
    }
    return result.stdout;
  }

  commandExists(command: string): boolean {
    try {
      Bun.which(command);
      return true;
    } catch {
      return false;
    }
  }
}
```

### Selection Service (Interactive Selection)

```typescript
// core/services/SelectionService.ts
export class SelectionService {
  constructor(private shell: ShellExecutor) {}

  async selectOne<T>(
    items: T[],
    options: {
      prompt?: string;
      display?: (item: T) => string;
      allowCancel?: boolean;
    }
  ): Promise<T | null> {
    const hasFzf = this.shell.commandExists("fzf");
    const hasPeco = this.shell.commandExists("peco");

    if (hasFzf) {
      return this.selectWithFzf(items, options);
    } else if (hasPeco) {
      return this.selectWithPeco(items, options);
    } else {
      return this.selectWithPrompt(items, options);
    }
  }

  private async selectWithFzf<T>(items: T[], options: SelectOptions<T>): Promise<T | null> {
    const display = options.display || ((x) => String(x));
    const itemsList = items.map(display).join("\n");

    const result = await this.shell.exec(
      `echo "${itemsList}" | fzf --prompt="${options.prompt || 'Select: '}"`,
      { silent: true }
    );

    if (!result.success && options.allowCancel) {
      return null;
    }

    const selectedText = result.stdout.trim();
    return items.find(item => display(item) === selectedText) || null;
  }

  // Similar implementations for Peco and fallback prompt
}
```

---

## 🎨 Build System & Tooling

### Single Binary Compilation

```json
// package.json
{
  "name": "zsh-utils",
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run bin/cli.ts",
    "build": "bun build bin/cli.ts --compile --outfile dist/zsh-utils",
    "build:release": "bun build bin/cli.ts --compile --minify --outfile dist/zsh-utils",
    "test": "bun test",
    "lint": "eslint bin/",
    "format": "prettier --write 'bin/**/*.ts'"
  },
  "dependencies": {
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.3.3",
    "eslint": "^8.56.0",
    "prettier": "^3.1.1"
  }
}
```

### TypeScript Configuration

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
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true, // Only for Option 1
    "emitDecoratorMetadata": true,  // Only for Option 1
    "paths": {
      "@core/*": ["./bin/core/*"],
      "@scripts/*": ["./bin/scripts/*"],
      "@utils/*": ["./bin/core/utils/*"],
      "@services/*": ["./bin/core/services/*"]
    }
  },
  "include": ["bin/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### ZSH Integration

```bash
# bin/scripts.zsh - Wrapper functions
# After compilation, all scripts run through single binary

git-commit-dir() {
  "$ZSH_CONFIG/dist/zsh-utils" git-commit-dir "$@"
}

largest-files() {
  "$ZSH_CONFIG/dist/zsh-utils" largest-files "$@"
}

# Or use a generic function generator
for script in git-commit-dir largest-files xcode-icon-generator; do
  eval "$script() { \$ZSH_CONFIG/dist/zsh-utils $script \"\$@\"; }"
done
```

---

## 🧪 Testing Strategy

```typescript
// tests/scripts/git-commit-dir.test.ts
import { describe, expect, it, beforeEach, mock } from "bun:test";
import { CommitDirectoryScript } from "@scripts/git/commit-dir";
import { GitService } from "@services/GitService";

describe("CommitDirectoryScript", () => {
  let script: CommitDirectoryScript;
  let mockGit: GitService;

  beforeEach(() => {
    mockGit = {
      getChangedFiles: mock(() => Promise.resolve([
        { path: "src/file.ts", status: "M", staged: false }
      ])),
      stageFiles: mock(() => Promise.resolve()),
      commit: mock(() => Promise.resolve({ hash: "abc123", ... }))
    } as any;

    script = new CommitDirectoryScript({ git: mockGit });
  });

  it("should commit changes in directory", async () => {
    await script.run(["src"], { message: "Update src" });

    expect(mockGit.getChangedFiles).toHaveBeenCalledWith("src");
    expect(mockGit.stageFiles).toHaveBeenCalledWith(["src/file.ts"]);
    expect(mockGit.commit).toHaveBeenCalledWith("Update src");
  });

  it("should warn if no changes", async () => {
    mockGit.getChangedFiles = mock(() => Promise.resolve([]));

    await script.run(["src"], {});

    expect(mockGit.stageFiles).not.toHaveBeenCalled();
  });
});
```

---

## 📦 Migration Strategy

### Phase 1: Foundation (Weeks 1-3)
- [ ] Setup Bun project structure
- [ ] Implement base classes (Script, GitScript, XcodeScript, etc.)
- [ ] Implement decorators (Option 1) or Zod schemas (Options 2/3)
- [ ] Create core services (GitService, SelectionService, SettingsService)
- [ ] Create core utilities (Logger, ShellExecutor, Formatter)
- [ ] Build CLI framework with auto-discovery
- [ ] Setup testing infrastructure
- [ ] Write comprehensive tests for core

### Phase 2: High-Value Scripts (Weeks 4-6)
Priority scripts to migrate first:

**Git Scripts** (Most used):
- [ ] git-commit-dir
- [ ] git-commit-deletes
- [ ] git-commit-renames
- [ ] git-history
- [ ] git-smart-rebase

**Xcode Scripts**:
- [ ] xcode-icon-generator
- [ ] xcode-add-file
- [ ] xcode-delete-file

**System Scripts**:
- [ ] largest-files
- [ ] game-mode
- [ ] uninstall-app

### Phase 3: Remaining Scripts (Weeks 7-9)
- [ ] Gmail scripts (if still needed)
- [ ] LLM scripts
- [ ] Utility scripts
- [ ] Specialized scripts

### Phase 4: Python Placeholders (Week 10)
- [ ] Create TypeScript wrappers for Python ML scripts
- [ ] Use `Bun.spawn` to call Python when needed
- [ ] Document which scripts still use Python backend

### Phase 5: Cleanup & Polish (Week 11)
- [ ] Remove Ruby/Rust infrastructure
- [ ] Update documentation (SCRIPTS.md, CLAUDE.md)
- [ ] Performance optimization
- [ ] Bundle size optimization

---

## 💡 Recommendation

### **Option 1: Decorator-Driven Architecture**

**Why?**

1. **Easiest to add new scripts** - Your #1 requirement. Just create a class with decorators.

2. **Most maintainable** - Self-documenting code. Decorators make validation/behavior explicit.

3. **Best developer experience** - IDE autocomplete, compile-time checking, minimal boilerplate.

4. **Future-proof** - Decorators are Stage 3 proposal, will be in ES standard soon. TypeScript support is stable.

5. **Smallest scripts** - Compare:
   - Ruby: ~100-120 lines
   - Option 1 (Decorators): ~30-40 lines
   - Option 2 (Functional): ~50-60 lines
   - Option 3 (Hybrid): ~60-70 lines

**Risk Mitigation for Decorators:**
- TypeScript's `experimentalDecorators` is stable and used in production by Angular, NestJS, TypeORM
- Can always remove decorators later and convert to Option 3 (minimal refactoring)
- Bun has excellent decorator support

### Example: Adding a New Script with Option 1

```typescript
// bin/scripts/git/commit-renames.ts
import { GitScript } from "@core/base/GitScript";
import { Category, Description } from "@core/decorators/metadata";

@Category("git")
@Description("Commit only renamed files")
export class CommitRenamesScript extends GitScript {
  emoji = "📝";

  async run() {
    const renamed = await this.git.getRenamedFiles();

    if (renamed.length === 0) {
      this.logger.warn("No renamed files found");
      return;
    }

    renamed.forEach(f => console.log(`  ${f.oldPath} → ${f.newPath}`));

    if (await this.confirm("Commit these renames?")) {
      const message = await this.prompt("Commit message:");
      await this.git.stageFiles(renamed.map(f => f.newPath));
      await this.git.commit(message);
      this.logger.success("Renames committed!");
    }
  }
}
```

That's it! The script:
- ✅ Auto-discovered by CLI
- ✅ Auto-validates git repository (via `GitScript`)
- ✅ Has logging, prompts, confirmation built-in
- ✅ Fully type-safe
- ✅ ~20 lines of actual code

---

## 🚀 Next Steps

### Option A: **Validate with Prototype** (Recommended)

**Timeline: 1-2 days**

I implement a working prototype with:
- ✅ Base infrastructure (Script, GitScript, decorators)
- ✅ GitService with 5-6 core operations
- ✅ 2 working scripts (git-commit-dir + largest-files)
- ✅ Full compilation to single binary
- ✅ Tests demonstrating the pattern

**Benefits:**
- See real code, not just proposals
- Test the developer experience yourself
- Validate build/performance before committing
- Make informed decision with working prototype

### Option B: **Start Full Migration**

**Timeline: 10-12 weeks**

Proceed directly to Phase 1 implementation.

### Option C: **Hybrid Approach**

**Timeline: Extended**

Keep Ruby for complex scripts, migrate only high-value simple scripts.

---

## ❓ Questions to Consider

1. **Decorator comfort level?**
   - Comfortable → Option 1
   - Prefer stable features → Option 2 or 3

2. **How important is minimal boilerplate?**
   - Critical → Option 1
   - Not critical → Option 2 or 3

3. **Timeline pressure?**
   - Want it fast → Let's prototype (Option A)
   - Can take time → Full migration (Option B)

4. **Python scripts**
   - Still needed? Keep Python backend, TypeScript wrappers
   - Deprecated? Just document, skip migration

---

## 📚 Additional Resources

- [TypeScript Decorators Guide](https://www.typescriptlang.org/docs/handbook/decorators.html)
- [Bun CLI Compilation](https://bun.sh/docs/bundler/executables)
- [Zod Documentation](https://zod.dev)
- [Example Projects using this architecture]

---

**What do you want to do next?**

A) I'll build a prototype of Option 1 for you to review
B) Let's discuss and refine one of these options
C) You want to see a different architecture approach
D) Start full migration with Option 1 immediately
