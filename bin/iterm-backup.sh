#!/bin/bash
# @category: backup
# @description: Backup essential iTerm2 configurations
# @tags: iterm2, macos, backup, configuration

# iTerm2 Essential Settings Backup Script
# Backs up only the important iTerm2 configuration files, excluding clutter

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
SETTINGS_DIR="$ZSH_CONFIG/Settings"
ITERM_BACKUP_DIR="$SETTINGS_DIR/iTerm"
ITERM_PREFS_PATH="$HOME/Library/Preferences"

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
    echo "iTerm2 Essential Settings Backup"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo " --help, -h     Show this help message"
    echo " --dry-run      Show what would be backed up without doing it"
    echo ""
    echo "What gets backed up:"
    echo " • iTerm2 preferences (com.googlecode.iterm2.plist)"
    echo " • iTerm2 private preferences (com.googlecode.iterm2.private.plist)"
    echo " • Dynamic profiles and color schemes"
    echo " • Custom key bindings and shell integrations"
    echo ""
    echo "Note: Large log files and cache data are excluded to keep backups lean."
}

# Parse command line arguments
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Use --help to see available options."
            exit 1
            ;;
    esac
done

# Check if iTerm2 preferences exist
check_iterm_installation() {
    log_info "Checking for iTerm2 installation..."
    
    local main_pref="$ITERM_PREFS_PATH/com.googlecode.iterm2.plist"
    local private_pref="$ITERM_PREFS_PATH/com.googlecode.iterm2.private.plist"
    
    if [[ ! -f "$main_pref" ]]; then
        log_warning "iTerm2 main preferences not found at $main_pref"
        log_info "iTerm2 may not be installed or hasn't been run yet"
        return 1
    fi
    
    log_success "iTerm2 installation found"
    return 0
}

# Main backup function
backup_iterm_settings() {
    log_info "Starting iTerm2 essential settings backup..."
    
    # Create backup directory
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$ITERM_BACKUP_DIR"
    fi
    
    log_info "Backup directory: $ITERM_BACKUP_DIR"
    
    # Essential files to backup
    local files_to_backup=(
        "com.googlecode.iterm2.plist"
        "com.googlecode.iterm2.private.plist"
    )
    
    # Backup main preference files
    for file in "${files_to_backup[@]}"; do
        local source_path="$ITERM_PREFS_PATH/$file"
        local dest_path="$ITERM_BACKUP_DIR/$file"
        
        if [[ -f "$source_path" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                cp "$source_path" "$dest_path"
                log_success "Backed up: $file"
            else
                log_info "[DRY RUN] Would backup: $file"
            fi
        else
            log_warning "File not found, skipping: $file"
        fi
    done
    
    # Check for additional iTerm2 related files
    local additional_files=(
        "com.googlecode.iterm2.plist.bak"
    )
    
    for file in "${additional_files[@]}"; do
        local source_path="$ITERM_PREFS_PATH/$file"
        local dest_path="$ITERM_BACKUP_DIR/$file"
        
        if [[ -f "$source_path" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                cp "$source_path" "$dest_path"
                log_success "Backed up additional file: $file"
            else
                log_info "[DRY RUN] Would backup additional file: $file"
            fi
        fi
    done
    
    # Check for DynamicProfiles directory if it exists
    local dynamic_profiles_source="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    local dynamic_profiles_dest="$ITERM_BACKUP_DIR/DynamicProfiles"
    
    if [[ -d "$dynamic_profiles_source" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            # Remove existing backup directory to avoid nested structure
            rmtrash -rf "$dynamic_profiles_dest" 2>/dev/null || true
            # Copy the directory properly
            cp -R "$dynamic_profiles_source" "$dynamic_profiles_dest"
            log_success "Backed up: DynamicProfiles directory"
        else
            log_info "[DRY RUN] Would backup: DynamicProfiles directory"
        fi
    fi
    
    # Clean up any unwanted files that might have been copied
    if [[ "$DRY_RUN" == false ]]; then
        # Remove any cache or log files that shouldn't be in backup
        local cleanup_patterns=(
            "$ITERM_BACKUP_DIR/*.log"
            "$ITERM_BACKUP_DIR/*Cache*"
            "$ITERM_BACKUP_DIR/temp*"
        )
        
        for pattern in "${cleanup_patterns[@]}"; do
            rmtrash -rf $pattern 2>/dev/null || true
        done
    fi
    
    log_success "iTerm2 essential settings backup completed!"
    
    if [[ "$DRY_RUN" == false ]] && [[ -d "$ITERM_BACKUP_DIR" ]]; then
        log_info "Backed up to: $ITERM_BACKUP_DIR"
        tree "$ITERM_BACKUP_DIR" 2>/dev/null || find "$ITERM_BACKUP_DIR" -type f
    fi
}

# Run the backup
if check_iterm_installation; then
    backup_iterm_settings
else
    log_error "Cannot proceed without iTerm2 installation"
    exit 1
fi