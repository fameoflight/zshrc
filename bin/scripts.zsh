# Custom utility scripts and functions
# This file contains wrapper functions for utility scripts that should be available in ZSH
# Setup/backup scripts are only available via Makefile targets

# Note: Color logging functions are loaded from logging.zsh

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
  
  # Change to the script's directory and use bundle exec
  (
    cd "$ZSH_CONFIG" || return
    bundle exec ruby "bin/$script_name" "$@"
  )
}

# =============================================================================
# UTILITY SCRIPT FUNCTIONS (Available in ZSH)
# =============================================================================

# Monitor arrangement script for stacked external monitors
stack-monitors() {
  _execute_ruby_script "stacked-monitor.rb" "$@"
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

# Claude-Gemini integration - run Claude Code with Gemini API via proxy
claude-gemini() {
  local script_path="$ZSH_CONFIG/bin/claude-gemini.sh"
  
  if [[ ! -f "$script_path" ]]; then
    log_error "Claude-Gemini script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    log_info "Making claude-gemini.sh executable..."
    chmod +x "$script_path"
  fi
  
  bash "$script_path" "$@"
}

# Gmail inbox fetcher
gmail-inbox() {
  _execute_ruby_script "gmail-inbox.rb" "$@"
}

# Camera & microphone usage checker
check-camera-mic() {
  _execute_ruby_script "check-camera-mic.rb" "$@"
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
  echo "  📚 calibre-update        - Update Calibre to the latest version"
  echo "  🖥️  stack-monitors        - Configure stacked monitor setup"  
  echo "  📄 merge-pdf             - Merge multiple PDF files"
  echo "  📝 merge-md              - Merge markdown files with their references into a single file"
  echo "  ☁️  dropbox-backup        - Move directory to Dropbox with symlink backup"
  echo "  🗑️  uninstall-app         - Comprehensive application uninstaller"
  echo "  🔍 comment-only-changes  - Detect files with only comment changes for low-risk commits"
  echo "  🔄 git-commit-renames    - Commit only pure renames (R100) after user confirmation"
  echo "  🗑️  git-commit-deletes    - Commit only deletions (D) after user confirmation"
  echo "  🤖 claude-gemini         - Run Claude Code with Gemini API via proxy"
  echo "  📥 gmail-inbox           - Fetch and manage Gmail inbox"
  echo "  📹🎤 check-camera-mic     - Check which apps are using camera or microphone"
  echo "  📜 list-scripts          - Show this help"
  echo ""
  
  # Show setup/backup scripts available via Makefile only
  echo "🔧 Setup/Backup Scripts (Makefile targets only):"
  echo "  🛠️  make macos-optimize - Optimize macOS system settings"
  echo "  🤖 make claude-setup   - Setup Claude Code settings via symlinks"
  echo "  🤖 make gemini-setup   - Setup Gemini settings via symlinks"
  echo "  🤖 make agent-setup    - Convert CLAUDE.md to AGENT.md with symlinks"
  echo "  💾 make vscode-backup  - Backup VS Code essential settings"
  echo "  💾 make xcode-backup   - Backup Xcode essential settings"
  echo "  💾 make iterm-backup   - Backup iTerm2 essential settings"
  echo "  ⚙️  make iterm-setup    - Restore iTerm2 settings from backup"
  echo ""

  # Show repository maintenance scripts available via Makefile only
  echo "🧹 Repository Maintenance (Makefile targets only):"
  echo "  🔍 make find-orphans   - Find and report orphaned Makefile targets"
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
            echo "  🔧 $basename_script"
            ;;
          rb)
            echo "  💎 $basename_script"
            ;;
          py)
            echo "  🐍 $basename_script"
            ;;
          *)
            echo "  📄 $basename_script"
            ;;
        esac
      fi
    done
  else
    echo "  ❌ Scripts directory not found"
  fi
}