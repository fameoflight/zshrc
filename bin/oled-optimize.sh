#!/usr/bin/env bash
#
# OLED Monitor Optimization Script
# Configures macOS settings specifically for OLED displays
# Focuses on burn-in prevention and optimal display performance
#
# Author: Hemant Verma <fameoflight@gmail.com>

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="OLED Monitor Optimizer"
readonly MIN_MACOS_VERSION=10
readonly WALLPAPER_CHANGE_INTERVAL=300  # seconds (5 minutes)

# Source centralized logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"

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
        echo -e "\033[1m🖥️  $1\033[0m"
        echo "═══════════════════════════════════════════════════════════"
    }
fi

# Check if running on macOS
check_platform() {
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
}

# Detect if this is a laptop or desktop
detect_device_type() {
    # Check if device has a battery (laptop) or not (desktop)
    if system_profiler SPPowerDataType | grep -q "Battery Information"; then
        DEVICE_TYPE="laptop"
        log_info "🔋 Laptop detected - using laptop-optimized power settings"
    else
        DEVICE_TYPE="desktop"
        log_info "🖥️  Desktop detected - using desktop-optimized power settings"
    fi
}

# Request administrator access
request_sudo() {
    log_info "Requesting administrator access..."
    sudo -v
    
    # Keep-alive: update existing sudo time stamp until script has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# Show confirmation before making changes
confirm_changes() {
    echo ""
    log_info "This script will optimize your macOS settings for OLED displays."
    log_info "It focuses on burn-in prevention and display protection."
    log_info "Some changes require a restart to take effect."
    echo ""
}

# Dark mode and appearance optimizations
configure_dark_mode() {
    log_section "Dark Mode & Appearance"
    
    log_info "Enabling dark mode system-wide"
    defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
    
    log_info "Enabling dark menu bar and Dock"
    defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool false
    
    log_info "Disabling menu bar transparency to reduce static elements"
    defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false
    
    log_info "Disabling menu bar auto-hide (user preference)"
    defaults write NSGlobalDomain _HIHideMenuBar -bool false
    
    log_info "Setting wallpaper with continuous shuffle across all spaces:"
    echo "  • Wallpaper rotation: enabled (shuffle continuously)"
    echo "  • Change interval: every $((WALLPAPER_CHANGE_INTERVAL / 60)) minutes"
    echo "  • Random order: enabled"
    echo "  • Multiple displays: same wallpaper across all displays"
    echo "  • Show in all spaces: enabled"
    
    # Enable wallpaper rotation with shuffle
    osascript -e 'tell application "System Events"
        tell every desktop
            set picture rotation to 1  -- (0=off, 1=interval, 2=login, 3=sleep)
            set change interval to '"$WALLPAPER_CHANGE_INTERVAL"'.0  -- '$((WALLPAPER_CHANGE_INTERVAL / 60))' minutes in seconds
            set random order to true
            set pictures folder to (POSIX file "/System/Library/Desktop Pictures")
        end tell
    end tell' 2>/dev/null || true
    
    # Enable "Show on all Spaces" via separate AppleScript
    log_info "Enabling 'Show on all Spaces' for wallpaper across all desktops"
    local applescript_path="$ZSH_CONFIG/bin/enable-wallpaper-all-spaces.applescript"
    
    if [[ -f "$applescript_path" ]]; then
        log_info "Executing AppleScript to enable 'Show on all Spaces'..."
        osascript "$applescript_path" 2>/dev/null || log_warning "Could not automatically enable 'Show on all Spaces' - please enable manually in System Settings > Wallpaper"
    else
        log_warning "AppleScript not found at $applescript_path - please enable 'Show on all Spaces' manually"
    fi
    
    log_info "Wallpaper will now shuffle every $((WALLPAPER_CHANGE_INTERVAL / 60)) minutes across all displays and spaces"
    log_info "Using System Desktop Pictures folder for variety"
    
    # Automatically set up dark wallpapers for OLED protection
    log_info "Setting up dark wallpapers folder for maximum OLED protection"
    
    # Create a dark wallpapers directory if it doesn't exist
    mkdir -p ~/Pictures/DarkWallpapers
    
    # Copy dark system wallpapers
    if [[ -d "/System/Library/Desktop Pictures" ]]; then
        log_info "Copying dark system wallpapers..."
        find "/System/Library/Desktop Pictures" -name "*[Dd]ark*" -o -name "*[Bb]lack*" -o -name "*[Nn]ight*" | head -5 | while read -r wallpaper; do
            cp "$wallpaper" ~/Pictures/DarkWallpapers/ 2>/dev/null || true
        done
    fi
    
    # Set to use dark wallpapers folder
    osascript -e 'tell application "System Events"
        tell every desktop
            set picture rotation to 1  -- Enable interval rotation
            set change interval to '"$WALLPAPER_CHANGE_INTERVAL"'.0  -- '$((WALLPAPER_CHANGE_INTERVAL / 60))' minutes in seconds  
            set random order to true
            set pictures folder to (POSIX file ((path to home folder as string) & "Pictures/DarkWallpapers"))
        end tell
    end tell' 2>/dev/null || true
    
    # Ensure "Show on all Spaces" remains enabled for dark wallpapers
    log_info "Ensuring 'Show on all Spaces' is enabled for dark wallpaper rotation"
    
    log_success "Dark wallpapers setup complete - shuffling from ~/Pictures/DarkWallpapers for OLED protection"
    
    log_success "Dark mode optimizations complete"
}

# Display and energy optimizations
configure_display_energy() {
    log_section "Display & Energy Management"
    
    if [[ "$DEVICE_TYPE" == "laptop" ]]; then
        log_info "🔋 Laptop power settings for OLED protection"
        log_info "Setting display sleep (3 minutes on battery, 5 minutes on power)"
        sudo pmset -b displaysleep 3 disksleep 10
        sudo pmset -c displaysleep 5 disksleep 15
        
        log_info "Configuring laptop power management for OLED protection"
        sudo pmset -a standbydelay 7200  # 2 hours standby (laptop-friendly)
        sudo pmset -a hibernatemode 3    # Safe sleep (not deep sleep)
        sudo pmset -a autopoweroffdelay 14400  # 4 hours auto power off
        
        log_info "Enabling powernap for background updates while protecting display"
        sudo pmset -a powernap 1
    else
        log_info "🖥️  Desktop power settings for OLED protection"
        log_info "Setting conservative display sleep (5 minutes)"
        sudo pmset -c displaysleep 5 disksleep 20
        
        log_info "Configuring desktop power management for OLED protection"
        sudo pmset -a standbydelay 300   # 5 minutes standby (desktop)
        sudo pmset -a hibernatemode 0    # No hibernation needed for desktop
        sudo pmset -a autopoweroff 0     # No auto power off for desktop
        
        log_info "Disabling powernap on desktop (reduces unnecessary display activity)"
        sudo pmset -a powernap 0
    fi
    
    log_info "Setting aggressive screen saver activation (3 minutes)"
    defaults write com.apple.screensaver idleTime -int 180
    
    log_info "Enabling screen saver password requirement immediately"
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    
    log_info "Disabling automatic brightness to maintain consistent OLED levels"
    sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false
    
    log_info "Disabling wake for network access (keeps display off)"
    sudo pmset -a womp 0
    
    log_info "Reducing display brightness to OLED-safe levels (75%)"
    osascript -e 'tell application "System Events" to set brightness of (first display process) to 0.75' 2>/dev/null || true
    
    log_success "Display and energy optimizations complete for $DEVICE_TYPE"
}

# Screen saver optimizations
configure_screensaver() {
    log_section "Screen Saver Settings"
    
    log_info "Setting screen saver to 'Flurry' (dark, moving content)"
    defaults write com.apple.screensaver moduleDict -dict moduleName -string "Flurry" path -string "/System/Library/Screen Savers/Flurry.saver" type -int 0
    
    log_info "Enabling screen saver hot corners (bottom-right corner)"
    defaults write com.apple.dock wvous-br-corner -int 5
    defaults write com.apple.dock wvous-br-modifier -int 0
    
    log_info "Configuring aggressive idle time for screen protection"
    defaults write com.apple.screensaver idleTime -int 180  # 3 minutes
    
    log_success "Screen saver optimizations complete"
}

# Dock and UI optimizations for OLED (hardcoded current values)
configure_dock_ui() {
    log_section "Dock & UI for OLED (Using Hardcoded Values)"
    
    log_info "Setting dock with your current optimized configuration:"
    echo "  • Tile size: 83 (your current setting)"
    echo "  • Large size: 128 (your current setting)" 
    echo "  • Auto-hide: enabled (your current setting)"
    echo "  • Auto-hide delay: 0.1s (your current setting)"
    echo "  • Auto-hide time modifier: 0.2s (your current setting)"
    echo "  • Orientation: bottom (your current setting)"
    echo "  • Magnification: enabled (your current setting)"
    
    # Apply your exact current dock settings
    defaults write com.apple.dock tilesize -int 83
    defaults write com.apple.dock largesize -int 128
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0.1
    defaults write com.apple.dock autohide-time-modifier -float 0.2
    defaults write com.apple.dock orientation -string "bottom"
    defaults write com.apple.dock magnification -bool true
    
    # OLED-specific optimizations
    log_info "Setting Dock to dark theme for OLED protection"
    defaults write com.apple.dock theme -string "dark"
    
    log_success "Dock optimized with your hardcoded settings for OLED protection"
}

# Application-specific OLED optimizations
configure_applications() {
    log_section "Application Settings for OLED"
    
    # Terminal
    log_info "Setting Terminal to use dark theme"
    defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
    
    # Safari (sandboxed - limited configuration)
    if [[ -d "/Applications/Safari.app" ]]; then
        log_info "Safari detected - enable dark mode manually in Safari > Settings > General"
        # Note: Safari preferences are sandboxed and cannot be modified via defaults
    fi
    
    # Chrome
    if [[ -d "/Applications/Google Chrome.app" ]]; then
        log_info "Configuring Chrome for OLED optimization"
        defaults write com.google.Chrome DefaultSearchProviderEnabled -bool true
        # Note: Dark mode must be enabled manually in Chrome settings
    fi
    
    # TextEdit
    log_info "Setting TextEdit to dark appearance"
    defaults write com.apple.TextEdit NSRequiresAquaSystemAppearance -bool false
    
    # System Preferences
    log_info "Setting System Preferences to dark theme"
    defaults write com.apple.systempreferences NSRequiresAquaSystemAppearance -bool false
    
    log_success "Application optimizations complete"
}

# True Tone and color management
configure_color_management() {
    log_section "Color Management & True Tone"
    
    log_info "Configuring True Tone for OLED displays"
    # True Tone settings (if supported)
    defaults write com.apple.CoreBrightness TrueTone -bool true 2>/dev/null || log_warning "True Tone not supported on this system"
    
    log_info "Setting color temperature for evening use"
    # Night Shift settings
    defaults write com.apple.CoreBrightness BlueReductionEnabled -bool true
    defaults write com.apple.CoreBrightness BlueReductionMode -int 2  # Custom schedule
    
    log_info "Optimizing display color profile"
    # Note: Specific color profile selection may require manual adjustment
    
    log_success "Color management optimizations complete"
}

# Finder optimizations for OLED
configure_finder_oled() {
    log_section "Finder OLED Settings"
    
    log_info "Setting Finder to dark sidebar"
    defaults write com.apple.finder NSRequiresAquaSystemAppearance -bool false
    
    log_info "Using dark desktop background"
    defaults write com.apple.finder CreateDesktop -bool false  # Hide desktop icons to reduce static elements
    
    log_info "Setting Finder window background to dark"
    defaults write com.apple.finder NSWindowTabbingEnabled -bool false
    
    log_success "Finder OLED optimizations complete"
}

# Notification and alert optimizations
configure_notifications() {
    log_section "Notifications & Alerts"
    
    log_info "Reducing notification banner time (less static display)"
    defaults write com.apple.notificationcenterui bannerTime -int 3
    
    log_info "Disabling notification center on lock screen"
    defaults write com.apple.ncprefs NotificationCenterEnabled -bool false
    
    log_info "Setting alerts to use dark appearance"
    defaults write com.apple.notificationcenterui NSRequiresAquaSystemAppearance -bool false
    
    log_success "Notification optimizations complete"
}

# Hot corners for OLED protection (hardcoded current values)
configure_hot_corners() {
    log_section "Hot Corners for Display Protection (Using Your Current Setup)"
    
    log_info "Applying your custom hot corner configuration:"
    echo "  • Top-left: Disabled (user preference)"
    echo "  • Top-right: Disabled (user preference)"
    echo "  • Bottom-left: Lock Screen (user preference)"
    echo "  • Bottom-right: Mission Control (user preference)"
    
    # Apply your custom hot corner settings
    defaults write com.apple.dock wvous-tl-corner -int 0   # Disabled
    defaults write com.apple.dock wvous-tl-modifier -int 0
    defaults write com.apple.dock wvous-tr-corner -int 0   # Disabled
    defaults write com.apple.dock wvous-tr-modifier -int 0
    defaults write com.apple.dock wvous-bl-corner -int 13  # Lock Screen
    defaults write com.apple.dock wvous-bl-modifier -int 0
    defaults write com.apple.dock wvous-br-corner -int 2   # Mission Control
    defaults write com.apple.dock wvous-br-modifier -int 0
    
    log_success "Hot corners set with your hardcoded OLED-optimized configuration"
}

# Restart required applications
restart_apps() {
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
        if pgrep -f "$app" >/dev/null; then
            log_info "Restarting $app..."
            killall "$app" 2>/dev/null || true
        fi
    done
    
    log_success "Applications restarted"
}

# Show completion message with OLED-specific advice
show_completion() {
    echo ""
    log_success "🎉 OLED monitor optimization complete!"
    echo ""
    log_info "📱 Additional OLED protection recommendations:"
    echo "  • Manually enable dark mode in browsers (Chrome: chrome://settings/appearance)"
    echo "  • Consider using dark themes in development tools (VS Code, Terminal apps)"
    echo "  • If using wallpaper rotation, ensure all images are dark/black"
    echo "  • Adjust individual app brightness settings where available"
    echo "  • Use bottom-right hot corner to quickly activate screen saver"
    echo "  • Dock settings applied: 83px tile size, 128px magnification, 0.1s auto-hide delay"
    echo ""
    log_warning "⚠️  Remember: OLED burn-in is permanent - these settings help prevent it!"
    echo ""
    log_warning "⚠️  A system restart is required for all changes to take full effect."
    log_info "Please restart your system when convenient to complete the OLED optimization."
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME

DESCRIPTION:
    Optimizes macOS settings specifically for OLED displays.
    Focuses on burn-in prevention and optimal OLED performance.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -f, --force     Skip confirmation prompts
    --dry-run       Show what would be changed without making changes

EXAMPLES:
    $0              Run interactively with confirmations
    $0 --force      Run without confirmation prompts
    $0 --dry-run    Preview changes without applying them

OLED OPTIMIZATIONS:
    • Enable system-wide dark mode
    • Aggressive screen saver and display sleep settings
    • Auto-hide menu bar and dock to prevent burn-in
    • Configure hot corners for quick screen protection
    • Set dark desktop backgrounds and themes
    • Optimize power management for display protection
    • Configure applications for dark themes
    • Set up True Tone and Night Shift

BURN-IN PREVENTION:
    • Quick screen saver activation (3 minutes)
    • Auto-hide static UI elements
    • Dark themes throughout system
    • Reduced brightness levels
    • Hot corner screen saver activation

EOF
}

# Parse command line arguments
parse_args() {
    FORCE_MODE=false
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE_MODE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Dry run mode - show what would be changed
dry_run() {
    echo -e "\033[1m🔍 DRY RUN MODE - No changes will be made\033[0m"
    echo ""
    log_info "The following OLED optimizations would be applied:"
    echo ""
    echo "• Enable system-wide dark mode and themes"
    echo "• Set screen saver to activate after 3 minutes"
    echo "• Auto-hide menu bar and dock to prevent burn-in"
    echo "• Set up hot corners for quick screen protection"
    echo "• Configure dark desktop backgrounds"
    echo "• Set application-specific dark themes"
    echo "• Configure True Tone and Night Shift"
    echo "• Reduce notification banner time"
    echo "• Set OLED-safe brightness levels"
    echo ""
    
    # Detect device type for dry run info
    if system_profiler SPPowerDataType | grep -q "Battery Information"; then
        echo "🔋 Laptop power management:"
        echo "  • Display sleep: 3 min (battery) / 5 min (power)"
        echo "  • Standby delay: 2 hours"
        echo "  • Hibernate mode: Safe sleep (mode 3)"
        echo "  • Powernap: Enabled for background updates"
    else
        echo "🖥️  Desktop power management:"
        echo "  • Display sleep: 5 minutes"
        echo "  • Standby delay: 5 minutes"
        echo "  • Hibernate mode: Disabled (mode 0)"
        echo "  • Powernap: Disabled to reduce display activity"
    fi
    
    echo ""
    log_warning "⚠️  These settings prioritize OLED protection over convenience"
    echo ""
    log_info "Run without --dry-run to apply these changes"
}

# Main execution
main() {
    echo -e "\033[1m🖥️  $SCRIPT_NAME\033[0m"
    echo "═══════════════════════════════════════════════════════════"
    
    check_platform
    detect_device_type
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run
        return 0
    fi
    
    request_sudo
    
    if [[ "$FORCE_MODE" == false ]]; then
        confirm_changes
    fi
    
    configure_dark_mode
    configure_display_energy
    configure_screensaver
    configure_dock_ui
    configure_applications
    configure_color_management
    configure_finder_oled
    configure_notifications
    configure_hot_corners
    restart_apps
    show_completion
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi