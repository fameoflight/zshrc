# Function to load Claude API key on demand
_load_claude_env() {
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    # Try to load from various common locations
    local env_files=(
      "$HOME/.claude/anthropic_api_key"
      "$HOME/.config/claude/api_key"
      "$HOME/.anthropic_api_key"
      "$ZSH_CONFIG/private.env"
    )
    
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]]; then
        export ANTHROPIC_API_KEY="$(cat "$env_file" | tr -d '\n\r')"
        log_debug "Loaded ANTHROPIC_API_KEY from $env_file"
        break
      fi
    done
    
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
      log_warning "ANTHROPIC_API_KEY not found - Claude will use interactive authentication"
      log_debug "Checked locations: ${env_files[*]}"
      return 0
    fi
  fi
  return 0
}

function claude() {
  # Load Claude API key on demand (optional)
  _load_claude_env

  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local NC='\033[0m'

  # Check for claude in both /usr/local/bin and /opt/homebrew/bin
  local claude_path=""
  if [[ -f /usr/local/bin/claude ]]; then
    claude_path="/usr/local/bin/claude"
  elif [[ -f /opt/homebrew/bin/claude ]]; then
    claude_path="/opt/homebrew/bin/claude"
  fi

  if [[ -n "$claude_path" ]]; then
    # Make sure this is a git repository
    if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
      echo -e "${RED}❌ Error: claude can only be executed in a git repository.${NC}"
      return 1
    fi

    # Go to the root of the git repository
    cd `git rev-parse --show-toplevel` || return 1

    # Ensure CLAUDE.md exists (create symlink to AGENT.md if needed)
    if [[ -f AGENT.md ]] && [[ ! -f CLAUDE.md ]]; then
      ln -sf AGENT.md CLAUDE.md
      echo -e "${BLUE}🔗 Created CLAUDE.md → AGENT.md symlink${NC}"
    elif [[ ! -f CLAUDE.md ]] && [[ ! -f AGENT.md ]]; then
      echo -e "${YELLOW}⚠️  Warning: Neither CLAUDE.md nor AGENT.md exists in the root of the git repository.${NC}"
      echo -e "${BLUE}ℹ️  Run 'agent-setup' to set up unified agent documentation${NC}"
    fi

    echo -e "${BLUE}🚀 Running claude in: ${GREEN}`pwd`${NC}"
    "$claude_path" "$@"
  else
    echo -e "${RED}❌ Error: claude not found in /usr/local/bin or /opt/homebrew/bin${NC}"
    echo -e "${BLUE}ℹ️  Please install claude from https://claude.ai/code${NC}"
    return 1
  fi
}