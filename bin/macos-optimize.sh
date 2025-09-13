#!/usr/bin/env bash
#
# macOS System Optimization Script
# Configures macOS settings for developers and power users
#
# Original sources:
# - https://github.com/mathiasbynens/dotfiles/blob/master/.macos  
# - https://gist.github.com/brandonb927/3195465
#
# Updated and modernized by Hemant Verma

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="macOS System Optimizer"

# Source common macOS utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.common/mac.zsh"

# General UI/UX optimizations
configure_ui_ux() {
    log_section "General UI/UX"
    
    log_info "Disabling Gatekeeper (allows installation of apps from anywhere)"
    sudo spctl --master-disable
    
    log_info "Increasing window resize speed for Cocoa applications"
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    
    log_info "Expanding save panel by default"
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    
    log_info "Expanding print panel by default"
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
    
    log_info "Automatically quitting printer app once print jobs complete"
    defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
    
    log_info "Disabling system-wide resume"
    defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
    
    log_info "Saving to disk (not to iCloud) by default"
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    
    log_info "Disabling automatic termination of inactive apps"
    defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
    
    log_info "Revealing IP address, hostname, OS version when clicking clock in login window"
    sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
    
    log_info "Disabling smart quotes and dashes (better for coding)"
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
    
    log_success "UI/UX optimizations complete"
}

# Keyboard and trackpad optimizations
configure_input() {
    log_section "Keyboard & Trackpad"
    
    log_info "Enabling full keyboard access for all controls"
    defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
    
    log_info "Disabling press-and-hold for keys in favor of key repeat"
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    
    log_info "Setting fast keyboard repeat rate"
    defaults write NSGlobalDomain KeyRepeat -int 1
    defaults write NSGlobalDomain InitialKeyRepeat -int 10
    
    log_info "Setting trackpad and mouse speed"
    defaults write -g com.apple.trackpad.scaling 2
    defaults write -g com.apple.mouse.scaling 2.5
    
    log_info "Enabling tap to click for trackpad"
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    
    log_info "Increasing sound quality for Bluetooth audio devices"
    defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
    
    log_success "Input device optimizations complete"
}

# Screen and display optimizations
configure_display() {
    log_section "Display & Screen"
    
    log_info "Requiring password immediately after sleep or screen saver"
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    
    log_info "Enabling subpixel font rendering on non-Apple LCDs"
    defaults write NSGlobalDomain AppleFontSmoothing -int 1
    
    log_info "Enabling HiDPI display modes (requires restart)"
    sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
    
    log_success "Display optimizations complete"
}

# Finder optimizations
configure_finder() {
    log_section "Finder"
    
    log_info "Showing all filename extensions"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    
    log_info "Showing status bar"
    defaults write com.apple.finder ShowStatusBar -bool true
    
    log_info "Showing path bar"
    defaults write com.apple.finder ShowPathbar -bool true
    
    log_info "Displaying full POSIX path as window title"
    defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
    
    log_info "Keeping folders on top when sorting by name"
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    
    log_info "Disabling warning when changing file extensions"
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    
    log_info "Enabling spring loading for directories"
    defaults write NSGlobalDomain com.apple.springing.enabled -bool true
    defaults write NSGlobalDomain com.apple.springing.delay -float 0
    
    log_info "Avoiding creation of .DS_Store files on network and USB volumes"
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
    
    log_info "Disabling disk image verification"
    defaults write com.apple.frameworks.diskimages skip-verify -bool true
    defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
    defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
    
    log_info "Automatically opening new window for external drives"
    defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
    defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
    defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true
    
    log_info "Using list view in all Finder windows by default"
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    
    log_info "Disabling warning before emptying Trash"
    defaults write com.apple.finder WarnOnEmptyTrash -bool false
    
    log_info "Showing hard drives, servers, and removable media on desktop"
    defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
    defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
    defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
    
    log_success "Finder optimizations complete"
}

# Dock optimizations
configure_dock() {
    log_section "Dock & Mission Control"
    
    # Use device-specific dock settings
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                log_info "High-performance desktop: Larger dock size for better visibility"
                defaults write com.apple.dock tilesize -int 64
                ;;
            *"iMac"*)
                log_info "iMac: Medium dock size optimized for built-in display"
                defaults write com.apple.dock tilesize -int 56
                ;;
            *)
                log_info "Desktop: Standard dock size"
                defaults write com.apple.dock tilesize -int 48
                ;;
        esac
        
        log_info "Desktop: Disabling auto-hide for productivity"
        defaults write com.apple.dock autohide -bool false
    else
        log_info "Laptop: Smaller dock size for screen real estate"
        defaults write com.apple.dock tilesize -int 42
        
        log_info "Laptop: Enabling auto-hide to save screen space"
        defaults write com.apple.dock autohide -bool true
        defaults write com.apple.dock autohide-delay -float 0
        defaults write com.apple.dock autohide-time-modifier -float 0
    fi
    
    log_info "Minimizing windows into their application's icon"
    defaults write com.apple.dock minimize-to-application -bool true
    
    log_info "Enabling spring loading for all Dock items"
    defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
    
    log_info "Showing indicator lights for open applications"
    defaults write com.apple.dock show-process-indicators -bool true
    
    log_info "Don't animate opening applications from Dock"
    defaults write com.apple.dock launchanim -bool false
    
    log_info "Speeding up Mission Control animations"
    defaults write com.apple.dock expose-animation-duration -float 0.1
    defaults write com.apple.dock "expose-group-by-app" -bool true
    
    log_info "Disabling Dashboard"
    defaults write com.apple.dashboard mcx-disabled -bool true
    
    log_info "Don't show Dashboard as a Space"
    defaults write com.apple.dock dashboard-in-overlay -bool true
    
    log_info "Making Dock icons of hidden applications translucent"
    defaults write com.apple.dock showhidden -bool true
    
    log_success "Dock optimizations complete for $DEVICE_TYPE"
}

# Security and privacy optimizations
configure_security() {
    log_section "Security & Privacy"
    
    log_info "Enabling firewall"
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    
    log_info "Disabling remote apple events"
    sudo systemsetup -setremoteappleevents off 2>/dev/null || true
    
    log_info "Disabling remote login"
    sudo systemsetup -setremotelogin off 2>/dev/null || true
    
    log_info "Disabling wake-on-lan"
    sudo systemsetup -setwakeonnetworkaccess off 2>/dev/null || true
    
    log_success "Security optimizations complete"
}

# Performance optimizations with device-aware settings
configure_performance() {
    log_section "Performance"
    
    # Use common power management
    mac_configure_desktop_power "performance"
    
    log_info "Disabling local Time Machine snapshots"
    sudo tmutil disablelocal 2>/dev/null || true
    
    log_info "Preventing Time Machine from prompting for new disks"
    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
    
    # Device-specific performance tweaks
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                log_info "High-performance desktop: Extended sleep delays for heavy workloads"
                sudo pmset -a standbydelay 86400  # 24 hours
                ;;
            *)
                log_info "Desktop: Standard performance settings"
                ;;
        esac
    fi
    
    log_success "Performance optimizations complete"
}

# Developer-specific optimizations
configure_developer() {
    log_section "Developer Settings"
    
    log_info "Showing hidden files in Finder"
    defaults write com.apple.finder AppleShowAllFiles -bool true
    
    log_info "Enabling locate database"
    sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist 2>/dev/null || true
    
    log_info "Disabling Spotlight indexing for /Volumes"
    sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes" 2>/dev/null || true
    
    log_success "Developer optimizations complete"
}

# App-specific optimizations
configure_apps() {
    log_section "Application Settings"
    
    # Chrome
    if [[ -d "/Applications/Google Chrome.app" ]]; then
        log_info "Disabling backswipe navigation in Chrome"
        defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false
        defaults write com.google.Chrome.canary AppleEnableSwipeNavigateWithScrolls -bool false
    fi
    
    # TextEdit
    log_info "Using plain text mode for new TextEdit documents"
    defaults write com.apple.TextEdit RichText -int 0
    defaults write com.apple.TextEdit PlainTextEncoding -int 4
    defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
    
    # Disk Utility
    log_info "Enabling Debug menu in Disk Utility"
    defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
    defaults write com.apple.DiskUtility advanced-image-options -bool true
    
    log_success "Application optimizations complete"
}

# Show completion message
show_macos_completion() {
    echo ""
    log_success "🎉 macOS system optimization complete!"
    echo ""
    mac_show_system_info
    echo ""
    log_info "📋 Applied optimizations:"
    echo "  • UI/UX improvements (faster animations, better defaults)"
    echo "  • Keyboard and trackpad optimizations"
    echo "  • Display and screen settings"
    echo "  • Finder enhancements (show extensions, hidden files)"
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        echo "  • Desktop-optimized Dock settings (larger size, always visible)"
        echo "  • Desktop-optimized power management"
    else
        echo "  • Laptop-optimized Dock settings (smaller size, auto-hide)"
        echo "  • Laptop-optimized power management"
    fi
    echo "  • Security improvements (firewall, disable remote access)"
    echo "  • Performance tweaks (SSD optimization, power management)"
    echo "  • Developer settings (hidden files, locate database)"
    echo "  • Application-specific optimizations"
    echo "  • Productivity-focused hot corners"
    echo ""
    
    mac_show_completion "macOS system optimization" "true"
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME

DESCRIPTION:
    Optimizes macOS settings for developers and power users.
    Includes UI/UX improvements, performance tweaks, and developer-friendly settings.

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

WHAT IT DOES:
    • Optimizes UI/UX settings (faster animations, better defaults)
    • Configures Finder for power users (show extensions, hidden files)
    • Sets up developer-friendly settings (fast key repeat, etc.)
    • Improves performance (device-specific power management)
    • Enhances security settings (firewall, disable remote access)
    • Optimizes Dock and Mission Control (device-aware sizing)
    • Device-specific optimizations (desktop vs laptop)

DEVICE-SPECIFIC FEATURES:
    Desktop optimizations:
    • Larger Dock icons for better visibility
    • Dock always visible for productivity
    • Extended sleep delays for heavy workloads
    • Optimized power management for always-on usage
    
    Laptop optimizations:
    • Smaller Dock icons to save screen space
    • Auto-hiding Dock for maximum screen real estate
    • Battery-optimized power management
    • Balanced performance and battery life

EOF
}

# Dry run mode - show what would be changed
dry_run() {
    echo -e "\033[1m🔍 DRY RUN MODE - No changes will be made\033[0m"
    echo ""
    mac_show_system_info
    echo ""
    log_info "The following optimizations would be applied:"
    echo ""
    echo "• General UI/UX improvements (faster animations, better defaults)"
    echo "• Keyboard and trackpad optimizations (fast repeat, tap to click)"  
    echo "• Display settings (require password after sleep, better fonts)"
    echo "• Finder enhancements (show extensions, status bar, path bar)"
    echo "• Security improvements (enable firewall, disable remote access)"
    echo "• Performance tweaks (disable motion sensor, optimize sleep)"
    echo "• Developer settings (show hidden files, enable locate database)"
    echo "• Application-specific optimizations (Chrome, TextEdit, etc.)"
    echo ""
    
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        echo "🖥️  Desktop-specific optimizations:"
        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                echo "  • Large Dock icons (64px) for high-performance workstation"
                echo "  • Extended sleep delays (24 hours) for heavy workloads"
                ;;
            *"iMac"*)
                echo "  • Medium Dock icons (56px) optimized for built-in display"
                ;;
            *)
                echo "  • Standard Dock icons (48px)"
                ;;
        esac
        echo "  • Dock always visible for productivity"
        echo "  • Desktop power management (no hibernation, extended standby)"
        echo "  • Productivity-focused hot corners"
    else
        echo "🔋 Laptop-specific optimizations:"
        echo "  • Smaller Dock icons (42px) to save screen space"
        echo "  • Auto-hiding Dock for maximum screen real estate"
        echo "  • Battery-optimized power management"
        echo "  • Balanced performance and battery life"
    fi
    
    echo ""
    log_info "Run without --dry-run to apply these changes"
}

# Main execution
main() {
    echo -e "\033[1m🍎 $SCRIPT_NAME\033[0m"
    echo "═══════════════════════════════════════════════════════════"
    
    mac_check_platform
    mac_detect_device
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run
        return 0
    fi
    
    mac_request_sudo
    
    if [[ "$FORCE_MODE" == false ]]; then
        mac_confirm_changes "macOS system optimization" "This will apply developer and power user optimizations to your system."
    fi
    
    configure_ui_ux
    configure_input
    configure_display
    configure_finder
    configure_dock
    configure_security
    configure_performance
    configure_developer
    configure_apps
    mac_configure_hot_corners
    mac_restart_apps
    show_macos_completion
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