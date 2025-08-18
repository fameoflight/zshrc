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
readonly SCRIPT_NAME="macOS Optimizer"
readonly MIN_MACOS_VERSION=10

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
        echo -e "\033[1m🔧 $1\033[0m"
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
    log_warn "This script will modify your macOS system preferences."
    log_warn "Some changes require a restart to take effect."
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

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
    
    log_info "Setting Dock icon size"
    defaults write com.apple.dock tilesize -int 48
    
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
    
    log_info "Automatically hiding and showing Dock"
    defaults write com.apple.dock autohide -bool true
    
    log_info "Removing auto-hiding Dock delay"
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0
    
    log_info "Making Dock icons of hidden applications translucent"
    defaults write com.apple.dock showhidden -bool true
    
    log_success "Dock optimizations complete"
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

# Performance optimizations  
configure_performance() {
    log_section "Performance"
    
    log_info "Disabling sudden motion sensor (not needed for SSDs)"
    sudo pmset -a sms 0
    
    log_info "Increasing sleep delay to 24 hours"
    sudo pmset -a standbydelay 86400
    
    log_info "Disabling local Time Machine snapshots"
    sudo tmutil disablelocal 2>/dev/null || true
    
    log_info "Preventing Time Machine from prompting for new disks"
    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
    
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

# Restart required applications
restart_apps() {
    log_section "Restarting Applications"
    
    local apps_to_restart=(
        "Dock"
        "Finder"
        "SystemUIServer"
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

# Show completion message
show_completion() {
    echo ""
    log_success "🎉 macOS optimization complete!"
    echo ""
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

EXAMPLES:
    $0              Run interactively with confirmations
    $0 --force      Run without confirmation prompts
    $0 --dry-run    Preview changes without applying them

WHAT IT DOES:
    • Optimizes UI/UX settings (faster animations, better defaults)
    • Configures Finder for power users (show extensions, hidden files)
    • Sets up developer-friendly settings (fast key repeat, etc.)
    • Improves performance (disables unnecessary features)
    • Enhances security settings
    • Optimizes Dock and Mission Control

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
    echo -e "${BOLD}🔍 DRY RUN MODE - No changes will be made${NC}"
    echo ""
    log_info "The following optimizations would be applied:"
    echo ""
    echo "• General UI/UX improvements (faster animations, better defaults)"
    echo "• Keyboard and trackpad optimizations (fast repeat, tap to click)"  
    echo "• Display settings (require password after sleep, better fonts)"
    echo "• Finder enhancements (show extensions, status bar, path bar)"
    echo "• Dock optimizations (auto-hide, faster animations)"
    echo "• Security improvements (enable firewall, disable remote access)"
    echo "• Performance tweaks (disable motion sensor, optimize sleep)"
    echo "• Developer settings (show hidden files, enable locate database)"
    echo "• Application-specific optimizations (Chrome, TextEdit, etc.)"
    echo ""
    log_info "Run without --dry-run to apply these changes"
}

# Main execution
main() {
    echo -e "${BOLD}🍎 $SCRIPT_NAME${NC}"
    echo "═══════════════════════════════════════════════════════════"
    
    check_platform
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run
        return 0
    fi
    
    request_sudo
    
    if [[ "$FORCE_MODE" == false ]]; then
        confirm_changes
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
    restart_apps
    show_completion
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi