#!/bin/bash

# Development Tools Setup Script
# Extracted from Makefile for better organization and quieter output

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Import utility functions
BREW_INSTALL_QUIET="$SCRIPT_DIR/utils/brew-install-quiet.sh"

# Package lists (from Makefile)
CORE_UTILS_BREW="tree wget watch ripgrep fd bat eza htop jq yq"
DEV_UTILS_BREW="duti fswatch ssh-copy-id rmtrash sleepwatcher pkgconf dockutil librsvg"
MODERN_CLI_BREW="zoxide starship fzf claude-code gemini-cli yt-dlp"
EDITORS_CASK="visual-studio-code zed lm-studio"

# Function to install packages quietly
install_packages() {
    local category="$1"
    local packages="$2"

    if command -v log_info >/dev/null 2>&1; then
        log_info "Installing $category: $packages"
    else
        echo "📦 Installing $category: $packages"
    fi

    for pkg in $packages; do
        if "$BREW_INSTALL_QUIET" "$pkg"; then
            # Package installed successfully (output handled by script)
            :
        else
            if command -v log_warning >/dev/null 2>&1; then
                log_warning "Could not install $pkg (may already be installed)"
            else
                echo "⚠️  Could not install $pkg (may already be installed)"
            fi
        fi
    done
}

# Function to install casks quietly
install_casks() {
    local category="$1"
    local casks="$2"

    if command -v log_info >/dev/null 2>&1; then
        log_info "Installing $category: $casks"
    else
        echo "📦 Installing $category: $casks"
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

# Main execution based on arguments
case "${1:-all}" in
    "core-utils")
        install_packages "core utilities" "$CORE_UTILS_BREW"
        ;;
    "dev-utils")
        install_packages "development utilities" "$DEV_UTILS_BREW"
        ;;
    "modern-cli")
        install_packages "modern CLI tools" "$MODERN_CLI_BREW"
        # Configure Claude auto-updater setting
        if command -v claude >/dev/null 2>&1; then
            claude config set autoUpdates false >/dev/null 2>&1 || true
        fi
        ;;
    "editors")
        install_casks "editors and IDEs" "$EDITORS_CASK"
        # Install vim and neovim (formulae, not casks)
        "$BREW_INSTALL_QUIET" "vim" || true
        "$BREW_INSTALL_QUIET" "neovim" || true
        ;;
    "all")
        install_packages "core utilities" "$CORE_UTILS_BREW"
        install_packages "development utilities" "$DEV_UTILS_BREW"
        install_packages "modern CLI tools" "$MODERN_CLI_BREW"
        # Configure Claude auto-updater setting
        if command -v claude >/dev/null 2>&1; then
            claude config set autoUpdates false >/dev/null 2>&1 || true
        fi
        install_casks "editors and IDEs" "$EDITORS_CASK"
        # Install vim and neovim
        "$BREW_INSTALL_QUIET" "vim" || true
        "$BREW_INSTALL_QUIET" "neovim" || true

        if command -v log_success >/dev/null 2>&1; then
            log_success "Development tools installation complete"
        else
            echo "✅ Development tools installation complete"
        fi
        ;;
    *)
        echo "Usage: $0 [core-utils|dev-utils|modern-cli|editors|all]"
        echo ""
        echo "Categories:"
        echo " core-utils  - Essential CLI utilities (tree, wget, ripgrep, etc.)"
        echo " dev-utils   - Development utilities (duti, fswatch, etc.)"
        echo " modern-cli  - Modern CLI tools (zoxide, starship, fzf, claude-code)"
        echo " editors     - Text editors and IDEs (VS Code, Zed, vim, neovim)"
        echo " all         - Install all categories (default)"
        exit 1
        ;;
esac