#!/bin/bash

# Troubleshooting and Maintenance Script
# Handles Homebrew fixes, system diagnostics, and maintenance tasks

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Check Full Disk Access permissions (macOS)
check_full_disk_access() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return 0  # Not macOS, skip check
    fi

    if command -v log_info >/dev/null 2>&1; then
        log_info "Checking Full Disk Access permissions..."
    else
        echo "🔐 Checking Full Disk Access permissions..."
    fi

    # Try to access a protected file to test permissions
    local test_file="/Library/Preferences/com.apple.systempreferences.plist"

    if [[ -r "$test_file" ]]; then
        if command -v log_success >/dev/null 2>&1; then
            log_success "Full Disk Access granted"
        else
            echo "✅ Full Disk Access granted"
        fi
        return 0
    else
        if command -v log_warning >/dev/null 2>&1; then
            log_warning "Full Disk Access not granted"
        else
            echo "⚠️  Full Disk Access not granted"
        fi

        echo ""
        echo "🔒 Your terminal needs Full Disk Access to configure macOS settings."
        echo ""
        echo "📋 Quick Setup:"
        echo "  1. Open: System Settings → Privacy & Security → Full Disk Access"
        echo "  2. Click the 🔒 lock and enter your password"
        echo "  3. Click '+' and add: $(basename "$SHELL") or iTerm2"
        echo "  4. Ensure it's checked (✅)"
        echo "  5. Restart your terminal and run the command again"
        echo ""
        echo "💡 Alternative: Grant access to your terminal app (iTerm2, Terminal.app, etc.)"
        echo ""

        # Try to open System Settings automatically
        if command -v open >/dev/null 2>&1; then
            echo "🔍 Opening Privacy & Security settings..."
            open "x-apple.systempreferences:com.apple.preference.security?Privacy_Disk"
        fi

        return 1
    fi
}

# Fix Homebrew permissions and issues
fix_brew_permissions() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Fixing Homebrew permissions..."
    else
        echo "🔒 Fixing permissions..."
    fi

    if [[ -d "/usr/local" ]] && [[ -w "/usr/local" ]]; then
        echo "Fixing /usr/local permissions..."
        sudo chown -R "$(whoami):admin" /usr/local 2>/dev/null || echo "⚠️  Could not fix /usr/local permissions (may not be needed)"
        sudo chmod -R g+w /usr/local 2>/dev/null || true
    else
        echo "ℹ️  /usr/local not writable or doesn't exist (normal on Apple Silicon)"
    fi

    if [[ -d "/opt/homebrew" ]]; then
        echo "Fixing /opt/homebrew permissions..."
        sudo chown -R "$(whoami):admin" /opt/homebrew || echo "⚠️  Could not fix /opt/homebrew permissions"
        sudo chmod -R g+w /opt/homebrew || true
    else
        echo "ℹ️  /opt/homebrew not found"
    fi

    echo "✅ Permission fixes completed"
}

# Run Homebrew diagnostics
run_brew_doctor() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Running Homebrew diagnostics..."
    else
        echo "🩺 Running Homebrew diagnostics..."
    fi

    if command -v brew >/dev/null 2>&1; then
        brew doctor
    else
        if command -v log_error >/dev/null 2>&1; then
            log_error "Homebrew not found, reinstalling..."
        else
            echo "❌ Homebrew not found, reinstalling..."
        fi
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
}

# Update Homebrew packages
update_brew() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Updating Homebrew and packages..."
    else
        echo "🔄 Updating Homebrew and packages..."
    fi

    if command -v brew >/dev/null 2>&1; then
        brew update >/dev/null 2>&1 || echo "⚠️  Homebrew update failed"
        brew upgrade >/dev/null 2>&1 || echo "⚠️  Package upgrade failed"
        echo "✅ Homebrew update completed"
    else
        echo "❌ Homebrew not available"
    fi
}

# Fix broken Homebrew symlinks
fix_brew_symlinks() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Fixing broken Homebrew symlinks..."
    else
        echo "🔗 Fixing broken Homebrew symlinks..."
    fi

    if command -v brew >/dev/null 2>&1; then
        brew link --overwrite $(brew list --formula) 2>/dev/null || echo "⚠️  Some packages may already be linked"
        echo "✅ Symlink fixes completed"
    else
        echo "❌ Homebrew not available for relinking"
    fi
}

# Clean incomplete Homebrew processes
clean_brew() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Cleaning incomplete Homebrew processes and cache..."
    else
        echo "🧹 Cleaning incomplete Homebrew processes and cache..."
    fi

    if command -v brew >/dev/null 2>&1; then
        echo "Checking for incomplete downloads..."
        ps aux | grep -i brew | grep -v grep | head -5
        echo "Cleaning up Homebrew cache..."
        brew cleanup >/dev/null 2>&1 || echo "⚠️  Cache cleanup failed"
        echo "Cleaning up services..."
        brew services cleanup >/dev/null 2>&1 || echo "⚠️  Services cleanup failed"
        echo "✅ Homebrew cleanup complete"
    else
        echo "❌ Homebrew not available"
    fi
}

# Update or install Xcode
update_xcode() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Managing Xcode installation..."
    else
        echo "🛠️  Managing Xcode installation..."
    fi

    if command -v mas >/dev/null 2>&1; then
        if ! mas list | grep -q "497799835"; then
            echo "📥 Installing Xcode via App Store..."
            mas install 497799835 2>/dev/null || echo "⚠️  Xcode install failed - try manually from App Store"
        else
            echo "🔄 Updating Xcode via App Store..."
            mas upgrade 497799835 2>/dev/null || echo "⚠️  Xcode update failed - try manually from App Store"
        fi
    else
        echo "⚠️  mas not available - install with 'brew install mas'"
    fi

    echo "🔧 Updating Xcode Command Line Tools..."
    softwareupdate --install --agree-to-license "Command Line Tools" 2>/dev/null || echo "ℹ️  Command Line Tools up to date or not available"
}

# Fix Homebrew issues with permissions
fix_brew_full() {
    fix_brew_permissions
    run_brew_doctor
    update_brew
    fix_brew_symlinks
    update_xcode

    if command -v log_success >/dev/null 2>&1; then
        log_success "Homebrew troubleshooting complete"
    else
        echo "✅ Homebrew troubleshooting complete"
    fi
}

# Fix Homebrew issues without changing system permissions
fix_brew_safe() {
    run_brew_doctor
    update_brew
    fix_brew_symlinks
    update_xcode

    if command -v log_success >/dev/null 2>&1; then
        log_success "Homebrew troubleshooting complete (no permission changes)"
    else
        echo "✅ Homebrew troubleshooting complete (no permission changes)"
    fi
}

# Run system diagnostics
run_system_doctor() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Running system diagnostics..."
    else
        echo "🩺 Running system diagnostics..."
    fi

    echo "🖥️  Platform: $(uname)"
    echo "🐚 Shell: $SHELL"
    echo "⚙️  ZSH Config: $ZSH_CONFIG"
    echo "🔍 Checking tools:"

    if command -v brew >/dev/null 2>&1; then echo "  🍺 Homebrew: ✅"; else echo "  🍺 Homebrew: ❌"; fi
    if command -v git >/dev/null 2>&1; then echo "  🐙 Git: ✅"; else echo "  🐙 Git: ❌"; fi
    if command -v python3 >/dev/null 2>&1; then echo "  🐍 Python: ✅"; else echo "  🐍 Python: ❌"; fi
    if command -v node >/dev/null 2>&1; then echo "  🟢 Node.js: ✅"; else echo "  🟢 Node.js: ❌"; fi

    echo ""
    echo "📊 System Resources:"
    echo "  💾 Available disk space: $(df -h / | awk 'NR==2 {print $4}')"
    echo "  🧠 Available memory: $(vm_stat | awk '/free/ {gsub(/\./, "", $3); print $3 * 4096 / 1024 / 1024 " MB"}')"
    echo "  🔄 System uptime: $(uptime | awk -F'[ ,]+' '{print $3,$4,$5}')"

    echo "💻 Hardware Information:"
    # CPU detection
    if command -v sysctl >/dev/null 2>&1; then
        local cpu_cores
        cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")
        echo "  🔥 CPU cores: $cpu_cores"

        # CPU model info (macOS)
        local cpu_model
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
        echo "  🔥 CPU model: $cpu_model"
    elif [[ -f /proc/cpuinfo ]]; then
        # Linux CPU detection
        local cpu_cores
        cpu_cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "Unknown")
        echo "  🔥 CPU cores: $cpu_cores"

        local cpu_model
        cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//' 2>/dev/null || echo "Unknown")
        echo "  🔥 CPU model: $cpu_model"
    else
        echo "  🔥 CPU: Unable to detect"
    fi

    # GPU detection
    if command -v system_profiler >/dev/null 2>&1; then
        # macOS GPU detection
        local gpu_count
        gpu_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Chipset Model\|VRAM" || echo "Unknown")
        echo "  🎮 GPU count: $gpu_count"

        local gpu_info
        gpu_info=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Chipset Model" | head -1 | cut -d':' -f2 | sed 's/^ *//' || echo "Unknown")
        if [[ "$gpu_info" != "Unknown" ]]; then
            echo "  🎮 GPU: $gpu_info"
        fi
    elif command -v lspci >/dev/null 2>&1; then
        # Linux GPU detection
        local gpu_count
        gpu_count=$(lspci 2>/dev/null | grep -c -i "vga\|3d\|display" || echo "Unknown")
        echo "  🎮 GPU count: $gpu_count"

        local gpu_info
        gpu_info=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -1 | cut -d':' -f3 | sed 's/^ *//' || echo "Unknown")
        if [[ "$gpu_info" != "Unknown" ]]; then
            echo "  🎮 GPU: $gpu_info"
        fi
    else
        echo "  🎮 GPU: Unable to detect"
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "System diagnostics complete"
    else
        echo "✅ System diagnostics complete"
    fi
}

# Clean temporary files
clean_system() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Cleaning up system..."
    else
        echo "🧹 Cleaning up..."
    fi

    echo "🗑️  Removing backup files..."
    find . -name "*.bak" -delete 2>/dev/null || true
    echo "🗑️  Removing .DS_Store files..."
    find . -name ".DS_Store" -delete 2>/dev/null || true

    if command -v brew >/dev/null 2>&1; then
        echo "🍺 Cleaning Homebrew cache..."
        brew cleanup >/dev/null 2>&1 || echo "⚠️  Homebrew cleanup failed"
    fi

    echo "🗑️  Cleaning user cache directories..."
    rm -rf ~/Library/Caches/*/* 2>/dev/null || true
    rm -rf ~/.cache/*/* 2>/dev/null || true

    if command -v log_success >/dev/null 2>&1; then
        log_success "System cleanup complete"
    else
        echo "✅ System cleanup complete"
    fi
}

# Update repository and submodules
update_repository() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Updating repository and submodules..."
    else
        echo "🔄 Updating repository and submodules..."
    fi

    echo "🔗 Setting up tracking branch if needed..."
    git branch --set-upstream-to=origin/master master 2>/dev/null || echo "✅ Branch tracking already set up"

    echo "⬇️  Pulling latest changes..."
    git pull origin master

    echo "📦 Updating submodules..."
    git submodule update --remote --merge

    echo "🍺 Updating Homebrew packages..."
    if command -v brew >/dev/null 2>&1; then
        brew update && brew upgrade
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Repository update complete"
    else
        echo "✅ Repository update complete"
    fi
}

# Find orphaned Makefile targets
find_orphans() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Finding orphaned targets in Makefile..."
    else
        echo "🔍 Finding orphaned targets in Makefile..."
    fi

    if [[ -f "Gemfile" ]] && command -v bundle >/dev/null 2>&1; then
        bundle exec ruby bin/internal-find-orphaned-targets.rb
    else
        echo "⚠️  Could not run orphaned targets finder (Gemfile or bundler not available)"
    fi
}

# Check common issues and provide solutions
check_common_issues() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Checking common issues..."
    else
        echo "🔍 Checking common issues..."
    fi

    echo "🔍 Checking PATH issues..."
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo "⚠️  ~/bin not in PATH - add to shell configuration"
    fi

    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "⚠️  ~/.local/bin not in PATH - add to shell configuration"
    fi

    echo "🔍 Checking for common configuration issues..."
    if [[ ! -f "$HOME/.gitconfig" ]]; then
        echo "⚠️  Git configuration not found - run 'make github-setup'"
    fi

    if ! command -v code >/dev/null 2>&1; then
        echo "⚠️  VS Code not in PATH - may need shell restart"
    fi

    echo "🔍 Checking ZSH configuration..."
    if [[ ! -L "$HOME/.zshrc" ]]; then
        echo "⚠️  .zshrc not symlinked - run 'make install'"
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Common issues check complete"
    else
        echo "✅ Common issues check complete"
    fi
}

# Main execution based on arguments
case "${1:-help}" in
    "fix-brew-full"|"fix-brew")
        fix_brew_full
        ;;
    "fix-brew-safe")
        fix_brew_safe
        ;;
    "fix-permissions")
        fix_brew_permissions
        ;;
    "brew-doctor")
        run_brew_doctor
        ;;
    "brew-clean")
        clean_brew
        ;;
    "brew-relink")
        fix_brew_symlinks
        ;;
    "xcode-update")
        update_xcode
        ;;
    "system-doctor"|"doctor")
        run_system_doctor
        ;;
    "clean")
        clean_system
        ;;
    "update")
        update_repository
        ;;
    "find-orphans")
        find_orphans
        ;;
    "check-issues")
        check_common_issues
        ;;
    "all")
        echo "🚀 Running comprehensive troubleshooting..."
        fix_brew_safe
        clean_brew
        run_system_doctor
        check_common_issues
        echo "✅ Comprehensive troubleshooting complete"
        ;;
    "help"|*)
        echo "Usage: $0 [command]"
        echo ""
        echo "Troubleshooting commands:"
        echo "  fix-brew-full    - Fix Homebrew with permission changes"
        echo "  fix-brew-safe    - Fix Homebrew without permission changes (recommended)"
        echo "  fix-permissions  - Fix Homebrew directory permissions"
        echo "  brew-doctor      - Run Homebrew diagnostics"
        echo "  brew-clean       - Clean incomplete Homebrew processes"
        echo "  brew-relink      - Fix broken Homebrew symlinks"
        echo "  xcode-update     - Update or install Xcode"
        echo "  system-doctor    - Run comprehensive system diagnostics"
        echo "  clean            - Clean temporary files and caches"
        echo "  update           - Update repository and submodules"
        echo "  find-orphans     - Find orphaned Makefile targets"
        echo "  check-issues     - Check for common configuration issues"
        echo "  all              - Run comprehensive troubleshooting"
        echo "  help             - Show this help message"
        exit 1
        ;;
esac