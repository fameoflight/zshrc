# Custom utility scripts and functions
# This file contains wrapper functions for utility scripts that should be available in ZSH
# Setup/backup scripts are only available via Makefile targets

# Note: Color logging functions are loaded from logging.zsh

# =============================================================================
# UTILITY SCRIPT FUNCTIONS (Available in ZSH)
# =============================================================================

# Monitor arrangement script for stacked external monitors
stack-monitors() {
  ruby "$ZSH_CONFIG/scripts/stacked-monitor.rb" "$@"
}

# Calibre e-book manager updater
calibre-update() {
  local script_path="$ZSH_CONFIG/scripts/calibre-update.sh"
  
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
  local script_path="$ZSH_CONFIG/scripts/merge-pdf.rb"
  
  if [[ ! -f "$script_path" ]]; then
    log_error "PDF merge script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    log_info "Making merge-pdf.rb executable..."
    chmod +x "$script_path"
  fi
  
  # Set BUNDLE_GEMFILE to use project gems
  BUNDLE_GEMFILE="$ZSH_CONFIG/Gemfile" ruby "$script_path" "$@"
}

# Dropbox backup utility
dropbox-backup() {
  local script_path="$ZSH_CONFIG/scripts/dropbox-backup.sh"
  
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
  local script_path="$ZSH_CONFIG/scripts/uninstall-app.rb"
  
  if [[ ! -f "$script_path" ]]; then
    log_error "Uninstall app script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    log_info "Making uninstall-app.rb executable..."
    chmod +x "$script_path"
  fi
  
  # Set BUNDLE_GEMFILE to use project gems
  BUNDLE_GEMFILE="$ZSH_CONFIG/Gemfile" ruby "$script_path" "$@"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# List all available custom scripts and functions
list-scripts() {
  local scripts_dir="$ZSH_CONFIG/scripts"
  
  echo "📜 Custom Scripts Organization:"
  echo ""
  
  # Show utility scripts available in ZSH
  echo "🐚 ZSH Utility Functions (interactive use):"
  echo "  📚 calibre-update   - Update Calibre to the latest version"
  echo "  🖥️  stack-monitors   - Configure stacked monitor setup"  
  echo "  📄 merge-pdf        - Merge multiple PDF files"
  echo "  ☁️  dropbox-backup   - Move directory to Dropbox with symlink backup"
  echo "  🗑️  uninstall-app    - Comprehensive application uninstaller"
  echo "  📜 list-scripts     - Show this help"
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
