#!/bin/bash

# Git Configuration Script
# Sets up Git user information, aliases, and default associations

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Configure user information
setup_user_info() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting user information..."
    else
        echo "👤 Setting user information..."
    fi

    # Get user info from environment or use defaults
    local name="${NAME:-Hemant Verma}"
    local email="${EMAIL:-fameoflight@gmail.com}"

    git config --global --replace-all user.name "$name"
    git config --global --replace-all user.email "$email"
    echo "✅ User information configured"
    echo " Name: $name"
    echo " Email: $email"
}

# Configure editors
setup_editors() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting editors..."
    else
        echo "📝 Setting editors..."
    fi

    git config --global --replace-all core.editor "vim"
    git config --global --replace-all sequence.editor "vim"
    echo "✅ Editors configured"
}

# Configure push behavior
setup_push_behavior() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting push behavior..."
    else
        echo "🚀 Setting push behavior..."
    fi

    git config --global --replace-all push.default current
    git config --global --replace-all push.recurseSubmodules on-demand

    git config --global core.filemode false
    echo "✅ Push behavior configured"
}

# Configure ignore file
setup_ignore_file() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting ignore file..."
    else
        echo "🚫 Setting ignore file..."
    fi

    SETTINGS="$ZSH_CONFIG/Settings"
    if [[ -f "$SETTINGS/.git_ignore" ]]; then
        git config --global --replace-all core.excludesfile "$SETTINGS/.git_ignore"
        echo "✅ Git ignore file configured"
    else
        echo "⚠️  Git ignore file not found at $SETTINGS/.git_ignore"
    fi
}

# Setup Git aliases
setup_aliases() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Git aliases..."
    else
        echo "⚡ Setting up Git aliases..."
    fi

    # Log aliases
    git config --global --replace-all alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

    # Cherry pick and rebase aliases
    git config --global --replace-all alias.cp "cherry-pick"
    git config --global --replace-all alias.ri "rebase --interactive"
    git config --global --replace-all alias.rc "rebase --continue"
    git config --global --replace-all alias.rb "rebase --abort"

    # Checkout and status aliases
    git config --global --replace-all alias.co "checkout"
    git config --global --replace-all alias.st "status"
    git config --global --replace-all alias.pushf "push --force-with-lease"

    # Branch aliases
    git config --global --replace-all alias.master "checkout master"
    git config --global --replace-all alias.main "checkout main"

    # Remote and info aliases
    git config --global --replace-all alias.url "remote show origin"
    git config --global --replace-all alias.root "rev-parse --show-toplevel"

    # Stash aliases with search functionality
    git config --global --replace-all alias.sshow "!f() { git stash show stash^{/$$*} -p; }; f"
    git config --global --replace-all alias.sapply "!f() { git stash apply stash^{/$$*}; }; f"

    echo "✅ Git aliases configured"
}

# Setup default editor associations
setup_editor_associations() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Configuring default editor associations..."
    else
        echo "🔧 Configuring default editor associations..."
    fi

    if command -v duti >/dev/null 2>&1; then
        echo "Setting VS Code as default for code files..."
        duti -s com.microsoft.VSCode .rb all
        duti -s com.microsoft.VSCode .js all
        duti -s com.microsoft.VSCode .json all
        duti -s com.microsoft.VSCode .md all
        echo "✅ Editor associations configured"
    else
        echo "⚠️  duti not installed - skipping editor associations"
        echo "Install with: brew install duti"
    fi
}

# Configure GPG signing (optional setup)
setup_gpg_signing() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Configuring GPG signing (optional)..."
    else
        echo "🔐 Configuring GPG signing (optional)..."
    fi

    echo "GPG signing is not automatically configured."
    echo "To enable GPG signing, run:"
    echo " git config --global commit.gpgsign true"
    echo " git config --global gpg.program $(which gpg)"
    echo " git config --global user.signingkey YOUR_GPG_KEY_ID"
    echo ""
    echo "Generate a GPG key with:"
    echo " gpg --full-generate-key"
}

# Configure SSH key management hints
setup_ssh_hints() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "SSH key management hints..."
    else
        echo "🔑 SSH key management hints..."
    fi

    # Get user info from environment or use defaults
    local name="${NAME:-Hemant Verma}"
    local email="${EMAIL:-fameoflight@gmail.com}"

    echo "SSH key management:"
    echo " Generate new SSH key: ssh-keygen -t ed25519 -C '$email'"
    echo " Add SSH key to ssh-agent: ssh-add ~/.ssh/id_ed25519"
    echo " Copy SSH public key: pbcopy < ~/.ssh/id_ed25519.pub"
    echo " Test SSH connection: ssh -T git@github.com"
    echo " Note: Use name: $name, email: $email"
}

# Show current Git configuration
show_config() {
    echo ""
    echo "📋 Current Git Configuration:"
    echo "================================"
    git config --global --list | grep -E "(user\.|core\.|push\.|alias\.)" | sort
}

# Validate configuration
validate_config() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Validating Git configuration..."
    else
        echo "🩺 Validating Git configuration..."
    fi

    local errors=0

    # Check user name
    if [[ -z "$(git config --global user.name)" ]]; then
        echo "❌ User name not configured"
        ((errors++))
    else
        echo "✅ User name: $(git config --global user.name)"
    fi

    # Check user email
    if [[ -z "$(git config --global user.email)" ]]; then
        echo "❌ User email not configured"
        ((errors++))
    else
        echo "✅ User email: $(git config --global user.email)"
    fi

    # Check editor
    if [[ -z "$(git config --global core.editor)" ]]; then
        echo "⚠️  Default editor not configured"
    else
        echo "✅ Editor: $(git config --global core.editor)"
    fi

    # Check push behavior
    if [[ -z "$(git config --global push.default)" ]]; then
        echo "⚠️  Push behavior not configured"
    else
        echo "✅ Push default: $(git config --global push.default)"
    fi

    # Count aliases
    local alias_count
    alias_count=$(git config --global --get-regexp '^alias\.' | wc -l)
    echo "✅ Aliases configured: $alias_count"

    if [[ $errors -eq 0 ]]; then
        echo ""
        if command -v log_success >/dev/null 2>&1; then
            log_success "Git configuration is valid"
        else
            echo "✅ Git configuration is valid"
        fi
    else
        echo ""
        echo "❌ Found $errors configuration errors"
        return 1
    fi
}

# Main execution based on arguments
case "${1:-all}" in
    "user-info")
        setup_user_info
        ;;
    "editors")
        setup_editors
        ;;
    "push")
        setup_push_behavior
        ;;
    "ignore")
        setup_ignore_file
        ;;
    "aliases")
        setup_aliases
        ;;
    "associations")
        setup_editor_associations
        ;;
    "gpg")
        setup_gpg_signing
        ;;
    "ssh")
        setup_ssh_hints
        ;;
    "validate")
        validate_config
        ;;
    "show")
        show_config
        ;;
    "all")
        setup_user_info
        setup_editors
        setup_push_behavior
        setup_ignore_file
        setup_aliases
        setup_editor_associations
        setup_gpg_signing
        setup_ssh_hints
        validate_config
        show_config

        if command -v log_success >/dev/null 2>&1; then
            log_success "Git configuration complete"
        else
            echo "✅ Git configuration complete"
        fi
        ;;
    *)
        echo "Usage: $0 [user-info|editors|push|ignore|aliases|associations|gpg|ssh|validate|show|all]"
        echo ""
        echo "Configuration options:"
        echo " user-info    - Set user name and email"
        echo " editors      - Configure default editors"
        echo " push         - Configure push behavior"
        echo " ignore       - Set up global git ignore file"
        echo " aliases      - Configure Git aliases"
        echo " associations - Set default applications for file types"
        echo " gpg          - Show GPG signing configuration hints"
        echo " ssh          - Show SSH key management hints"
        echo " validate     - Validate current Git configuration"
        echo " show         - Show current Git configuration"
        echo " all          - Configure all Git settings (default)"
        exit 1
        ;;
esac