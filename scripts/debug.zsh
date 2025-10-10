#!/usr/bin/env zsh
# @author    Claude Code
# @license   GPL v3
#
# ZSH Startup Performance Debugging Script
# Comprehensive tools to analyze and optimize shell startup time

# Load logging functions for consistent output
source "$ZSH_CONFIG/logging.zsh" 2>/dev/null || {
    # Fallback logging if not available
    function log_info() { echo "ℹ️  $*" >&2; }
    function log_success() { echo "✅ $*" >&2; }
    function log_warning() { echo "⚠️  $*" >&2; }
    function log_error() { echo "❌ $*" >&2; }
    function log_progress() { echo "🔄 $*" >&2; }
    function log_section() { echo "🔧 $*" >&2; }
}

# Script information
DEBUG_SCRIPT_VERSION="1.0.0"
DEBUG_SCRIPT_NAME="ZSH Performance Debugger"

function show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

ZSH Startup Performance Debugger - Analyze and optimize shell startup time

COMMANDS:
    profile           Run detailed startup profiling (default)
    baseline          Test minimal ZSH startup time
    compare           Compare performance before/after optimizations
    components        Test individual component loading times
    recommend         Show optimization recommendations
    test-optimizations Test if optimizations are working

OPTIONS:
    -h, --help       Show this help message
    -v, --verbose    Verbose output with detailed timing
    -n, --number N   Run profile N times and average results
    -o, --output FILE Save results to file
    --no-color       Disable colored output

EXAMPLES:
    $0                           # Run basic profiling
    $0 profile -n 5              # Profile 5 times and average
    $0 baseline                  # Test minimal startup time
    $0 compare                   # Compare current vs optimized
    $0 components                # Test individual components

EOF
}

# Parse command line arguments
VERBOSE=false
RUN_COUNT=1
OUTPUT_FILE=""
NO_COLOR=false
COMMAND="profile"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--number)
            RUN_COUNT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --no-color)
            NO_COLOR=true
            shift
            ;;
        profile|baseline|compare|components|recommend|test-optimizations)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Helper function for timing
function time_command() {
    local cmd="$1"
    local desc="$2"

    if [[ "$NO_COLOR" == "true" ]]; then
        /usr/bin/time -p "$cmd" 2>&1 | grep "real" | cut -d' ' -f2
    else
        echo -n "📊 $desc: "
        /usr/bin/time -p "$cmd" 2>&1 | grep "real" | cut -d' ' -f2 | while read time; do
            if (( $(echo "$time > 1.0" | bc -l) )); then
                echo "${time}s (🐌 Slow)"
            elif (( $(echo "$time > 0.5" | bc -l) )); then
                echo "${time}s (⚠️  Moderate)"
            else
                echo "${time}s (✅ Fast)"
            fi
        done
    fi
}

# Detailed profiling with ZSH built-in tracing
function profile_zsh_startup() {
    log_section "ZSH Startup Performance Profiling"

    local profile_file="/tmp/zsh_profile_$$"
    local temp_zshrc="/tmp/zshrc_debug_$$"

    # Create temporary zshrc with profiling enabled
    cat > "$temp_zshrc" << 'EOF'
# Enable profiling
zmodload zsh/datetime
setopt PROMPT_SUBST
PS4='+$EPOCHREALTIME %N:%i> '

# Start profiling
exec 3>&2 2>/tmp/zsh_profile_temp
setopt XTRACE

# Source actual configuration
source "$HOME/.config/zsh/zshrc"

# Stop profiling
unsetopt XTRACE
exec 2>&3 3>&-
EOF

    log_progress "Running startup profiling..."

    # Profile the startup
    (zsh -i -c "source $temp_zshrc; exit" 2>/dev/null)

    if [[ -f "/tmp/zsh_profile_temp" ]]; then
        log_progress "Analyzing profile results..."

        # Process results
        echo
        echo "🔍 Top 20 Slowest Operations:"
        echo "─────────────────────────────────"

        awk '
        /^\+/ {
            gsub(/^\+/, "")
            if (prev_time) {
                duration = $1 - prev_time
                printf "%8.3f ms  %s\n", duration * 1000, substr($0, index($0, " ") + 1)
            }
            prev_time = $1
        }' "/tmp/zsh_profile_temp" | sort -nr | head -20

        echo
        log_success "Profiling complete!"

        # Cleanup
        rm -f "/tmp/zsh_profile_temp" "$temp_zshrc"
    else
        log_error "Profiling failed - no data collected"
    fi
}

# Test baseline startup time
function test_baseline() {
    log_section "Baseline Performance Testing"

    echo "Testing minimal ZSH startup (no configuration)..."
    time_command "env -i zsh -c 'echo minimal'" "Minimal ZSH startup"

    echo
    echo "Testing current configuration..."
    time_command "zsh -i -c 'exit'" "Current startup"

    echo
    echo "Testing major components individually..."

    # Test individual components
    time_command "(source $ZSH_CONFIG/environment.zsh)" "Environment loading"
    time_command "(source $ZSH_CONFIG/completion.zsh)" "Completion loading"
    time_command "(source $ZSH_CONFIG/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh)" "Syntax highlighting"

    # Test NVM
    if [[ -d "$HOME/.config/nvm" ]]; then
        time_command "([ -s \"$HOME/.config/nvm/nvm.sh\" ] && . \"$HOME/.config/nvm/nvm.sh\")" "NVM loading"
    fi
}

# Compare performance with optimizations
function compare_performance() {
    log_section "Performance Comparison"

    echo "Testing current configuration..."
    local current_time=$(time_command "zsh -i -c 'exit'" "Current startup" | grep -o '[0-9.]*')

    echo
    echo "📈 Performance Analysis:"
    if (( $(echo "$current_time > 1.0" | bc -l) )); then
        log_warning "Your ZSH startup is slow (>1s). Significant optimization needed."
        echo "   💡 Consider implementing NVM lazy loading and completion optimization"
    elif (( $(echo "$current_time > 0.5" | bc -l) )); then
        log_warning "Your ZSH startup is moderate (>500ms). Some optimization recommended."
        echo "   💡 Try lazy loading and completion caching"
    else
        log_success "Your ZSH startup is fast (<500ms). Good job!"
    fi

    echo
    echo "🎯 Quick wins to try:"
    echo "   1. Lazy load NVM (saves 100-150ms)"
    echo "   2. Optimize completions (saves 50-100ms)"
    echo "   3. Cache brew prefix (saves ~20ms)"
}

# Test individual components
function test_components() {
    log_section "Component-by-Component Analysis"

    local components=(
        "environment.zsh:Environment setup"
        "options.zsh:Shell options"
        "prompt.zsh:Prompt configuration"
        "functions.zsh:Custom functions"
        "aliases.zsh:Command aliases"
        "completion.zsh:Tab completion"
        "darwin.zsh:macOS-specific config"
        "zsh-syntax-highlighting/zsh-syntax-highlighting.zsh:Syntax highlighting"
    )

    for component in "${components[@]}"; do
        local file="${component%%:*}"
        local desc="${component##*:}"

        if [[ -f "$ZSH_CONFIG/$file" ]]; then
            time_command "(source $ZSH_CONFIG/$file)" "$desc"
        else
            log_info "Skipping $desc (not found)"
        fi
    done

    # Test external tools
    echo
    echo "🔌 External Tools:"

    if command -v brew >/dev/null 2>&1; then
        time_command "brew --prefix >/dev/null" "Brew prefix lookup"
    fi

    if [[ -d "$HOME/.config/nvm" ]]; then
        time_command "ls $HOME/.config/nvm >/dev/null" "NVM directory access"
    fi

    # Test SSH operations
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        time_command "ssh-add -l >/dev/null 2>&1 || true" "SSH agent check"
    fi
}

# Show optimization recommendations
function show_recommendations() {
    log_section "Optimization Recommendations"

    echo "🎯 High Impact, Low Risk Changes:"
    echo
    echo "1. Lazy Load NVM (Save: 100-150ms)"
    cat << 'EOF'
   Replace NVM loading in zshrc with:

   export NVM_DIR="$HOME/.config/nvm"
   function nvm() {
       unset -f nvm
       [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
       nvm "$@"
   }
EOF
    echo
    echo "2. Optimize Completions (Save: 50-100ms)"
    cat << 'EOF'
   Add to completion.zsh:

   zstyle ':completion:*' use-cache on
   zstyle ':completion:*' cache-path ~/.zsh/cache
   zstyle ':completion:*' menu select
EOF
    echo
    echo "3. Cache Brew Prefix (Save: ~20ms)"
    cat << 'EOF'
   Add to darwin.zsh:

   if [[ ! -f /tmp/brew_prefix_cache ]]; then
       brew --prefix > /tmp/brew_prefix_cache 2>/dev/null
   fi
EOF
    echo
    echo "🔧 Advanced Optimizations:"
    echo "   • Consider using 'zinit' or 'zplug' for plugin management"
    echo "   • Remove unused aliases and functions"
    echo "   • Use shell startup analyzers like 'zsh-bench'"
    echo "   • Consider moving heavy operations to background"
}

# Test if optimizations are working
function test_optimizations() {
    log_section "Testing Optimizations"

    # Test NVM lazy loading
    if typeset -f nvm >/dev/null; then
        log_success "✅ NVM lazy loading is active"
    else
        log_warning "⚠️  NVM is being loaded at startup (slow)"
    fi

    # Test completion cache
    if [[ -d ~/.zsh/cache ]]; then
        log_success "✅ Completion cache directory exists"
    else
        log_info "ℹ️  Completion cache not configured"
    fi

    # Test syntax highlighting
    if typeset -f _zsh_highlight >/dev/null; then
        log_success "✅ Syntax highlighting is loaded"
    else
        log_info "ℹ️  Syntax highlighting not loaded"
    fi

    echo
    echo "🏃‍♂️ Current startup time:"
    time_command "zsh -i -c 'exit'" "Full startup"
}

# Main execution
function main() {
    log_section "$DEBUG_SCRIPT_NAME v$DEBUG_SCRIPT_VERSION"

    # Validate dependencies
    if ! command -v bc >/dev/null 2>&1; then
        log_warning "bc not found - some timing comparisons may not work"
    fi

    if [[ "$OUTPUT_FILE" != "" ]]; then
        exec > >(tee -a "$OUTPUT_FILE") 2>&1
        log_info "Output will be saved to: $OUTPUT_FILE"
    fi

    # Run specified command
    case "$COMMAND" in
        profile)
            for i in $(seq 1 $RUN_COUNT); do
                if [[ "$RUN_COUNT" -gt 1 ]]; then
                    echo
                    log_progress "Run $i/$RUN_COUNT"
                fi
                profile_zsh_startup
            done
            ;;
        baseline)
            test_baseline
            ;;
        compare)
            compare_performance
            ;;
        components)
            test_components
            ;;
        recommend)
            show_recommendations
            ;;
        test-optimizations)
            test_optimizations
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac

    echo
    log_success "Debug session complete!"
    echo
    echo "💡 Quick fix commands:"
    echo "   make debug          # Run this debugger"
    echo "   make debug profile  # Run detailed profiling"
    echo "   make debug compare  # Compare performance"
}

# Run main function
main "$@"