#!/bin/bash
# Agent Documentation Setup Script
# Converts existing CLAUDE.md to AGENT.md and creates symlinks for unified AI agent documentation

set -euo pipefail

# Source logging functions
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
    log_section() { echo -e "\033[1;35m🔧 $1\033[0m"; }
fi

# Show help
show_help() {
    log_section "Agent Documentation Setup Script"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo " --help, -h     Show this help message"
    echo " --dry-run      Show what would be done without doing it"
    echo " --force        Overwrite existing files without prompting"
    echo ""
    echo "What this script does:"
    echo " • Converts CLAUDE.md to AGENT.md (unified AI documentation)"
    echo " • Creates CLAUDE.md → AGENT.md symlink"
    echo " • Creates GEMINI.md → AGENT.md symlink"
    echo " • Works in current git repository root"
    echo ""
    echo "Benefits:"
    echo " • Single source of truth for all AI agents"
    echo " • Automatic compatibility with Claude Code and Gemini CLI"
    echo " • Future-proof for other AI tools"
    echo ""
}

# Configuration
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
confirm_action() {
    local message="$1"
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo -n "$message [y/N]: "
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
setup_agent_docs() {
    log_section "Setting up unified agent documentation"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Make sure we're in a git repository
    if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
        log_error "Must be run from within a git repository"
        exit 1
    fi
    
    # Go to the root of the git repository
    local git_root
    git_root=$(git rev-parse --show-toplevel)
    cd "$git_root" || exit 1
    
    log_info "Working in git repository: $git_root"
    
    # Check current state and plan actions
    local has_claude=false
    local has_agent=false
    local has_gemini=false
    
    [ -f CLAUDE.md ] && has_claude=true
    [ -f AGENT.md ] && has_agent=true
    [ -f GEMINI.md ] && has_gemini=true
    
    # Handle CLAUDE.md → AGENT.md conversion
    if [ "$has_claude" = true ] && [ "$has_agent" = false ]; then
        if confirm_action "Convert CLAUDE.md to AGENT.md?"; then
            log_info "Converting CLAUDE.md to AGENT.md..."
            if [ "$DRY_RUN" = false ]; then
                mv CLAUDE.md AGENT.md
            fi
            log_success "CLAUDE.md converted to AGENT.md"
            has_agent=true
            has_claude=false
        else
            log_info "Skipping CLAUDE.md conversion"
        fi
    elif [ "$has_claude" = true ] && [ "$has_agent" = true ]; then
        log_warning "Both CLAUDE.md and AGENT.md exist"
        log_info "You may want to manually merge them and remove CLAUDE.md"
    fi
    
    # Create CLAUDE.md symlink if we have AGENT.md
    if [ "$has_agent" = true ]; then
        if [ "$has_claude" = false ] || [ -L CLAUDE.md ]; then
            log_info "Creating CLAUDE.md → AGENT.md symlink..."
            if [ "$DRY_RUN" = false ]; then
                [ -L CLAUDE.md ] && rm CLAUDE.md  # Remove existing symlink
                ln -sf AGENT.md CLAUDE.md
            fi
            log_success "CLAUDE.md symlink created"
        else
            log_warning "CLAUDE.md exists as regular file (not symlink)"
        fi
        
        # Create GEMINI.md symlink
        if [ "$has_gemini" = false ] || [ -L GEMINI.md ]; then
            log_info "Creating GEMINI.md → AGENT.md symlink..."
            if [ "$DRY_RUN" = false ]; then
                [ -L GEMINI.md ] && rm GEMINI.md  # Remove existing symlink
                ln -sf AGENT.md GEMINI.md
            fi
            log_success "GEMINI.md symlink created"
        else
            log_warning "GEMINI.md exists as regular file (not symlink)"
        fi
    else
        log_error "No AGENT.md file found or created"
        log_info "Please create an AGENT.md file with your AI agent instructions"
        exit 1
    fi
    
    # Show final state
    if [ "$DRY_RUN" = false ]; then
        log_section "Final Documentation Structure"
        echo ""
        echo "📁 Agent documentation files:"
        if [ -f AGENT.md ]; then
            echo " AGENT.md     (main documentation file)"
        fi
        if [ -L CLAUDE.md ]; then
            echo " CLAUDE.md    → $(readlink CLAUDE.md)"
        elif [ -f CLAUDE.md ]; then
            echo " CLAUDE.md    (regular file)"
        fi
        if [ -L GEMINI.md ]; then
            echo " GEMINI.md    → $(readlink GEMINI.md)"
        elif [ -f GEMINI.md ]; then
            echo " GEMINI.md    (regular file)"
        fi
        echo ""
        log_success "Agent documentation setup completed!"
        log_info "When Claude edits CLAUDE.md, it will update AGENT.md automatically"
        log_info "When Gemini edits GEMINI.md, it will update AGENT.md automatically"
    fi
}

# Run the setup
setup_agent_docs