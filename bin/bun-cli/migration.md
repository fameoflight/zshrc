# Bun Migration Plan

## Purpose

This document defines the practical migration path for this repository's script ecosystem from a Ruby and Python first model to a Bun first model.

The intended end state is:

- Bun is the primary user-facing CLI and shell entrypoint.
- Ruby is removed from normal day-to-day operation.
- Python remains only as a backend for ML and CoreML workloads where it is still the right tool.
- Shell wrappers, Make targets, environment setup, and docs all reflect the Bun-first model.

This plan is based on the repository state reviewed on March 10, 2026.

## Repository Snapshot

### Bun

Observed in repo:

- [`bin/bun-cli/package.json`](/Users/hemantv/zshrc/bin/bun-cli/package.json) defines the package as `zsh-utils`.
- [`bin/bun-cli/src/cli.ts`](/Users/hemantv/zshrc/bin/bun-cli/src/cli.ts) is a real CLI entrypoint with script discovery and command dispatch.
- [`bin/bun-cli/src/scripts`](/Users/hemantv/zshrc/bin/bun-cli/src/scripts) currently contains 44 TypeScript commands.
- Categories currently present in Bun:
  - `ai`
  - `browser`
  - `demo`
  - `epub`
  - `files`
  - `git`
  - `macos`
  - `media`
  - `network`
  - `utils`
  - `xcode`
- Build and validation scripts already exist:
  - `bun run build`
  - `bun run build:release`
  - `bun run test`
  - `bun run typecheck`
- [`bin/bun-cli/dist`](/Users/hemantv/zshrc/bin/bun-cli/dist) exists but has no built artifact checked in.
- No Bun test files were found under `bin/bun-cli`.
- [`bin/bun-cli/scripts.zsh`](/Users/hemantv/zshrc/bin/bun-cli/scripts.zsh) now exists and provides compatibility wrappers for migrated commands.
- [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh) now sources Bun when Bun is runnable, and Bun-loaded wrappers override overlapping Ruby command names.
- `list-scripts` and `scripts --help` now present Bun as the primary interface when Bun is enabled.
- Bun was not available on `PATH` in the current shell review, so the CLI was not executed during this pass.

### Ruby

Observed in repo:

- [`bin/ruby-cli/bin`](/Users/hemantv/zshrc/bin/ruby-cli/bin) contains 39 Ruby command scripts.
- [`bin/ruby-cli/scripts.zsh`](/Users/hemantv/zshrc/bin/ruby-cli/scripts.zsh) remains available as a fallback from [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh) when Bun is not runnable.
- [`Makefile`](/Users/hemantv/zshrc/Makefile) still has active Ruby setup targets:
  - `ruby`
  - `ruby-gems`
- The default `make mac` path no longer installs Ruby.
- [`Makefile`](/Users/hemantv/zshrc/Makefile) no longer uses Ruby for the `find-orphans` maintenance target.
- [`shell/env.shared.sh`](/Users/hemantv/zshrc/shell/env.shared.sh) still provisions `RUBY_CLI_CACHE`.
- [`AGENT.md`](/Users/hemantv/zshrc/AGENT.md) still documents the custom scripts system as multi-language with explicit Ruby development guidance.

Conclusion:

- Ruby is now mostly a fallback or rollback runtime rather than the intended primary CLI path.
- Ruby is still present in docs, environment setup, and optional Make targets, so it is not fully retired yet.

### Python

Observed in repo:

- [`bin/python-cli/pyproject.toml`](/Users/hemantv/zshrc/bin/python-cli/pyproject.toml) defines a standalone `python-cli` package.
- `bin/python-cli` currently contains 15 Python files.
- [`bin/python-cli/scripts.zsh`](/Users/hemantv/zshrc/bin/python-cli/scripts.zsh) is sourced from [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh), so Python workflows are also on the default interactive path.
- Python-backed commands currently exposed in shell include:
  - `upscale-image`
  - `upscale-video`
  - `detect-human`
  - `detect-watermark`
  - `pytorch-infer`
  - `find-similar-images`
  - `find-duplicate-images`
  - `setup-pytorch-models`
  - `list-pytorch-models`
  - `youtube-info`
  - `youtube-subs`
- Some Python workflows are invoked through top-level shell wrappers in `bin/`, not only through the `python-cli` package.
- [`shell/env.shared.sh`](/Users/hemantv/zshrc/shell/env.shared.sh) provisions `PYTHON_CLI_CACHE`.

Conclusion:

- Python is still both a backend and a user-facing CLI surface.
- That is the main architectural mismatch with the Bun-first target.

## What Is Already Migrated

These Ruby commands already appear to have Bun equivalents:

- `auto-retry`
- `battery-info`
- `change-extension`
- `check-camera-mic`
- `clip-video`
- `comment-only-changes`
- `console-log-remover`
- `electron-icon-generator`
- `game-mode`
- `gmail-inbox`
- `git-commit-deletes`
- `git-commit-dir`
- `git-commit-renames`
- `git-commit-splitter`
- `git-common`
- `git-compress`
- `git-history` -> Bun script name is `git/file-history`
- `git-smart-rebase`
- `git-template`
- `internal-find-orphaned-targets`
- `investigate-naval-js`
- `largest-files`
- `llm-generate`
- `merge-markdown`
- `merge-pdf`
- `openrouter-usage`
- `safari-epub`
- `setup-dev-tools`
- `spotlight-manage`
- `stacked-monitor`
- `test-click-naval`
- `uninstall-app`
- `website-epub`
- `xcode-add-file`
- `xcode-delete-file`
- `xcode-icon-generator`
- `xcode-list-categories`
- `xcode-view-files`
- `youtube-transcript-chat`

Important caveat:

- "Implemented in Bun" is not the same as "migrated".
- These commands only become the default shell path when Bun is actually available, because [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh) enables Bun wrappers conditionally.

## Ruby Commands Still Missing In Bun

No remaining Ruby-only command names were identified after the current Bun ports.

Remaining work is now mostly about:

- validating the newly added Bun replacements end to end
- removing Ruby from default onboarding and shell fallbacks once Bun is guaranteed present
- deciding whether the old Ruby implementation directory should be archived immediately or kept briefly as a rollback path

## Python Surface Still Outside Bun

These workflows still have Python as the direct user-facing interface:

- `upscale-image`
- `upscale-video`
- `detect-human`
- `detect-watermark`
- `pytorch-infer`
- `find-similar-images`
- `find-duplicate-images`
- `setup-pytorch-models`
- `list-pytorch-models`
- `youtube-info`
- `youtube-subs`

## Migration Goals

### Primary goals

1. Make Bun the default and documented CLI runtime.
2. Remove Ruby as an operational dependency for normal use.
3. Keep Python only where it provides durable technical value.
4. Preserve current command names during the rollout where that meaningfully reduces breakage.
5. Add enough verification that the Bun layer is safe to expand.

### Non-goals

- Rewriting PyTorch or CoreML internals from Python into TypeScript.
- Renaming every command at the same time as the runtime migration.
- Shipping a big-bang cutover.

## Repo-Derived Gaps Blocking Cutover

The main blockers are not code parity alone. The blockers are the control-plane files that still point somewhere else.

### Gap 1: Bun is implemented but not wired in

Current state:

- [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh) sources Python, Ruby, and Rust wrappers.
- There is no corresponding Bun wrapper.
- `list-scripts` still presents Ruby and Python as the main CLI layers.
- `scripts()` also indexes Ruby and Python functions, not Bun commands.

Impact:

- Bun cannot become the real default until shell entrypoints are changed.

### Gap 2: Makefile still assumes Ruby is supported

Current state:

- [`Makefile`](/Users/hemantv/zshrc/Makefile) still installs Ruby and Ruby gems.
- `find-orphans` still executes Ruby directly.

Impact:

- Any onboarding or automation path still implies Ruby is part of the supported system.

### Gap 3: Docs still describe the old architecture

Current state:

- [`AGENT.md`](/Users/hemantv/zshrc/AGENT.md) still teaches a multi-language script model and Ruby-specific authoring workflow.
- `migration.md` previously overstated Bun progress relative to what the shell actually does.

Impact:

- New changes will continue to drift unless the documentation is aligned with the intended control plane.

### Gap 4: Python is still a first-class CLI, not a backend

Current state:

- Python functions are exported directly in shell wrappers.
- Some commands call top-level shell scripts in `bin/` rather than going through a shared Bun adapter layer.

Impact:

- Users still need to know which runtime owns which command.
- That is exactly what the migration should eliminate.

### Gap 5: Bun lacks a verification floor

Current state:

- `test` and `typecheck` scripts exist in [`bin/bun-cli/package.json`](/Users/hemantv/zshrc/bin/bun-cli/package.json).
- No Bun test files were found.
- The binary build output directory is empty.

Impact:

- Without at least smoke-level tests, moving more command ownership into Bun increases risk quickly.

## Guiding Principles

### 1. Bun is the control plane

Bun should own:

- command discovery
- user-facing help
- shell wrappers
- orchestration
- configuration conventions
- validation
- packaging

Python should remain an implementation detail for selected ML workflows.

### 2. Migrate behavior, not just source files

A command is only considered migrated when all of the following are true:

- there is a Bun implementation
- the shell reaches Bun first
- docs describe the Bun path
- there is at least smoke-level verification
- the old runtime is not the default route anymore

### 3. Migrate by shared infrastructure

Batch by domain:

- Git
- file utilities
- macOS
- Xcode
- AI and chat
- ML orchestration

This avoids rebuilding the same plumbing multiple times.

### 4. Keep compatibility at the shell edge during rollout

Preserve current command names where practical, but move the implementation under them.

## Target Architecture

### User-facing model

- One primary CLI: `zsh-utils`.
- Shell functions and wrappers call Bun first.
- Legacy command names remain as compatibility shims until they are intentionally retired.

### Runtime model

- Bun executes non-ML utilities directly.
- Bun shells out to Python for ML and CoreML workloads.
- Python packages remain for model execution and heavy inference.
- Ruby is removed after parity and shell cutover are complete.

### Environment model

Steady-state environment expectations:

- Bun runtime available and documented.
- `PYTHON_CLI_CACHE` remains if Python backends still use it.
- `RUBY_CLI_CACHE` is removed once Ruby is retired.

### Directory model

Recommended steady-state additions:

```text
bin/
  bun-cli/
    src/
      cli.ts
      core/
      scripts/
      adapters/
        python/
```

Notes:

- `adapters/python/` should hold Bun-side wrappers for retained Python workflows.
- Ruby-specific helper code should be removed or archived after cutover.

## Phase 0: Lock The Baseline

### Objective

Create an accurate ownership map before changing defaults.

### Tasks

- Record the runtime owner for every shell-exposed command.
- Record every Make target that invokes Ruby or Python directly.
- Record every doc that still presents Ruby or Python as canonical.
- Confirm the final Bun binary name remains `zsh-utils`.
- Decide which legacy command names will remain as wrappers during the transition.

### Deliverables

- this migration plan
- a command ownership table
- a cutover checklist for shell wrappers, Make targets, and docs

### Exit criteria

- Every currently exposed command is classified as:
  - Bun-native
  - Bun frontend with Python backend
  - pending Bun port
  - retire

## Phase 1: Make Bun Runnable And Verifiable

### Objective

Turn `bin/bun-cli` into a runnable and testable toolchain.

### Tasks

- Install Bun in the environment used for this repo.
- Make `bun run src/cli.ts list` work locally.
- Make `bun run typecheck` pass.
- Make `bun run build` produce `bin/bun-cli/dist/zsh-utils`.
- Add minimum Bun tests covering:
  - script discovery
  - CLI argument parsing
  - one Git command
  - one file utility
  - one macOS command with mocked shell dependencies

### Deliverables

- working Bun install path
- successful typecheck
- successful build artifact
- minimum smoke tests

### Exit criteria

- A clean machine can build and run `zsh-utils list`.
- Bun has a non-zero verification floor.

## Phase 2: Put Bun On The Shell Path

### Objective

Make Bun the front door without breaking familiar command names.

### Tasks

- Add a Bun shell wrapper file, ideally [`bin/bun-cli/scripts.zsh`](/Users/hemantv/zshrc/bin/bun-cli/scripts.zsh).
- Update [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh) to source Bun first.
- Add Bun-backed compatibility functions for already migrated commands.
- Update `list-scripts` to show Bun as the primary CLI runtime.
- Update `scripts()` discovery so Bun commands are indexed and discoverable.
- Add Make targets for Bun setup, typecheck, build, and smoke checks.

### Deliverables

- Bun wrapper layer
- Bun-first shell startup path
- Bun-focused `list-scripts`
- Make targets for Bun validation

### Exit criteria

- Typical interactive use reaches Bun first.
- Existing command names continue to work.

## Phase 3: Finish The Remaining Ruby Ports

### Objective

Eliminate Ruby-only command ownership.

### Sequencing

Port in this order:

1. low-risk maintenance and utility scripts
2. domain infrastructure
3. high-complexity interactive tools

### Wave 3.1: Low-risk ports

Port first:

- `internal-find-orphaned-targets`
- `setup-dev-tools`
- `clip-video`

Reason:

- these unlock Makefile and maintenance cleanup quickly

### Wave 3.2: Medium-complexity ports

Port next:

- `electron-icon-generator`
- `investigate-naval-js`
- `test-click-naval`

Reason:

- narrower blast radius than Xcode, Gmail, or chat flows

### Wave 3.3: Xcode batch

Build shared Bun infrastructure first:

- `XcodeService`
- project discovery
- pbxproj editing helpers
- category mapping logic

Then port:

- `xcode-add-file`
- `xcode-delete-file`
- `xcode-icon-generator`
- `xcode-list-categories`
- `xcode-view-files`

Reason:

- all five commands share the same domain model

### Wave 3.4: High-complexity interactive ports

Port last:

- `gmail-inbox`
- `youtube-transcript-chat`

Requirements before porting:

- define auth and config ownership
- define cache and persistence layout
- isolate reusable service boundaries from the Ruby implementation

### Deliverables

- Bun equivalents for every remaining Ruby-only command
- compatibility wrappers routing old command names to Bun

### Exit criteria

- No normal workflow requires Ruby.
- No Make target requires Ruby.

## Phase 4: Convert Python Into A Backend Behind Bun

### Objective

Keep Python for ML execution, but remove it as the primary user-facing control plane.

### Strategy

Do not rewrite ML internals into TypeScript first.

Instead:

- keep Python inference code
- add Bun adapters for Python-backed workflows
- standardize flags, output shape, help text, and config paths in Bun

### Tasks

- Add Bun adapter commands for:
  - `ml upscale-image`
  - `ml upscale-video`
  - `ml detect-human`
  - `ml detect-watermark`
  - `ml pytorch-infer`
  - `ml find-similar-images`
  - `ml find-duplicate-images`
  - `ml setup-models`
  - `ml list-models`
  - `youtube info`
  - `youtube subs`
- Standardize logging and error handling across Bun and Python-backed commands.
- Standardize config and cache paths.
- Decide whether the standalone `python-cli` entrypoint remains temporarily supported.

### Suggested ownership split

Keep in Python:

- model loading
- PyTorch inference
- CoreML integration
- image tensor pipelines

Move to Bun:

- argument normalization
- command discovery
- help text
- orchestration
- user prompts
- config selection
- shell integration

### Exit criteria

- Users can access ML and YouTube workflows through Bun commands.
- Python is no longer the main entrypoint users need to remember.

## Phase 5: Remove Ruby From Active Use

### Objective

Retire Ruby after Bun parity and shell cutover are complete.

### Tasks

- Remove Ruby sourcing from [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh).
- Remove `ruby` and `ruby-gems` from normal onboarding paths in [`Makefile`](/Users/hemantv/zshrc/Makefile).
- Replace `find-orphans` with a Bun implementation.
- Remove `RUBY_CLI_CACHE` from [`shell/env.shared.sh`](/Users/hemantv/zshrc/shell/env.shared.sh).
- Archive or delete `bin/ruby-cli`.
- Rewrite docs that still teach Ruby as a first-class script runtime.

### Exit criteria

- A new machine can use the repo without Ruby installed.

## Phase 6: Cleanup And Compatibility Retirement

### Objective

Remove transitional scaffolding after Bun usage is stable.

### Tasks

- Decide how long legacy command wrappers remain.
- Remove wrappers that only exist for transition support.
- Normalize command naming and categories where needed.
- Archive or delete obsolete migration notes once final architecture docs exist.

### Exit criteria

- One clear runtime model remains.
- Transitional layers are intentionally minimal.

## Prioritization

### Highest priority

- Make Bun runnable
- Put Bun on the shell path
- Replace Ruby-backed maintenance targets
- Port the low-risk Ruby-only commands

### Medium priority

- Build Bun adapters over Python workflows
- unify config and output conventions
- update docs and onboarding

### Lowest priority

- rewriting Python ML internals into TypeScript
- removing compatibility wrappers early

## Command Ownership Proposal

### Bun-native long term

- Git commands
- file utilities
- macOS utilities
- EPUB utilities
- repository maintenance helpers
- Xcode utilities
- general AI and chat orchestration

### Bun frontend with Python backend

- image upscaling
- video upscaling
- watermark detection
- human detection
- PyTorch and CoreML inference
- similar and duplicate image search
- YouTube metadata extraction
- YouTube subtitle extraction

### Likely retire candidates

Evaluate these before investing migration effort:

- `investigate-naval-js`
- `test-click-naval`

Questions:

- Is it still used?
- Is it a one-off script rather than a supported command?
- Should it move to an internal or temporary scripts area instead?

## Definition Of Done

The migration is complete when all of the following are true:

- Bun is installed and documented as the primary CLI runtime.
- Shell wrappers route users to Bun by default.
- Ruby is not required for normal operation.
- Python functionality is accessed through Bun for user-facing workflows.
- Bun build, typecheck, and smoke tests exist.
- Docs describe the Bun-first architecture rather than the legacy multi-runtime model.
- Legacy wrappers are either removed or clearly marked transitional.

## Open Decisions

These decisions should be made early because they affect multiple files.

### 1. Final CLI name

Keep `zsh-utils` unless there is a strong reason to rename it. The package and build scripts already use that name.

### 2. Compatibility window

Decide whether old command names remain indefinitely as shell shims or only through the migration period.

### 3. Python strategy

Keep Python as a backend for ML workloads unless there is a concrete reason to replace a specific subsystem.

### 4. Xcode scope

Decide whether every current Xcode helper should be promoted into the Bun CLI, or whether some commands should be explicitly demoted to internal tooling.

### 5. Doc strategy

Decide whether to fully rewrite [`bin/SCRIPTS.md`](/Users/hemantv/zshrc/bin/SCRIPTS.md) around Bun, or split it into:

- Bun-first command architecture
- Python backend notes
- archived legacy runtime guidance

## Immediate Execution Backlog

The next concrete work items should be:

1. Add Bun to the local toolchain and verify `bun run src/cli.ts list`.
2. Add `bin/bun-cli/scripts.zsh`.
3. Update [`bin/scripts.zsh`](/Users/hemantv/zshrc/bin/scripts.zsh) so Bun is sourced and listed first.
4. Add Bun Make targets for install, typecheck, build, and smoke checks.
5. Port `internal-find-orphaned-targets` so `find-orphans` stops depending on Ruby.
6. Port `setup-dev-tools` if that logic should remain a supported CLI instead of only a shell script.
7. Add the first Bun smoke tests before expanding command ownership further.
