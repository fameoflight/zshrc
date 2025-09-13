#!/usr/bin/env bash
#
# Common macOS Utilities
# Shared functions for macOS optimization scripts
#
# Author: Hemant Verma <fameoflight@gmail.com>

# Ensure this is only sourced once
if [[ "${MAC_UTILS_LOADED:-}" == "true" ]]; then
    return 0
fi
export MAC_UTILS_LOADED="true"

# Configuration
readonly MIN_MACOS_VERSION=10

# Get script directory for sourcing logging
MAC_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$(dirname "$MAC_UTILS_DIR")")"

# Source centralized logging functions
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback definitions if logging.zsh not available
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
    log_warn() { log_warning "$1"; }  # Backward compatibility alias
    log_section() {
        echo ""
        echo -e "\033[1m🔧 $1\033[0m"
        echo "═══════════════════════════════════════════════════════════"
    }
fi

# Check if running on macOS
mac_check_platform() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script only works on macOS"
        exit 1
    fi
    
    local macos_version
    macos_version=$(sw_vers -productVersion | cut -d. -f1)
    
    if [[ $macos_version -lt $MIN_MACOS_VERSION ]]; then
        log_warn "This script is optimized for macOS 10.0+. Your version: $(sw_vers -productVersion)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Export macOS version for use by other functions
    export MACOS_VERSION="$macos_version"
    export MACOS_FULL_VERSION="$(sw_vers -productVersion)"
}

# Enhanced device detection with detailed hardware identification
mac_detect_device() {
    DEVICE_TYPE="desktop"  # Default to desktop
    
    # Multiple detection methods for better accuracy
    local has_battery=false
    local is_imac=false
    local is_macbook=false
    local is_mac_mini=false
    local is_mac_pro=false
    local is_mac_studio=false
    
    # Check for battery presence
    if system_profiler SPPowerDataType 2>/dev/null | grep -q "Battery Information"; then
        has_battery=true
    fi
    
    # Check hardware model
    local model=$(system_profiler SPHardwareDataType | grep "Model Name" | cut -d: -f2 | xargs)
    local model_id=$(system_profiler SPHardwareDataType | grep "Model Identifier" | cut -d: -f2 | xargs)
    local chip=$(system_profiler SPHardwareDataType | grep "Chip" | cut -d: -f2 | xargs)
    
    case "$model" in
        *"MacBook"*) is_macbook=true ;;
        *"iMac"*) is_imac=true ;;
        *"Mac mini"*) is_mac_mini=true ;;
        *"Mac Pro"*) is_mac_pro=true ;;
        *"Mac Studio"*) is_mac_studio=true ;;
    esac
    
    # Determine device type and provide detailed logging
    if [[ "$has_battery" == true ]] || [[ "$is_macbook" == true ]]; then
        DEVICE_TYPE="laptop"
        log_info "🔋 Laptop detected: $model ($model_id)"
        [[ -n "$chip" ]] && log_info "   Processor: $chip"
    else
        DEVICE_TYPE="desktop"
        if [[ "$is_imac" == true ]]; then
            log_info "🖥️  iMac detected: $model ($model_id)"
        elif [[ "$is_mac_mini" == true ]]; then
            log_info "🖥️  Mac mini detected: $model ($model_id)"
            log_info "   Optimizing for external display setup"
        elif [[ "$is_mac_pro" == true ]]; then
            log_info "🖥️  Mac Pro detected: $model ($model_id)"
            log_info "   Using high-performance desktop settings"
        elif [[ "$is_mac_studio" == true ]]; then
            log_info "🖥️  Mac Studio detected: $model ($model_id)"
            log_info "   Using high-performance desktop settings"
        else
            log_info "🖥️  Desktop Mac detected: $model ($model_id)"
        fi
        [[ -n "$chip" ]] && log_info "   Processor: $chip"
    fi
    
    # Export for use by other functions
    export DEVICE_TYPE
    export DEVICE_MODEL="$model"
    export DEVICE_MODEL_ID="$model_id"
    export DEVICE_CHIP="$chip"
}

# Request administrator access with keep-alive
mac_request_sudo() {
    log_info "Requesting administrator access..."
    sudo -v
    
    # Keep-alive: update existing sudo time stamp until script has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# Show confirmation dialog with customizable message
mac_confirm_changes() {
    local script_name="${1:-macOS optimization}"
    local additional_info="${2:-}"
    
    echo ""
    log_warning "This script will modify your macOS system preferences."
    log_warning "Some changes require a restart to take effect."
    [[ -n "$additional_info" ]] && log_info "$additional_info"
    echo ""
    read -p "Do you want to continue with $script_name? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

# Restart common macOS applications
mac_restart_apps() {
    log_section "Restarting Applications"
    
    local apps_to_restart=(
        "Dock"
        "Finder"
        "SystemUIServer"
        "NotificationCenter"
        "ControlStrip"
        "cfprefsd"
    )
    
    for app in "${apps_to_restart[@]}"; do
        if pgrep -f "$app" >/dev/null 2>&1; then
            log_info "Restarting $app..."
            killall "$app" 2>/dev/null || true
            sleep 0.5
        fi
    done
    
    log_success "Applications restarted"
}

# Configure desktop-optimized power management
mac_configure_desktop_power() {
    local context="${1:-desktop}"
    
    log_section "Power Management ($context)"
    
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                log_info "🖥️  High-performance desktop power settings"
                sudo pmset -c displaysleep 10 disksleep 30
                sudo pmset -a standbydelay 600   # 10 minutes
                sudo pmset -a hibernatemode 0    # No hibernation
                sudo pmset -a autopoweroff 0     # No auto power off
                sudo pmset -a powernap 0          # Disable powernap for stability
                ;;
            *"Mac mini"*)
                log_info "🖥️  Mac mini power settings (external display optimized)"
                sudo pmset -c displaysleep 8 disksleep 25
                sudo pmset -a standbydelay 300   # 5 minutes
                sudo pmset -a hibernatemode 0    # No hibernation
                sudo pmset -a autopoweroff 0     # No auto power off
                sudo pmset -a powernap 0          # Disable for consistent performance
                ;;
            *"iMac"*)
                log_info "🖥️  iMac power settings"
                sudo pmset -c displaysleep 8 disksleep 20
                sudo pmset -a standbydelay 300   # 5 minutes
                sudo pmset -a hibernatemode 0    # No hibernation
                sudo pmset -a autopoweroff 0     # No auto power off
                sudo pmset -a powernap 1          # Enable for background updates
                ;;
            *)
                log_info "🖥️  Standard desktop power settings"
                sudo pmset -c displaysleep 8 disksleep 20
                sudo pmset -a standbydelay 300   # 5 minutes
                sudo pmset -a hibernatemode 0    # No hibernation
                sudo pmset -a autopoweroff 0     # No auto power off
                sudo pmset -a powernap 0          # Conservative default
                ;;
        esac
    else
        log_info "🔋 Laptop power settings"
        sudo pmset -b displaysleep 5 disksleep 10   # Battery
        sudo pmset -c displaysleep 8 disksleep 15   # Power adapter
        sudo pmset -a standbydelay 7200              # 2 hours
        sudo pmset -a hibernatemode 3                # Safe sleep
        sudo pmset -a autopoweroffdelay 14400        # 4 hours
        sudo pmset -a powernap 1                     # Enable for updates
    fi
    
    # Common power optimizations
    log_info "Disabling sudden motion sensor (SSD optimization)"
    sudo pmset -a sms 0
    
    log_info "Disabling wake for network access"
    sudo pmset -a womp 0
    
    log_success "Power management configured for $DEVICE_TYPE ($DEVICE_MODEL)"
}

# Configure hot corners with simple, clean setup
mac_configure_hot_corners() {
    log_section "Hot Corners Configuration"
    
    log_info "Setting hot corners: Mission Control, Desktop, Lock Screen, Disabled"
    defaults write com.apple.dock wvous-tl-corner -int 2   # Mission Control
    defaults write com.apple.dock wvous-tl-modifier -int 0
    defaults write com.apple.dock wvous-tr-corner -int 4   # Desktop
    defaults write com.apple.dock wvous-tr-modifier -int 0
    defaults write com.apple.dock wvous-bl-corner -int 13  # Lock Screen
    defaults write com.apple.dock wvous-bl-modifier -int 0
    defaults write com.apple.dock wvous-br-corner -int 0   # Disabled
    defaults write com.apple.dock wvous-br-modifier -int 0
    
    log_success "Hot corners configured"
}

# Show system information summary
mac_show_system_info() {
    log_section "System Information"
    log_info "macOS Version: $MACOS_FULL_VERSION"
    log_info "Device Type: $DEVICE_TYPE"
    log_info "Model: $DEVICE_MODEL"
    log_info "Model ID: $DEVICE_MODEL_ID"
    [[ -n "$DEVICE_CHIP" ]] && log_info "Processor: $DEVICE_CHIP"
}

# Parse common command line arguments
mac_parse_common_args() {
    FORCE_MODE=false
    DRY_RUN=false
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                return 2  # Signal caller to show help
                ;;
            -f|--force)
                FORCE_MODE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done
    
    # Export for use by calling scripts
    export FORCE_MODE DRY_RUN VERBOSE
    return 0
}

# Completion message with restart prompt
mac_show_completion() {
    local script_name="${1:-macOS optimization}"
    local restart_required="${2:-true}"
    
    echo ""
    log_success "🎉 $script_name complete!"
    echo ""
    
    if [[ "$restart_required" == "true" ]]; then
        log_info "Some changes may require a system restart to take full effect."
        log_info "You can restart now or later at your convenience."
        echo ""
        read -p "Would you like to restart now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Restarting system in 5 seconds..."
            sleep 5
            sudo shutdown -r now
        else
            log_info "Remember to restart your system later to apply all changes."
        fi
    else
        log_info "All changes have been applied and are now active."
    fi
}

# Export all functions for use in other scripts
export -f mac_check_platform
export -f mac_detect_device  
export -f mac_request_sudo
export -f mac_confirm_changes
export -f mac_restart_apps
export -f mac_configure_desktop_power
export -f mac_configure_hot_corners
export -f mac_show_system_info
export -f mac_parse_common_args
export -f mac_show_completion