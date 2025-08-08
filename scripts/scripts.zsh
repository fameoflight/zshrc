# Custom utility scripts and functions
# This file contains wrapper functions for scripts in the scripts/ directory

# Monitor arrangement script for stacked external monitors
stack-monitors() {
  ruby "$ZSH_CONFIG/scripts/stacked-monitor.rb" "$@"
}

# Calibre e-book manager updater
calibre-update() {
  local script_path="$ZSH_CONFIG/scripts/calibre-update.sh"
  
  if [[ ! -f "$script_path" ]]; then
    echo "❌ Calibre update script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    echo "ℹ️  Making calibre-update.sh executable..."
    chmod +x "$script_path"
  fi
  
  bash "$script_path" "$@"
}

# PDF merger script (Python)
merge-pdf() {
  local script_path="$ZSH_CONFIG/scripts/merge_pdf.py"
  
  if [[ ! -f "$script_path" ]]; then
    echo "❌ PDF merge script not found at $script_path"
    return 1
  fi
  
  if [[ $# -eq 0 ]]; then
    echo "Usage: merge-pdf <output.pdf> <input1.pdf> <input2.pdf> [...]"
    echo "       merge-pdf output.pdf *.pdf"
    return 1
  fi
  
  python3 "$script_path" "$@"
}

# macOS system optimization script
macos-optimize() {
  local script_path="$ZSH_CONFIG/scripts/macos-optimize.sh"
  
  if [[ ! -f "$script_path" ]]; then
    echo "❌ macOS optimize script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    echo "ℹ️  Making macos-optimize.sh executable..."
    chmod +x "$script_path"
  fi
  
  bash "$script_path" "$@"
}

# List all available custom scripts
list-scripts() {
  local scripts_dir="$ZSH_CONFIG/scripts"
  
  echo "📜 Available custom scripts in $scripts_dir:"
  echo ""
  
  if [[ -d "$scripts_dir" ]]; then
    for script in "$scripts_dir"/*; do
      if [[ -f "$script" ]]; then
        local basename_script=$(basename "$script")
        local extension="${basename_script##*.}"
        
        case "$extension" in
          sh)
            echo "  🔧 $basename_script (Bash script)"
            ;;
          rb)
            echo "  💎 $basename_script (Ruby script)"
            ;;
          py)
            echo "  🐍 $basename_script (Python script)"
            ;;
          zsh)
            echo "  🐚 $basename_script (ZSH functions)"
            ;;
          *)
            echo "  📄 $basename_script"
            ;;
        esac
        
        # Show first comment line if available
        if [[ "$extension" == "sh" || "$extension" == "rb" || "$extension" == "py" ]]; then
          local desc=$(grep -m1 "^#.*" "$script" 2>/dev/null | head -1 | sed 's/^# *//' | sed 's/^#!//')
          if [[ -n "$desc" && "$desc" != *"bin/"* ]]; then
            echo "     ↳ $desc"
          fi
        fi
      fi
    done
  else
    echo "  ❌ Scripts directory not found"
  fi
  
  echo ""
  echo "🔧 Available script functions:"
  echo "  calibre-update   - Update Calibre to the latest version"
  echo "  stack-monitors   - Configure stacked monitor setup"  
  echo "  merge-pdf        - Merge multiple PDF files"
  echo "  macos-optimize   - Optimize macOS system settings for developers"
  echo "  dropbox-backup   - Move directory to Dropbox with symlink backup"
  echo "  claude-backup    - Backup Claude Code settings to repository"
  echo "  claude-setup     - Setup Claude Code settings from repository backup"
  echo "  list-scripts     - Show this help"
}

# Dropbox backup utility
dropbox-backup() {
  local script_path="$ZSH_CONFIG/scripts/dropbox-backup.sh"
  
  if [[ ! -f "$script_path" ]]; then
    echo "❌ Dropbox backup script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    echo "ℹ️  Making dropbox-backup.sh executable..."
    chmod +x "$script_path"
  fi
  
  bash "$script_path" "$@"
}

# Claude Code settings backup utility
claude-backup() {
  local script_path="$ZSH_CONFIG/scripts/claude-backup.sh"
  
  if [[ ! -f "$script_path" ]]; then
    echo "❌ Claude backup script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    echo "ℹ️  Making claude-backup.sh executable..."
    chmod +x "$script_path"
  fi
  
  bash "$script_path" "$@"
}

# Claude Code settings setup utility
claude-setup() {
  local script_path="$ZSH_CONFIG/scripts/claude-setup.sh"
  
  if [[ ! -f "$script_path" ]]; then
    echo "❌ Claude setup script not found at $script_path"
    return 1
  fi
  
  if [[ ! -x "$script_path" ]]; then
    echo "ℹ️  Making claude-setup.sh executable..."
    chmod +x "$script_path"
  fi
  
  bash "$script_path" "$@"
}