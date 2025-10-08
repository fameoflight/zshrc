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