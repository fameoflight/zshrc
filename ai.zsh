# AI Development Tools Configuration
# Author: Hemant Verma <fameoflight@gmail.com>
# 
# Configuration for AI development tools including LM Studio, Claude Code, and other AI utilities

# =============================================================================
# LM STUDIO CONFIGURATION
# =============================================================================

# Bootstrap LM Studio CLI if not already done
_lms_bootstrap() {
  local lms_path="$HOME/.lmstudio/bin/lms"
  
  if [[ ! -f "$lms_path" ]]; then
    log_info "LM Studio CLI not found"
    return 1
  fi
  
  if ! command -v lms >/dev/null 2>&1; then
    log_info "Bootstrapping LM Studio CLI"
    "$lms_path" bootstrap >/dev/null 2>&1
  fi
}

# Check if LM Studio is available
_lms_check() {
  if ! command -v lms >/dev/null 2>&1; then
    _lms_bootstrap
    if ! command -v lms >/dev/null 2>&1; then
      log_error "LM Studio CLI not available. Install LM Studio and run it once."
      return 1
    fi
  fi
  return 0
}

# =============================================================================
# LM STUDIO HELPER FUNCTIONS
# =============================================================================

# List downloaded models
lms-models() {
  _lms_check || return 1
  log_info "📋 Downloaded models:"
  lms ls
}

# List loaded models
lms-loaded() {
  _lms_check || return 1
  log_info "💾 Currently loaded models:"
  lms ps
}

# Quick load model with fuzzy search
lms-load() {
  _lms_check || return 1
  
  if [[ $# -eq 0 ]]; then
    log_info "Available models:"
    lms ls
    echo ""
    log_info "Usage: lms-load <model-name> [identifier]"
    return 1
  fi
  
  local model="$1"
  local identifier="$2"
  
  if [[ -n "$identifier" ]]; then
    log_progress "Loading model: $model with identifier: $identifier"
    lms load "$model" --identifier="$identifier"
  else
    log_progress "Loading model: $model"
    lms load "$model"
  fi
  
  if [[ $? -eq 0 ]]; then
    log_success "Model loaded successfully"
  else
    log_error "Failed to load model"
  fi
}

# Unload models
lms-unload() {
  _lms_check || return 1
  
  if [[ "$1" == "--all" ]]; then
    log_warning "Unloading all models"
    lms unload --all
  else
    log_info "Unloading current model"
    lms unload
  fi
  
  if [[ $? -eq 0 ]]; then
    log_success "Model(s) unloaded successfully"
  else
    log_error "Failed to unload model(s)"
  fi
}

# Start LM Studio server
lms-start() {
  _lms_check || return 1
  
  local port="${1:-1234}"
  log_progress "Starting LM Studio server on port $port"
  lms server start --port "$port"
  
  if [[ $? -eq 0 ]]; then
    log_success "LM Studio server started on http://localhost:$port"
  else
    log_error "Failed to start LM Studio server"
  fi
}

# Stop LM Studio server
lms-stop() {
  _lms_check || return 1
  
  log_progress "Stopping LM Studio server"
  lms server stop
  
  if [[ $? -eq 0 ]]; then
    log_success "LM Studio server stopped"
  else
    log_error "Failed to stop LM Studio server"
  fi
}

# Check LM Studio server status
lms-status() {
  _lms_check || return 1
  
  log_info "🔍 LM Studio status:"
  lms status
  echo ""
  log_info "🌐 Server status:"
  lms server status
}

# Quick query function for loaded model
lms-query() {
  _lms_check || return 1
  
  if [[ $# -eq 0 ]]; then
    log_error "Usage: lms-query <prompt>"
    return 1
  fi
  
  local prompt="$*"
  log_info "🤖 Querying model with: $prompt"
  
  # Use curl to query the local API endpoint
  local response=$(curl -s -X POST http://localhost:1234/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
      \"messages\": [
        {\"role\": \"user\", \"content\": \"$prompt\"}
      ],
      \"temperature\": 0.7,
      \"max_tokens\": 1000
    }" 2>/dev/null)
  
  if [[ $? -eq 0 ]] && [[ -n "$response" ]]; then
    # Extract content from JSON response using jq if available
    if command -v jq >/dev/null 2>&1; then
      echo "$response" | jq -r '.choices[0].message.content // "No response"'
    else
      echo "$response"
    fi
  else
    log_error "Failed to query model. Make sure server is running with 'lms-start'"
  fi
}

# Stream logs from LM Studio
lms-logs() {
  _lms_check || return 1
  
  log_info "📄 Streaming LM Studio logs (Ctrl+C to stop):"
  lms log stream
}

# Download a model
lms-get() {
  _lms_check || return 1
  
  if [[ $# -eq 0 ]]; then
    log_error "Usage: lms-get <model-identifier>"
    return 1
  fi
  
  local model="$1"
  log_progress "Downloading model: $model"
  lms get "$model"
  
  if [[ $? -eq 0 ]]; then
    log_success "Model downloaded successfully"
  else
    log_error "Failed to download model"
  fi
}

# =============================================================================
# CLAUDE CODE INTEGRATION
# =============================================================================

# Quick Claude Code alias
alias cc='claude-code'

# =============================================================================
# GEMINI INTEGRATION
# =============================================================================

# Quick Gemini alias
alias gg='gemini-cli'

# =============================================================================
# AI DEVELOPMENT ALIASES
# =============================================================================

# LM Studio aliases
alias lm='lms'
alias llm='lms-query'
alias ai-start='lms-start'
alias ai-stop='lms-stop'
alias ai-status='lms-status'
alias ai-models='lms-models'
alias ai-load='lms-load'
alias ai-unload='lms-unload'

# =============================================================================
# INITIALIZATION
# =============================================================================

# Auto-bootstrap LM Studio CLI on shell startup
_lms_bootstrap >/dev/null 2>&1