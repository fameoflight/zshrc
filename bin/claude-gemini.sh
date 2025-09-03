#!/bin/bash
set -euo pipefail

# Claude-Gemini Integration - Run Claude Code with Gemini API
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
PROXY_DIR="${ZSH_CONFIG}/gemini-claude-proxy"
VENV_DIR="${PROXY_DIR}/.venv"
SERVER_PID_FILE="${PROXY_DIR}/server.pid"
DEFAULT_PORT=8082
ORIGINAL_DIR=""

# Help function
show_help() {
    cat << EOF
🤖 Claude-Gemini Integration

Usage: claude-gemini [OPTION] [CLAUDE_ARGS...]

Methods:
  claude-gemini --start    Start proxy (restart if already running)
  claude-gemini --logs     Show server logs  
  claude-gemini            Run Claude with proxy (default)

Examples:
  claude-gemini --start    # Start/restart the proxy server
  claude-gemini --logs     # Show server logs
  claude-gemini            # Run Claude Code with Gemini proxy

Prerequisites:
- Run 'make claude-gemini-setup' first
- Add your Gemini API key with 'setup-gemini-key "your-key-here"'
EOF
}

# Parse command line arguments
parse_arguments() {
    START_SERVER=false
    SHOW_LOGS=false
    PORT=$DEFAULT_PORT
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
            --logs)
                SHOW_LOGS=true
                shift
                ;;
            *)
                CLAUDE_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# Simple logging for setup info
setup_log() {
    log_info "$1"
}

# Find a suitable python executable
find_python() {
    local python_execs=("python3.12" "python3.11" "python3")
    for py_cmd in "${python_execs[@]}"; do
        if command -v "$py_cmd" >/dev/null 2>&1; then
            local py_version=$("$py_cmd" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
            if [[ "$(printf '%s\n' "3.11" "$py_version" | sort -V | head -n1)" == "3.11" ]]; then
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
        log_info "Run 'make claude-gemini-setup' to initialize the setup"
        exit 1
    fi

    if ! find_python; then
        log_error "Python 3.11+ is required but could not be found."
        log_info "Please install a compatible version, e.g., with Homebrew: brew install python@3.12"
        exit 1
    fi
}


# Check if server is running
is_server_running() {
    local port=${1:-$PORT}
    curl -s "http://localhost:${port}/health" >/dev/null 2>&1
}

# Find Gemini API key from various locations
find_gemini_api_key() {
    local key_locations=(
        "$HOME/.gemini/api_key"
        "$HOME/.config/gemini/api_key" 
        "$HOME/.google_ai_api_key"
        "$HOME/.gemini_api_key"
        "$ZSH_CONFIG/private.env"
    )
    
    for location in "${key_locations[@]}"; do
        if [[ -f "$location" ]]; then
            if [[ "$location" == *"private.env" ]]; then
                # Source env file and return GEMINI_API_KEY
                source "$location" 2>/dev/null || true
                if [[ -n "${GEMINI_API_KEY:-}" ]]; then
                    echo "$GEMINI_API_KEY"
                    return 0
                fi
            else
                local key=$(cat "$location" 2>/dev/null | tr -d '\n\r')
                if [[ -n "$key" ]]; then
                    echo "$key"
                    return 0
                fi
            fi
        fi
    done
    
    # Check environment variable
    echo "${GEMINI_API_KEY:-}"
}

# Setup environment file with API key
setup_environment_file() {
    local env_file="${PROXY_DIR}/.env"
    local env_example="${PROXY_DIR}/.env.example"
    
    # Create .env if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        if [[ -f "$env_example" ]]; then
            cp "$env_example" "$env_file"
        else
            cat > "$env_file" << EOF
# Gemini API Configuration
GEMINI_API_KEY=your_gemini_api_key_here

# Server Configuration  
PORT=$PORT
HOST=localhost

# Model Configuration
DEFAULT_MODEL=gemini-1.5-flash-latest
EOF
        fi
    fi
    
    # Try to update with actual API key
    local api_key=$(find_gemini_api_key)
    if [[ -n "$api_key" && "$api_key" != "your_gemini_api_key_here" ]]; then
        # Update the .env file with the actual key (portable sed)
        local temp_file
        temp_file=$(mktemp)
        if grep -q "^GEMINI_API_KEY=" "$env_file"; then
            sed "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$api_key/" "$env_file" > "$temp_file" && mv "$temp_file" "$env_file"
        else
            cp "$env_file" "$temp_file"
            echo "GEMINI_API_KEY=$api_key" >> "$temp_file"
            mv "$temp_file" "$env_file"
        fi
    else
        log_warning "Gemini API key not found"
        log_info "Add your key to $env_file or use: setup-gemini-key 'your-key-here'"
    fi
}

# Ensure proxy setup is complete
ensure_proxy_setup() {
    local current_dir=$(pwd)
    
    # Ensure virtual environment exists
    if [[ ! -d "$VENV_DIR" ]]; then
        log_progress "Creating Python virtual environment"
        cd "$PROXY_DIR"
        "$PYTHON_EXEC" -m venv .venv
    fi
    
    # Install dependencies if requirements.txt exists
    local requirements_file="${PROXY_DIR}/requirements.txt"
    if [[ -f "$requirements_file" ]]; then
        cd "$PROXY_DIR"
        .venv/bin/pip install -q -r requirements.txt
    fi
    
    # Setup environment file
    setup_environment_file
    
    # Return to original directory
    cd "$current_dir"
}

# Start the proxy server (restart if already running)
start_proxy_server() {
    local current_dir=$(pwd)
    
    if is_server_running; then
        if [[ "$START_SERVER" == "true" ]]; then
            log_info "Restarting proxy server"
            stop_proxy_server
            sleep 1
        else
            return 0
        fi
    fi
    
    log_progress "Starting proxy server on port $PORT"
    
    cd "$PROXY_DIR"
    
    # Start server in background
    local log_file="${PROXY_DIR}/server.log"
    .venv/bin/python server.py > "$log_file" 2>&1 &
    local server_pid=$!
    
    echo $server_pid > "$SERVER_PID_FILE"
    
    # Return to original directory before waiting
    cd "$current_dir"
    
    # Wait for server to start
    local attempts=0
    while [[ $attempts -lt 15 ]]; do
        if is_server_running; then
            log_success "Proxy server started (PID: $server_pid)"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log_error "Failed to start proxy server"
    cleanup_pid_file
    exit 1
}

# Stop the proxy server
stop_proxy_server() {
    if [[ ! -f "$SERVER_PID_FILE" ]]; then
        return 0
    fi
    
    local pid=$(cat "$SERVER_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]]; then
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    fi
    
    cleanup_pid_file
}


# Setup Claude.md symlink
setup_claude_md() {
    if [[ -f "AGENT.md" && ! -f "CLAUDE.md" ]]; then
        ln -sf AGENT.md CLAUDE.md
    fi
}

# Run Claude Code with proxy
run_claude_with_proxy() {
    log_progress "Running Claude Code with Gemini API"
    
    # Use the original directory where command was called
    local target_dir="$ORIGINAL_DIR"
    cd "$target_dir"
    
    # Ensure we're in a git repository
    if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        log_error "claude can only be executed in a git repository"
        exit 1
    fi
    
    # Change to git root of the original project
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
    
    # Set environment and exec Claude
    export ANTHROPIC_BASE_URL="http://localhost:$PORT"
    export ANTHROPIC_API_KEY="dummy-key-for-proxy"
    
    # Execute Claude with remaining arguments
    if [[ ${#CLAUDE_ARGS[@]} -gt 0 ]]; then
        exec "$claude_path" "${CLAUDE_ARGS[@]}"
    else
        exec "$claude_path"
    fi
}

# Show server logs
show_server_logs() {
    local log_file="${PROXY_DIR}/server.log"
    
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    else
        log_error "No log file found at $log_file"
        exit 1
    fi
}

# Cleanup PID file
cleanup_pid_file() {
    [[ -f "$SERVER_PID_FILE" ]] && rm -f "$SERVER_PID_FILE"
}

# Main execution
main() {
    # Capture original directory before any processing
    ORIGINAL_DIR=$(pwd)
    
    parse_arguments "$@"
    validate_setup
    ensure_proxy_setup
    
    if [[ "$START_SERVER" == "true" ]]; then
        start_proxy_server
        log_success "Proxy server started on port $PORT"
        exit 0
    fi
    
    if [[ "$SHOW_LOGS" == "true" ]]; then
        show_server_logs
        exit 0
    fi
    
    # Default: start proxy and run Claude
    start_proxy_server
    run_claude_with_proxy
}

# Execute main function
main "$@"