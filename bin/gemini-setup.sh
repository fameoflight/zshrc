#!/bin/bash
# Gemini Settings Symlink Setup Script  
# Creates symlinks from ~/.gemini to the repository Settings/Gemini directory

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
SETTINGS_DIR="$ZSH_CONFIG/Settings"
GEMINI_SOURCE_DIR="$SETTINGS_DIR/Gemini"
GEMINI_USER_DIR="$HOME/.gemini"

# Source logging functions
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
    echo "🔗 Gemini Settings Symlink Setup Script"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo " --help, -h     Show this help message"
    echo " --dry-run      Show what would be linked without doing it"
    echo " --force        Remove existing files/links without prompting"
    echo ""
    echo "What gets symlinked:"
    echo " • Global GEMINI.md configuration"
    echo " • Gemini settings.json"
    echo " • Project configurations directory (if available)"
    echo ""
    echo "Source location: $GEMINI_SOURCE_DIR"
    echo "Target location: $GEMINI_USER_DIR"
    echo ""
    echo "Note: This creates symlinks, so changes are immediately synchronized"
    echo "     between the repository and Gemini CLI."
}

# Dry run and force modes
DRY_RUN=false
FORCE=false

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
        --force)
            FORCE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Function to prompt for confirmation
confirm_replace() {
    local target="$1"
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo -n "Target $target already exists. Replace with symlink? [y/N]: "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to safely create symlink
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"
    
    # Check if target already exists
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
            log_info "$name symlink already exists and is correct"
            return 0
        fi
        
        if ! confirm_replace "$(basename "$target")"; then
            log_info "Skipping $name (user chose not to replace)"
            return 0
        fi
        
        log_info "Removing existing $name..."
        if [ "$DRY_RUN" = false ]; then
            rm -rf "$target"
        fi
    fi
    
    log_info "Creating $name symlink..."
    if [ "$DRY_RUN" = false ]; then
        ln -sf "$source" "$target"
    fi
    log_success "$name symlinked"
}

# Main setup function
setup_gemini_symlinks() {
    log_info "Starting Gemini settings symlink setup..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Check if source directory exists
    if [ ! -d "$GEMINI_SOURCE_DIR" ]; then
        log_error "No Gemini settings found at $GEMINI_SOURCE_DIR"
        log_info "Make sure the Settings/Gemini directory exists in the repository"
        exit 1
    fi
    
    # Create Gemini user directory if it doesn't exist
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$GEMINI_USER_DIR"
    fi
    log_info "Target directory: $GEMINI_USER_DIR"
    
    # Files to symlink
    declare -a SYMLINK_FILES=(
        "GEMINI.md"
        "settings.json"
    )
    
    # Create symlinks for essential files
    for file in "${SYMLINK_FILES[@]}"; do
        source_path="$GEMINI_SOURCE_DIR/$file"
        dest_path="$GEMINI_USER_DIR/$file"
        
        if [ -f "$source_path" ]; then
            create_symlink "$source_path" "$dest_path" "$file"
        else
            log_warning "$file not found in source, skipping"
        fi
    done
    
    # Symlink projects directory if available
    if [ -d "$GEMINI_SOURCE_DIR/projects" ]; then
        create_symlink "$GEMINI_SOURCE_DIR/projects" "$GEMINI_USER_DIR/projects" "projects directory"
    else
        log_info "No projects directory found in source"
    fi
    
    log_success "Gemini settings symlinks setup completed!"
    
    # Show what was linked
    if [ "$DRY_RUN" = false ] && [ -d "$GEMINI_USER_DIR" ]; then
        log_info "Symlinks created in: $GEMINI_USER_DIR"
        echo ""
        echo "📁 Current Gemini directory contents:"
        ls -la "$GEMINI_USER_DIR" | grep -E "(GEMINI\.md|settings\.json|projects)" || echo " No relevant symlinks found"
        echo ""
        log_info "Changes to files in $GEMINI_SOURCE_DIR will be immediately"
        log_info "reflected in Gemini CLI (no restart required for most changes)"
    fi
}

# Run the setup
setup_gemini_symlinks