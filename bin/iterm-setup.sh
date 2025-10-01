#!/bin/bash
# iTerm2 Essential Settings Setup Script
# Restores iTerm2 configurations from backed up settings files

set -euo pipefail

# Source logging functions
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback definitions if logging.zsh not available
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
    log_progress() { echo -e "\033[0;36m🔄 $1\033[0m"; }
    log_section() { echo -e "\033[0;35m🔧 $1\033[0m"; }
    log_complete() { echo -e "\033[1;32m🎉 $1 complete!\033[0m"; }
    log_separator() { echo -e "\033[0;90m----------------------------------------\033[0m"; }
fi

# Configuration
SETTINGS_DIR="${ZSH_CONFIG:-$HOME/.config/zsh}/Settings"
ITERM_BACKUP_DIR="$SETTINGS_DIR/iTerm"
ITERM_PREFS_PATH="$HOME/Library/Preferences"
ITERM_APP_SUPPORT="$HOME/Library/Application Support/iTerm2"

# Options
DRY_RUN=false
FORCE=false
BACKUP_EXISTING=true

show_help() {
    log_section "iTerm2 Essential Settings Setup"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo " -h, --help          Show this help message"
    echo " -n, --dry-run       Show what would be done without making changes"
    echo " -f, --force         Overwrite existing settings without prompting"
    echo " --no-backup         Skip backing up existing settings"
    echo " -v, --version       Show script version"
    echo ""
    echo "Restores:"
    echo " • iTerm2 preferences (com.googlecode.iterm2.plist)"
    echo " • iTerm2 private preferences (com.googlecode.iterm2.private.plist)"
    echo " • Dynamic Profiles (if available)"
    echo " • Custom key mappings and themes"
    echo ""
    echo "Examples:"
    echo " $0                  # Standard setup"
    echo " $0 --dry-run        # Preview changes"
    echo " $0 --force          # Overwrite without prompting"
}

show_version() {
    echo "iTerm2 Setup Script v1.0.0"
    echo "Part of ZSH Configuration Suite"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --no-backup)
            BACKUP_EXISTING=false
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if backup directory exists
check_backup_availability() {
    log_info "Checking for iTerm2 backup files..."
    
    if [[ ! -d "$ITERM_BACKUP_DIR" ]]; then
        log_error "Backup directory not found: $ITERM_BACKUP_DIR"
        log_info "Run 'iterm-backup' first to create backup files"
        return 1
    fi
    
    local main_pref="$ITERM_BACKUP_DIR/com.googlecode.iterm2.plist"
    if [[ ! -f "$main_pref" ]]; then
        log_error "Main iTerm2 preferences backup not found at $main_pref"
        log_info "Run 'iterm-backup' first to create backup files"
        return 1
    fi
    
    log_success "iTerm2 backup files found"
    return 0
}

# Check if iTerm2 is currently running
check_iterm_running() {
    if pgrep -f "iTerm" >/dev/null 2>&1; then
        log_warning "iTerm2 is currently running"
        if [[ "$FORCE" == false ]]; then
            echo -n "iTerm2 should be closed before restoring settings. Continue anyway? [y/N] "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_info "Setup cancelled. Please close iTerm2 and run again."
                exit 1
            fi
        fi
        log_info "Proceeding with iTerm2 running (changes will take effect after restart)"
    fi
}

# Backup existing settings
backup_existing_settings() {
    if [[ "$BACKUP_EXISTING" == false ]]; then
        return 0
    fi
    
    log_info "Backing up existing iTerm2 settings..."
    local backup_suffix=$(date +"%Y%m%d_%H%M%S")
    local backup_made=false
    
    for file in "com.googlecode.iterm2.plist" "com.googlecode.iterm2.private.plist"; do
        local source_path="$ITERM_PREFS_PATH/$file"
        local backup_path="$ITERM_PREFS_PATH/${file}.backup_${backup_suffix}"
        
        if [[ -f "$source_path" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                cp "$source_path" "$backup_path"
                log_success "Backed up $file to ${file}.backup_${backup_suffix}"
                backup_made=true
            else
                log_info "Would backup $file to ${file}.backup_${backup_suffix}"
            fi
        fi
    done
    
    if [[ "$backup_made" == true ]]; then
        log_info "Existing settings backed up with suffix: backup_${backup_suffix}"
    fi
}

# Restore iTerm2 preferences
restore_iterm_settings() {
    log_section "Restoring iTerm2 Settings"
    
    local files_restored=0
    
    # Main preference files
    local pref_files=(
        "com.googlecode.iterm2.plist"
        "com.googlecode.iterm2.private.plist"
    )
    
    for file in "${pref_files[@]}"; do
        local source_path="$ITERM_BACKUP_DIR/$file"
        local dest_path="$ITERM_PREFS_PATH/$file"
        
        if [[ -f "$source_path" ]]; then
            log_progress "Restoring $file..."
            
            if [[ "$DRY_RUN" == false ]]; then
                cp "$source_path" "$dest_path"
                log_success "Restored $file"
                ((files_restored++))
            else
                log_info "Would restore $file to $dest_path"
            fi
        else
            log_warning "Backup file not found: $file"
        fi
    done
    
    # Optional backup files
    local optional_files=(
        "com.googlecode.iterm2.plist.bak"
    )
    
    for file in "${optional_files[@]}"; do
        local source_path="$ITERM_BACKUP_DIR/$file"
        local dest_path="$ITERM_PREFS_PATH/$file"
        
        if [[ -f "$source_path" ]]; then
            log_progress "Restoring optional file $file..."
            
            if [[ "$DRY_RUN" == false ]]; then
                cp "$source_path" "$dest_path"
                log_success "Restored optional file $file"
                ((files_restored++))
            else
                log_info "Would restore optional file $file to $dest_path"
            fi
        fi
    done
    
    # Dynamic Profiles
    local dynamic_profiles_source="$ITERM_BACKUP_DIR/DynamicProfiles"
    local dynamic_profiles_dest="$ITERM_APP_SUPPORT/DynamicProfiles"
    
    if [[ -d "$dynamic_profiles_source" ]]; then
        log_progress "Restoring Dynamic Profiles..."
        
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$ITERM_APP_SUPPORT"
            if [[ -d "$dynamic_profiles_dest" ]]; then
                rm -rf "$dynamic_profiles_dest"
            fi
            cp -R "$dynamic_profiles_source" "$dynamic_profiles_dest"
            
            # Fix nested directory structure if it exists
            if [[ -d "$dynamic_profiles_dest/DynamicProfiles" ]]; then
                log_warning "Fixing nested DynamicProfiles directory structure..."
                mv "$dynamic_profiles_dest/DynamicProfiles"/* "$dynamic_profiles_dest/" 2>/dev/null || true
                rmdir "$dynamic_profiles_dest/DynamicProfiles" 2>/dev/null || true
            fi
            
            log_success "Restored Dynamic Profiles"
            ((files_restored++))
        else
            log_info "Would restore Dynamic Profiles to $dynamic_profiles_dest"
        fi
    fi
    
    if [[ $files_restored -gt 0 ]]; then
        log_success "Restored $files_restored iTerm2 configuration files"
    else
        log_warning "No files were restored"
    fi
}

# Verify restoration
verify_restoration() {
    log_info "Verifying restored settings..."
    
    local main_pref="$ITERM_PREFS_PATH/com.googlecode.iterm2.plist"
    if [[ -f "$main_pref" ]]; then
        log_success "Main preferences file verified"
        
        # Check if the restored file is readable
        if plutil -lint "$main_pref" >/dev/null 2>&1; then
            log_success "Preferences file format is valid"
        else
            log_warning "Preferences file may have formatting issues"
        fi
    else
        log_error "Main preferences file not found after restoration"
        return 1
    fi
    
    return 0
}

# Show post-setup instructions
show_post_setup_instructions() {
    log_separator
    log_complete "iTerm2 Setup"
    echo ""
    echo "Next steps:"
    echo " 1. 🔄 Restart iTerm2 to load the restored settings"
    echo " 2. ⚙️  Verify your profiles, themes, and key mappings"
    echo " 3. 🎨 Check color schemes and font settings"
    echo " 4. ⌨️  Test custom keyboard shortcuts"
    echo ""
    echo "If settings don't appear correctly:"
    echo " • Ensure iTerm2 is fully closed before restarting"
    echo " • Check Console app for any iTerm2 error messages"
    echo " • Run 'iterm-backup' to create a fresh backup if needed"
    echo ""
    log_info "Configuration files restored to:"
    echo " 📁 $ITERM_PREFS_PATH/"
    if [[ -d "$ITERM_APP_SUPPORT/DynamicProfiles" ]]; then
        echo " 📁 $ITERM_APP_SUPPORT/DynamicProfiles/"
    fi
}

# Main execution
main() {
    if [[ "$DRY_RUN" == true ]]; then
        log_section "iTerm2 Setup (Dry Run Mode)"
    else
        log_section "iTerm2 Setup"
    fi
    
    # Pre-flight checks
    if ! check_backup_availability; then
        exit 1
    fi
    
    check_iterm_running
    
    # Create necessary directories
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$ITERM_PREFS_PATH"
        mkdir -p "$ITERM_APP_SUPPORT"
    fi
    
    # Backup existing settings
    backup_existing_settings
    
    # Restore settings
    restore_iterm_settings
    
    # Verify restoration (skip in dry run mode)
    if [[ "$DRY_RUN" == false ]]; then
        if verify_restoration; then
            show_post_setup_instructions
        else
            log_error "Setup completed but verification failed"
            exit 1
        fi
    else
        log_info "Dry run completed - no changes made"
    fi
}

# Run main function
main "$@"