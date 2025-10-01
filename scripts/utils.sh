#!/bin/bash
# Utility functions for scripts

# Safe copy function - only copies if files differ
# Usage: safe_cp <source> <destination> [description]
safe_cp() {
    local source="$1"
    local destination="$2"
    local description="${3:-file}"

    if [[ ! -f "$source" ]]; then
        echo "❌ Source file not found: $source"
        return 1
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$destination")"

    # Check if files are different
    if ! cmp -s "$source" "$destination" 2>/dev/null; then
        cp "$source" "$destination"
        echo "✅ $description restored"
        return 0
    else
        echo "✅ $description already up to date"
        return 0
    fi
}

# Safe copy with executable permissions
# Usage: safe_cp_exec <source> <destination> [description]
safe_cp_exec() {
    local source="$1"
    local destination="$2"
    local description="${3:-file}"

    if safe_cp "$source" "$destination" "$description"; then
        chmod +x "$destination"
    fi
}

# Safe directory copy (recursive)
# Usage: safe_cp_r <source_dir> <destination_dir> [description]
safe_cp_r() {
    local source="$1"
    local destination="$2"
    local description="${3:-directory}"

    if [[ ! -d "$source" ]]; then
        echo "❌ Source directory not found: $source"
        return 1
    fi

    mkdir -p "$destination"

    # Check if directories are different by comparing contents
    if ! diff -rq "$source" "$destination" >/dev/null 2>&1; then
        cp -r "$source"/* "$destination/"
        echo "✅ $description restored"
    else
        echo "✅ $description already up to date"
    fi
}