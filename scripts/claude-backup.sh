#!/bin/bash
# Claude Settings Backup Script
# Backs up Claude Code settings from ~/.claude to the repository

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
    echo "🤖 Claude Settings Backup Script"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --dry-run      Show what would be backed up without doing it"
    echo ""
    echo "What gets backed up:"
    echo "  • Global CLAUDE.md configuration"
    echo "  • Claude Code settings.json"
    echo "  • Project configurations (excluding sensitive data)"
    echo ""
    echo "What gets excluded:"
    echo "  • Shell snapshots (temporary data)"
    echo "  • Todos (workspace-specific)"
    echo "  • Statsig data (analytics)"
    echo "  • Large project files"
    echo ""
    echo "Backup location: $CLAUDE_BACKUP_DIR"
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
backup_claude_settings() {
    log_info "Starting Claude settings backup..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Check if Claude directory exists
    if [ ! -d "$CLAUDE_USER_DIR" ]; then
        log_warning "No Claude directory found at $CLAUDE_USER_DIR"
        log_info "This might be the first time running Claude Code"
        return 0
    fi
    
    # Create backup directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$CLAUDE_BACKUP_DIR"
    fi
    log_info "Backup directory: $CLAUDE_BACKUP_DIR"
    
    # Essential files to backup
    declare -a ESSENTIAL_FILES=(
        "CLAUDE.md"
        "settings.json"
    )
    
    # Backup essential files
    for file in "${ESSENTIAL_FILES[@]}"; do
        source_path="$CLAUDE_USER_DIR/$file"
        dest_path="$CLAUDE_BACKUP_DIR/$file"
        
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
    
    # Backup project configurations (selective)
    if [ -d "$CLAUDE_USER_DIR/projects" ]; then
        log_info "Backing up project configurations..."
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$CLAUDE_BACKUP_DIR/projects"
            
            # Only backup small config files, not large project data
            find "$CLAUDE_USER_DIR/projects" -name "*.json" -o -name "*.md" -o -name "*.txt" | \
            while read -r file; do
                # Get relative path from projects directory
                rel_path="${file#$CLAUDE_USER_DIR/projects/}"
                dest_file="$CLAUDE_BACKUP_DIR/projects/$rel_path"
                
                # Create directory structure
                mkdir -p "$(dirname "$dest_file")"
                
                # Only copy small files (< 1MB)
                if [ "$(stat -f%z "$file" 2>/dev/null || echo 0)" -lt 1048576 ]; then
                    cp "$file" "$dest_file"
                fi
            done
        fi
        log_success "Project configurations backed up"
    else
        log_info "No projects directory found, skipping"
    fi
    
    # Clean up unwanted files that might have been backed up previously
    if [ "$DRY_RUN" = false ]; then
        log_info "Cleaning up unwanted files..."
        
        # Remove unwanted directories and files
        unwanted_items=(
            "$CLAUDE_BACKUP_DIR/shell-snapshots"
            "$CLAUDE_BACKUP_DIR/todos"
            "$CLAUDE_BACKUP_DIR/statsig"
        )
        
        for item in "${unwanted_items[@]}"; do
            if [ -e "$item" ]; then
                rm -rf "$item"
                log_info "Removed unwanted item: $(basename "$item")"
            fi
        done
        
        # Remove large files from projects backup
        find "$CLAUDE_BACKUP_DIR/projects" -type f -size +1M -delete 2>/dev/null || true
    fi
    
    log_success "Claude settings backup completed!"
    
    # Show what was backed up
    if [ "$DRY_RUN" = false ] && [ -d "$CLAUDE_BACKUP_DIR" ]; then
        log_info "Backed up to: $CLAUDE_BACKUP_DIR"
        echo ""
        tree "$CLAUDE_BACKUP_DIR" 2>/dev/null || find "$CLAUDE_BACKUP_DIR" -type f | head -20
    fi
}

# Run the backup
backup_claude_settings