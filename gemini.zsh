
# Function to load Gemini API key on demand
_load_gemini_env() {
  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    # Try to load from various common locations
    local env_files=(
      "$HOME/.gemini/api_key"
      "$HOME/.config/gemini/api_key"
      "$HOME/.google_ai_api_key"
      "$HOME/.gemini_api_key"
      "$ZSH_CONFIG/private.env"
    )
    
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]]; then
        # Check if it's a multi-line env file or single key
        if grep -q "GEMINI_API_KEY=" "$env_file" 2>/dev/null; then
          source "$env_file"
          log_debug "Loaded GEMINI_API_KEY from $env_file (env format)"
        else
          export GEMINI_API_KEY="$(cat "$env_file" | tr -d '\n\r')"
          log_debug "Loaded GEMINI_API_KEY from $env_file (plain text)"
        fi
        break
      fi
    done
    
    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
      log_warning "GEMINI_API_KEY not found - Gemini CLI may require manual authentication"
      log_debug "Checked locations: ${env_files[*]}"
      return 0
    fi
  fi
  return 0
}

function gemini-cli() {
  # Load Gemini API key on demand (optional)
  _load_gemini_env

  # Check for gemini in both /usr/local/bin and /opt/homebrew/bin
  local gemini_path=""
  if [[ -f /usr/local/bin/gemini ]]; then
    gemini_path="/usr/local/bin/gemini"
  elif [[ -f /opt/homebrew/bin/gemini ]]; then
    gemini_path="/opt/homebrew/bin/gemini"
  fi

  if [[ -n "$gemini_path" ]]; then
    # Make sure this is a git repository
    if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
      log_error "gemini can only be executed in a git repository"
      return 1
    fi

    # Go to the root of the git repository
    cd "$(git rev-parse --show-toplevel)" || return 1

    # Ensure GEMINI.md exists (create symlink to AGENT.md if needed)
    if [[ -f AGENT.md ]] && [[ ! -f GEMINI.md ]]; then
      ln -sf AGENT.md GEMINI.md
      log_info "Created GEMINI.md → AGENT.md symlink"
    elif [[ ! -f GEMINI.md ]] && [[ ! -f AGENT.md ]]; then
      log_warning "Neither GEMINI.md nor AGENT.md exists in the root of the git repository"
      log_info "Run 'agent-setup' to set up unified agent documentation"
    fi

    log_process_start "gemini in $(pwd)"
    "$gemini_path" "$@"
  else
    log_error "gemini not found in /usr/local/bin or /opt/homebrew/bin"
    log_info "Please install gemini CLI tool"
    return 1
  fi
}