#!/bin/bash

# macOS Setup Script
# Handles macOS-specific installations, settings, and optimizations

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Source utility functions
source "$SCRIPT_DIR/utils.sh"

# Import permission check from troubleshooting script
if [[ -f "$SCRIPT_DIR/troubleshooting.sh" ]]; then
    # Source only the permission check function
    source <(sed -n '/^# Check Full Disk Access/,/^}/p' "$SCRIPT_DIR/troubleshooting.sh")
fi

# Package lists
MAC_APPS_CASK="iterm2 rectangle raycast docker postman tableplus the-unarchiver keka slack zoom"

# Function to install casks quietly
install_casks() {
    local category="$1"
    local casks="$2"

    if command -v log_info >/dev/null 2>&1; then
        log_info "Installing $category..."
    else
        echo "📦 Installing $category..."
    fi

    for cask in $casks; do
        # Check if cask is already installed
        if brew list --cask "$cask" >/dev/null 2>&1; then
            if command -v log_success >/dev/null 2>&1; then
                log_success "$cask already installed"
            else
                echo "✅ $cask already installed"
            fi
        else
            if brew install --cask "$cask" >/dev/null 2>&1; then
                if command -v log_success >/dev/null 2>&1; then
                    log_success "$cask installed"
                else
                    echo "✅ $cask installed"
                fi
            else
                if command -v log_warning >/dev/null 2>&1; then
                    log_warning "Could not install $cask (may already be installed)"
                else
                    echo "⚠️  Could not install $cask (may already be installed)"
                fi
            fi
        fi
    done
}

# Install GitHub tools
install_github_tools() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Installing GitHub tools..."
    else
        echo "🐙 Installing GitHub tools..."
    fi

    # Install via quiet function if available
    if [[ -f "$SCRIPT_DIR/utils/brew-install-quiet.sh" ]]; then
        "$SCRIPT_DIR/utils/brew-install-quiet.sh" "gh" || true
        "$SCRIPT_DIR/utils/brew-install-quiet.sh" "git-lfs" || true
        "$SCRIPT_DIR/utils/brew-install-quiet.sh" "github" || true
    else
        brew install gh 2>/dev/null || echo "⚠️  Could not install gh"
        brew install git-lfs 2>/dev/null || echo "⚠️  Could not install git-lfs"
        brew install --cask github 2>/dev/null || echo "⚠️  Could not install github"
    fi
}

# Setup Xcode
setup_xcode() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Xcode configuration..."
    else
        echo "🔧 Setting up Xcode configuration..."
    fi

    # Install Xcode if not present
    echo "Installing Xcode if not present..."
    mas install 497799835 2>/dev/null || echo "Xcode already installed or not available via Mac App Store"

    # Setup Xcode user preferences
    SETTINGS="$ZSH_CONFIG/Settings"
    mkdir -p "${HOME}/Library/Developer/Xcode/UserData/FontAndColorThemes"
    mkdir -p "${HOME}/Library/Developer/Xcode/UserData/KeyBindings"

    safe_cp "${SETTINGS}/XCode/UserData/FontAndColorThemes/Solarized Dark.dvtcolortheme" \
           "${HOME}/Library/Developer/Xcode/UserData/FontAndColorThemes/" \
           "Solarized Dark color theme"
    safe_cp "${SETTINGS}/XCode/UserData/KeyBindings/Default.idekeybindings" \
           "${HOME}/Library/Developer/Xcode/UserData/KeyBindings/" \
           "Custom key bindings"

    echo "Setting Solarized Dark as default theme..."
    defaults write com.apple.dt.Xcode DVTFontAndColorCurrentTheme "Solarized Dark.dvtcolortheme" 2>/dev/null || echo "⚠️  Could not set default theme (Xcode may need to be running)"

    # Install Xcode command line tools
    echo "Installing Xcode command line tools..."
    xcode-select --install 2>/dev/null || echo "Command line tools already installed"

    echo ""
    echo "🔄 Note: You may need to restart Xcode for theme changes to take effect"
    echo "📝 To manually set the theme: Xcode → Settings → Themes → Select 'Solarized Dark'"
}

# Install macOS applications
install_mac_apps() {
    install_casks "macOS applications" "$MAC_APPS_CASK"
    if command -v log_success >/dev/null 2>&1; then
        log_success "macOS applications installation complete"
    else
        echo "✅ macOS applications installation complete"
    fi
}

# Run macOS optimization
run_macos_optimize() {
    if command -v log_info >/dev/null 2>&1; then
        log_info " Optimizing macOS system settings..."
    else
        echo "⚡ Optimizing macOS system settings..."
    fi

    # Check Full Disk Access permissions first
    if command -v check_full_disk_access >/dev/null 2>&1; then
        if command -v log_info >/dev/null 2>&1; then
            log_info " Checking Full Disk Access permissions..."
        fi
        if ! check_full_disk_access; then
            if command -v log_error >/dev/null 2>&1; then
                log_error " macOS optimization requires Full Disk Access"
            else
                echo "❌ macOS optimization requires Full Disk Access"
            fi
            echo "💡 Grant access and restart your terminal, then run again"
            return 1
        fi
    fi

    if [[ -f "$ZSH_CONFIG/bin/macos-optimize.sh" ]]; then
        if command -v log_info >/dev/null 2>&1; then
            log_info " Executing macos-optimize.sh..."
        fi
        bash "$ZSH_CONFIG/bin/macos-optimize.sh"
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            if command -v log_success >/dev/null 2>&1; then
                log_success " macOS optimization complete"
            else
                echo "✅ macOS optimization complete"
            fi
        else
            if command -v log_error >/dev/null 2>&1; then
                log_error " macOS optimization script failed with exit code $exit_code"
            else
                echo "❌ macOS optimization script failed with exit code $exit_code"
            fi
            return $exit_code
        fi
    else
        if command -v log_error >/dev/null 2>&1; then
            log_error " macOS optimization script not found at bin/macos-optimize.sh"
        else
            echo "❌ macOS optimization script not found at bin/macos-optimize.sh"
        fi
        return 1
    fi
}

# Run OLED optimization
run_oled_optimize() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Optimizing macOS for OLED displays..."
    else
        echo "🖥️  Optimizing macOS for OLED displays..."
    fi

    # Check Full Disk Access permissions first
    if command -v check_full_disk_access >/dev/null 2>&1; then
        if ! check_full_disk_access; then
            if command -v log_error >/dev/null 2>&1; then
                log_error "OLED optimization requires Full Disk Access"
            else
                echo "❌ OLED optimization requires Full Disk Access"
            fi
            echo "💡 Grant access and restart your terminal, then run again"
            return 1
        fi
    fi

    if [[ -f "$ZSH_CONFIG/bin/macos-oled-optimize.sh" ]]; then
        bash "$ZSH_CONFIG/bin/macos-oled-optimize.sh"
        if command -v log_success >/dev/null 2>&1; then
            log_success "OLED optimization complete"
        else
            echo "✅ OLED optimization complete"
        fi
    else
        if command -v log_error >/dev/null 2>&1; then
            log_error "OLED optimization script not found at bin/macos-oled-optimize.sh"
        else
            echo "❌ OLED optimization script not found at bin/macos-oled-optimize.sh"
        fi
        return 1
    fi
}

# Setup system hooks
setup_hooks() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up wake and sleep hooks..."
    else
        echo "⚙️  Setting up wake and sleep hooks..."
    fi

    if [[ -f "$ZSH_CONFIG/bin/setup-hooks.sh" ]]; then
        bash "$ZSH_CONFIG/bin/setup-hooks.sh"
        if command -v log_success >/dev/null 2>&1; then
            log_success "Hooks setup complete"
        else
            echo "✅ Hooks setup complete"
        fi
    else
        if command -v log_error >/dev/null 2>&1; then
            log_error "Hooks setup script not found at bin/setup-hooks.sh"
        else
            echo "❌ Hooks setup script not found at bin/setup-hooks.sh"
        fi
        return 1
    fi
}

# Main execution based on arguments
case "${1:-all}" in
    "github-tools")
        install_github_tools
        ;;
    "xcode-setup")
        setup_xcode
        ;;
    "mac-apps")
        install_mac_apps
        ;;
    "macos-optimize")
        run_macos_optimize
        ;;
    "macos-oled-optimize")
        run_oled_optimize
        ;;
    "setup-hooks")
        setup_hooks
        ;;
    "all")
        install_github_tools
        setup_xcode
        install_mac_apps
        run_macos_optimize
        ;;
    *)
        echo "Usage: $0 [github-tools|xcode-setup|mac-apps|macos-optimize|macos-oled-optimize|setup-hooks|all]"
        echo ""
        echo "Components:"
        echo " github-tools       - Install GitHub CLI and related tools"
        echo " xcode-setup        - Setup Xcode with themes and preferences"
        echo " mac-apps           - Install macOS applications via Homebrew casks"
        echo " macos-optimize     - Optimize macOS system settings for developers"
        echo " macos-oled-optimize - Optimize settings for OLED displays"
        echo " setup-hooks        - Setup wake/sleep hooks and login scripts"
        echo " all                - Install all components (default)"
        exit 1
        ;;
esac