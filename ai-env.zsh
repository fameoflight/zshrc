# AI Environment Configuration
# Author: Hemant Verma <fameoflight@gmail.com>
# 
# On-demand API key loading for AI tools
# This file provides functions to load API keys only when needed
#
# =============================================================================
# API KEY STORAGE LOCATIONS
# =============================================================================
#
# Claude (ANTHROPIC_API_KEY):
#   • ~/.claude/anthropic_api_key           (recommended)
#   • ~/.config/claude/api_key
#   • ~/.anthropic_api_key
#   • $ZSH_CONFIG/private.env               (for multiple keys)
#
# Gemini (GEMINI_API_KEY):
#   • ~/.gemini/api_key                     (recommended)
#   • ~/.config/gemini/api_key
#   • ~/.google_ai_api_key
#   • ~/.gemini_api_key
#   • $ZSH_CONFIG/private.env               (for multiple keys)
#
# Setup Commands:
#   setup-claude-key "sk-ant-api03-your-key-here"
#   setup-gemini-key "AIzaSyYour-gemini-key-here"
#
# Note: API keys are OPTIONAL - the tools will work without them but may
#       have limited functionality or require manual authentication.

# =============================================================================
# AI API KEY MANAGEMENT
# =============================================================================

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

# Function to load all AI environment variables if needed
_load_ai_env() {
  local service="${1:-all}"
  
  case "$service" in
    claude)
      _load_claude_env
      ;;
    gemini)
      _load_gemini_env
      ;;
    all|*)
      _load_claude_env
      _load_gemini_env
      ;;
  esac
}

# =============================================================================
# API KEY UTILITIES
# =============================================================================

# Check if Claude API key is available
check-claude-key() {
  if _load_claude_env; then
    log_success "Claude API key is configured"
    log_info "Key: ${ANTHROPIC_API_KEY:0:8}..."
  else
    log_error "Claude API key not configured"
    return 1
  fi
}

# Check if Gemini API key is available
check-gemini-key() {
  if _load_gemini_env; then
    log_success "Gemini API key is configured"
    log_info "Key: ${GEMINI_API_KEY:0:8}..."
  else
    log_error "Gemini API key not configured"
    return 1
  fi
}

# Check all AI API keys
check-ai-keys() {
  log_section "AI API Keys Status"
  
  echo -n "🤖 Claude (Anthropic): "
  if _load_claude_env >/dev/null 2>&1; then
    log_success "✓ Configured"
  else
    log_error "✗ Missing"
  fi
  
  echo -n "🤖 Gemini (Google): "
  if _load_gemini_env >/dev/null 2>&1; then
    log_success "✓ Configured"  
  else
    log_error "✗ Missing"
  fi
}

# =============================================================================
# SETUP HELPERS
# =============================================================================

# Setup Claude API key
setup-claude-key() {
  local key_file="$HOME/.claude/anthropic_api_key"
  
  if [[ $# -eq 0 ]]; then
    log_info "Usage: setup-claude-key <your-api-key>"
    log_info "This will save the key to: $key_file"
    return 1
  fi
  
  local api_key="$1"
  
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$key_file")"
  
  # Save the key
  echo -n "$api_key" > "$key_file"
  chmod 600 "$key_file"
  
  log_success "Claude API key saved to $key_file"
  log_info "Key: ${api_key:0:8}..."
}

# Setup Gemini API key
setup-gemini-key() {
  local key_file="$HOME/.gemini/api_key"
  
  if [[ $# -eq 0 ]]; then
    log_info "Usage: setup-gemini-key <your-api-key>"
    log_info "This will save the key to: $key_file"
    return 1
  fi
  
  local api_key="$1"
  
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$key_file")"
  
  # Save the key
  echo -n "$api_key" > "$key_file"
  chmod 600 "$key_file"
  
  log_success "Gemini API key saved to $key_file"
  log_info "Key: ${api_key:0:8}..."
}