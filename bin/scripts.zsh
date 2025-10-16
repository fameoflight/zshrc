# Custom utility scripts and functions
# This file contains wrapper functions for utility scripts that should be available in ZSH
# Setup/backup scripts are only available via Makefile targets

# Note: Color logging functions are loaded from logging.zsh

# Load Python CLI scripts and functions
if [[ -f "$ZSH_CONFIG/bin/python-cli/scripts.zsh" ]]; then
  source "$ZSH_CONFIG/bin/python-cli/scripts.zsh"
fi

# Load Ruby CLI scripts and functions
if [[ -f "$ZSH_CONFIG/bin/ruby-cli/scripts.zsh" ]]; then
  source "$ZSH_CONFIG/bin/ruby-cli/scripts.zsh"
fi

# Load Rust CLI scripts and functions
if [[ -f "$ZSH_CONFIG/bin/rust-cli/scripts.zsh" ]]; then
  source "$ZSH_CONFIG/bin/rust-cli/scripts.zsh"
fi

# ⚠️  IMPORTANT FOR DEVELOPERS:
# Before creating any new script, ALWAYS read /Users/hemantv/zshrc/bin/SCRIPTS.md
# It contains comprehensive documentation on:
# - Available base classes and utilities
# - Existing services you can reuse
# - Common patterns and best practices
# This will help you avoid duplicating functionality and follow established patterns.

# =============================================================================
# COMMON UTILITY FUNCTIONS
# =============================================================================

# Execute a Rust program with automatic building
_execute_rust_program() {
  local program_name="$1"
  local rust_binary="$ZSH_CONFIG/bin/rust-cli/target/release/rust-cli"
  shift # Remove program name from arguments

  # Build the Rust binary if it doesn't exist
  if [[ ! -f "$rust_binary" ]]; then
    log_info "rust-cli not found. Building with: make rust"
    cd "$ZSH_CONFIG" && make rust
  fi

  if [[ ! -f "$rust_binary" ]]; then
    log_error "rust-cli binary not available after build. Please run: cd $ZSH_CONFIG && make rust"
    return 1
  fi

  # Run the Rust program
  "$rust_binary" "$program_name" "$@"
}


_execute_ink_program() {
  local ink_cli_dir="$INK_CLI"
  local ink_cli_path="$ink_cli_dir/dist/cli.js"

  if [[ ! -d "$ink_cli_dir" ]]; then
    log_error "Ink CLI directory not found at $ink_cli_dir"
    return 1
  fi


  # Store current directory and change to ink-cli directory
  local current_dir="$(pwd)"
  (
    cd "$ink_cli_dir" || return
    # Load NVM and run Node.js commands
    if [ -f "$HOME/.config/nvm/nvm.sh" ]; then
      . "$HOME/.config/nvm/nvm.sh" && nvm use default

      # Run in development mode if DEV=1, otherwise use production mode
      if [[ "$DEV" == "1" ]]; then
        log_info "Running ink-cli in development mode..."
        log_info "current_dir: $current_dir, PWD: $(pwd)"
        ORIGINAL_WORKING_DIR="$current_dir" npm run dev "$@"
      else
        if [[ ! -f "$ink_cli_path" ]]; then
          log_info "Ink CLI not built. Building with: cd ~/zshrc && make ink"
          (
            cd "$ZSH_CONFIG"
            make ink
          )
        fi

        ORIGINAL_WORKING_DIR="$current_dir" npm start "$@"
      fi
    else
      log_error "NVM not found. Please install Node.js via NVM."
      return 1
    fi
  )

  # Return to original directory
  cd "$current_dir"
}

# =============================================================================
# SHELL SCRIPT FUNCTIONS (Available in ZSH)
# =============================================================================

# Calibre e-book manager updater
calibre-update() {
  local script_path="$ZSH_CONFIG/bin/calibre-update.sh"

  if [[ ! -f "$script_path" ]]; then
    log_error "Calibre update script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making calibre-update.sh executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Dropbox backup utility
dropbox-backup() {
  local script_path="$ZSH_CONFIG/bin/dropbox-backup.sh"

  if [[ ! -f "$script_path" ]]; then
    log_error "Dropbox backup script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making dropbox-backup.sh executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Interactive Command Line Interface - ink-cli tool
ink-cli() {
  _execute_ink_program "$@"
}

# Agent documentation setup - convert CLAUDE.md to AGENT.md with symlinks
agent-setup() {
  local script_path="$ZSH_CONFIG/bin/agent-setup.sh"

  if [[ ! -f "$script_path" ]]; then
    log_error "Agent setup script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making agent-setup.sh executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# =============================================================================
# LIST ALL AVAILABLE SCRIPTS
# =============================================================================

# List all available custom scripts and functions
list-scripts() {
  local scripts_dir="$ZSH_CONFIG/bin"

  echo "📜 Custom Scripts Organization:"
  echo ""

  # Show utility scripts available in ZSH
  echo "🐚 ZSH Utility Functions (interactive use):"
  echo " 📚 calibre-update        - Update Calibre to the latest version"
  echo " ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
  echo " 🖋️  ink-cli              - Interactive Command Line Interface with automatic help"
  echo " 🤖 agent-setup          - Convert CLAUDE.md to AGENT.md with symlinks"
  echo ""

  # Show Ruby CLI scripts are loaded from ruby-cli
  echo "💎 Ruby CLI Functions (loaded from ruby-cli/scripts.zsh):"
  echo "   Xcode tools, Game mode, AI/Chat utilities, File utilities"
  echo "   Git utilities, Email utilities, Video processing"
  echo ""

  # Show Python CLI scripts are loaded from python-cli
  echo "🐍 Python CLI Functions (loaded from python-cli/scripts.zsh):"
  echo "   AI/ML Model Inference, Computer Vision, YouTube Processing"
  echo "   Model Management, System utilities"
  echo ""

  # Show setup/backup scripts available via Makefile only
  echo "🔧 Setup/Backup Scripts (Makefile targets only):"
  echo " 🛠️  make macos-optimize - Optimize macOS system settings"
  echo " 🤖 make claude-setup   - Setup Claude Code settings via symlinks"
  echo " 🤖 make gemini-setup   - Setup Gemini settings via symlinks"
  echo " 💾 make vscode-backup  - Backup VS Code essential settings"
  echo " 💾 make xcode-backup   - Backup Xcode essential settings"
  echo " 💾 make iterm-backup   - Backup iTerm2 essential settings"
  echo " ⚙️  make iterm-setup    - Restore iTerm2 settings from backup"
  echo ""

  # Show repository maintenance scripts available via Makefile only
  echo "🧹 Repository Maintenance (Makefile targets only):"
  echo " 🔍 make find-orphans   - Find and report orphaned Makefile targets"
  echo ""

  # Show all script files for reference
  echo "📂 All Script Files in $scripts_dir:"
  if [[ -d "$scripts_dir" ]]; then
    for script in "$scripts_dir"/*; do
      if [[ -f "$script" && $(basename "$script") != "scripts.zsh" ]]; then
        local basename_script=$(basename "$script")
        local extension="${basename_script##*.}"

        case "$extension" in
          sh)
            echo " 🔧 $basename_script"
            ;;
          rb)
            echo " 💎 $basename_script (now in ruby-cli/bin/)"
            ;;
          py)
            echo " 🐍 $basename_script"
            ;;
          *)
            echo " 📄 $basename_script"
            ;;
        esac
      fi
    done
  else
    echo " ❌ Scripts directory not found"
  fi
}

# =============================================================================
# UNIFIED SCRIPTS INTERFACE
# =============================================================================

# Recently used scripts tracking with CSV format
_track_script_usage() {
  local script_name="$1"
  local history_file="$ZSH_CONFIG/.scripts_history"

  # Create history file with CSV header if it doesn't exist
  if [[ ! -f "$history_file" ]]; then
    echo "timestamp,script_name,working_directory" > "$history_file"
  fi

  # Get current timestamp and working directory
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local working_directory=$(pwd)

  # Add new entry directly to the file
  echo "$timestamp,\"$script_name\",\"$working_directory\"" >> "$history_file"

  # Keep only last 100 entries (plus header)
  if [[ -f "$history_file" ]]; then
    head -1 "$history_file" > "${history_file}.tmp"
    tail -n +2 "$history_file" | tail -100 >> "${history_file}.tmp"
    mv "${history_file}.tmp" "$history_file"
  fi
}

# Fuzzy finder integration for script selection
_fuzzy_select_script() {
  # Check if fzf is available
  if ! command -v fzf >/dev/null 2>&1; then
    log_error "fzf not found. Install with: brew install fzf"
    return 1
  fi

  local -a all_scripts
  local zsh_config_dir="${ZSH_CONFIG:-$HOME/.config/zsh}"

  # Collect all available scripts with descriptions and categories

  # Add ZSH utility functions
  if [[ -f "$zsh_config_dir/bin/scripts.zsh" ]]; then
    local -a utility_functions
    utility_functions=($(grep -E '^[a-zA-Z][a-zA-Z0-9_-]*\(\)' "$zsh_config_dir/bin/scripts.zsh" | grep -v '^_' | grep -v '^scripts\(\)' | grep -v '^list-scripts\(\)' | cut -d'(' -f1))

    for func in $utility_functions; do
      all_scripts+=("🐚 $func - ZSH utility function")
    done
  fi

  # Add Ruby CLI functions from ruby-cli
  if [[ -f "$zsh_config_dir/bin/ruby-cli/scripts.zsh" ]]; then
    local -a ruby_functions
    ruby_functions=($(grep -E '^[a-zA-Z][a-zA-Z0-9_-]*\(\)' "$zsh_config_dir/bin/ruby-cli/scripts.zsh" | grep -v '^_' | grep -v '^scripts\(\)' | grep -v '^list-ruby-cli-scripts\(\)' | cut -d'(' -f1))

    for func in $ruby_functions; do
      all_scripts+=("💎 $func - Ruby CLI function")
    done
  fi

  # Add Python CLI functions from python-cli
  if [[ -f "$zsh_config_dir/bin/python-cli/scripts.zsh" ]]; then
    local -a python_functions
    python_functions=($(grep -E '^[a-zA-Z][a-zA-Z0-9_-]*\(\)' "$zsh_config_dir/bin/python-cli/scripts.zsh" | grep -v '^_' | grep -v '^scripts\(\)' | grep -v '^list-python-cli-scripts\(\)' | cut -d'(' -f1))

    for func in $python_functions; do
      all_scripts+=("🐍 $func - Python CLI function")
    done
  fi

  # Add Makefile targets
  if [[ -f "$zsh_config_dir/Makefile" ]]; then
    local -a makefile_targets
    makefile_targets=($(grep -E '^[a-zA-Z][a-zA-Z0-9_-]*:' "$zsh_config_dir/Makefile" | grep -v '^\.PHONY' | cut -d':' -f1 | grep -E '^(macos|claude|gemini|vscode|xcode|iterm|find-orphans)' | head -20))

    for target in $makefile_targets; do
      all_scripts+=("🔧 $target - Makefile target")
    done
  fi

  # Add recently used scripts at the top
  if [[ -f "$zsh_config_dir/.scripts_history" ]]; then
    local -a recent_scripts
    # Skip header and get last 10 unique script names from CSV
    recent_scripts=($(tail -n +2 "$zsh_config_dir/.scripts_history" | cut -d',' -f2 | tail -10 | tac | sort -u))

    for script in $recent_scripts; do
      all_scripts=("⭐ $script - Recently used" "${all_scripts[@]}")
    done
  fi

  # Use fzf to select script
  local selected
  selected=$(printf "%s\n" "${all_scripts[@]}" | fzf \
    --height=20 \
    --layout=reverse \
    --border \
    --prompt="🔍 Select script: " \
    --preview='echo {}' \
    --preview-window=down:1 \
    --header="Tab: select, Enter: run, Esc: cancel")

  if [[ -n "$selected" ]]; then
    # Extract script name from selection
    local script_name=$(echo "$selected" | sed -E 's/^[🐚💎🐍🔧⭐] ([^ ]+) -.*/\1/')
    echo "$script_name"
  fi
}

# Unified scripts function - provides clean interface to all scripts
scripts() {
  local script_name="$1"
  shift  # Remove script name from arguments

  # Interactive fuzzy finder if no arguments
  if [[ -z "$script_name" ]]; then
    script_name=$(_fuzzy_select_script)
    [[ -z "$script_name" ]] && return 0  # User cancelled
    log_info "Selected: $script_name"
  fi

  # Show help if --help
  if [[ "$script_name" == "--help" ]] || [[ "$script_name" == "-h" ]]; then
    echo -e "\033[1m\033[0;36m📜 Scripts Interface\033[0m"
    echo ""
    echo -e "\033[1mUSAGE:\033[0m"
    echo " scripts                     Interactive fuzzy finder (fzf)"
    echo " scripts --help              Show this help"
    echo " scripts --list              Show all available scripts"
    echo " scripts --recent            Show recently used scripts"
    echo " scripts make                Show Makefile help (make targets)"
    echo " scripts <script> [args...]  Run a script with arguments"
    echo ""
    echo -e "\033[1m🐚 Available ZSH Utility Functions:\033[0m"
    echo " 📚 calibre-update        - Update Calibre to the latest version"
    echo " ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
    echo " 🖋️  ink-cli              - Interactive Command Line Interface with automatic help"
    echo " 🤖 agent-setup          - Convert CLAUDE.md to AGENT.md with symlinks"
    echo ""
    echo -e "\033[1m💎 Ruby CLI Functions (from ruby-cli):\033[0m"
    echo " Xcode tools, Game mode, AI/Chat, File utilities, Git tools"
    echo " Email, Video processing, System utilities"
    echo ""
    echo -e "\033[1m🐍 Python CLI Functions (from python-cli):\033[0m"
    echo " AI/ML Model Inference, Computer Vision, YouTube processing"
    echo " Model Management, System utilities"
    echo ""
    echo -e "\033[1m🔧 Setup/Backup Scripts (via Makefile):\033[0m"
    echo " 🛠️  macos-optimize       - Optimize macOS system settings"
    echo " 🖥️  macos-oled-optimize  - Optimize macOS for OLED displays"
    echo " 🤖 claude-setup         - Setup Claude Code settings"
    echo " 🤖 gemini-setup         - Setup Gemini CLI settings"
    echo " 💾 vscode-backup        - Backup VS Code settings"
    echo " 💾 xcode-backup         - Backup Xcode settings"
    echo " 💾 iterm-backup         - Backup iTerm2 settings"
    echo " ⚙️  iterm-setup          - Restore iTerm2 settings"
    echo ""
    echo -e "\033[1mEXAMPLES:\033[0m"
    echo " scripts                               # Interactive fuzzy finder"
    echo " scripts --recent                      # Show recently used scripts"
    echo " scripts make                          # Show all Makefile targets"
    echo " scripts calibre-update               # Update Calibre"
    echo " scripts dropbox-backup ~/Documents    # Backup to Dropbox"
    echo " scripts ink-cli                        # Interactive CLI tool"
    echo " scripts game-mode on                  # Ruby: Enable game mode"
    echo " scripts xcode-add-file MyFile.swift  # Ruby: Add to Xcode project"
    echo " scripts upscale-image photo.jpg      # Python: Upscale image"
    echo " scripts agent-setup                   # Shell: Setup agent docs"
    echo ""
    return 0
  fi

  # Show list if --list
  if [[ "$script_name" == "--list" ]] || [[ "$script_name" == "-l" ]]; then
    list-scripts
    return 0
  fi

  # Show recently used scripts
  if [[ "$script_name" == "--recent" ]] || [[ "$script_name" == "-r" ]]; then
    echo -e "\033[1m\033[0;36m⭐ Recently Used Scripts\033[0m"
    echo ""
    if [[ -f "$ZSH_CONFIG/.scripts_history" ]]; then
      echo "Last 20 scripts used:"
      # Skip header and format the CSV output
      tail -n +2 "$ZSH_CONFIG/.scripts_history" | tail -20 | awk -F',' '
      {
        timestamp = $1
        script = $2
        working_dir = $3

        # Remove quotes from fields
        gsub(/"/, "", script)
        gsub(/"/, "", working_dir)

        # Format timestamp for display
        gsub(/T/, " ", timestamp)
        gsub(/Z/, "", timestamp)

        printf "  \033[0;33m%d.\033[0m %s (\033[0;36m%s\033[0m)\n", NR, script, timestamp
        printf "    \033[0;37m📁 %s\033[0m\n", working_dir
      }'
    else
      echo "No script usage history found"
    fi
    echo ""
    echo "💡 Run any script to start tracking usage"
    return 0
  fi

  # Show Makefile help if make
  if [[ "$script_name" == "make" ]]; then
    echo -e "\033[0;34mℹ️  Running: make help from $ZSH_CONFIG\033[0m"
    cd "$ZSH_CONFIG" && make help
    return $?
  fi

  # First, check if it's a ZSH utility function
  local shell_functions=(
    "calibre-update" "dropbox-backup" "ink-cli" "agent-setup"
  )

  for func in "${shell_functions[@]}"; do
    if [[ "$script_name" == "$func" ]]; then
      # Track usage before execution
      _track_script_usage "$script_name"
      # Call the function directly with all arguments
      "$script_name" "$@"
      return $?
    fi
  done

  # Check if it's a setup/backup script (run via Makefile)
  local makefile_scripts=(
    "macos-optimize" "macos-oled-optimize" "claude-setup" "gemini-setup"
    "vscode-backup" "xcode-backup" "iterm-backup" "iterm-setup" "find-orphans"
  )

  for script in "${makefile_scripts[@]}"; do
    if [[ "$script_name" == "$script" ]]; then
      # Track usage before execution
      _track_script_usage "$script_name"
      echo -e "\033[0;34mℹ️  Running Makefile target: make $script_name $*\033[0m"
      cd "$ZSH_CONFIG" && make "$script_name" "$@"
      return $?
    fi
  done

  # Check if it's a raw script file in bin/
  local script_path="$ZSH_CONFIG/bin/$script_name"
  if [[ -f "$script_path" ]] && [[ -x "$script_path" ]]; then
    # Track usage before execution
    _track_script_usage "$script_name"
    echo -e "\033[0;34mℹ️  Running script: $script_path $*\033[0m"

    # Determine how to execute based on file extension
    case "$script_path" in
      *.sh)
        bash "$script_path" "$@"
        ;;
      *.applescript)
        osascript "$script_path" "$@"
        ;;
      *)
        "$script_path" "$@"
        ;;
    esac
    return $?
  fi

  # If we get here, script wasn't found
  echo -e "\033[0;31m❌ Script '$script_name' not found\033[0m"
  echo ""
  echo "Available scripts:"
  scripts --help | grep -E "^  [🔧🛠️💾⚙️📚🖥️📄📝☁️🗑️🔍🔄🤖📥📹🎤🌐]"
  return 1
}