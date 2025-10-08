#!/bin/bash

# Quiet Homebrew package installer
# Usage: brew-install-quiet.sh <package_name>
# Only installs if package is not already installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_INSTALL="$SCRIPT_DIR/check-install.sh"

PACKAGE_NAME="$1"

if [[ -z "$PACKAGE_NAME" ]]; then
    echo "❌ Usage: brew-install-quiet.sh <package_name>" >&2
    exit 1
fi

# Check if already installed
if "$CHECK_INSTALL" "$PACKAGE_NAME" >/dev/null 2>&1; then
    # Package is already installed, do nothing
    exit 0
else
    # Package not installed, install it
    if brew install "$PACKAGE_NAME" >/dev/null 2>&1; then
        echo "✅ $PACKAGE_NAME installed successfully"
    else
        echo "⚠️  Failed to install $PACKAGE_NAME"
        exit 1
    fi
fi