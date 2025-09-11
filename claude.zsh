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

# Function to load Z.AI API key on demand
_load_zai_env() {
  if [[ -z "${ZAI_API_KEY:-}" ]]; then
    # Try to load from various common locations
    local env_files=(
      "$HOME/.zai/api_key"
      "$HOME/.config/zai/api_key"
      "$HOME/.zai_api_key"
      "$ZSH_CONFIG/private.env"
    )
    
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]]; then
        export ZAI_API_KEY="$(cat "$env_file" | tr -d '\n\r')"
        log_debug "Loaded ZAI_API_KEY from $env_file"
        break
      fi
    done
    
    if [[ -z "${ZAI_API_KEY:-}" ]]; then
      log_error "ZAI_API_KEY not found - please set up your Z.AI API key"
      log_info "Run 'setup-zai-key \"your-api-key-here\"' to configure"
      log_info "You can get your API Key from https://z.ai/manage-apikey/apikey-list"
      return 1
    fi
  fi
  return 0
}

function claude-zai() {
  # Load Z.AI API key on demand
  if ! _load_zai_env; then
    return 1
  fi

  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local MAGENTA='\033[0;35m'
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

    # Set Z.AI environment variables
    export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
    export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"

    echo -e "${MAGENTA}🤖 Running Claude Code with Z.AI GLM-4.5 in: ${GREEN}`pwd`${NC}"
    echo -e "${BLUE}ℹ️  Using Z.AI endpoint: ${ANTHROPIC_BASE_URL}${NC}"
    "$claude_path" "$@"
  else
    echo -e "${RED}❌ Error: claude not found in /usr/local/bin or /opt/homebrew/bin${NC}"
    echo -e "${BLUE}ℹ️  Please install claude from https://claude.ai/code${NC}"
    return 1
  fi
}

# Legacy helper functions (kept for backward compatibility)
_check_local_endpoint() {
  curl -s --max-time 5 "http://localhost:1234/v1/models" >/dev/null 2>&1
}

_get_loaded_model() {
  local models_response=$(curl -s --max-time 5 "http://localhost:1234/v1/models" 2>/dev/null)
  echo "$models_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'data' in data and len(data['data']) > 0:
        print(data['data'][0]['id'])
except:
    pass
" 2>/dev/null
}

_check_local_model() {
  _check_local_endpoint
}

# Function to setup claude-code-proxy for local LLM
function setup-claude-proxy() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  echo -e "${BLUE}⚙️  Setting up Claude Code Proxy for local LLM...${NC}"

  local proxy_dir="$ZSH_CONFIG/claude-code-proxy"
  local env_file="$proxy_dir/.env"

  # Check if proxy exists
  if [[ ! -d "$proxy_dir" ]]; then
    echo -e "${RED}❌ claude-code-proxy directory not found${NC}"
    echo -e "${BLUE}ℹ️  Please run: git submodule update --init --recursive${NC}"
    return 1
  fi

  # Install Python dependencies in virtual environment
  echo -e "${CYAN}📦 Setting up Python virtual environment...${NC}"
  cd "$proxy_dir"
  
  # Check if Python is available
  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}❌ Python3 not found${NC}"
    echo -e "${BLUE}ℹ️  Please install Python3 first${NC}"
    return 1
  fi

  # Create virtual environment if it doesn't exist
  if [[ ! -d "venv" ]]; then
    echo -e "${BLUE}🔄 Creating virtual environment...${NC}"
    python3 -m venv venv
  fi

  # Activate virtual environment
  source venv/bin/activate

  # Upgrade pip in venv
  echo -e "${BLUE}🔄 Upgrading pip...${NC}"
  python -m pip install --upgrade pip

  # Install dependencies
  if [[ -f requirements.txt ]]; then
    echo -e "${BLUE}🔄 Installing requirements in virtual environment...${NC}"
    if ! pip install -r requirements.txt; then
      echo -e "${RED}❌ Failed to install Python dependencies${NC}"
      deactivate
      return 1
    fi
    echo -e "${GREEN}✅ Dependencies installed in virtual environment${NC}"
  else
    echo -e "${YELLOW}⚠️  requirements.txt not found, installing common dependencies...${NC}"
    pip install fastapi uvicorn httpx python-dotenv
  fi

  # Deactivate virtual environment
  deactivate

  # Return to original directory
  cd - >/dev/null

  # Check if LM Studio is running and get model
  echo -e "${CYAN}🔍 Checking LM Studio setup...${NC}"
  if ! _check_local_endpoint "http://localhost:1234"; then
    echo -e "${YELLOW}⚠️  LM Studio not running - proxy will be configured but won't work until you start LM Studio${NC}"
  else
    echo -e "${GREEN}✅ LM Studio is running${NC}"
  fi

  # Get loaded model, preferring Qwen3 Coder for coding tasks
  local loaded_model=$(_get_loaded_model "http://localhost:1234" 2>/dev/null)
  
  # If no model loaded, suggest the best coding model
  if [[ -z "$loaded_model" ]]; then
    loaded_model="qwen/qwen3-coder-30b"  # Default to best coding model
    echo -e "${YELLOW}⚠️  No model currently loaded in LM Studio${NC}"
    echo -e "${BLUE}ℹ️  Configuring for recommended model: ${loaded_model}${NC}"
    echo -e "${BLUE}ℹ️  Load this model in LM Studio for best coding performance${NC}"
  else
    echo -e "${BLUE}ℹ️  Using currently loaded model: ${loaded_model}${NC}"
    
    # Suggest Qwen3 Coder if using a different model
    if [[ "$loaded_model" != "qwen/qwen3-coder-30b" ]]; then
      echo -e "${CYAN}💡 Tip: 'qwen/qwen3-coder-30b' is optimized for coding tasks${NC}"
    fi
  fi

  # Create .env file for LM Studio configuration
  cat > "$env_file" << EOF
# Claude Code Proxy Configuration for LM Studio
# Optimized for Qwen3 Coder model

# Required: Dummy API key for LM Studio (any value works)
OPENAI_API_KEY="dummy-key-for-lmstudio"

# LM Studio endpoint
OPENAI_BASE_URL="http://localhost:1234/v1"

# Model mappings - all use the same local model
BIG_MODEL="$loaded_model"
MIDDLE_MODEL="$loaded_model"
SMALL_MODEL="$loaded_model"

# Server settings
HOST="0.0.0.0"
PORT="8082"
LOG_LEVEL="INFO"

# Performance settings
MAX_TOKENS_LIMIT="8192"
MIN_TOKENS_LIMIT="1024"
REQUEST_TIMEOUT="90"
MAX_RETRIES="2"

# Optional: Security - leave empty to accept any client API key
# ANTHROPIC_API_KEY=""
EOF

  echo -e "${GREEN}✅ Configuration created at: ${env_file}${NC}"
  echo -e "${BLUE}ℹ️  Configuration details:${NC}"
  echo -e "   ${CYAN}• Proxy server: http://localhost:8082${NC}"
  echo -e "   ${CYAN}• Target: LM Studio (localhost:1234)${NC}"
  echo -e "   ${CYAN}• Model: $loaded_model${NC}"
  
  echo -e "${YELLOW}📖 Next steps:${NC}"
  echo -e "   ${BLUE}1. Make sure LM Studio is running with a model loaded${NC}"
  echo -e "   ${BLUE}2. Start proxy: start-claude-proxy${NC}"
  echo -e "   ${BLUE}3. Use: claude-local (in another terminal)${NC}"
}

# Function to start claude-code-proxy
function start-claude-proxy() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  local proxy_dir="$ZSH_CONFIG/claude-code-proxy"
  
  if [[ ! -d "$proxy_dir" ]]; then
    echo -e "${RED}❌ claude-code-proxy not found${NC}"
    echo -e "${BLUE}ℹ️  Run: setup-claude-proxy first${NC}"
    return 1
  fi

  # Check if .env exists
  if [[ ! -f "$proxy_dir/.env" ]]; then
    echo -e "${RED}❌ Proxy not configured${NC}"
    echo -e "${BLUE}ℹ️  Run: setup-claude-proxy first${NC}"
    return 1
  fi

  echo -e "${BLUE}🚀 Starting Claude Code Proxy...${NC}"
  echo -e "${CYAN}ℹ️  Proxy will run at http://localhost:8082${NC}"
  echo -e "${CYAN}ℹ️  Press Ctrl+C to stop${NC}"
  
  # Change to proxy directory and start with virtual environment
  cd "$proxy_dir"
  
  # Check if virtual environment exists
  if [[ ! -d "venv" ]]; then
    echo -e "${RED}❌ Virtual environment not found${NC}"
    echo -e "${BLUE}ℹ️  Run: setup-claude-proxy first${NC}"
    return 1
  fi
  
  # Activate virtual environment and start proxy
  source venv/bin/activate
  python start_proxy.py
}

# Function to use Claude Code with local LLM via proxy (New clean implementation)
function claude-local() {
  local script_path="$ZSH_CONFIG/bin/claude-local.sh"

  if [[ ! -f "$script_path" ]]; then
    log_error "Script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making script executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Function to setup Z.AI API key
function setup-zai-key() {
  if [[ -z "$1" ]]; then
    log_error "Usage: setup-zai-key \"your-api-key-here\""
    return 1
  fi

  local api_key="$1"
  local zai_dir="$HOME/.zai"
  local key_file="$zai_dir/api_key"

  # Create directory
  mkdir -p "$zai_dir"
  chmod 700 "$zai_dir"

  # Write API key
  echo -n "$api_key" > "$key_file"
  chmod 600 "$key_file"

  log_success "Z.AI API key saved to $key_file"
  log_info "You can now use 'claude-zai' to run Claude Code with Z.AI GLM-4.5"
}