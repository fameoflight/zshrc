#!/bin/bash

# Permission Check Script
# Checks if terminal has required permissions for macOS optimization

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

echo "🔐 macOS Permission Checker"
echo "==========================="
echo ""

# Check if we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ℹ️  This script is for macOS only"
    exit 0
fi

# Check Full Disk Access
test_file="/Library/Preferences/com.apple.systempreferences.plist"
if [[ -r "$test_file" ]]; then
    if command -v log_success >/dev/null 2>&1; then
        log_success "✅ Full Disk Access granted"
    else
        echo "✅ Full Disk Access granted"
    fi

    echo ""
    echo "🎉 Your terminal has all required permissions!"
    echo "💡 You can now run: make macos-optimize"

else
    if command -v log_warning >/dev/null 2>&1; then
        log_warning "⚠️  Full Disk Access required"
    else
        echo "⚠️  Full Disk Access required"
    fi

    echo ""
    echo "📋 Quick Setup Instructions:"
    echo "1. Open: System Settings → Privacy & Security → Full Disk Access"
    echo "2. Click the 🔒 lock and enter your password"
    echo "3. Click the '+' button below the app list"
    echo "4. Navigate to and select your terminal app:"
    echo "  • iTerm2: /Applications/iTerm.app"
    echo "  • Terminal: /System/Applications/Utilities/Terminal.app"
    echo "5. Ensure the terminal app is checked (✅)"
    echo "6. Close System Settings"
    echo "7. Restart your terminal completely"
    echo ""
    echo "💡 After granting access:"
    echo "  • Restart your terminal"
    echo "  • Run this check again: bash scripts/check-permissions.sh"
    echo "  • Then run: make macos-optimize"
    echo ""

    # Try to open System Settings automatically
    if command -v open >/dev/null 2>&1; then
        echo "🔍 Opening Privacy & Security settings..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Disk"
    fi

    echo ""
    echo "❌ Permission check failed. Grant access and try again."
    exit 1
fi