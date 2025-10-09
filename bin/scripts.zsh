# Custom utility scripts and functions
# This file contains wrapper functions for utility scripts that should be available in ZSH
# Setup/backup scripts are only available via Makefile targets

# Note: Color logging functions are loaded from logging.zsh

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

# Execute a Ruby script with proper bundle setup and error handling
_execute_ruby_script() {
  local script_name="$1"
  local script_path="$ZSH_CONFIG/bin/$1"
  shift # Remove script name from arguments

  if [[ ! -f "$script_path" ]]; then
    log_error "$script_name not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making $script_name executable..."
    chmod +x "$script_path"
  fi

  # Store the current working directory and change to script's directory
  local current_dir="$(pwd)"
  (
    cd "$ZSH_CONFIG" || return
    ORIGINAL_WORKING_DIR="$current_dir" bundle exec ruby "bin/$script_name" "$@"
  )
}

# Execute a Rust program with automatic building
_execute_rust_program() {
  local program_name="$1"
  local rust_binary="$ZSH_CONFIG/bin/rust/target/release/utils"
  shift # Remove program name from arguments

  # Build the Rust binary if it doesn't exist
  if [[ ! -f "$rust_binary" ]]; then
    log_info "Rust utils not found. Building with: make rust"
    cd "$ZSH_CONFIG" && make rust
  fi

  if [[ ! -f "$rust_binary" ]]; then
    log_error "Rust utils binary not available after build. Please run: cd $ZSH_CONFIG && make rust"
    return 1
  fi

  # Run the Rust program
  "$rust_binary" "$program_name" "$@"
}

_execute_ink_program() {
  local ink_cli_dir="$ZSH_CONFIG/bin/ink-cli"
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
# UTILITY SCRIPT FUNCTIONS (Available in ZSH)
# =============================================================================

# Monitor arrangement script for stacked external monitors
stack-monitors() {
  _execute_ruby_script "stacked-monitor.rb" "$@"
}

# Game mode script - enable only LG OLED monitor with HDR
game-mode() {
  # Handle simple on/off commands intuitively
  case "${1:-}" in
    on)
      shift
      _execute_ruby_script "game-mode.rb" "$@"
      ;;
    off)
      shift
      _execute_ruby_script "game-mode.rb" --restore "$@"
      ;;
    *)
      _execute_ruby_script "game-mode.rb" "$@"
      ;;
  esac
}

# Test LLM element detection functionality
test-llm-detection() {
  _execute_ruby_script "test-llm-detection.rb" "$@"
}

# YouTube transcript chat - Download transcripts and chat with video content
youtube-transcript-chat() {
  _execute_ruby_script "youtube-transcript-chat.rb" "$@"
}

# Alias for easier access
yt-chat() {
  youtube-transcript-chat "$@"
}

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

# PDF merger script (Ruby)
merge-pdf() {
  _execute_ruby_script "merge-pdf.rb" "$@"
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

# Application uninstaller - comprehensive removal of apps, processes, and files
uninstall-app() {
  _execute_ruby_script "uninstall-app.rb" "$@"
}

# Comment-only changes detector - identify low-risk comment changes for safe commits
comment-only-changes() {
  _execute_ruby_script "comment-only-changes.rb" "$@"
}

# Markdown file merger - merge markdown files with their references into a single file
merge-md() {
  _execute_ruby_script "merge-markdown.rb" "$@"
}

# Git commit pure renames - commits only R100 renames after user confirmation
git-commit-renames() {
  _execute_ruby_script "git-commit-renames.rb" "$@"
}

# Git commit deletes - commits only deletions (D) after user confirmation
git-commit-deletes() {
  _execute_ruby_script "git-commit-deletes.rb" "$@"
}

# Git commit directory - stage and commit changes in a specific directory
git-commit-dir() {
  _execute_ruby_script "git-commit-dir.rb" "$@"
}

# Git compress - compress git history to single initial commit
git-compress() {
  _execute_ruby_script "git-compress.rb" "$@"
}



# Gmail inbox fetcher
gmail-inbox() {
  _execute_ruby_script "gmail-inbox.rb" "$@"
}

# Camera & microphone usage checker
check-camera-mic() {
  _execute_ruby_script "check-camera-mic.rb" "$@"
}

# Interactive Command Line Interface - ink-cli tool
ink-cli() {
  _execute_ink_program "$@"
}

# Image upscaling utility - AI-powered image upscaling
upscale-image() {
  local script_path="$ZSH_CONFIG/bin/upscale-image"

  if [[ ! -f "$script_path" ]]; then
    log_error "upscale-image script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making upscale-image executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Video upscaling utility - AI-powered video upscaling with selective frame processing
upscale-video() {
  local script_path="$ZSH_CONFIG/bin/upscale-video"

  if [[ ! -f "$script_path" ]]; then
    log_error "upscale-video script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making upscale-video executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Video clipping utility - Extract clips from videos using FFmpeg
clip-video() {
  _execute_ruby_script "clip-video.rb" "$@"
}

# Website URL extractor and EPUB creator
website-epub() {
  _execute_ruby_script "website-epub.rb" "$@"
}

# Safari reading list to EPUB converter
safari-epub() {
  _execute_ruby_script "safari-epub.rb" "$@"
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

# Spotlight indexing management - control macOS Spotlight settings
spotlight-manage() {
  _execute_ruby_script "spotlight-manage.rb" "$@"
}

# LLM command and script generator - create commands/scripts from natural language
llm-generate() {
  _execute_ruby_script "llm-generate.rb" "$@"
}

# Auto-retry utility that uses local LLM to analyze command failures and determine retry strategies
auto-retry() {
  _execute_ruby_script "auto-retry.rb" "$@"
}

# Human detection utility using YOLOv8 models
detect-human() {
  local script_path="$ZSH_CONFIG/bin/detect-human"

  if [[ ! -f "$script_path" ]]; then
    log_error "detect-human script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making detect-human script executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Similar image search using computer vision
find-similar-images() {
  local script_path="$ZSH_CONFIG/bin/find-similar-images.py"

  if [[ ! -f "$script_path" ]]; then
    log_error "Similar image search script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making find-similar-images.py executable..."
    chmod +x "$script_path"
  fi

  python3 "$script_path" "$@"
}

# Find duplicate images in a folder
find-duplicate-images() {
  local script_path="$ZSH_CONFIG/bin/find-duplicate-images.py"

  if [[ ! -f "$script_path" ]]; then
    log_error "Duplicate image finder script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making find-duplicate-images.py executable..."
    chmod +x "$script_path"
  fi

  python3 "$script_path" "$@"
}

# Disk usage analyzer - Fast analysis of du output
disk-usage() {
  local input="$1"

  if [[ -z "$input" ]]; then
    log_error "Usage: disk-usage <directory_or_file>"
    return 1
  fi

  # If input is a directory, create du output file and pass to Rust program
  if [[ -d "$input" ]]; then
    log_info "Analyzing directory: $input"
    local temp_file="/tmp/du_output_$(date +%s).txt"

    # Generate du output
    du "$input" > "$temp_file"
    if [[ $? -ne 0 ]]; then
      log_error "Failed to run du on directory: $input"
      return 1
    fi

    # Call Rust program with the generated file
    _execute_rust_program "disk-usage" "$temp_file" "${@:2}"

    # Cleanup temp file
    rm -f "$temp_file"
  else
    # Input is a file, pass directly to Rust program
    _execute_rust_program "disk-usage" "$@"
  fi
}

# =============================================================================
# XCODE PROJECT MANAGEMENT
# =============================================================================

# Add file to Xcode project with automatic category detection
xcode-add-file() {
  _execute_ruby_script "xcode-add-file.rb" "$@"
}

# View files in Xcode project, optionally filtered by category
xcode-view-files() {
  _execute_ruby_script "xcode-view-files.rb" "$@"
}

# Remove file from Xcode project and filesystem
xcode-delete-file() {
  _execute_ruby_script "xcode-delete-file.rb" "$@"
}

# List available file categories for Xcode project organization
xcode-list-categories() {
  _execute_ruby_script "xcode-list-categories.rb" "$@"
}

# Generate app icons for Xcode projects with customizable themes
xcode-icon-generator() {
  _execute_ruby_script "xcode-icon-generator.rb" "$@"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# List all available custom scripts and functions
list-scripts() {
  local scripts_dir="$ZSH_CONFIG/bin"
  
  echo "📜 Custom Scripts Organization:"
  echo ""
  
  # Show utility scripts available in ZSH
  echo "🐚 ZSH Utility Functions (interactive use):"
  echo " 📚 calibre-update        - Update Calibre to the latest version"
  echo " 🖥️  stack-monitors        - Configure stacked monitor setup"
  echo " 🎮 game-mode            - Toggle game mode (on/off) for gaming displays"
  echo " 📄 merge-pdf             - Merge multiple PDF files"
  echo " 📝 merge-md              - Merge markdown files with their references into a single file"
  echo " 🎥 youtube-transcript-chat - Download YouTube transcripts and chat with video content using local LLM"
  echo " 🎬 yt-chat               - Alias for youtube-transcript-chat"
  echo " ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
  echo " 🗑️  uninstall-app         - Comprehensive application uninstaller"
  echo " 🔍 comment-only-changes  - Detect files with only comment changes for low-risk commits"
  echo " 🔄 git-commit-renames    - Commit only pure renames (R100) after user confirmation"
  echo " 🗑️  git-commit-deletes    - Commit only deletions (D) after user confirmation"
  echo " 📁 git-commit-dir        - Stage and commit changes in a specific directory"
  echo " 📥 gmail-inbox           - Fetch and manage Gmail inbox"
  echo " 📹🎤 check-camera-mic     - Check which apps are using camera or microphone"
  echo " 🖋️  ink-cli              - Interactive Command Line Interface with automatic help"
  echo " 🌐 website-epub         - Extract all HTTP/HTTPS URLs from a website"
  echo " 🧭 safari-epub          - Convert Safari reading list to EPUB"
  echo " 🤖 agent-setup          - Convert CLAUDE.md to AGENT.md with symlinks"
  echo " 🤖 llm-generate          - Generate commands and scripts using local LLM"
  echo " 🔄 auto-retry            - Auto-retry failed commands with LLM analysis"
  echo " 🖼️  upscale-image        - Upscale images using PyTorch models with CoreML"
  echo " 🎬 clip-video            - Extract clips from videos using FFmpeg"
  echo " 👤 detect-human          - Detect humans in images using YOLOv8"
  echo " 🔍 find-similar-images  - Find similar images using computer vision"
  echo " 🔄 find-duplicate-images - Find duplicate images in a folder"
  echo " 📱 xcode-add-file        - Add file to Xcode project with category detection"
  echo " 📱 xcode-view-files      - View files in Xcode project by category"
  echo " 📱 xcode-delete-file     - Remove file from Xcode project and filesystem"
  echo " 📱 xcode-list-categories - List available Xcode file categories"
  echo " 🎨 xcode-icon-generator  - Generate app icons for Xcode projects"
  echo " 📜 list-scripts          - Show this help"
  echo "  📚 calibre-update        - Update Calibre to the latest version"
  echo "  🖥️  stack-monitors        - Configure stacked monitor setup"
  echo "  📄 merge-pdf             - Merge multiple PDF files"
  echo "  📝 merge-md              - Merge markdown files with their references into a single file"
  echo "  🎥 youtube-transcript-chat - Download YouTube transcripts and chat with video content using local LLM"
  echo "  🎬 yt-chat               - Alias for youtube-transcript-chat"
  echo "  ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
  echo "  🗑️  uninstall-app         - Comprehensive application uninstaller"
  echo "  🔍 comment-only-changes  - Detect files with only comment changes for low-risk commits"
  echo "  🔄 git-commit-renames    - Commit only pure renames (R100) after user confirmation"
  echo "  🗑️  git-commit-deletes    - Commit only deletions (D) after user confirmation"
  echo "  📥 gmail-inbox           - Fetch and manage Gmail inbox"
  echo "  📹🎤 check-camera-mic     - Check which apps are using camera or microphone"
  echo "  🖋️  ink-cli              - Interactive Command Line Interface with automatic help"
  echo "  🌐 website-epub         - Extract all HTTP/HTTPS URLs from a website"
  echo "  🧭 safari-epub          - Convert Safari reading list to EPUB"
  echo "  🤖 agent-setup          - Convert CLAUDE.md to AGENT.md with symlinks"
  echo "  🤖 llm-generate          - Generate commands and scripts using local LLM"
  echo "  🔄 auto-retry            - Auto-retry failed commands with LLM analysis"
  echo "  📜 list-scripts          - Show this help"
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
            echo " 💎 $basename_script"
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
    local script_name=$(echo "$selected" | sed -E 's/^[🐚🔧⭐] ([^ ]+) -.*/\1/')
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
    echo " 🖥️  stack-monitors        - Configure stacked monitor setup"
  echo " 🎮 game-mode            - Toggle game mode (on/off) for gaming displays"
    echo " 📄 merge-pdf             - Merge multiple PDF files"
    echo " 📝 merge-md              - Merge markdown files with their references"
    echo " ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
    echo " 🗑️  uninstall-app         - Comprehensive application uninstaller"
    echo " 🔍 comment-only-changes  - Detect files with only comment changes"
    echo " 🔄 git-commit-renames    - Commit only pure renames after confirmation"
    echo " 🗑️  git-commit-deletes    - Commit only deletions after confirmation"
    echo " 📁 git-commit-dir        - Stage and commit changes in a specific directory"
    echo " 📥 gmail-inbox           - Fetch and manage Gmail inbox"
    echo " 📹🎤 check-camera-mic     - Check which apps are using camera/microphone"
    echo " 🌐 website-epub         - Extract all HTTP/HTTPS URLs from a website"
    echo " 🧭 safari-epub          - Convert Safari reading list to EPUB"
    echo " 🤖 agent-setup          - Convert CLAUDE.md to AGENT.md with symlinks"
    echo " 🔍 spotlight-manage     - Manage macOS Spotlight indexing settings"
    echo " 🤖 llm-generate          - Generate commands and scripts using local LLM"
    echo " 👤 detect-human          - Detect humans in images using YOLOv8"
    echo " 🔍 find-similar-images  - Find similar images using computer vision"
    echo " 🔄 find-duplicate-images - Find duplicate images in a folder"
    echo " 📱 xcode-add-file        - Add file to Xcode project with category detection"
    echo " 📱 xcode-view-files      - View files in Xcode project by category"
    echo " 📱 xcode-delete-file     - Remove file from Xcode project and filesystem"
    echo " 📱 xcode-list-categories - List available Xcode file categories"
    echo " 🎨 xcode-icon-generator  - Generate app icons for Xcode projects"
    echo "  📚 calibre-update        - Update Calibre to the latest version"
    echo "  🖥️  stack-monitors        - Configure stacked monitor setup"
    echo "  🎮 game-mode            - Enable game mode (LG OLED only with HDR)"
    echo "  📄 merge-pdf             - Merge multiple PDF files"
    echo "  📝 merge-md              - Merge markdown files with their references"
    echo "  ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
    echo "  🗑️  uninstall-app         - Comprehensive application uninstaller"
    echo "  🔍 comment-only-changes  - Detect files with only comment changes"
    echo "  🔄 git-commit-renames    - Commit only pure renames after confirmation"
    echo "  🗑️  git-commit-deletes    - Commit only deletions after confirmation"
    echo "  📥 gmail-inbox           - Fetch and manage Gmail inbox"
    echo "  📹🎤 check-camera-mic     - Check which apps are using camera/microphone"
    echo "  🌐 website-epub         - Extract all HTTP/HTTPS URLs from a website"
    echo "  🧭 safari-epub          - Convert Safari reading list to EPUB"
    echo "  🤖 agent-setup          - Convert CLAUDE.md to AGENT.md with symlinks"
    echo "  🔍 spotlight-manage     - Manage macOS Spotlight indexing settings"
    echo "  🤖 llm-generate          - Generate commands and scripts using local LLM"
    echo "  🔄 auto-retry            - Auto-retry failed commands with LLM analysis"
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
    echo " scripts merge-pdf output.pdf *.pdf    # Merge PDF files"
    echo " scripts stack-monitors --dry-run      # Test monitor setup"
    echo " scripts game-mode on                  # Enable game mode for gaming"
    echo " scripts game-mode off                 # Restore all monitors"
    echo " scripts spotlight-manage --status     # Check Spotlight status"
    echo " scripts uninstall-app Docker          # Uninstall application"
    echo " scripts macos-optimize --dry-run      # Preview macOS optimizations"
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
  local utility_functions=(
    "calibre-update" "stack-monitors" "game-mode" "merge-pdf" "merge-md" "dropbox-backup"
    "uninstall-app" "comment-only-changes" "git-commit-renames" "git-commit-deletes" "git-commit-dir"
    "gmail-inbox" "check-camera-mic" "ink-cli" "website-epub" "safari-epub"
    "agent-setup" "spotlight-manage" "llm-generate" "auto-retry" "upscale-image" "detect-human" "find-similar-images" "find-duplicate-images"
    "xcode-add-file" "xcode-view-files" "xcode-delete-file" "xcode-list-categories" "xcode-icon-generator"
  )
  
  for func in "${utility_functions[@]}"; do
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
      *.rb)
        BUNDLE_GEMFILE="$ZSH_CONFIG/Gemfile" ruby "$script_path" "$@"
        ;;
      *.py)
        python3 "$script_path" "$@"
        ;;
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