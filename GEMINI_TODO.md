# Refactoring Plan: ZSH Configuration Repository

## Executive Summary

This repository has a robust, modular architecture for ZSH configuration and a sophisticated Ruby-based framework for utility scripts. However, a significant portion of the scripts in the `bin/` and `scripts/` directories are implemented as standalone shell scripts, bypassing the powerful `ScriptBase` framework. This leads to code duplication, inconsistent user experience, and increased maintenance overhead. The refactoring roadmap focuses on migrating these shell scripts to the Ruby framework, consolidating logic, and introducing automated quality checks.

## Critical Issues

1.  **Framework Bypass**: Numerous shell scripts (`.sh`) exist in `bin/` and `scripts/` that re-implement functionality already provided by the Ruby framework (e.g., logging, command execution, user prompts).
2.  **Inconsistent Tooling**: The use of shell scripts for tasks that are perfect candidates for the Ruby framework creates a fragmented and inconsistent development environment.
3.  **Code Duplication**: Logic for setup, error handling, and logging is duplicated across many shell scripts instead of being centralized as intended by the Ruby `ScriptBase` and its utilities.
4.  **Lack of Automated Quality Gates**: The repository lacks automated linting (e.g., ShellCheck for shell, RuboCop for Ruby) and testing, which allows inconsistencies and potential bugs to accumulate.

## Refactoring Roadmap

-   **Phase 1: Core Script Migration & Consolidation (High Priority)**: Migrate the most frequently used and architecturally important shell scripts to the Ruby framework. This will provide the biggest immediate impact on consistency and maintainability.
-   **Phase 2: Automation & Quality Assurance (Medium Priority)**: Integrate RuboCop and ShellCheck into the `Makefile` to enforce coding standards and catch common errors automatically.
-   **Phase 3: Framework Enhancement & Cleanup (Low Priority)**: Refine the core Ruby framework based on the migration experience and remove now-redundant shell scripts and helper functions.

---

## TASK-001: Migrate Setup & Backup Shell Scripts to Ruby Framework

**Priority**: High
**Estimated Effort**: 2 Days
**Dependencies**: None
**Risk Level**: Medium

### Description
The primary setup and backup scripts located in `bin/` (e.g., `vscode-backup.sh`, `iterm-backup.sh`) and `scripts/` (e.g., `setup-dev-tools.sh`, `setup-macos.sh`) are implemented as shell scripts. This is a direct deviation from the "Ruby-first" philosophy documented in `SCRIPTS.md`. Migrating these to Ruby scripts inheriting from `ScriptBase` will centralize logging, error handling (via `ErrorUtils`), and command execution (via `System.execute`), making them more robust and easier to maintain.

### Current Issues
-   **Divergent Change**: Modifying the logging format requires editing dozens of individual shell scripts.
-   **Code Smells (Dispensables)**: Shell scripts contain boilerplate code for sourcing utilities and checking for dependencies, which is handled automatically by `ScriptBase`.
-   **Inconsistent Error Handling**: Some scripts use `set -e`, while others have manual error checks, leading to unpredictable behavior on failure.

### Refactoring Strategy
Systematically port each key shell script to a new Ruby script in the `bin/` directory. The `Makefile` targets will be updated to call the new Ruby scripts instead of the old shell scripts.

### Subtasks
#### 1. Migrate `scripts/setup-dev-tools.sh` (Estimated: 4h)
   - **Action**: Create `bin/setup-dev-tools.rb`. Implement the logic for installing Homebrew packages using `System::Homebrew.install_formulae` and `System::Homebrew.install_casks`.
   - **Pattern Applied**: Command Pattern (encapsulating the setup for each tool category).
   - **Files Affected**: `scripts/setup-dev-tools.sh` (delete), `bin/setup-dev-tools.rb` (create), `Makefile` (update target).
   - **Testing**: Run `make dev-tools` and verify that all packages are installed correctly.
   - **Implementation Details**:
     - Use a hash to map categories (`core-utils`, `dev-utils`) to package lists.
     - Leverage `System.execute?` to check if a command exists before attempting installation.
   - **Debug Logging to Add**:
     - Log level INFO: "Installing 'core-utils' packages..."
     - Log level DEBUG: "Executing: brew install wget tree ..."

#### 2. Migrate `scripts/setup-macos.sh` (Estimated: 4h)
   - **Action**: Create `bin/setup-macos.rb`. Port the `defaults write` commands and other macOS configuration logic into Ruby methods.
   - **Pattern Applied**: Single Responsibility Principle (each method handles one aspect of macOS setup).
   - **Files Affected**: `scripts/setup-macos.sh` (delete), `bin/setup-macos.rb` (create), `Makefile` (update target).
   - **Testing**: Run `make macos-optimize` and verify settings in System Preferences.
   - **Implementation Details**:
     - Use the `MacOSUtils` concern for interacting with macOS-specific features if applicable, or `System.execute` for `defaults` commands.
   - **Debug Logging to Add**:
     - Log level INFO: "Applying Dock settings..."
     - Log level DEBUG: "Executing: defaults write com.apple.dock autohide -bool true"

#### 3. Migrate Backup Scripts (`vscode-backup.sh`, `iterm-backup.sh`, `xcode-backup.sh`) (Estimated: 3h)
   - **Action**: Create corresponding Ruby scripts (`bin/vscode-backup.rb`, etc.). Use Ruby's `FileUtils` for copying files and `System.execute` for shell commands.
   - **Pattern Applied**: DRY (Don't Repeat Yourself) by creating a shared backup utility module if common logic emerges.
   - **Files Affected**: `bin/*-backup.sh` (delete), `bin/*-backup.rb` (create), `Makefile` (update targets).
   - **Testing**: Run `make vscode-backup` and verify that backup files are created in the correct location.

### Success Criteria
- [ ] All major setup and backup workflows are executed by Ruby scripts.
- [ ] Redundant shell scripts in `scripts/` and `bin/` are removed.
- [ ] The `Makefile` is updated to call the new Ruby scripts.
- [ ] All migrated scripts use the centralized `Logger` for output.

### Testing Strategy
- **Manual Testing**: Execute the top-level `make` targets (`mac`, `dev-tools`, `app-settings`) and verify the system is configured as expected.
- **Integration Tests**: The `Makefile` targets serve as integration tests. A successful run without errors indicates success.

---

## TASK-002: Integrate Automated Linting and Quality Checks

**Priority**: Medium
**Estimated Effort**: 3 Hours
**Dependencies**: TASK-001
**Risk Level**: Low

### Description
The repository lacks automated checks to enforce code quality and style. This allows for inconsistencies and potential errors, especially with a mix of languages. Integrating `RuboCop` for Ruby and `ShellCheck` for the remaining shell scripts will create a quality gate and ensure all contributions adhere to a consistent standard.

### Current Issues
-   **Inconsistent Formatting**: Ruby and shell scripts have varying formatting and style.
-   **Potential Bugs**: Shell scripts may contain common bugs (e.g., unquoted variables) that `ShellCheck` can detect automatically.
-   **Manual Code Review Overhead**: Reviewers must manually check for style issues, which can be automated.

### Refactoring Strategy
1.  Add `rubocop` to the `Gemfile`.
2.  Create a `.rubocop.yml` configuration file with sensible defaults.
3.  Add a `lint` target to the `Makefile` that runs `rubocop` and `shellcheck`.
4.  Optionally, add a `lint-fix` target to auto-correct issues.

### Subtasks
#### 1. Configure RuboCop (Estimated: 1.5h)
   - **Action**: Add `rubocop` and relevant plugins to the `Gemfile`. Run `bundle install`. Generate an initial `.rubocop.yml` configuration.
   - **Pattern Applied**: Convention over Configuration.
   - **Files Affected**: `Gemfile`, `.rubocop.yml` (create).
   - **Testing**: Run `bundle exec rubocop` and ensure it analyzes the Ruby files.

#### 2. Configure ShellCheck (Estimated: 0.5h)
   - **Action**: Add a `shellcheck` target to the `Makefile` that finds and analyzes all `.sh` and `.zsh` files.
   - **Pattern Applied**: Fail Fast (detecting script errors early).
   - **Files Affected**: `Makefile`.
   - **Testing**: Run `make shellcheck` and observe the output.

#### 3. Create Master `lint` Target (Estimated: 1h)
   - **Action**: Create a `lint` target in the `Makefile` that depends on the `rubocop` and `shellcheck` targets.
   - **Files Affected**: `Makefile`.
   - **Testing**: Run `make lint`.

### Success Criteria
- [ ] `make lint` successfully runs `rubocop` on all `.rb` files.
- [ ] `make lint` successfully runs `shellcheck` on all `.sh` and `.zsh` files.
- [ ] The build fails if linting errors are detected.

### Testing Strategy
- **Unit Tests**: The linting tools themselves are the unit tests for code style and quality.
- **Integration Tests**: Running `make lint` in a CI environment (if available) would be the integration test.

---

## TASK-003: Refactor ZSHRC Entrypoint for Clarity and Performance

**Priority**: Low
**Estimated Effort**: 4 Hours
**Dependencies**: None
**Risk Level**: Medium

### Description
The main `zshrc` file has grown organically. It contains a mix of direct `source` calls, a `foreach` loop for sourcing, and appended logic for `conda`, `pnpm`, and `nvm`. This can be reorganized for better readability, maintainability, and slightly improved startup performance. The NVM lazy-loading implementation is good but can be further isolated.

### Current Issues
-   **Mixed Sourcing Logic**: The file uses a `sources` array and a `foreach` loop, but also has many direct `source` calls, making the load order less obvious.
-   **Configuration Sprawl**: App-specific configurations (`conda`, `pnpm`, `nvm`, `lmstudio`) are appended at the end, making the core configuration less distinct from user-specific tool setup.
-   **Redundant Checks**: The `foreach` loop checks for file existence (`[[ -a $file ]]`), which is good but can be made more efficient.

### Refactoring Strategy
1.  Consolidate all core file sourcing into the `sources` array.
2.  Move tool-specific initializations (`conda`, `nvm`, etc.) into a separate, clearly marked file like `tools.zsh` or similar, which is sourced from the main `zshrc`.
3.  Optimize the sourcing loop.

### Subtasks
#### 1. Consolidate Sourcing (Estimated: 2h)
   - **Action**: Move all core `.zsh` files currently sourced directly into the `sources` array. Ensure the load order is preserved.
   - **Pattern Applied**: Single Responsibility Principle (the loop is responsible for sourcing, the array for configuration).
   - **Files Affected**: `zshrc`.
   - **Testing**: Start a new ZSH session and verify that the prompt, aliases, and functions work as expected.

#### 2. Isolate Tool Initializations (Estimated: 2h)
   - **Action**: Create a new file `tools.zsh`. Move the `conda`, `pnpm`, `lmstudio`, and `nvm` initialization blocks from `zshrc` into this new file. Source `tools.zsh` from `zshrc`.
   - **Pattern Applied**: Separation of Concerns.
   - **Files Affected**: `zshrc`, `tools.zsh` (create).
   - **Testing**: Open a new terminal. Verify that `conda`, `nvm`, and `pnpm` commands are available and work correctly. Check that lazy-loading for NVM is still functional.

### Success Criteria
- [ ] The `zshrc` file primarily contains the logic for sourcing other files.
- [ ] Tool-specific shell initializations are isolated in a separate file.
- [ ] ZSH startup time is not negatively impacted and is potentially slightly faster.

### Testing Strategy
- **Manual Testing**: Thoroughly test the shell environment after changes: check aliases, functions, prompt, and tool commands (`nvm`, `conda`).
- **Performance Tests**: Use the `make debug-profile` target to measure and compare ZSH startup time before and after the changes.

---

## TASK-004: Modularize CLI Tooling into Separate Submodule Repositories

**Priority**: High
**Estimated Effort**: 1.5 Days
**Dependencies**: None
**Risk Level**: High

### Description
The current repository is a monorepo containing the ZSH configuration, Ruby scripts, Python CLI tools, and Rust programs. This tight coupling makes independent development and versioning of the different language toolsets difficult. This task involves extracting the Ruby, Python, and Rust CLI tools into their own dedicated Git repositories and re-integrating them back into this repository as Git submodules. This will promote better separation of concerns, independent versioning, and a cleaner main repository structure.

### Current Issues
-   **Monolithic Structure**: The `zshrc` repository is responsible for too many distinct components.
-   **Coupling**: Changes to the Python CLI require a change in the `zshrc` repository history.
-   **Versioning Complexity**: It's impossible to version the Rust CLI independently of the ZSH configuration.

### Refactoring Strategy
1.  Create three new, empty Git repositories (e.g., `zsh-ruby-cli`, `zsh-python-cli`, `zsh-rust-cli`).
2.  Use `git filter-repo` or a similar tool to extract the history of the respective subdirectories (`bin/` for ruby, `bin/python-cli`, `bin/rust`) into the new repositories.
3.  Remove the original directories from the `zshrc` repository.
4.  Add the three new repositories as Git submodules, placing them in their original locations.
5.  Update the `Makefile` and any build/run scripts to correctly reference the new submodule paths.

### Subtasks
#### 1. Extract Ruby CLI (Estimated: 4h)
   - **Action**: Create a new repository. Extract all Ruby scripts from `bin/` and the `.common` directory into it.
   - **Files Affected**: `bin/*.rb`, `bin/.common/`, `.gitmodules`.
   - **Testing**: Run `make ruby-gems` and ensure scripts are still executable from the main project.

#### 2. Extract Python CLI (Estimated: 3h)
   - **Action**: Create a new repository. Extract the `bin/python-cli` directory into it.
   - **Files Affected**: `bin/python-cli/`, `.gitmodules`.
   - **Testing**: Run `make pytorch-setup` and verify Python scripts function correctly within the submodule context.

#### 3. Extract Rust CLI (Estimated: 3h)
   - **Action**: Create a new repository. Extract the `bin/rust` directory into it.
   - **Files Affected**: `bin/rust/`, `.gitmodules`.
   - **Testing**: Run `make rust` and verify the build process works correctly within the submodule.

#### 4. Update Build System (Estimated: 2h)
   - **Action**: Modify the `Makefile` to `cd` into the submodule directories before running language-specific commands (e.g., `cd bin/rust && cargo build`).
   - **Files Affected**: `Makefile`.
   - **Testing**: Run all major `make` targets (`install`, `mac`, `rust`, `python-models`) to ensure they still work.

### Success Criteria
- [ ] The `bin/python-cli`, `bin/rust`, and Ruby script directories are Git submodules.
- [ ] The main repository's history is cleaned of the extracted files.
- [ ] All `make` targets that depend on these tools continue to function correctly.
- [ ] The `.gitmodules` file is correctly configured.

### Testing Strategy
- **Integration Tests**: The `Makefile` targets are the primary integration tests. A full `make setup` run should complete without errors.
- **Manual Testing**: Clone the repository fresh using `git clone --recurse-submodules` to ensure the entire setup works correctly for a new user.
