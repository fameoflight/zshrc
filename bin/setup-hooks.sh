#!/bin/bash
# @category: setup
# @description: Setup git hooks for the zshrc repository
# @tags: git, hooks, automation

set -euo pipefail

# Source logging functions
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback definitions if logging.zsh not available
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
    log_section() { echo -e "\033[0;35m🔧 $1\033[0m"; }
    log_progress() { echo -e "\033[0;36m🔄 $1\033[0m"; }
fi

# Configuration
ZSH_CONFIG="${ZSH_CONFIG:-$HOME/.config/zsh}"
LAUNCH_AGENT_LABEL="com.hemantv.wakeup"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"
WAKEUP_SCRIPT="$ZSH_CONFIG/hooks/wakeup.sh"
SLEEP_SCRIPT="$ZSH_CONFIG/hooks/sleep.sh"
LOGS_DIR="$HOME/logs"

cleanup_existing_setup() {
    log_section "Cleaning up existing wake/sleep hook setup"

    # Remove from Login Items if present
    log_progress "Checking for wakeup.sh in Login Items"
    if osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "wakeup.sh"; then
        log_warning "Found wakeup.sh in Login Items - removing"
        osascript -e 'tell application "System Events" to delete login item "wakeup.sh"' 2>/dev/null || true
        log_success "Removed wakeup.sh from Login Items"
    else
        log_info "wakeup.sh not found in Login Items"
    fi

    # Unload and remove existing LaunchAgent
    if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
        log_progress "Unloading existing LaunchAgent"
        launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
        log_progress "Removing existing LaunchAgent plist"
        rm -f "$LAUNCH_AGENT_PLIST"
        log_success "Cleaned up existing LaunchAgent"
    else
        log_info "No existing LaunchAgent found"
    fi

    # Stop sleepwatcher service if running
    log_progress "Stopping sleepwatcher service"
    brew services stop sleepwatcher 2>/dev/null || true

    # Remove existing symlinks
    [[ -L "$HOME/.wakeup" ]] && rm -f "$HOME/.wakeup" && log_info "Removed existing .wakeup symlink"
    [[ -L "$HOME/.sleep" ]] && rm -f "$HOME/.sleep" && log_info "Removed existing .sleep symlink"
}

setup_sleepwatcher() {
    log_section "Setting up sleepwatcher and hook scripts"

    # Ensure sleepwatcher is installed
    log_progress "Ensuring sleepwatcher is installed"
    if ! command -v sleepwatcher >/dev/null 2>&1; then
        log_info "Installing sleepwatcher via Homebrew"
        brew install sleepwatcher
    else
        log_success "sleepwatcher already installed"
    fi

    # Create logs directory
    log_progress "Creating logs directory"
    mkdir -p "$LOGS_DIR"

    # Link wakeup and sleep scripts
    log_progress "Linking wakeup script to ~/.wakeup"
    ln -sf "$WAKEUP_SCRIPT" "$HOME/.wakeup"

    log_progress "Linking sleep script to ~/.sleep"
    ln -sf "$SLEEP_SCRIPT" "$HOME/.sleep"

    # Start sleepwatcher service
    log_progress "Starting sleepwatcher service"
    brew services start sleepwatcher

    log_success "sleepwatcher setup complete"
}

setup_launch_agent() {
    log_section "Setting up LaunchAgent for login hook"

    # Create LaunchAgents directory
    log_progress "Creating LaunchAgents directory"
    mkdir -p "$HOME/Library/LaunchAgents"

    # Create the LaunchAgent plist
    log_progress "Creating LaunchAgent plist"
    cat > "$LAUNCH_AGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>${WAKEUP_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOGS_DIR}/wakeup.out</string>
    <key>StandardErrorPath</key>
    <string>${LOGS_DIR}/wakeup.err</string>
</dict>
</plist>
EOF

    # Load the LaunchAgent
    log_progress "Loading LaunchAgent"
    launchctl load "$LAUNCH_AGENT_PLIST"

    log_success "LaunchAgent setup complete"
}

verify_setup() {
    log_section "Verifying hook setup"

    # Check sleepwatcher service
    if brew services list | grep -q "sleepwatcher.*started"; then
        log_success "sleepwatcher service is running"
    else
        log_warning "sleepwatcher service may not be running properly"
    fi

    # Check LaunchAgent
    if launchctl list | grep -q "$LAUNCH_AGENT_LABEL"; then
        log_success "LaunchAgent is loaded"
    else
        log_warning "LaunchAgent may not be loaded properly"
    fi

    # Check script files
    if [[ -x "$WAKEUP_SCRIPT" ]]; then
        log_success "Wakeup script is executable"
    else
        log_error "Wakeup script is not executable"
    fi

    if [[ -x "$SLEEP_SCRIPT" ]]; then
        log_success "Sleep script is executable"
    else
        log_warning "Sleep script not found or not executable"
    fi

    # Check symlinks
    if [[ -L "$HOME/.wakeup" && -L "$HOME/.sleep" ]]; then
        log_success "Hook script symlinks are in place"
    else
        log_warning "Some hook script symlinks may be missing"
    fi
}

main() {
    log_section "Setting up wake and sleep hooks"

    # Verify required files exist
    if [[ ! -f "$WAKEUP_SCRIPT" ]]; then
        log_error "Wakeup script not found at $WAKEUP_SCRIPT"
        exit 1
    fi

    if [[ ! -x "$WAKEUP_SCRIPT" ]]; then
        log_info "Making wakeup script executable"
        chmod +x "$WAKEUP_SCRIPT"
    fi

    if [[ -f "$SLEEP_SCRIPT" && ! -x "$SLEEP_SCRIPT" ]]; then
        log_info "Making sleep script executable"
        chmod +x "$SLEEP_SCRIPT"
    fi

    # Perform setup steps
    cleanup_existing_setup
    setup_sleepwatcher
    setup_launch_agent
    verify_setup

    log_success "Wake and sleep hooks setup complete!"
    log_info "Scripts will run on system wake/sleep and login"
    log_info "Logs are stored in: $LOGS_DIR"
}

# Execute main function
main "$@"