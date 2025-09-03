# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a ZSH configuration repository containing modular shell configuration files. The repository originated from Sebastian Tramp's ZSH configuration and has been customized by Hemant Verma (<fameoflight@gmail.com>).

## Architecture

The configuration follows a modular design where the main `zshrc` file sources multiple `.zsh` files in a specific order:

### Core Configuration Flow

1. `logging.zsh` - **Centralized logging functions (loaded first for universal access)**
2. `environment.zsh` - Environment variables and paths
3. `options.zsh` - Shell options and settings
4. `prompt.zsh` - Prompt configuration
5. `functions.zsh` - Custom functions and key bindings
6. `aliases.zsh` - Command aliases and suffix handlers
7. Platform-specific files (e.g., `darwin.zsh` for macOS)
8. Application-specific configurations (`git.zsh`, `rails.zsh`, `claude.zsh`, etc.)
9. `completion.zsh` - Tab completion setup
10. `private.zsh` - User-specific private configurations

### Key Components

- **Modular Structure**: Each feature area has its own `.zsh` file
- **Platform Detection**: Automatically sources OS-specific configurations
- **External Dependencies**: Includes `zsh-syntax-highlighting` as a Git submodule
- **Path Management**: Manages various development tool paths (Python, Node, Conda, etc.)

## Installation and Setup Commands

### Initial Setup

```bash
make install          # Full installation - creates symlinks and directories
make install-zsh      # ZSH-only installation
make install-bash     # Bash installation
```

### macOS Setup

```bash
make mac             # Complete macOS setup with applications
make mac-helpers     # Install development tools via Homebrew
make brew            # Install/update Homebrew
```

### Git Configuration

```bash
make github-setup    # Configure Git with user info and aliases
```

### Updates

```bash
make update          # Update repository and submodules
```

## Custom Functions and Utilities

The configuration provides numerous custom functions in `aliases.zsh` and `functions.zsh`:

### Development Helpers

- `kill-port <port>` - Kill process running on specific port
- `kill-grep <pattern>` - Kill processes matching pattern
- `clean-pyc` - Remove all .pyc files recursively
- `fix-pep8` - Auto-fix Python PEP8 issues in git staged files

### Navigation

- `workspace` - cd to ~/workspace
- `latest-dir` - Enter most recently created directory
- `..`, `...`, `....` - Quick navigation up directory tree

### File Operations

- `path <pattern>` - Find files matching pattern
- `buf <file>` - Backup file with timestamp
- `massmove` - Batch rename files interactively

## Environment Variables

Key environment variables set by the configuration:

- `ZSH_CONFIG` - Points to ~/.config/zsh (this repository when linked)
- `EDITOR` - Set to "vim"
- Various PATH extensions for development tools

## Dependencies and External Tools

- **zsh-syntax-highlighting** - Git submodule for command highlighting
- **Homebrew** - Package manager for macOS setup
- **Development tools** - Python/Conda, Node.js/pnpm, Ruby/RVM support

## AI Tool Configuration

The configuration includes integration for AI development tools including Claude Code and Gemini CLI. API keys are **optional** - the tools will work without them but may have limited functionality.

### API Key Storage (Optional)

#### Claude (ANTHROPIC_API_KEY)

Store your Claude API key in any of these locations:

- `~/.claude/anthropic_api_key` (recommended)
- `~/.config/claude/api_key`
- `~/.anthropic_api_key`
- `$ZSH_CONFIG/private.env` (for multiple keys)

#### Gemini (GEMINI_API_KEY)

Store your Gemini API key in any of these locations:

- `~/.gemini/api_key` (recommended)
- `~/.config/gemini/api_key`
- `~/.google_ai_api_key`
- `~/.gemini_api_key`
- `$ZSH_CONFIG/private.env` (for multiple keys)

#### Setup Commands

```bash
# One-time setup (creates files with proper permissions)
setup-claude-key "sk-ant-api03-your-key-here"
setup-gemini-key "AIzaSyYour-gemini-key-here"

```

#### Available Functions

- `claude` - Claude Code CLI wrapper (loads API key automatically)
- `gemini-cli` - Gemini CLI wrapper (loads API key automatically)
- `cc` - Alias for claude-code
- `gg` - Alias for gemini-cli

**Note**: API keys are loaded on-demand only when the functions are executed, keeping your shell environment clean.

## Git Integration

The configuration includes extensive Git integration:

- Custom aliases (lg, cp, ri, rc, pushf, etc.)
- Rebase editor configuration
- Push behavior defaults
- SSH key management

## Custom Scripts System

The repository implements a sophisticated **Ruby-based** custom scripts system that provides modular utility functions across the development environment. This system consists of five key components:

1. **Centralized Gemfile** for dependency management
2. **Common Ruby utilities** in `bin/.common/` directory
3. **Ruby script files** in the `bin/` directory
4. **ZSH wrapper functions** in `bin/scripts.zsh`
5. **Makefile integration** for automated deployment and gem installation

### Architecture Overview

#### Ruby-First Design Philosophy

The scripts system is built using **Ruby as the primary scripting language** with centralized dependency management and shared utilities. This provides:

- **Rich standard library** for file operations, system integration, and data processing
- **Powerful gems ecosystem** for terminal UI, HTTP requests, database operations, and more
- **Object-oriented structure** with inheritance and modular design
- **Centralized logging and error handling** across all scripts
- **Interactive prompts** with confirmation dialogs and progress indicators
- **Comprehensive testing capabilities** with RSpec and RuboCop integration

#### Loading Mechanism

The scripts system is loaded automatically as part of the ZSH configuration:

```bash
# In zshrc (line 29):
sources+="$ZSH_CONFIG/bin/scripts.zsh"
```

This ensures all script wrapper functions are available immediately when starting a new shell session.

#### Component Integration

1. **Centralized Gemfile** (`Gemfile`) - Manages all Ruby dependencies:

   - Terminal UI gems (tty-prompt, tty-progressbar, pastel)
   - System interaction gems (open3, sqlite3, rexml)
   - Development tools (rspec, rubocop)
   - Installed via `make ruby-gems` target

2. **Common Utilities** (`bin/.common/`) - Shared Ruby modules:

   - `logger.rb` - Centralized logging with emoji indicators and colors
   - `system.rb` - System command execution and platform utilities
   - `script_base.rb` - Base class providing common functionality for all scripts

3. **Ruby Scripts** (`bin/`) - Utility scripts inheriting from ScriptBase:

   - `uninstall-app.rb` - Comprehensive application removal
   - `calibre-update.rb` - E-book manager updates (planned migration)
   - `stack-monitors.rb` - Monitor configuration utility

4. **Wrapper Functions** (`bin/scripts.zsh`) - ZSH functions for utility scripts only:

   - Handle script path resolution with Ruby execution
   - Set `BUNDLE_GEMFILE` environment for dependency access
   - Provide error checking and validation
   - Use centralized logging functions
   - **Only available for utility scripts**, not setup/backup scripts

5. **Makefile Integration** - Setup/backup scripts and gem installation:
   - `make ruby-gems` → Installs all Gemfile dependencies
   - `make macos-optimize` → `bin/macos-optimize.sh` (bash - to be migrated)
   - `make claude-setup` → `bin/claude-setup.sh` (bash - to be migrated)
   - Setup scripts remain bash-based during migration period

### Available Scripts and Functions

The scripts system is organized into three distinct categories:

#### 🛠️ Setup/Backup Scripts (Makefile Targets Only)

These scripts handle system configuration, application setup, and backup operations. They are **only accessible via Makefile targets** and are not available as ZSH functions:

##### System Configuration

- **`make macos-optimize`** - Optimize macOS system settings for developers
  - Configures Finder, Dock, energy settings, and development tools
  - **Script**: `bin/macos-optimize.sh`

##### AI Development Tools Setup

- **`make claude-setup`** - Setup Claude Code settings via symlinks

  - Creates symlinks for Claude Code configuration files
  - **Script**: `bin/claude-setup.sh`

- **`make gemini-setup`** - Setup Gemini CLI settings via symlinks

  - Configures Gemini CLI with appropriate settings
  - **Script**: `bin/gemini-setup.sh`

- **`make agent-setup`** - Convert CLAUDE.md to AGENT.md with symlinks
  - Creates unified documentation for multiple AI tools
  - **Script**: `bin/agent-setup.sh`

##### Application Backup/Restore

- **`make xcode-backup`** - Backup current Xcode essential settings

  - Backs up themes, key bindings, and simulator configurations
  - **Script**: `bin/xcode-backup.sh`

- **`make vscode-backup`** - Backup VS Code essential settings

  - Saves user settings, extensions list, and keybindings
  - **Script**: `bin/vscode-backup.sh`

- **`make iterm-backup`** - Backup iTerm2 essential settings

  - Exports iTerm2 preferences and profile configurations
  - **Script**: `bin/iterm-backup.sh`

- **`make iterm-setup`** - Restore iTerm2 settings from backup
  - Restores iTerm2 configuration from backup files
  - **Script**: `bin/iterm-setup.sh`

#### 🧹 Repository Maintenance (Makefile Targets Only)

- **`make find-orphans`** - Find and report orphaned Makefile targets
  - **Script**: `bin/internal-find-orphaned-targets.rb`

#### 🐚 Utility Scripts (ZSH Functions)

These scripts provide general utilities and are available as interactive ZSH functions:

- **`calibre-update`** - Update Calibre e-book manager to the latest version

  - **Usage**: `calibre-update [--help] [--version] [--no-launch]`
  - Automatically downloads, installs, and launches the latest Calibre
  - Includes backup of existing installation and proper error handling
  - **Script**: `bin/calibre-update.sh`

- **`stack-monitors`** - Configure stacked external monitor setup

  - **Usage**: `stack-monitors [--dry-run] [--debug]`
  - Configures non-16" primary monitor with two stacked 16" monitors
  - Uses `displayplacer` tool for precise monitor arrangement
  - **Script**: `bin/stacked-monitor.rb`

- **`merge-pdf`** - Merge multiple PDF files into one

  - **Usage**: `merge-pdf [OPTIONS] <output_file> <input_files_or_directory>`
  - Ruby-based PDF merging utility using combine_pdf gem
  - Supports directory input with recursive scanning option
  - **Script**: `bin/merge-pdf.rb`

- **`dropbox-backup`** - Move directory to Dropbox with symlink backup

  - **Usage**: `dropbox-backup [source-directory]`
  - Safely moves directories to Dropbox and creates symlinks
  - **Script**: `bin/dropbox-backup.sh`

- **`uninstall-app`** - Comprehensive application uninstaller
  - **Usage**: `uninstall-app [app-name]`
  - Removes Homebrew packages, kills processes, and cleans up files
  - **Script**: `bin/uninstall-app.sh`

#### Discovery and Help

- **`list-scripts`** - Display all available custom scripts and functions
  - Shows ZSH utility functions, Makefile-only setup/backup scripts, and repository maintenance scripts.
  - Provides clear organization of the three-tier system
  - Quick overview of all available functionality

### Three-Tier Script Organization

#### ZSH Utility Functions Pattern

Utility scripts available in ZSH follow this wrapper function pattern in `scripts.zsh`:

```zsh
utility-script() {
  local script_path="$ZSH_CONFIG/bin/utility-script.sh"

  if [[ ! -f "$script_path" ]]; then
    log_error "Script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making script executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}
```

#### Makefile-Only Scripts Pattern

Setup and backup scripts are only accessible via Makefile targets:

```makefile
setup-script:
 @bash "${ZSH_CONFIG}/bin/setup-script.sh"
```

This three-tier approach provides:

- **Clear separation** - Utilities vs setup/backup operations
- **Controlled access** - Setup scripts require intentional `make` invocation
- **Interactive utilities** - Common tools available directly in shell
- **Consistent error handling** - Both tiers use centralized logging

### Integration with Makefile

The scripts system integrates seamlessly with the Makefile automation:

#### Direct Script Execution

```makefile
# Makefile calls script directly
macos-optimize:
 @if [ -f "bin/macos-optimize.sh" ]; then \
  bash bin/macos-optimize.sh; \
 fi
```

#### Through Wrapper Functions

```makefile
# Makefile calls through bash wrapper
claude-setup:
 @bash "${ZSH}/bin/claude-setup.sh"
```

#### Complex Integration Examples

- **`make setup`** - Calls `app-settings` and `ai-tools` targets
- **`make app-settings`** - Orchestrates multiple backup/restore scripts
- **`make ai-tools`** - Runs both Claude and Gemini setup scripts

### Ruby Development Workflow

#### Setting Up Development Environment

1. **Install Ruby dependencies:**

   ```bash
   make ruby-gems
   ```

2. **Common utilities are automatically available:**

   - `logger.rb` - Centralized logging system
   - `system.rb` - System interaction utilities
   - `script_base.rb` - Base class for all scripts

3. **Available gems in scripts:**

   ```ruby
   require 'tty-prompt'     # Interactive prompts
   require 'tty-progressbar' # Progress indicators
   require 'pastel'         # Terminal colors
   require 'sqlite3'        # Database operations
   require 'rexml'          # XML/Plist parsing
   ```

#### Script Testing and Quality

**Run RuboCop for code quality:**

```bash
cd $ZSH_CONFIG
bundle exec rubocop bin/
```

**Run RSpec tests:**

```bash
cd $ZSH_CONFIG
bundle exec rspec spec/
```

**Debug mode:**

```bash
DEBUG=1 uninstall-app --verbose "TestApp"
```

#### Common Ruby Patterns

**Using the logger:**

```ruby
log_info("Processing request")
log_success("Operation completed")
log_warning("Potential issue detected")
log_error("Critical error occurred")
log_progress("Working on task...")
```

**System command execution:**

```ruby
# Execute and return output
result = System.execute("brew list", description: "Listing packages")

# Execute and return success/failure
success = System.execute?("which brew", description: "Checking Homebrew")

# Interactive confirmation
if confirm_action("Proceed with operation?")
  # User confirmed
end
```

**File operations with logging:**

```ruby
remove_file("/path/to/file")           # Single file
remove_files(["/path1", "/path2"])     # Multiple files with confirmation
find_in_directories(dirs, "pattern")   # Search across directories
```

### Adding New Scripts

To add new custom scripts to the system:

#### 1. Create the Ruby Script File

**For utility scripts (Ruby - preferred):**

```bash
# Create script in bin/ directory
touch bin/my-utility-script.rb
chmod +x bin/my-utility-script.rb
```

**For setup/backup scripts (Bash - legacy):**

```bash
touch bin/my-setup-script.sh
chmod +x bin/my-setup-script.sh
```

#### 2. Add Script Content

**Ruby utility script template:**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Description: What this script does
class MyUtilityScript < ScriptBase
  def banner_text
    <<~BANNER
      🔧 My Utility Script

      Usage: #{script_name} [OPTIONS] <arguments>
    BANNER
  end

  def add_custom_options(opts)
    opts.on('-x', '--example', 'Example custom option') do
      @options[:example] = true
    end
  end

  def validate!
    # Add any validation logic
    super
  end

  def run
    log_banner("My Utility Script")

    # Main script logic
    log_info("Starting process...")

    # Your implementation here

    show_completion("My Utility Script")
  end
end

# Execute the script
MyUtilityScript.execute if __FILE__ == $0
```

**Bash setup/backup script template:**

```bash
#!/bin/bash
set -euo pipefail

# Source logging functions if available
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Script implementation
log_info "Starting my-setup-script"
# ... script logic ...
log_success "Script completed successfully"
```

#### 3. Add Wrapper Function (Ruby Utility Scripts Only)

**For Ruby utility scripts**, add to `bin/scripts.zsh`:

```zsh
my-utility-script() {
  local script_path="$ZSH_CONFIG/bin/my-utility-script.rb"

  if [[ ! -f "$script_path" ]]; then
    log_error "Script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making script executable..."
    chmod +x "$script_path"
  fi

  # Set BUNDLE_GEMFILE to use project gems
  BUNDLE_GEMFILE="$ZSH_CONFIG/Gemfile" ruby "$script_path" "$@"
}
```

**For setup/backup scripts**, do NOT add wrapper functions. They should only be accessible via Makefile targets.

#### 4. Add Makefile Target (Required for Setup/Backup Scripts)

```makefile
.PHONY: my-setup-script
my-setup-script:
 @bash "${ZSH_CONFIG}/bin/my-setup-script.sh"
```

#### 5. Update list-scripts Function

Update the appropriate section in the `list-scripts` function:

**For Ruby utility scripts:**

```zsh
echo "  🔧 my-utility-script - Description of what this utility does"
```

**For bash setup/backup scripts:**

```zsh
echo "  🛠️  make my-setup-script - Description of what this setup does"
```

### Script Development Guidelines

#### Determining Script Category

**Setup/Backup Scripts (Makefile-only)** should be used for:

- System configuration and optimization
- Application setup and configuration
- Backup and restore operations
- One-time or infrequent setup tasks
- Operations that modify system settings

**Repository Maintenance Scripts (Makefile-only)** should be used for:

- Internal repository maintenance tasks
- Scripts that are not intended for daily use
- Scripts that analyze or modify the repository itself

**Utility Scripts (ZSH functions)** should be used for:

- General-purpose utilities
- Frequently used interactive tools
- File manipulation and processing
- Development workflow helpers
- Day-to-day operational commands

#### Error Handling

- Use `set -euo pipefail` in bash scripts for strict error handling
- Always validate input parameters and required dependencies
- Provide meaningful error messages using `log_error`

#### Logging Standards

- Use centralized logging functions from `logging.zsh`
- Source logging functions at the start of each script
- Provide fallback logging functions if `logging.zsh` unavailable
- Use appropriate log levels: `log_info`, `log_success`, `log_warning`, `log_error`

#### Help and Documentation

- Include `--help` option for all scripts
- Add descriptive comments at the top of each script
- Follow consistent parameter naming conventions
- Document expected environment variables

#### Language-Specific Patterns

**Ruby Scripts (Preferred):**

All new utility scripts should be written in Ruby using the ScriptBase class:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Brief description of what this script does
class MyUtilityScript < ScriptBase
  def banner_text
    "Usage: #{script_name} [OPTIONS] <arguments>"
  end

  def add_custom_options(opts)
    opts.on('-c', '--custom', 'Custom option') do
      @options[:custom] = true
    end
  end

  def validate!
    # Add validation logic here
    super
  end

  def run
    log_banner("Starting #{script_name}")

    # Your script logic here
    log_info("Processing...")

    show_completion(script_name)
  end

  private

  def show_examples
    puts "Examples:"
    puts "  #{script_name} --custom argument"
  end
end

# Execute the script
MyUtilityScript.execute if __FILE__ == $0
```

**Bash Scripts (Legacy - Setup/Backup Only):**

Setup and backup scripts remain in bash during migration period:

```bash
#!/bin/bash
set -euo pipefail

# Source centralized logging
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi
```

**Ruby Script Features:**

- **Automatic Bundler setup** - Gemfile dependencies available automatically
- **Rich terminal UI** - Progress bars, colored output, interactive prompts
- **Comprehensive logging** - Centralized logger with emoji indicators
- **Error handling** - Proper exception handling and exit codes
- **Option parsing** - Standardized help, dry-run, verbose, and force options
- **Platform utilities** - Built-in macOS/Linux detection and system integration
- **Testing support** - RSpec and RuboCop integration for quality assurance

### Integration Benefits

This three-tier scripts system provides several key advantages:

1. **Clear Separation** - Utility vs setup/backup operations have distinct access patterns
2. **Controlled Access** - Setup scripts require intentional Makefile invocation
3. **Interactive Convenience** - Utility scripts available immediately in new shell sessions
4. **Workflow Integration** - Setup scripts integrate seamlessly with automation workflows
5. **Error Handling** - Consistent error checking and user feedback across both tiers
6. **Discoverability** - `list-scripts` provides clear overview of both categories
7. **Extensibility** - Easy to add new scripts following established patterns
8. **Maintainability** - Centralized logging and error handling patterns
9. **Safety** - Setup operations are protected from accidental execution
10. **Flexibility** - Choose the right access pattern based on script purpose

## Directory Structure

The repository is organized with the following structure:

```
/Users/hemantv/zshrc/
├── CLAUDE.md                      # Project documentation and Claude instructions
├── Makefile                       # Installation and setup automation
├── README                         # Repository overview
├── bashrc                         # Bash configuration fallback
├── profile                        # Shell profile settings
├── zshrc                         # Main ZSH configuration entry point
│
├── Core ZSH Configuration Files:
├── logging.zsh                   # Centralized logging functions (loaded first)
├── environment.zsh               # Environment variables and PATH management
├── options.zsh                   # ZSH shell options and settings
├── prompt.zsh                    # Command prompt configuration
├── functions.zsh                 # Custom functions and key bindings
├── aliases.zsh                   # Command aliases and suffix handlers
├── completion.zsh                # Tab completion setup
├── private.zsh                   # User-specific private configurations
│
├── Platform-Specific Files:
├── darwin.zsh                    # macOS-specific configurations
├── linux.zsh                     # Linux-specific configurations
│
├── Application Integration:
├── android.zsh                   # Android development tools
├── claude.zsh                    # Claude AI integration
├── erlang.zsh                    # Erlang development environment
├── fasd.zsh                      # Fast directory navigation
├── git.zsh                       # Git configuration and aliases
├── monorepo.zsh                  # Monorepo development tools
├── rails.zsh                     # Ruby on Rails development
│
├── External Dependencies:
├── zsh-syntax-highlighting/      # Git submodule for command syntax highlighting
│   ├── highlighters/             # Syntax highlighting engines
│   ├── docs/                     # Documentation
│   └── tests/                    # Test suite
├── dircolors-solarized/          # Solarized color scheme for ls command
│   ├── dircolors.*               # Various color scheme variants
│   └── img/                      # Screenshot examples
│
├── Custom Scripts System:
├── bin/                      # Custom utility scripts
│   ├── scripts.zsh               # ZSH wrapper functions for scripts
│   ├── calibre-update.sh         # Calibre e-book manager updater
│   ├── dropbox-backup.sh         # Dropbox backup utility
│   ├── dropbox-backup copy.sh    # Backup script copy
│   ├── macos-optimize.sh         # macOS system optimization
│   ├── merge_pdf.py              # PDF file merger (Python)
│   └── stacked-monitor.rb        # Monitor arrangement utility (Ruby)
│
├── Additional Functions:
├── functions.d/                  # Autocompletion function definitions
│   ├── _autocmd                  # Vim autocmd completion
│   ├── _efa                      # EFA (public transport) completion
│   ├── _mdfind                   # macOS Spotlight completion
│   └── _owcli                    # OpenWhisk CLI completion
│
├── Archived Configuration:
├── byobu/                        # Byobu terminal multiplexer configs
│   ├── color.tmux                # Color scheme
│   ├── datetime.tmux             # Date/time display
│   ├── keybindings.tmux          # Key bindings
│   ├── prompt                    # Prompt configuration
│   ├── windows.tmux              # Window management
│   └── disable-autolaunch        # Autolaunch settings
│
├── Application Settings:
├── Settings/                     # Application-specific configurations
│   ├── Sublime3/                 # Sublime Text 3 settings
│   │   ├── Preferences.sublime-settings
│   │   └── User/                 # User-specific settings
│   ├── XCode/                    # Xcode configuration and simulators
│   │   └── UserData/             # User data including themes and simulators
│   ├── iTerm/                    # iTerm2 terminal settings
│   │   └── com.googlecode.iterm2.plist
│   ├── bitbucket                 # Bitbucket configuration
│   ├── ctags_for_ruby           # Ruby ctags configuration
│   ├── dock.plist               # macOS Dock settings
│   ├── gemrc                    # Ruby gem configuration
│   └── irbrc                    # Interactive Ruby configuration
│
└── Licenses:
    └── licences/                 # Software license files
        ├── License.sublime_license
        └── SizeUp.sizeuplicense
```

### Key Directory Details

#### Core Configuration Flow

The main `zshrc` file sources these files in order:

1. `logging.zsh` → `environment.zsh` → `options.zsh` → `prompt.zsh` → `functions.zsh` → `aliases.zsh`
2. Platform detection: `darwin.zsh` (macOS) or `linux.zsh`
3. Application integrations: `git.zsh`, `rails.zsh`, `claude.zsh`, etc.
4. Completion system: `completion.zsh`
5. Private overrides: `private.zsh`

#### Scripts System (`bin/`)

- **`scripts.zsh`** - Contains wrapper functions for all custom scripts
- **Utility Scripts** - Bash, Python, and Ruby scripts for various system tasks
- **Wrapper Functions** - ZSH functions that provide easy access to scripts with error handling

#### External Dependencies

- **`zsh-syntax-highlighting/`** - Git submodule providing real-time syntax highlighting
- **`dircolors-solarized/`** - Solarized color schemes for directory listings

#### Settings Archive (`Settings/`)

- **`Sublime3/`** - Text editor preferences and packages
- **`XCode/`** - Development environment settings including iOS simulator data
- **`iTerm/`** - Terminal emulator configuration
- **Various config files** - Application-specific settings for development tools

## Style Guidelines

### Function Naming Convention

- Use hyphen-separated names (kebab-case) for ZSH functions and aliases
- **Preferred**: `flutter-studio`
- **Avoid**: `flutter_studio`
- This follows the existing pattern used throughout the configuration (e.g., `kill-port`, `clean-pyc`, `latest-dir`)

### Emoji Usage in Scripts and Output

- **Use emojis liberally** in user-facing messages, status updates, and progress indicators
- **Emojis enhance readability** and make the terminal output more visually appealing
- **Common emoji patterns used in this project**:
  - ✅ Success/completion
  - ❌ Errors/failures
  - ⚠️ Warnings
  - 🔍 Searching/checking
  - 🔄 Updating/processing
  - 📦 Installing/packages
  - 🔗 Linking/connections
  - 🧹 Cleaning/maintenance
  - 🛠️ Tools/utilities
  - 🚀 Starting/launching
  - 📝 Writing/editing
  - 💾 Backing up
  - 🐚 Shell operations
  - 🍺 Homebrew operations
  - 🐙 Git operations
  - 🐍 Python operations
  - 💎 Ruby operations
- **Examples**:
  - `echo "✅ Installation complete"`
  - `echo "🔄 Updating packages..."`
  - `echo "⚠️  Warning: File not found"`

### Color Usage in Terminal Output

- **Combine colors with emojis** for maximum visual impact and user experience
- **Use colors consistently** to establish visual patterns for different message types
- **Color definitions and usage patterns**:
  - **RED** (`\033[0;31m`) - Errors and critical failures
  - **GREEN** (`\033[0;32m`) - Success messages and completions
  - **YELLOW** (`\033[1;33m`) - Warnings and important notices
  - **BLUE** (`\033[0;34m`) - Information and process indicators
  - **MAGENTA** (`\033[0;35m`) - Section headers and categories
  - **CYAN** (`\033[0;36m`) - Progress updates and ongoing operations
  - **BOLD** (`\033[1m`) - Important headings and status messages
  - **NC** (`\033[0m`) - Reset to no color (always use at end)

### Color Implementation Guidelines

- **Always use `-e` flag** with echo when using color codes: `echo -e "$(COLOR)message$(NC)"`
- **Always reset colors** with `$(NC)` at the end of colored text
- **Combine colors and emojis** for maximum effectiveness:

  ```bash
  echo -e "$(BOLD)$(GREEN)✅ Installation complete$(NC)"
  echo -e "$(RED)❌ Error: File not found$(NC)"
  echo -e "$(YELLOW)⚠️  Warning: Backup recommended$(NC)"
  echo -e "$(BLUE)🔍 Searching for files...$(NC)"
  ```

- **Use BOLD for emphasis** on important status messages and headings
- **Keep color usage consistent** across all scripts and makefiles
- **Test color output** in different terminal environments to ensure compatibility

### Using Centralized Logging Functions

**IMPORTANT**: Always use the centralized logging functions defined in `logging.zsh` for consistent output across all scripts and functions.

#### Core Logging Functions

```bash
# Available in ALL ZSH contexts (functions, scripts, aliases):
log_success "Installation completed successfully"     # Green + ✅
log_error "Failed to find required file"            # Red + ❌ (to stderr)
log_warning "Backup recommended before proceeding"   # Yellow + ⚠️
log_info "Checking system requirements"              # Blue + ℹ️
log_progress "Downloading updates"                   # Cyan + 🔄
log_section "System Configuration"                   # Magenta + 🔧
log_debug "Debugging information"                    # Dim + 🐛 (only if DEBUG=1)
```

#### Specialized Logging Functions

```bash
# File operations:
log_file_created "/path/to/file"                    # Green + 📄
log_file_updated "/path/to/file"                    # Blue + 📝
log_file_backed_up "/path/to/file"                  # Cyan + 💾

# System operations:
log_install "package-name"                          # Green + 📦
log_clean "cache files"                             # Cyan + 🧹
log_update "system packages"                        # Blue + 🔄

# Platform-specific:
log_brew "Installing packages"                       # Yellow + 🍺
log_git "Committing changes"                        # Magenta + 🐙
log_python "Running script"                         # Blue + 🐍
log_ruby "Installing gems"                          # Red + 💎
log_macos "System configuration"                    # Blue + 🍎
log_linux "Package installation"                   # Blue + 🐧

# Utility functions:
log_separator                                       # Print separator line
log_complete "Setup process"                        # Celebration message
log_banner "Script Title"                          # Header with separator
```

#### Usage in Bash Scripts

For bash scripts, source the logging functions at the top:

```bash
#!/bin/bash
set -euo pipefail

# Source logging functions
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback definitions if logging.zsh not available
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
fi

# Now use logging functions throughout script
log_info "Starting script execution"
log_success "Script completed successfully"
```

#### Example Usage in Functions

```bash
my_function() {
  log_section "Starting Configuration Process"
  log_info "Checking system requirements"

  if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew found"
    log_brew "Updating package lists"
  else
    log_error "Homebrew not installed"
    return 1
  fi

  log_progress "Installing packages"
  # ... installation logic ...

  log_file_created "/path/to/config"
  log_complete "Configuration process"
}
```

#### Mandatory Usage Rules

- **NEVER use raw `echo` with color codes** - always use logging functions
- **NEVER redefine color constants** - use the ones from `logging.zsh`
- **ALWAYS use `log_error`** for error messages (outputs to stderr)
- **ALWAYS use appropriate semantic functions** (e.g., `log_git` for Git operations)
- **Use `log_debug`** for debug information that should be hidden by default

These functions automatically handle color codes, emojis, proper formatting, and stderr redirection for errors, ensuring consistent visual styling across all scripts.

### Color Scheme Philosophy

- **Visual Hierarchy**: Colors create clear information hierarchy and improve scanability
- **Semantic Consistency**: Each color has specific meaning (red=error, green=success, etc.)
- **Accessibility**: Color choices work in both light and dark terminal themes
- **Performance Feedback**: Colors provide immediate visual feedback for user actions
- **Professional Appearance**: Enhanced terminal output creates a more polished user experience

# Using Gemini CLI for Large Codebase Analysis

When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive
context window. Use `gg -p` to leverage Google Gemini's large context capacity.

## File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the
gemini command:

### Examples

**Single file analysis:**

````bash
gg -p "@src/main.py Explain this file's purpose and structure"

Multiple files:
gg -p "@package.json @src/index.js Analyze the dependencies used in the code"

Entire directory:
gg -p "@src/ Summarize the architecture of this codebase"

Multiple directories:
gg -p "@src/ @tests/ Analyze test coverage for the source code"

Current directory and subdirectories:
gg -p "@./ Give me an overview of this entire project"

#
Or use --all_files flag:
gemini --all_files -p "Analyze the project structure and dependencies"

Implementation Verification Examples

Check if a feature is implemented:
gg -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"

Verify authentication implementation:
gg -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"

Check for specific patterns:
gg -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"

Verify error handling:
gg -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"

Check for rate limiting:
gg -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"

Verify caching strategy:
gg -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"

Check for specific security measures:
gg -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"

Verify test coverage for features:
gg -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"

When to Use Gemini CLI

Use gg -p when:
- Analyzing entire codebases or large directories
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase

Important Notes

- Paths in @ syntax are relative to your current working directory when invoking gemini
- The CLI will include file contents directly in the context
- No need for --yolo flag for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results # Using Gemini CLI for Large Codebase Analysis


When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive
context window. Use `gg -p` to leverage Google Gemini's large context capacity.


## File and Directory Inclusion Syntax


Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the
 gemini command:


### Examples:


**Single file analysis:**
```bash
gg -p "@src/main.py Explain this file's purpose and structure"


Multiple files:
gg -p "@package.json @src/index.js Analyze the dependencies used in the code"


Entire directory:
gg -p "@src/ Summarize the architecture of this codebase"


Multiple directories:
gg -p "@src/ @tests/ Analyze test coverage for the source code"


Current directory and subdirectories:
gg -p "@./ Give me an overview of this entire project"
# Or use --all_files flag:
gg --all_files -p "Analyze the project structure and dependencies"


Implementation Verification Examples


Check if a feature is implemented:
gg -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"


Verify authentication implementation:
gg -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"


Check for specific patterns:
gg -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"


Verify error handling:
gg -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"


Check for rate limiting:
gg -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"


Verify caching strategy:
gg -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"


Check for specific security measures:
gg -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"


Verify test coverage for features:
gg -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"


When to Use Gemini CLI


Use gg -p when:
- Analyzing entire codebases or large directories
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase


Important Notes


- Paths in @ syntax are relative to your current working directory when invoking gemini
- The CLI will include file contents directly in the context
- No need for --yolo flag for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results
```
````
