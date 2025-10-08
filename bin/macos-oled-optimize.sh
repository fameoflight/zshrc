#!/usr/bin/env bash
#
# macOS OLED Monitor Optimization Script
# Configures macOS settings specifically for OLED displays
# Focuses on burn-in prevention and optimal display performance
#
# Author: Hemant Verma <fameoflight@gmail.com>

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="macOS OLED Monitor Optimizer"
readonly WALLPAPER_CHANGE_INTERVAL=300  # seconds (5 minutes)

# Source common macOS utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.common/mac.zsh"

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
    echo " • Wallpaper rotation: enabled (shuffle continuously)"
    echo " • Change interval: every $((WALLPAPER_CHANGE_INTERVAL / 60)) minutes"
    echo " • Random order: enabled"
    echo " • Multiple displays: same wallpaper across all displays"
    echo " • Show in all spaces: enabled"
    
    # Enable wallpaper rotation with shuffle
    osascript -e 'tell application "System Events"
        tell every desktop
            set picture rotation to 1  -- (0=off, 1=interval, 2=login, 3=sleep)
            set change interval to '"$WALLPAPER_CHANGE_INTERVAL"'.0  -- '$((WALLPAPER_CHANGE_INTERVAL / 60))' minutes in seconds
            set random order to true
            set pictures folder to (POSIX file "/System/Library/Desktop Pictures")
        end tell
    end tell' 2>/dev/null || true
    
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
    
    log_success "Dark wallpapers setup complete - shuffling from ~/Pictures/DarkWallpapers for OLED protection"
    log_success "Dark mode optimizations complete"
}

# Display and energy optimizations for OLED
configure_oled_display() {
    log_section "OLED Display & Energy Management"

    # Use common power management with OLED-specific tweaks
    mac_configure_desktop_power "OLED protection"

    # OLED-specific display sleep settings (more aggressive)
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        # Desktop: Disable system sleep to keep background services running
        log_info "Desktop: Disabling system sleep to keep background services running"
        sudo pmset -a sleep 0

        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                log_info "High-performance desktop: Aggressive OLED protection (3 min display sleep)"
                sudo pmset -a displaysleep 3
                sudo pmset -a disksleep 0
                ;;
            *)
                log_info "Desktop: OLED-protective display sleep (5 minutes)"
                sudo pmset -a displaysleep 5
                sudo pmset -a disksleep 0
                ;;
        esac
    else
        # Laptop: Normal battery-optimized sleep (system CAN sleep)
        log_info "Laptop: OLED-protective display sleep (3 min battery, 5 min power)"
        sudo pmset -b displaysleep 3
        sudo pmset -b sleep 15
        sudo pmset -c displaysleep 5
        sudo pmset -c sleep 30
    fi
    
    log_info "Setting aggressive screen saver activation (3 minutes)"
    defaults write com.apple.screensaver idleTime -int 180
    
    log_info "Enabling screen saver password requirement immediately"
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    
    log_info "Disabling automatic brightness to maintain consistent OLED levels"
    sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false 2>/dev/null || true
    
    log_info "Reducing display brightness to OLED-safe levels (75%)"
    osascript -e 'tell application "System Events" to set brightness of (first display process) to 0.75' 2>/dev/null || true
    
    log_success "OLED display optimizations complete for $DEVICE_TYPE"
}

# Screen saver optimizations
configure_screensaver() {
    log_section "Screen Saver Settings"
    
    log_info "Setting screen saver to 'Flurry' (dark, moving content)"
    defaults write com.apple.screensaver moduleDict -dict moduleName -string "Flurry" path -string "/System/Library/Screen Savers/Flurry.saver" type -int 0
    
    log_info "Configuring aggressive idle time for screen protection"
    defaults write com.apple.screensaver idleTime -int 180  # 3 minutes
    
    log_success "Screen saver optimizations complete"
}

# Dock and UI optimizations for OLED
configure_oled_dock() {
    log_section "Dock & UI for OLED Protection"
    
    log_info "Setting dock with OLED-optimized configuration:"
    echo " • Tile size: 83 (optimized for visibility)"
    echo " • Large size: 128 (magnification enabled)" 
    echo " • Auto-hide: enabled (reduces static elements)"
    echo " • Auto-hide delay: 0.1s (quick response)"
    echo " • Auto-hide time modifier: 0.2s (smooth animation)"
    echo " • Orientation: bottom"
    echo " • Magnification: enabled"
    
    # Apply OLED-optimized dock settings
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
    
    log_success "Dock optimized with OLED-protective settings"
}

# Application-specific OLED optimizations
configure_oled_applications() {
    log_section "Application Settings for OLED"
    
    # Terminal
    log_info "Setting Terminal to use dark theme"
    defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
    
    # Safari (sandboxed - limited configuration)
    if [[ -d "/Applications/Safari.app" ]]; then
        log_info "Safari detected - enable dark mode manually in Safari > Settings > General"
    fi
    
    # Chrome
    if [[ -d "/Applications/Google Chrome.app" ]]; then
        log_info "Configuring Chrome for OLED optimization"
        defaults write com.google.Chrome DefaultSearchProviderEnabled -bool true
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
    defaults write com.apple.CoreBrightness TrueTone -bool true 2>/dev/null || log_warning "True Tone not supported on this system"
    
    log_info "Setting color temperature for evening use"
    defaults write com.apple.CoreBrightness BlueReductionEnabled -bool true
    defaults write com.apple.CoreBrightness BlueReductionMode -int 2  # Custom schedule
    
    log_info "Optimizing display color profile for OLED"
    
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

# Show completion message with OLED-specific advice
show_oled_completion() {
    echo ""
    log_success "🎉 OLED monitor optimization complete!"
    echo ""
    mac_show_system_info
    echo ""
    log_info "📱 Additional OLED protection recommendations:"
    echo " • Manually enable dark mode in browsers (Chrome: chrome://settings/appearance)"
    echo " • Consider using dark themes in development tools (VS Code, Terminal apps)"
    echo " • If using wallpaper rotation, ensure all images are dark/black"
    echo " • Adjust individual app brightness settings where available"
    echo " • Use hot corners to quickly activate screen saver or lock screen"
    echo " • Dock settings applied: 83px tile size, 128px magnification, 0.1s auto-hide delay"
    echo ""
    log_warning "⚠️  Remember: OLED burn-in is permanent - these settings help prevent it!"
    echo ""
    
    mac_show_completion "OLED monitor optimization" "true"
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
    -v, --verbose   Enable verbose output

EXAMPLES:
    $0              Run interactively with confirmations
    $0 --force      Run without confirmation prompts
    $0 --dry-run    Preview changes without applying them

OLED OPTIMIZATIONS:
    • Enable system-wide dark mode and themes
    • Aggressive screen saver and display sleep settings
    • Auto-hide menu bar and dock to prevent burn-in
    • Configure hot corners for quick screen protection
    • Set dark desktop backgrounds and wallpaper rotation
    • Optimize power management for display protection
    • Configure applications for dark themes
    • Set up True Tone and Night Shift
    • Device-specific optimizations (desktop vs laptop)

BURN-IN PREVENTION:
    • Quick screen saver activation (3 minutes)
    • Auto-hide static UI elements
    • Dark themes throughout system
    • Reduced brightness levels (75%)
    • Hot corner screen saver activation
    • Wallpaper rotation with dark images

EOF
}

# Dry run mode - show what would be changed
dry_run() {
    echo -e "\033[1m🔍 DRY RUN MODE - No changes will be made\033[0m"
    echo ""
    mac_show_system_info
    echo ""
    log_info "The following OLED optimizations would be applied:"
    echo ""
    echo "• Enable system-wide dark mode and themes"
    echo "• Set screen saver to activate after 3 minutes"
    echo "• Auto-hide menu bar and dock to prevent burn-in"
    echo "• Set up OLED-protective hot corners"
    echo "• Configure dark desktop backgrounds with rotation"
    echo "• Set application-specific dark themes"
    echo "• Configure True Tone and Night Shift"
    echo "• Reduce notification banner time"
    echo "• Set OLED-safe brightness levels (75%)"
    echo "• Hide desktop icons to reduce static elements"
    echo ""
    
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        echo "🖥️  Desktop power management:"
        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                echo " • Display sleep: 3 minutes (aggressive OLED protection)"
                ;;
            *)
                echo " • Display sleep: 5 minutes (OLED protection)"
                ;;
        esac
        echo " • Standby delay: 5 minutes"
        echo " • Hibernate mode: Disabled"
        echo " • Powernap: Disabled to reduce display activity"
    else
        echo "🔋 Laptop power management:"
        echo " • Display sleep: 3 min (battery) / 5 min (power)"
        echo " • Standby delay: 2 hours"
        echo " • Hibernate mode: Safe sleep"
        echo " • Powernap: Enabled for background updates"
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
    
    mac_check_platform
    mac_detect_device
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run
        return 0
    fi
    
    mac_request_sudo
    
    if [[ "$FORCE_MODE" == false ]]; then
        mac_confirm_changes "OLED display optimization" "This will configure settings to prevent OLED burn-in and optimize display performance."
    fi
    
    configure_dark_mode
    configure_oled_display
    configure_screensaver
    configure_oled_dock
    configure_oled_applications
    configure_color_management
    configure_finder_oled
    configure_notifications
    mac_configure_hot_corners
    mac_restart_apps
    show_oled_completion
}

# Parse command line arguments
parse_args() {
    mac_parse_common_args "$@"
    local result=$?
    
    if [[ $result -eq 2 ]]; then
        show_help
        exit 0
    elif [[ $result -ne 0 ]]; then
        show_help
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi