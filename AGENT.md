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

The repository includes a custom scripts system located in the `scripts/` directory with wrapper functions in `scripts/scripts.zsh`.

### Available Custom Scripts

- **`calibre-update`** - Update Calibre e-book manager to the latest version

  - Usage: `calibre-update [--help] [--version] [--no-launch]`
  - Automatically downloads, installs, and launches the latest Calibre
  - Includes backup of existing installation and proper error handling

- **`stack-monitors`** - Configure stacked external monitor setup

  - Usage: `stack-monitors [--dry-run] [--debug]`
  - Configures non-16" primary monitor with two stacked 16" monitors
  - Uses `displayplacer` tool for precise monitor arrangement

- **`merge-pdf`** - Merge multiple PDF files into one

  - Usage: `merge-pdf output.pdf input1.pdf input2.pdf [...]`
  - Python-based PDF merging utility

- **`list-scripts`** - Display all available custom scripts and functions
  - Shows scripts in the `scripts/` directory with descriptions
  - Lists available wrapper functions and their usage

### Adding New Scripts

To add new custom scripts:

1. **Create the script** in `scripts/` directory (e.g., `scripts/my-script.sh`)
2. **Make it executable**: `chmod +x scripts/my-script.sh`
3. **Add wrapper function** in `scripts/scripts.zsh`:

   ```zsh
   my-script() {
     local script_path="$ZSH_CONFIG/scripts/my-script.sh"
     bash "$script_path" "$@"
   }
   ```

4. **Test the function**: The wrapper will be available after reloading the shell
5. **Update `list-scripts`** function if needed to include new functionality

### Script Guidelines

- Use proper error handling and validation
- Include help options (`--help`, `-h`)
- Follow the kebab-case naming convention for wrapper functions
- Include descriptive comments at the top of scripts
- Use modern shell scripting practices (`set -euo pipefail` for bash)
- Add appropriate logging with emoji indicators for better UX

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
├── scripts/                      # Custom utility scripts
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

#### Scripts System (`scripts/`)

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
