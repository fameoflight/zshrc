#!/usr/bin/env bash
# @category: system
# @description: Update Calibre e-book manager to latest version on macOS
# @tags: calibre, macos, update, ebooks

#
# Update Calibre to the latest version on macOS
# Replaces any existing version in /Applications or ~/Applications
#
# Original Copyright (C) 2012 Faraz Yashar
# Modernized and improved by Hemant Verma
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.

set -euo pipefail

# Configuration
readonly CALIBRE_DOWNLOAD_URL="https://calibre-ebook.com/dist/osx"
readonly TMP_DMG="/tmp/calibre.dmg"
readonly APP_NAME="calibre.app"
readonly INSTALL_DIR="/Applications"

# Source centralized logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"

if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback definitions if logging.zsh not available
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
    log_warn() { log_warning "$1"; }  # Backward compatibility alias
fi

# Exit with error message
error_exit() {
    log_error "${1:-Unknown Error}"
    log_error "You can manually download and install Calibre from https://calibre-ebook.com/download_osx"
    exit "${2:-1}"
}

# Check if we're on macOS
check_platform() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error_exit "This script only works on macOS (detected: $(uname))"
    fi
}

# Safely kill Calibre if running
stop_calibre() {
    if pgrep -f calibre >/dev/null 2>&1; then
        log_info "Stopping running Calibre processes..."
        pkill -f calibre || true
        sleep 2
    fi
}

# Download Calibre DMG with progress
download_calibre() {
    log_info "Downloading Calibre from $CALIBRE_DOWNLOAD_URL..."
    
    # Clean up any existing download
    [[ -f "$TMP_DMG" ]] && rmtrash -f "$TMP_DMG"
    
    # Download with progress bar and proper error handling
    if ! curl -L --progress-bar --fail --output "$TMP_DMG" "$CALIBRE_DOWNLOAD_URL"; then
        error_exit "Failed to download Calibre from $CALIBRE_DOWNLOAD_URL"
    fi
    
    # Verify download
    if [[ ! -f "$TMP_DMG" ]] || [[ ! -s "$TMP_DMG" ]]; then
        error_exit "Downloaded file is missing or empty"
    fi
    
    log_success "Download completed successfully"
}

# Mount DMG and return mount point
mount_dmg() {
    log_info "Mounting Calibre disk image..."
    
    if ! hdiutil attach "$TMP_DMG" -quiet; then
        error_exit "Failed to mount $TMP_DMG"
    fi
    
    # Find the mount point
    local mount_point
    mount_point=$(find /Volumes -name "calibre*" -maxdepth 1 -type d | head -1)
    
    if [[ -z "$mount_point" ]]; then
        error_exit "Could not find mounted Calibre volume"
    fi
    
    if [[ ! -d "$mount_point/$APP_NAME" ]]; then
        hdiutil detach "$mount_point" -quiet || true
        error_exit "Could not find $APP_NAME in the mounted volume"
    fi
    
    log_success "Mounted disk image at $mount_point"
    echo "$mount_point"
}

# Backup existing Calibre installation
backup_existing() {
    local backup_needed=false
    local backup_dir="/tmp/calibre-backup-$(date +%s).app"
    
    # Check ~/Applications first
    if [[ -d "$HOME/Applications/$APP_NAME" ]]; then
        log_info "Backing up existing Calibre from ~/Applications..."
        mv "$HOME/Applications/$APP_NAME" "$backup_dir"
        backup_needed=true
    elif [[ -d "$INSTALL_DIR/$APP_NAME" ]]; then
        log_info "Backing up existing Calibre from $INSTALL_DIR..."
        mv "$INSTALL_DIR/$APP_NAME" "$backup_dir"
        backup_needed=true
    fi
    
    if [[ "$backup_needed" == true ]]; then
        log_success "Backup created at $backup_dir"
    fi
}

# Install Calibre
install_calibre() {
    local mount_point="$1"
    
    log_info "Installing Calibre to $INSTALL_DIR..."
    
    # Ensure target directory exists and is writable
    if [[ ! -d "$INSTALL_DIR" ]]; then
        error_exit "$INSTALL_DIR does not exist"
    fi
    
    if [[ ! -w "$INSTALL_DIR" ]]; then
        log_warn "$INSTALL_DIR is not writable, you may need to run with sudo"
    fi
    
    # Copy the application
    if ! cp -R "$mount_point/$APP_NAME" "$INSTALL_DIR/$APP_NAME"; then
        error_exit "Failed to copy $APP_NAME to $INSTALL_DIR"
    fi
    
    log_success "Calibre installed successfully to $INSTALL_DIR/$APP_NAME"
}

# Unmount DMG
cleanup_dmg() {
    local mount_point="$1"
    
    log_info "Cleaning up..."
    
    # Unmount the DMG
    if ! hdiutil detach "$mount_point" -quiet; then
        log_warn "Failed to unmount $mount_point (this is usually not critical)"
    fi
    
    # Remove temporary DMG
    [[ -f "$TMP_DMG" ]] && rmtrash -f "$TMP_DMG"
}

# Launch Calibre
launch_calibre() {
    if [[ -d "$INSTALL_DIR/$APP_NAME" ]]; then
        log_info "Launching Calibre..."
        open "$INSTALL_DIR/$APP_NAME"
        log_success "Calibre has been launched!"
    else
        log_error "Installation verification failed - $INSTALL_DIR/$APP_NAME not found"
        return 1
    fi
}

# Show version info
show_version() {
    if [[ -d "$INSTALL_DIR/$APP_NAME" ]]; then
        local version
        version=$(defaults read "$INSTALL_DIR/$APP_NAME/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
        log_success "Installed Calibre version: $version"
    fi
}

# Main execution
main() {
    echo "🚀 Calibre Updater for macOS"
    echo "=============================="
    
    check_platform
    stop_calibre
    download_calibre
    
    local mount_point
    mount_point=$(mount_dmg)
    
    # Ensure cleanup happens even if script fails
    trap "cleanup_dmg '$mount_point'" EXIT
    
    backup_existing
    install_calibre "$mount_point"
    show_version
    launch_calibre
    
    echo ""
    log_success "Calibre update completed successfully! 🎉"
}

# Show help
show_help() {
    cat << EOF
Calibre Updater for macOS

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show current installed Calibre version (if any)
    --no-launch     Don't launch Calibre after installation

EXAMPLES:
    $0              Update Calibre and launch it
    $0 --no-launch  Update Calibre but don't launch it
    $0 --version    Show currently installed version

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                if [[ -d "$INSTALL_DIR/$APP_NAME" ]]; then
                    show_version
                else
                    log_error "Calibre is not installed in $INSTALL_DIR"
                    exit 1
                fi
                exit 0
                ;;
            --no-launch)
                NO_LAUNCH=1
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Override launch function if --no-launch specified
if [[ "${NO_LAUNCH:-}" == "1" ]]; then
    launch_calibre() {
        log_info "Skipping launch as requested"
        show_version
    }
fi

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi