#!/bin/bash

# Dropbox Backup Script
# Moves a directory to Dropbox backup folder and creates a symlink
# Usage: dropbox-backup [directory] [--help] [--dry-run]

set -euo pipefail

# Configuration
DROPBOX_PATH="${HOME}/Dropbox"
DROPBOX_BACKUP_PATH="${DROPBOX_PATH}/My Backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
📦 Dropbox Backup - Move directory to Dropbox with symlink

USAGE:
    dropbox-backup [DIRECTORY] [OPTIONS]

ARGUMENTS:
    DIRECTORY    Directory to move (defaults to current directory)

OPTIONS:
    --help       Show this help message
    --dry-run    Show what would be done without making changes

EXAMPLES:
    dropbox-backup                    # Backup current directory
    dropbox-backup ~/projects/myapp   # Backup specific directory
    dropbox-backup --dry-run          # Preview changes

DESCRIPTION:
    This script moves a directory to your Dropbox backup folder and creates
    a symlink in the original location, allowing seamless access while
    ensuring cloud backup.
EOF
}

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
    echo -e "${RED}❌ $1${NC}" >&2
}

validate_dropbox() {
    if [[ ! -d "$DROPBOX_PATH" ]]; then
        log_error "Dropbox directory not found at: $DROPBOX_PATH"
        log_info "Please ensure Dropbox is installed and synchronized"
        exit 1
    fi
}

validate_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        exit 1
    fi
    
    if [[ ! -r "$dir" ]]; then
        log_error "Cannot read directory: $dir"
        exit 1
    fi
}

get_real_path() {
    local path="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$path"
    else
        # Fallback for systems without realpath
        cd "$path" && pwd -P
    fi
}

main() {
    local dry_run=false
    local target_dir=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                log_info "Use --help for usage information"
                exit 1
                ;;
            *)
                if [[ -z "$target_dir" ]]; then
                    target_dir="$1"
                else
                    log_error "Too many arguments"
                    log_info "Use --help for usage information"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to current directory if none specified
    if [[ -z "$target_dir" ]]; then
        target_dir="$(pwd)"
    fi
    
    # Validate inputs
    validate_dropbox
    validate_directory "$target_dir"
    
    # Get absolute path and basename
    local real_path
    real_path=$(get_real_path "$target_dir")
    local base_name
    base_name=$(basename "$real_path")
    local dropbox_dest_path="${DROPBOX_BACKUP_PATH}/${base_name}"
    
    log_info "Source directory: $real_path"
    log_info "Destination: $dropbox_dest_path"
    
    # Check if destination already exists
    if [[ -e "$dropbox_dest_path" ]]; then
        log_error "Destination already exists: $dropbox_dest_path"
        log_info "Please remove or rename the existing backup first"
        exit 1
    fi
    
    # Check if source is already a symlink
    if [[ -L "$real_path" ]]; then
        log_warning "Source is already a symlink: $real_path"
        local link_target
        link_target=$(readlink "$real_path")
        log_info "Currently links to: $link_target"
        
        if [[ "$link_target" == "$dropbox_dest_path" ]]; then
            log_success "Directory is already backed up to Dropbox"
            exit 0
        fi
    fi
    
    if $dry_run; then
        log_info "DRY RUN - No changes will be made:"
        echo " 1. Create directory: $(dirname "$dropbox_dest_path")"
        echo " 2. Move: $real_path → $dropbox_dest_path"
        echo " 3. Create symlink: $real_path → $dropbox_dest_path"
        exit 0
    fi
    
    # Execute the backup
    log_info "Creating backup directory structure..."
    mkdir -p "$(dirname "$dropbox_dest_path")"
    
    log_info "Moving directory to Dropbox..."
    mv "$real_path" "$dropbox_dest_path"
    
    log_info "Creating symlink..."
    ln -sfn "$dropbox_dest_path" "$real_path"
    
    log_success "Backup completed successfully!"
    log_info "Your files are now backed up to Dropbox and accessible via the original path"
}

# Run main function with all arguments
main "$@"