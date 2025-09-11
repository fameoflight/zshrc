#!/bin/bash
set -euo pipefail

# Claude-Local Integration - Run Claude Code with Local LLM
# Author: Hemant Verma <fameoflight@gmail.com>

# Source logging functions if available
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback logging functions
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
    log_progress() { echo -e "\033[0;36m🔄 $1\033[0m"; }
fi

# Configuration
PYTHON_EXEC=""
PROXY_DIR="${ZSH_CONFIG}/claude-code-proxy"
VENV_DIR="${PROXY_DIR}/venv"
SERVER_PID_FILE="${PROXY_DIR}/server.pid"
DEFAULT_PORT=8082
ORIGINAL_DIR=""
LM_STUDIO_ENDPOINT="http://localhost:1234"

# Help function
show_help() {
    cat << EOF
🤖 Claude-Local Integration - Local LLM with Claude Code

Usage: claude-local [OPTION] [MODEL] [CLAUDE_ARGS...]

Options:
  -h, --help           Show this help message
  --start              Start proxy (restart if already running)
  --stop               Stop the proxy server
  --logs               Show server logs
  --setup              Setup proxy configuration
  --models             List available models

Model Selection:
  MODEL                Specify model to load (supports fuzzy matching)
  
Examples:
  claude-local                              # Use current model
  claude-local qwen-30b "write hello world" # Load Qwen model and run
  claude-local --start                      # Just start the proxy
  claude-local --logs                       # Show server logs
  claude-local --models                     # List available models
  claude-local gemma "explain this code"    # Load Gemma and run

Model Matching:
  - 'qwen-30b' matches 'qwen/qwen3-32b'
  - 'coder' matches 'qwen/qwen3-coder-30b'
  - 'gemma' matches 'google/gemma-3-27b'
  
Prerequisites:
- Run 'setup-claude-proxy' first to configure
- Ensure LM Studio is running with models available
EOF
}

# Parse command line arguments
parse_arguments() {
    START_SERVER=false
    STOP_SERVER=false
    SHOW_LOGS=false
    SHOW_MODELS=false
    SETUP_PROXY=false
    REQUESTED_MODEL=""
    CLAUDE_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --start)
                START_SERVER=true
                shift
                ;;
            --stop)
                STOP_SERVER=true
                shift
                ;;
            --logs)
                SHOW_LOGS=true
                shift
                ;;
            --models)
                SHOW_MODELS=true
                shift
                ;;
            --setup)
                SETUP_PROXY=true
                shift
                ;;
            --*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # First non-option argument could be model name
                if [[ -z "$REQUESTED_MODEL" ]] && [[ "$1" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
                    REQUESTED_MODEL="$1"
                    shift
                else
                    CLAUDE_ARGS+=("$1")
                    shift
                fi
                ;;
        esac
    done
}

# Find a suitable python executable
find_python() {
    local python_execs=("python3.12" "python3.11" "python3")
    for py_cmd in "${python_execs[@]}"; do
        if command -v "$py_cmd" >/dev/null 2>&1; then
            local py_version=$("$py_cmd" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
            if [[ "$(printf '%s\n' "3.8" "$py_version" | sort -V | head -n1)" == "3.8" ]]; then
                PYTHON_EXEC="$py_cmd"
                return 0
            fi
        fi
    done
    return 1
}

# Validation checks
validate_setup() {
    if [[ ! -d "$PROXY_DIR" ]]; then
        log_error "Proxy directory not found at $PROXY_DIR"
        log_info "Run 'setup-claude-proxy' to initialize the setup"
        exit 1
    fi

    if ! find_python; then
        log_error "Python 3.8+ is required but could not be found"
        log_info "Please install a compatible version, e.g., with Homebrew: brew install python@3.12"
        exit 1
    fi
}

# Check if server is running
is_server_running() {
    curl -s --max-time 3 "$LM_STUDIO_ENDPOINT/v1/models" >/dev/null 2>&1
}

# Check if proxy is running
is_proxy_running() {
    curl -s --max-time 3 "http://localhost:$DEFAULT_PORT/health" >/dev/null 2>&1
}

# Get current loaded model from LM Studio
get_loaded_model() {
    local models_response=$(curl -s --max-time 5 "$LM_STUDIO_ENDPOINT/v1/models" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$models_response" ]]; then
        return 1
    fi
    
    # Extract first model ID using Python
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

# Find best matching model
find_best_model_match() {
    local search_term="$1"
    local models_response=$(curl -s --max-time 5 "$LM_STUDIO_ENDPOINT/v1/models" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$models_response" ]]; then
        return 1
    fi
    
    # Use Python for robust model matching
    echo "$models_response" | python3 -c "
import json, sys
search_term = '$search_term'.lower()

try:
    data = json.load(sys.stdin)
    models = [model['id'] for model in data['data']]
    
    # Exact match first
    for model in models:
        if model == '$search_term':
            print(model)
            sys.exit(0)
    
    # Partial matches
    best_match = ''
    best_score = 0
    
    for model in models:
        model_lower = model.lower()
        if search_term in model_lower:
            score = len(search_term)
            if score > best_score:
                best_score = score
                best_match = model
    
    if best_match:
        print(best_match)
    else:
        sys.exit(1)
except:
    sys.exit(1)
"
}

# Load model using LM Studio CLI
load_model() {
    local model_name="$1"
    
    # Check if LM Studio CLI is available
    if ! command -v lms >/dev/null 2>&1; then
        log_warning "LM Studio CLI not available - please load '$model_name' manually"
        return 1
    fi
    
    # Unload current models
    log_progress "Unloading current models"
    lms unload --all >/dev/null 2>&1 || true
    
    # Load the specified model
    log_progress "Loading model: $model_name"
    if lms load "$model_name" 2>&1; then
        log_success "Model loaded: $model_name"
        return 0
    else
        log_error "Failed to load model: $model_name"
        return 1
    fi
}

# Update proxy configuration with new model
update_proxy_config() {
    local model_name="$1"
    local env_file="$PROXY_DIR/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Proxy configuration not found"
        return 1
    fi
    
    log_progress "Updating proxy configuration for: $model_name"
    
    # Update all model mappings
    sed -i.bak "s/^BIG_MODEL=.*/BIG_MODEL=\"$model_name\"/" "$env_file"
    sed -i.bak "s/^MIDDLE_MODEL=.*/MIDDLE_MODEL=\"$model_name\"/" "$env_file"
    sed -i.bak "s/^SMALL_MODEL=.*/SMALL_MODEL=\"$model_name\"/" "$env_file"
    rm -f "$env_file.bak"
}

# Kill existing proxy process
kill_existing_proxy() {
    if [[ -f "$SERVER_PID_FILE" ]]; then
        local pid=$(cat "$SERVER_PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_warning "Stopping existing proxy (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$SERVER_PID_FILE"
    fi
    
    # Kill any process on port
    local existing_pid=$(lsof -ti:$DEFAULT_PORT 2>/dev/null | head -1)
    if [[ -n "$existing_pid" ]]; then
        log_warning "Killing process on port $DEFAULT_PORT (PID: $existing_pid)"
        kill -TERM "$existing_pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$existing_pid" 2>/dev/null || true
    fi
}

# Start the proxy server
start_proxy_server() {
    local current_dir=$(pwd)
    
    # Kill existing proxy
    kill_existing_proxy
    
    # Validate environment
    if [[ ! -d "$VENV_DIR" ]]; then
        log_error "Virtual environment not found at $VENV_DIR"
        log_info "Run 'setup-claude-proxy' to initialize"
        return 1
    fi
    
    log_progress "Starting proxy server on port $DEFAULT_PORT"
    
    cd "$PROXY_DIR"
    
    # Clean up log file
    local log_file="$PROXY_DIR/server.log"
    [[ -f "$log_file" ]] && rm -f "$log_file"
    
    # Start server in background
    source "$VENV_DIR/bin/activate"
    nohup python start_proxy.py > "$log_file" 2>&1 &
    local server_pid=$!
    
    echo $server_pid > "$SERVER_PID_FILE"
    cd "$current_dir"
    
    # Wait for server to start
    local attempts=0
    while [[ $attempts -lt 15 ]]; do
        if is_proxy_running; then
            log_success "Proxy server started (PID: $server_pid)"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log_error "Failed to start proxy server"
    kill_existing_proxy
    return 1
}

# Stop the proxy server
stop_proxy_server() {
    kill_existing_proxy
    log_success "Proxy server stopped"
}

# Show server logs
show_server_logs() {
    local log_file="$PROXY_DIR/server.log"
    
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    else
        log_error "No log file found at $log_file"
        return 1
    fi
}

# List available models
list_models() {
    if ! is_server_running; then
        log_error "LM Studio not running"
        log_info "Please start LM Studio first"
        return 1
    fi
    
    log_info "Available models:"
    curl -s "$LM_STUDIO_ENDPOINT/v1/models" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for model in data['data']:
        model_id = model['id']
        if 'qwen' in model_id.lower() or 'qwq' in model_id.lower():
            print(f'  🤖 {model_id} (Qwen family)')
        elif 'coder' in model_id.lower():
            print(f'  💻 {model_id} (Coding focused)')
        elif 'gemma' in model_id.lower():
            print(f'  🔮 {model_id} (Gemma family)')
        else:
            print(f'  📦 {model_id}')
except Exception as e:
    print(f'  Error loading models: {e}')
" 2>/dev/null
}

# Setup Claude.md symlink
setup_claude_md() {
    if [[ -f "AGENT.md" && ! -f "CLAUDE.md" ]]; then
        ln -sf AGENT.md CLAUDE.md
        log_info "Created CLAUDE.md → AGENT.md symlink"
    fi
}

# Run Claude Code with proxy
run_claude_with_proxy() {
    local current_dir="$ORIGINAL_DIR"
    cd "$current_dir"
    
    # Ensure we're in a git repository
    if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        log_error "claude can only be executed in a git repository"
        exit 1
    fi
    
    # Change to git root
    local git_root=$(git rev-parse --show-toplevel)
    cd "$git_root"
    
    # Setup Claude.md
    setup_claude_md
    
    # Find Claude binary
    local claude_path=""
    if [[ -f "/opt/homebrew/bin/claude" ]]; then
        claude_path="/opt/homebrew/bin/claude"
    elif [[ -f "/usr/local/bin/claude" ]]; then
        claude_path="/usr/local/bin/claude"
    elif command -v claude >/dev/null 2>&1; then
        claude_path=$(which claude)
    else
        log_error "Claude Code CLI not found"
        log_info "Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    
    # Set environment for proxy
    export ANTHROPIC_BASE_URL="http://localhost:$DEFAULT_PORT"
    export ANTHROPIC_API_KEY="proxy-key"
    
    log_progress "Running Claude Code with local LLM"
    
    # Execute Claude with arguments
    if [[ ${#CLAUDE_ARGS[@]} -gt 0 ]]; then
        exec "$claude_path" "${CLAUDE_ARGS[@]}"
    else
        exec "$claude_path"
    fi
}

# Main execution
main() {
    # Capture original directory
    ORIGINAL_DIR=$(pwd)
    
    parse_arguments "$@"
    
    # Handle setup option
    if [[ "$SETUP_PROXY" == "true" ]]; then
        log_info "Run 'setup-claude-proxy' to configure the proxy"
        exit 0
    fi
    
    # Handle stop option
    if [[ "$STOP_SERVER" == "true" ]]; then
        stop_proxy_server
        exit 0
    fi
    
    # Handle logs option
    if [[ "$SHOW_LOGS" == "true" ]]; then
        show_server_logs
        exit 0
    fi
    
    # Handle models option
    if [[ "$SHOW_MODELS" == "true" ]]; then
        list_models
        exit 0
    fi
    
    # Validate setup for operations that need it
    if [[ "$START_SERVER" == "false" ]]; then
        validate_setup
    fi
    
    # Handle start server option
    if [[ "$START_SERVER" == "true" ]]; then
        validate_setup
        start_proxy_server
        log_success "Proxy server started on port $DEFAULT_PORT"
        exit 0
    fi
    
    # Default: run with proxy
    validate_setup
    
    # Check LM Studio is running
    if ! is_server_running; then
        log_error "LM Studio not running"
        log_info "Please start LM Studio first"
        exit 1
    fi
    
    # Handle model selection
    local target_model=""
    if [[ -n "$REQUESTED_MODEL" ]]; then
        log_info "Finding best match for: $REQUESTED_MODEL"
        
        target_model=$(find_best_model_match "$REQUESTED_MODEL")
        if [[ -z "$target_model" ]]; then
            log_error "No model found matching: $REQUESTED_MODEL"
            list_models
            exit 1
        fi
        
        log_success "Found match: $target_model"
        
        # Check if model needs to be loaded
        local current_model=$(get_loaded_model)
        if [[ "$current_model" != "$target_model" ]]; then
            if ! load_model "$target_model"; then
                log_error "Failed to load model"
                exit 1
            fi
            
            # Update proxy configuration
            update_proxy_config "$target_model"
            
            # Restart proxy with new config
            if is_proxy_running; then
                log_progress "Restarting proxy with new model"
                kill_existing_proxy
                sleep 1
            fi
            
            if ! start_proxy_server; then
                log_error "Failed to start proxy"
                exit 1
            fi
        else
            log_success "Model already loaded: $target_model"
        fi
    else
        # Just ensure proxy is running
        if ! is_proxy_running; then
            log_progress "Starting proxy server"
            if ! start_proxy_server; then
                log_error "Failed to start proxy"
                exit 1
            fi
        else
            log_success "Proxy server is running"
        fi
        
        target_model=$(get_loaded_model)
    fi
    
    # Show status
    if [[ -n "$target_model" ]]; then
        log_success "Using model: $target_model"
    fi
    
    # Run Claude Code
    run_claude_with_proxy
}

# Execute main function
main "$@"