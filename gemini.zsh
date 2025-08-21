function gemini-cli() {
  # Source ai-env.zsh if _load_gemini_env is not available
  if ! typeset -f _load_gemini_env >/dev/null; then
    source "$ZSH_CONFIG/ai-env.zsh"
  fi
  
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
    cd `git rev-parse --show-toplevel` || return 1

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