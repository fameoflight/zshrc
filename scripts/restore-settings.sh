#!/bin/bash

# Application Setup and Restore Script
# Handles application settings restoration and configuration

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Restore iTerm2 settings
restore_iterm() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Restoring iTerm2 settings..."
    else
        echo "🖥️  Restoring iTerm2 settings..."
    fi

    if [[ -f "$ZSH_CONFIG/bin/iterm-setup.sh" ]]; then
        bash "$ZSH_CONFIG/bin/iterm-setup.sh"
        if command -v log_success >/dev/null 2>&1; then
            log_success "iTerm2 settings restored"
        else
            echo "✅ iTerm2 settings restored"
        fi
    else
        if command -v log_warning >/dev/null 2>&1; then
            log_warning "iTerm2 setup script not found"
        else
            echo "⚠️  iTerm2 setup script not found"
        fi
    fi
}

# Restore VS Code settings
restore_vscode() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up VS Code configuration..."
    else
        echo "⚙️  Setting up VS Code configuration..."
    fi

    # Install VS Code if not present
    echo "Installing VS Code if not present..."
    brew install --cask visual-studio-code 2>/dev/null || echo "VS Code already installed"

    # Setup VS Code user settings
    SETTINGS="$ZSH_CONFIG/Settings"
    mkdir -p "${HOME}/Library/Application Support/Code/User"

    if [[ -d "$SETTINGS/VSCode/User" ]]; then
        echo "Copying VS Code settings from repository..."
        cp -r "$SETTINGS/VSCode/User/"* "${HOME}/Library/Application Support/Code/User/"
        echo "✅ VS Code settings applied from $SETTINGS/VSCode/User/"
    else
        echo "⚠️  No VS Code settings found in repository to apply"
    fi

    if [[ -f "$SETTINGS/VSCode/extensions.txt" ]]; then
        echo "Installing VS Code extensions from list..."
        while read -r extension; do
            if [[ -n "$extension" ]]; then
                code --install-extension "$extension" 2>/dev/null || echo "⚠️  Could not install extension: $extension"
            fi
        done < "$SETTINGS/VSCode/extensions.txt"
        echo "✅ VS Code extensions installation completed"
    else
        echo "⚠️  No extensions list found to install"
    fi

    echo ""
    echo "🔄 Note: You may need to restart VS Code for all settings to take effect"

    if command -v log_success >/dev/null 2>&1; then
        log_success "VS Code setup complete"
    else
        echo "✅ VS Code setup complete"
    fi
}

# Restore Xcode settings
restore_xcode() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Restoring Xcode settings..."
    else
        echo "🎨 Restoring Xcode settings..."
    fi

    # Delegate to macos script for xcode setup
    if [[ -f "$SCRIPT_DIR/setup-macos.sh" ]]; then
        bash "$SCRIPT_DIR/setup-macos.sh" xcode-setup
    else
        echo "❌ setup-macos.sh not found"
        return 1
    fi
}

# Restore Sublime Text settings
restore_sublime() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Restoring Sublime Text settings..."
    else
        echo "📝 Restoring Sublime Text settings..."
    fi

    SETTINGS="$ZSH_CONFIG/Settings"
    if [[ -d "$SETTINGS/Sublime3" ]]; then
        echo "Setting up Sublime Text 3 configuration..."
        mkdir -p "${HOME}/Library/Application Support/Sublime Text 3/Packages/User"

        if [[ -f "$SETTINGS/Sublime3/Preferences.sublime-settings" ]]; then
            cp "$SETTINGS/Sublime3/Preferences.sublime-settings" \
               "${HOME}/Library/Application Support/Sublime Text 3/Packages/User/"
            echo "✅ Sublime Text preferences restored"
        fi

        if [[ -d "$SETTINGS/Sublime3/User" ]]; then
            cp -r "$SETTINGS/Sublime3/User/"* \
                  "${HOME}/Library/Application Support/Sublime Text 3/Packages/User/"
            echo "✅ Sublime Text user settings restored"
        fi
    else
        echo "⚠️  Sublime Text settings not found in repository"
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Sublime Text setup complete"
    else
        echo "✅ Sublime Text setup complete"
    fi
}

# Restore macOS Dock settings
restore_dock() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Restoring macOS Dock settings..."
    else
        echo "🔵 Restoring macOS Dock settings..."
    fi

    SETTINGS="$ZSH_CONFIG/Settings"
    if [[ -f "$SETTINGS/dock.plist" ]]; then
        echo "Restoring Dock configuration..."
        cp "$SETTINGS/dock.plist" "${HOME}/Library/Preferences/com.apple.dock.plist"
        killall Dock 2>/dev/null || true
        echo "✅ Dock settings restored and reloaded"
    else
        echo "⚠️  Dock settings file not found"
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Dock restoration complete"
    else
        echo "✅ Dock restoration complete"
    fi
}

# Restore Ruby configuration
restore_ruby_config() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Restoring Ruby configuration..."
    else
        echo "💎 Restoring Ruby configuration..."
    fi

    SETTINGS="$ZSH_CONFIG/Settings"
    USER_BIN="${HOME}/bin"

    if [[ -f "$SETTINGS/irbrc" ]]; then
        cp "$SETTINGS/irbrc" "${HOME}/.irbrc"
        echo "✅ IRB configuration restored"
    else
        echo "⚠️  IRB configuration file not found"
    fi

    if [[ -f "$SETTINGS/gemrc" ]]; then
        cp "$SETTINGS/gemrc" "${HOME}/.gemrc"
        echo "✅ Gem configuration restored"
    else
        echo "⚠️  Gem configuration file not found"
    fi

    if [[ -f "$SETTINGS/ctags_for_ruby" ]]; then
        mkdir -p "$USER_BIN"
        cp "$SETTINGS/ctags_for_ruby" "$USER_BIN/ctags_for_ruby"
        chmod +x "$USER_BIN/ctags_for_ruby"
        echo "✅ Ruby ctags configuration restored"
    else
        echo "⚠️  Ruby ctags file not found"
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Ruby configuration restoration complete"
    else
        echo "✅ Ruby configuration restoration complete"
    fi
}

# Setup Claude Code
setup_claude() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Claude Code..."
    else
        echo "🤖 Setting up Claude Code..."
    fi

    if [[ -f "$ZSH_CONFIG/bin/claude-setup.sh" ]]; then
        bash "$ZSH_CONFIG/bin/claude-setup.sh"
        if command -v log_success >/dev/null 2>&1; then
            log_success "Claude Code setup complete"
        else
            echo "✅ Claude Code setup complete"
        fi
    else
        if command -v log_warning >/dev/null 2>&1; then
            log_warning "Claude setup script not found"
        else
            echo "⚠️  Claude setup script not found"
        fi
    fi
}

# Create Claude binary symlink
setup_claude_link() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Claude binary symlink..."
    else
        echo "🔗 Setting up Claude binary symlink..."
    fi

    if command -v claude >/dev/null 2>&1; then
        echo "Creating ~/.local/bin directory..."
        mkdir -p ~/.local/bin
        if [[ -f /opt/homebrew/bin/claude ]]; then
            echo "Creating symlink from ~/.local/bin/claude to /opt/homebrew/bin/claude..."
            ln -sf /opt/homebrew/bin/claude ~/.local/bin/claude
            echo "✅ Claude binary symlink created"
        elif [[ -f /usr/local/bin/claude ]]; then
            echo "Creating symlink from ~/.local/bin/claude to /usr/local/bin/claude..."
            ln -sf /usr/local/bin/claude ~/.local/bin/claude
            echo "✅ Claude binary symlink created"
        else
            echo "⚠️  Claude binary not found in standard locations"
        fi
    else
        echo "❌ Claude not installed - install with 'brew install claude-code'"
        exit 1
    fi
}

# Setup Gemini CLI
setup_gemini() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Gemini CLI..."
    else
        echo "🤖 Setting up Gemini CLI..."
    fi

    echo "Creating ~/.gemini directory..."
    mkdir -p ~/.gemini
    echo "Creating symlink for settings.json..."
    ln -sf "${ZSH_CONFIG}/Settings/Gemini/settings.json" ~/.gemini/settings.json
    echo "✅ Gemini CLI settings symlinked from Settings/Gemini/"

    if [[ -f "$ZSH_CONFIG/bin/gemini-setup.sh" ]]; then
        echo "Running additional Gemini setup script..."
        bash "$ZSH_CONFIG/bin/gemini-setup.sh"
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Gemini CLI setup complete"
    else
        echo "✅ Gemini CLI setup complete"
    fi
}

# Setup Claude-Gemini integration
setup_claude_gemini() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Claude-Gemini integration..."
    else
        echo "🤖 Setting up Claude-Gemini integration..."
    fi

    echo "Ensuring gemini-claude-proxy submodule is initialized..."
    git submodule update --init --recursive gemini-claude-proxy
    echo "Setting up Python virtual environment..."
    cd gemini-claude-proxy && python3.11 -m venv .venv
    echo "Installing Python dependencies..."
    cd gemini-claude-proxy && .venv/bin/pip install -r requirements.txt
    echo "Setting up environment configuration..."

    if [[ -f "gemini-claude-proxy/.env.example" ]]; then
        cp gemini-claude-proxy/.env.example gemini-claude-proxy/.env
        echo "✅ Created .env from .env.example"
    fi

    echo "⚠️  Please add your Gemini API key to gemini-claude-proxy/.env"
    echo "ℹ️  Or use: setup-gemini-key 'your-key-here'"
    echo "✅ Claude-Gemini integration setup complete"
    echo "🚀 Use 'claude-gemini' command to run Claude Code with Gemini API"

    if command -v log_success >/dev/null 2>&1; then
        log_success "Claude-Gemini integration setup complete"
    else
        echo "✅ Claude-Gemini integration setup complete"
    fi
}

# Main execution based on arguments
case "${1:-all}" in
    "iterm")
        restore_iterm
        ;;
    "vscode")
        restore_vscode
        ;;
    "xcode")
        restore_xcode
        ;;
    "sublime")
        restore_sublime
        ;;
    "dock")
        restore_dock
        ;;
    "ruby-config")
        restore_ruby_config
        ;;
    "claude")
        setup_claude
        ;;
    "claude-link")
        setup_claude_link
        ;;
    "gemini")
        setup_gemini
        ;;
    "claude-gemini")
        setup_claude_gemini
        ;;
    "ai-tools")
        setup_claude
        setup_gemini
        ;;
    "all")
        restore_iterm
        restore_vscode
        restore_xcode
        restore_sublime
        restore_dock
        restore_ruby_config
        setup_claude
        setup_gemini
        ;;
    *)
        echo "Usage: $0 [iterm|vscode|xcode|sublime|dock|ruby-config|claude|claude-link|gemini|claude-gemini|ai-tools|all]"
        echo ""
        echo "Application setups:"
        echo " iterm         - Restore iTerm2 settings"
        echo " vscode        - Setup VS Code with settings and extensions"
        echo " xcode         - Restore Xcode settings"
        echo " sublime       - Restore Sublime Text settings"
        echo " dock          - Restore macOS Dock settings"
        echo " ruby-config   - Restore Ruby configuration files"
        echo " claude        - Setup Claude Code"
        echo " claude-link   - Create Claude binary symlink"
        echo " gemini        - Setup Gemini CLI"
        echo " claude-gemini - Setup Claude-Gemini integration"
        echo " ai-tools      - Setup both Claude and Gemini"
        echo " all           - Restore all settings (default)"
        exit 1
        ;;
esac