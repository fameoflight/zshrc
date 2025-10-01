#!/bin/bash

# Check if a package is installed via Homebrew
# Usage: check-install.sh <package_name>
# Returns: 0 if installed, 1 if not installed

set -euo pipefail

PACKAGE_NAME="$1"

if [[ -z "$PACKAGE_NAME" ]]; then
    echo "❌ Usage: check-install.sh <package_name>" >&2
    exit 1
fi

# Check if package is installed
if brew list "$PACKAGE_NAME" >/dev/null 2>&1; then
    echo "✅ $PACKAGE_NAME already installed"
    exit 0
else
    echo "📦 Installing $PACKAGE_NAME..."
    exit 1
fi