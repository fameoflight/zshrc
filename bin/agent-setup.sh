#!/bin/bash
# Agent Documentation Setup Script
# Converts existing CLAUDE.md to AGENTS.md and creates symlinks for unified AI agent documentation

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
  echo " • Converts CLAUDE.md to AGENTS.md (unified AI documentation)"
  echo " • Creates CLAUDE.md → AGENTS.md symlink"
  echo " • Creates GEMINI.md → AGENTS.md symlink"
  echo " • Creates .github/copilot-instructions.md → AGENTS.md symlink"
  echo " • Also creates an additional .github/copilot-instructions-agents.md → AGENTS.md symlink"
  echo " • Works in current git repository root"
  echo ""
  echo "Benefits:"
  echo " • Single source of truth for all AI agents"
  echo " • Automatic compatibility with Claude Code and Gemini CLI"
  echo " • GitHub Copilot integration with unified instructions"
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
  local has_agents=false
  local has_gemini=false
  local has_copilot=false

  [ -f CLAUDE.md ] && has_claude=true
  [ -f AGENTS.md ] && has_agents=true
  [ -f GEMINI.md ] && has_gemini=true
  [ -f .github/copilot-instructions.md ] && has_copilot=true

  # Handle CLAUDE.md → AGENTS.md conversion
  if [ "$has_claude" = true ] && [ "$has_agents" = false ]; then
    if confirm_action "Convert CLAUDE.md to AGENTS.md?"; then
      log_info "Converting CLAUDE.md to AGENTS.md..."
      if [ "$DRY_RUN" = false ]; then
        mv CLAUDE.md AGENTS.md
      fi
      log_success "CLAUDE.md converted to AGENTS.md"
      has_agents=true
      has_claude=false
    else
      log_info "Skipping CLAUDE.md conversion"
    fi
  elif [ "$has_claude" = true ] && [ "$has_agents" = true ]; then
    log_warning "Both CLAUDE.md and AGENTS.md exist"
    log_info "You may want to manually merge them and remove CLAUDE.md"
  fi

  # Create CLAUDE.md symlink if we have AGENTS.md
  if [ "$has_agents" = true ]; then
    if [ "$has_claude" = false ] || [ -L CLAUDE.md ]; then
      log_info "Creating CLAUDE.md → AGENTS.md symlink..."
      if [ "$DRY_RUN" = false ]; then
        [ -L CLAUDE.md ] && rm CLAUDE.md  # Remove existing symlink
        ln -sf AGENTS.md CLAUDE.md
      fi
      log_success "CLAUDE.md symlink created"
    else
      log_warning "CLAUDE.md exists as regular file (not symlink)"
    fi

    # Create GEMINI.md symlink
    if [ "$has_gemini" = false ] || [ -L GEMINI.md ]; then
      log_info "Creating GEMINI.md → AGENTS.md symlink..."
      if [ "$DRY_RUN" = false ]; then
        [ -L GEMINI.md ] && rm GEMINI.md  # Remove existing symlink
        ln -sf AGENTS.md GEMINI.md
      fi
      log_success "GEMINI.md symlink created"
    else
      log_warning "GEMINI.md exists as regular file (not symlink)"
    fi

    # Create .github/copilot-instructions.md symlink(s)
    if [ "$has_copilot" = false ] || [ -L .github/copilot-instructions.md ]; then
      log_info "Creating .github/copilot-instructions.md → AGENTS.md symlink..."
      if [ "$DRY_RUN" = false ]; then
        # Ensure .github directory exists
        mkdir -p .github
        [ -L .github/copilot-instructions.md ] && rm .github/copilot-instructions.md  # Remove existing symlink
        ln -sf ../AGENTS.md .github/copilot-instructions.md
      fi
      log_success ".github/copilot-instructions.md symlink created"
    else
      log_warning ".github/copilot-instructions.md exists as regular file (not symlink)"
    fi

    # Create an additional link .github/copilot-instructions-agents.md → AGENTS.md
    log_info "Creating additional .github/copilot-instructions-agents.md → AGENTS.md symlink..."
    if [ "$DRY_RUN" = false ]; then
      mkdir -p .github
      [ -L .github/copilot-instructions-agents.md ] && rm .github/copilot-instructions-agents.md
      ln -sf ../AGENTS.md .github/copilot-instructions-agents.md
    fi
    log_success ".github/copilot-instructions-agents.md symlink created"

  else
    log_error "No AGENTS.md file found or created"
    log_info "Please create an AGENTS.md file with your AI agent instructions"
    exit 1
  fi

  # Show final state
  if [ "$DRY_RUN" = false ]; then
    log_section "Final Documentation Structure"
    echo ""
    echo "📁 Agent documentation files:"
    if [ -f AGENTS.md ]; then
      echo " AGENTS.md     (main documentation file)"
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
    if [ -L .github/copilot-instructions.md ]; then
      echo " .github/copilot-instructions.md → $(readlink .github/copilot-instructions.md)"
    elif [ -f .github/copilot-instructions.md ]; then
      echo " .github/copilot-instructions.md (regular file)"
    fi
    if [ -L .github/copilot-instructions-agents.md ]; then
      echo " .github/copilot-instructions-agents.md → $(readlink .github/copilot-instructions-agents.md)"
    fi
    echo ""
    log_success "Agent documentation setup completed!"
    log_info "When Claude edits CLAUDE.md, it will update AGENTS.md automatically"
    log_info "When Gemini edits GEMINI.md, it will update AGENTS.md automatically"
    log_info "GitHub Copilot will use the unified instructions from AGENTS.md"
  fi
}

# Run the setup
setup_agent_docs