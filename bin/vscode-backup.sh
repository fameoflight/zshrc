#!/bin/bash
# VS Code Essential Settings Backup Script
# Backs up only the important VS Code configuration files, excluding clutter

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
SETTINGS_DIR="$ZSH_CONFIG/Settings"
VSCODE_BACKUP_DIR="$SETTINGS_DIR/VSCode"
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

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
    echo "VS Code Essential Settings Backup"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo " --help, -h     Show this help message"
    echo " --dry-run      Show what would be backed up without doing it"
    echo ""
    echo "What gets backed up:"
    echo " • User settings (settings.json)"
    echo " • Custom keybindings"
    echo " • Custom snippets"
    echo " • Task and launch configurations"
    echo " • Extensions list"
    echo ""
    echo "What gets excluded:"
    echo " • Global storage (extension caches)"
    echo " • History files"
    echo " • Logs and temporary files"
    echo " • Workspace-specific settings"
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
backup_vscode_settings() {
    log_info "Starting VS Code essential settings backup..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Check if VS Code User directory exists
    if [ ! -d "$VSCODE_USER_DIR" ]; then
        log_warning "No VS Code User directory found at $VSCODE_USER_DIR"
        return 0
    fi
    
    # Create backup directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$VSCODE_BACKUP_DIR/User"
    fi
    log_info "Backup directory: $VSCODE_BACKUP_DIR"
    
    # Essential files to backup
    declare -a ESSENTIAL_FILES=(
        "settings.json"
        "keybindings.json" 
        "tasks.json"
        "launch.json"
        "locale.json"
    )
    
    # Essential directories to backup
    declare -a ESSENTIAL_DIRS=(
        "snippets"
    )
    
    # Backup essential files
    for file in "${ESSENTIAL_FILES[@]}"; do
        source_path="$VSCODE_USER_DIR/$file"
        dest_path="$VSCODE_BACKUP_DIR/User/$file"
        
        if [ -f "$source_path" ]; then
            log_info "Backing up $file..."
            if [ "$DRY_RUN" = false ]; then
                cp "$source_path" "$dest_path"
            fi
            log_success "$file backed up"
        else
            log_info "$file not found, skipping"
        fi
    done
    
    # Backup essential directories
    for dir in "${ESSENTIAL_DIRS[@]}"; do
        source_path="$VSCODE_USER_DIR/$dir"
        dest_path="$VSCODE_BACKUP_DIR/User/$dir"
        
        if [ -d "$source_path" ]; then
            log_info "Backing up $dir directory..."
            if [ "$DRY_RUN" = false ]; then
                rmtrash -rf "$dest_path" 2>/dev/null || true
                cp -r "$source_path" "$dest_path"
            fi
            log_success "$dir directory backed up"
        else
            log_info "$dir directory not found, skipping"
        fi
    done
    
    # Backup extensions list
    log_info "Backing up VS Code extensions list..."
    if command -v code >/dev/null 2>&1; then
        if [ "$DRY_RUN" = false ]; then
            code --list-extensions > "$VSCODE_BACKUP_DIR/extensions.txt" 2>/dev/null || {
                log_warning "Could not list extensions (VS Code might not be running)"
                touch "$VSCODE_BACKUP_DIR/extensions.txt"
            }
        fi
        log_success "Extensions list backed up"
    else
        log_warning "VS Code CLI not available, skipping extensions backup"
    fi
    
    # Clean up unwanted files that might have been backed up previously
    if [ "$DRY_RUN" = false ]; then
        log_info "Cleaning up unwanted files..."
        
        # Remove unwanted directories and files
        unwanted_items=(
            "$VSCODE_BACKUP_DIR/User/globalStorage"
            "$VSCODE_BACKUP_DIR/User/History"
            "$VSCODE_BACKUP_DIR/User/logs"
            "$VSCODE_BACKUP_DIR/User/CachedExtensions"
            "$VSCODE_BACKUP_DIR/User/CachedExtensionVSIXs"
            "$VSCODE_BACKUP_DIR/User/workspaceStorage"
            "$VSCODE_BACKUP_DIR/User/User"  # In case of recursive copy mistakes
        )
        
        for item in "${unwanted_items[@]}"; do
            if [ -e "$item" ]; then
                rmtrash -rf "$item"
                log_info "Removed unwanted item: $(basename "$item")"
            fi
        done
    fi
    
    log_success "VS Code essential settings backup completed!"
    
    # Show what was backed up
    if [ "$DRY_RUN" = false ] && [ -d "$VSCODE_BACKUP_DIR" ]; then
        log_info "Backed up to: $VSCODE_BACKUP_DIR"
        echo ""
        tree "$VSCODE_BACKUP_DIR" 2>/dev/null || find "$VSCODE_BACKUP_DIR" -type f
    fi
}

# Run the backup
backup_vscode_settings