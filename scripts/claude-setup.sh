#!/bin/bash
# Claude Settings Setup Script  
# Restores Claude Code settings from the repository to ~/.claude

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
SETTINGS_DIR="$ZSH_CONFIG/Settings"
CLAUDE_BACKUP_DIR="$SETTINGS_DIR/Claude"
CLAUDE_USER_DIR="$HOME/.claude"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Show help
show_help() {
    echo "🤖 Claude Settings Setup Script"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --dry-run      Show what would be restored without doing it"
    echo "  --force        Overwrite existing settings without prompting"
    echo ""
    echo "What gets restored:"
    echo "  • Global CLAUDE.md configuration"
    echo "  • Claude Code settings.json"
    echo "  • Project configurations (if available)"
    echo ""
    echo "Source location: $CLAUDE_BACKUP_DIR"
    echo "Target location: $CLAUDE_USER_DIR"
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
confirm_overwrite() {
    local file="$1"
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo -n "File $file already exists. Overwrite? [y/N]: "
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

# Main setup function
setup_claude_settings() {
    log_info "Starting Claude settings setup..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Check if backup directory exists
    if [ ! -d "$CLAUDE_BACKUP_DIR" ]; then
        log_error "No Claude backup found at $CLAUDE_BACKUP_DIR"
        log_info "Run 'claude-backup' first to create a backup, or check if the Settings/Claude directory exists"
        exit 1
    fi
    
    # Create Claude user directory if it doesn't exist
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$CLAUDE_USER_DIR"
    fi
    log_info "Target directory: $CLAUDE_USER_DIR"
    
    # Essential files to restore
    declare -a ESSENTIAL_FILES=(
        "CLAUDE.md"
        "settings.json"
    )
    
    # Restore essential files
    for file in "${ESSENTIAL_FILES[@]}"; do
        source_path="$CLAUDE_BACKUP_DIR/$file"
        dest_path="$CLAUDE_USER_DIR/$file"
        
        if [ -f "$source_path" ]; then
            # Check if destination exists and prompt if needed
            if [ -f "$dest_path" ] && [ "$DRY_RUN" = false ]; then
                if ! confirm_overwrite "$file"; then
                    log_info "Skipping $file (user chose not to overwrite)"
                    continue
                fi
            fi
            
            log_info "Restoring $file..."
            if [ "$DRY_RUN" = false ]; then
                cp "$source_path" "$dest_path"
            fi
            log_success "$file restored"
        else
            log_warning "$file not found in backup, skipping"
        fi
    done
    
    # Restore project configurations if available
    if [ -d "$CLAUDE_BACKUP_DIR/projects" ]; then
        log_info "Restoring project configurations..."
        if [ "$DRY_RUN" = false ]; then
            # Check if projects directory exists
            if [ -d "$CLAUDE_USER_DIR/projects" ] && [ "$FORCE" = false ]; then
                echo -n "Projects directory already exists. Merge configurations? [y/N]: "
                read -r response
                case "$response" in
                    [yY]|[yY][eE][sS])
                        # Proceed with merge
                        ;;
                    *)
                        log_info "Skipping project configurations"
                        return
                        ;;
                esac
            fi
            
            # Copy project configurations
            cp -r "$CLAUDE_BACKUP_DIR/projects" "$CLAUDE_USER_DIR/" 2>/dev/null || {
                log_warning "Could not restore all project configurations"
            }
        fi
        log_success "Project configurations restored"
    else
        log_info "No project configurations found in backup"
    fi
    
    # Set proper permissions
    if [ "$DRY_RUN" = false ]; then
        chmod -R u+rw "$CLAUDE_USER_DIR"
        find "$CLAUDE_USER_DIR" -type d -exec chmod u+x {} \;
    fi
    
    log_success "Claude settings setup completed!"
    
    # Show what was restored
    if [ "$DRY_RUN" = false ] && [ -d "$CLAUDE_USER_DIR" ]; then
        log_info "Settings restored to: $CLAUDE_USER_DIR"
        echo ""
        echo "📁 Current Claude directory contents:"
        tree "$CLAUDE_USER_DIR" -L 2 2>/dev/null || ls -la "$CLAUDE_USER_DIR"
        echo ""
        log_info "You may need to restart Claude Code for all settings to take effect"
    fi
}

# Run the setup
setup_claude_settings