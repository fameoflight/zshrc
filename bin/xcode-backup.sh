#!/bin/bash
# Xcode Essential Settings Backup Script
# Backs up only the important Xcode configuration files, excluding clutter

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
SETTINGS_DIR="$ZSH_CONFIG/Settings"
XCODE_BACKUP_DIR="$SETTINGS_DIR/XCode"
XCODE_USER_DATA="$HOME/Library/Developer/Xcode/UserData"

# Source centralized logging functions
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback definitions if logging.zsh not available
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
fi

# Show help
show_help() {
    echo "Xcode Essential Settings Backup"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo " --help, -h     Show this help message"
    echo " --dry-run      Show what would be backed up without doing it"
    echo ""
    echo "What gets backed up:"
    echo " • Font and color themes"
    echo " • Custom key bindings"
    echo " • IDE preferences state"
    echo " • Xcode system preferences"
    echo ""
    echo "What gets excluded:"
    echo " • Simulator device data"
    echo " • Build caches"
    echo " • Capabilities cache"
    echo " • Previews data"
    echo " • Provisioning profiles"
    echo " • XcodeCloud data"
}

# Dry run mode
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Main backup function
backup_xcode_settings() {
    log_info "Starting Xcode essential settings backup..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Check if Xcode UserData exists
    if [ ! -d "$XCODE_USER_DATA" ]; then
        log_warning "No Xcode UserData found at $XCODE_USER_DATA"
        return 0
    fi
    
    # Create backup directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$XCODE_BACKUP_DIR/UserData"
    fi
    log_info "Backup directory: $XCODE_BACKUP_DIR"
    
    # Essential files and directories to backup
    declare -a ESSENTIAL_ITEMS=(
        "FontAndColorThemes"
        "KeyBindings"
        "IDEPreferencesController.xcuserstate"
    )
    
    # Backup essential UserData items
    for item in "${ESSENTIAL_ITEMS[@]}"; do
        source_path="$XCODE_USER_DATA/$item"
        dest_path="$XCODE_BACKUP_DIR/UserData/$item"
        
        if [ -e "$source_path" ]; then
            log_info "Backing up $item..."
            if [ "$DRY_RUN" = false ]; then
                rmtrash -rf "$dest_path" 2>/dev/null || true
                cp -r "$source_path" "$dest_path"
            fi
            log_success "$item backed up"
        else
            log_warning "$item not found, skipping"
        fi
    done
    
    # Backup system preferences
    log_info "Backing up Xcode system preferences..."
    if defaults read com.apple.dt.Xcode >/dev/null 2>&1; then
        if [ "$DRY_RUN" = false ]; then
            defaults export com.apple.dt.Xcode "$XCODE_BACKUP_DIR/com.apple.dt.Xcode.plist"
        fi
        log_success "System preferences backed up"
    else
        log_warning "No Xcode preferences found to backup"
    fi
    
    # Clean up unwanted files that might have been backed up previously
    if [ "$DRY_RUN" = false ]; then
        log_info "Cleaning up unwanted files..."
        
        # Remove simulator and cache data if they exist in backup
        unwanted_dirs=(
            "$XCODE_BACKUP_DIR/UserData/Previews"
            "$XCODE_BACKUP_DIR/UserData/Capabilities"
            "$XCODE_BACKUP_DIR/UserData/XcodeCloud"
            "$XCODE_BACKUP_DIR/UserData/Provisioning Profiles"
            "$XCODE_BACKUP_DIR/UserData/IDEEditorInteractivityHistory"
        )
        
        for dir in "${unwanted_dirs[@]}"; do
            if [ -d "$dir" ]; then
                rmtrash -rf "$dir"
                log_info "Removed unwanted directory: $(basename "$dir")"
            fi
        done
    fi
    
    log_success "Xcode essential settings backup completed!"
    
    # Show what was backed up
    if [ "$DRY_RUN" = false ] && [ -d "$XCODE_BACKUP_DIR" ]; then
        log_info "Backed up to: $XCODE_BACKUP_DIR"
        echo ""
        tree "$XCODE_BACKUP_DIR" 2>/dev/null || find "$XCODE_BACKUP_DIR" -type f | head -10
    fi
}

# Run the backup
backup_xcode_settings