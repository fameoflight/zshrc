# CLAUDE.md

_ZSH Configuration Repository - Documentation for Claude Code (claude.ai/code)_

## Repository Overview

Modular ZSH configuration system originated from Sebastian Tramp's configuration, customized by Hemant Verma. Features centralized logging, platform-specific configurations, and extensive custom scripts system.

## Quick Start

```bash
make install          # Full installation with symlinks
make mac             # Complete macOS setup
make github-setup    # Configure Git
make update          # Update repository and submodules
```

## Core Architecture

### Configuration Loading Order

1. **`logging.zsh`** - Centralized logging (loaded first for universal access)
2. **`environment.zsh`** - Environment variables and PATH management
3. **`options.zsh`** - Shell options and settings
4. **`prompt.zsh`** - Prompt configuration
5. **`functions.zsh`** - Custom functions and key bindings
6. **`aliases.zsh`** - Command aliases and suffix handlers
7. **Platform-specific** - `darwin.zsh` (macOS) or `linux.zsh`
8. **Application configs** - `git.zsh`, `rails.zsh`, `claude.zsh`, etc.
9. **`completion.zsh`** - Tab completion setup
10. **`private.zsh`** - User-specific private configurations

### Key Features

- **Modular Design** - Each feature area has dedicated `.zsh` file
- **Platform Detection** - Automatic OS-specific configuration loading
- **External Dependencies** - `zsh-syntax-highlighting` submodule
- **Path Management** - Automated setup for Python, Node, Conda, Ruby, etc.

## Development Utilities

### Navigation & File Operations

```bash
workspace              # cd ~/workspace
latest-dir            # Enter most recently created directory
path <pattern>        # Find files matching pattern
buf <file>            # Backup file with timestamp
massmove              # Batch rename files interactively
```

### Development Helpers

```bash
kill-port <port>      # Kill process on specific port
kill-grep <pattern>   # Kill processes matching pattern
clean-pyc             # Remove .pyc files recursively
fix-pep8              # Auto-fix Python PEP8 in staged files
```

## AI Tools Integration

### API Key Setup (Optional)

API keys enable enhanced functionality but aren't required.

**Claude (Anthropic):**

```bash
setup-claude-key "sk-ant-api03-your-key-here"
# Stores in ~/.claude/anthropic_api_key
```

**Gemini (Google):**

```bash
setup-gemini-key "AIzaSyYour-gemini-key-here"
# Stores in ~/.gemini/api_key
```

**Available Functions:**

- `claude` / `cc` - Claude Code CLI with auto-loaded API key
- `gemini-cli` / `gg` - Gemini CLI with auto-loaded API key

## Custom Scripts System

Three-tier Ruby-based scripts system with centralized dependency management and shared utilities.

### Script Categories

#### 🐚 Utility Scripts (ZSH Functions)

_Available immediately in shell - for frequent use_

```bash
calibre-update         # Update Calibre e-book manager
stack-monitors         # Configure stacked monitor setup
merge-pdf              # Merge multiple PDF files
dropbox-backup         # Move directories to Dropbox with symlinks
uninstall-app          # Comprehensive application uninstaller
list-scripts           # Show all available scripts
```

#### 🛠️ Setup/Backup Scripts (Makefile Only)

_Controlled access for system configuration_

```bash
make macos-optimize    # Optimize macOS developer settings
make claude-setup      # Setup Claude Code configuration
make gemini-setup      # Setup Gemini CLI configuration
make xcode-backup      # Backup Xcode essential settings
make vscode-backup     # Backup VS Code settings
make iterm-backup      # Backup iTerm2 configuration
```

#### 🧹 Repository Maintenance (Makefile Only)

_Internal repository tools_

```bash
make find-orphans      # Find orphaned Makefile targets
```

### Ruby Script Development

**Install dependencies:**

```bash
make ruby-gems
```

**Available gems:** tty-prompt, tty-progressbar, pastel, sqlite3, rexml

**Script template:**

```ruby
#!/usr/bin/env ruby
require_relative '.common/script_base'

class MyUtilityScript < ScriptBase
  def banner_text
    "Usage: #{script_name} [OPTIONS] <arguments>"
  end

  def run
    log_banner("Starting #{script_name}")
    # Implementation here
    show_completion(script_name)
  end
end

MyUtilityScript.execute if __FILE__ == $0
```

## Centralized Logging System

**Core Functions:**

```bash
log_success "Operation completed"     # Green + ✅
log_error "Failed to find file"      # Red + ❌ (stderr)
log_warning "Backup recommended"     # Yellow + ⚠️
log_info "Checking requirements"     # Blue + ℹ️
log_progress "Processing data"       # Cyan + 🔄
log_section "Configuration"         # Magenta + 🔧
```

**Specialized Functions:**

```bash
log_file_created "/path"            # 📄 File operations
log_install "package"               # 📦 Installation
log_brew "Installing tools"         # 🍺 Homebrew
log_git "Committing changes"        # 🐙 Git operations
```

**Usage in scripts:**

```bash
# Source logging in bash scripts
source "$ZSH_CONFIG/logging.zsh"
log_info "Script started"
```

**When to use Gemini:**

- Analyzing entire codebases (>100KB)
- Verifying implementations across multiple files
- Understanding project-wide patterns
- Context exceeds Claude's limits

## Git Integration

**Custom aliases:** `lg` (log), `cp` (cherry-pick), `ri` (rebase interactive), `rc` (rebase continue), `pushf` (force push)

**Configuration includes:**

- Rebase editor setup
- SSH key management
- Push behavior defaults

## Environment Variables

- `ZSH_CONFIG` - Points to ~/.config/zsh
- `EDITOR` - Set to "vim"
- `PATH` - Extended for development tools (Python, Node, Ruby, etc.)

## Development Guidelines

### Style Conventions

- **Function naming:** Use kebab-case (`my-function` not `my_function`)
- **Logging:** Always use centralized logging functions, never raw `echo`
- **Colors:** Use logging functions for consistent emoji + color output
- **Error handling:** Use `set -euo pipefail` in bash scripts

### Adding New Scripts

**For utility scripts (Ruby preferred):**

1. Create `bin/my-script.rb` using ScriptBase template
2. Add wrapper function in `bin/scripts.zsh`
3. Update `list-scripts` function

**For setup/backup scripts (bash):**

1. Create `bin/my-script.sh`
2. Add Makefile target only (no wrapper function)
3. Source logging functions

## Directory Structure

```
├── zshrc                    # Main configuration entry
├── logging.zsh             # Centralized logging (loaded first)
├── environment.zsh         # Environment variables
├── [other core .zsh files]
├── bin/                    # Custom scripts system
│   ├── scripts.zsh         # Wrapper functions
│   ├── .common/            # Ruby utilities
│   └── [script files]
├── functions.d/            # Completion functions
├── Settings/               # Application backups
└── zsh-syntax-highlighting/ # External dependency
```

## Installation

The configuration uses symlinks to `~/.config/zsh/` allowing easy updates while maintaining customizations in `private.zsh`.

**Key installation targets:**

- `make install` - Full setup with symlinks
- `make mac` - macOS-specific setup with Homebrew
- `make github-setup` - Git configuration
- `make update` - Update repository and submodules
