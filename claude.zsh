function claude() {
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

    # Check for CLAUDE.md
    if [[ ! -f CLAUDE.md ]]; then
      echo -e "${YELLOW}⚠️  Warning: CLAUDE.md does not exist in the root of the git repository.${NC}"
    fi

    echo -e "${BLUE}🚀 Running claude in: ${GREEN}`pwd`${NC}"
    "$claude_path" "$@"
  else
    echo -e "${RED}❌ Error: claude not found in /usr/local/bin or /opt/homebrew/bin${NC}"
    echo -e "${BLUE}ℹ️  Please install claude from https://claude.ai/code${NC}"
    return 1
  fi
}