#!/bin/bash

# Post-Mac Setup Script
# Displays completion message and runs orphaned targets analysis

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Display post-mac setup completion message
show_completion_message() {
    if command -v log_success >/dev/null 2>&1; then
        log_success "Complete macOS setup finished successfully!"
    else
        echo -e "\033[1;32m✅ Complete macOS setup finished successfully!\033[0m"
    fi
    echo ""

    if command -v log_success >/dev/null 2>&1; then
        log_success "Your development environment is now fully configured."
    else
        echo -e "\033[1;36m🎉 Your development environment is now fully configured.\033[0m"
    fi
    echo ""

    if command -v log_warning >/dev/null 2>&1; then
        log_warning "💡 Suggested next steps:"
    else
        echo -e "\033[1;33m💡 Suggested next steps:\033[0m"
    fi

    echo "  - Restart your terminal to apply all changes."
    echo "  - Run 'make help' to see all available commands."
    echo "  - Customize your setup further by editing private.zsh."
    echo "  - If you use an OLED display, consider running 'make macos-oled-optimize'."
    echo ""
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

# Main execution
show_completion_message
find_orphans