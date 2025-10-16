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
    if sudo spctl --master-disable 2>/dev/null; then
        log_success "Gatekeeper disabled"
    else
        log_warning "Could not disable Gatekeeper automatically"
        log_info "To disable manually: System Settings → Privacy & Security → Allow apps downloaded from: Anywhere"
    fi
    
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
    
    log_info "Setting comfortable keyboard repeat rate"
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 25
    
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

    log_info "Reducing window corner radius for sharper appearance"
    defaults write com.apple.Dock windowCornerRadius -int 4

    # Clean up unwanted dock items
    log_info "Removing unwanted applications from dock"
    if command -v dockutil >/dev/null 2>&1; then
        # Remove specific unwanted applications
        dockutil --remove "Notes" 2>/dev/null || true
        dockutil --remove "Reminders" 2>/dev/null || true
        dockutil --remove "Finder" 2>/dev/null || true
        dockutil --remove "Mail" 2>/dev/null || true
        dockutil --remove "Preview" 2>/dev/null || true
        log_success "Cleaned up dock applications"
    else
        log_warning "dockutil not available - install with 'brew install dockutil' to clean dock"
    fi

    # Clear recent apps from dock
    log_info "Clearing recent applications from dock"
    defaults write com.apple.dock recent-apps -array

    log_success "Dock optimizations complete for $DEVICE_TYPE"
}

# Menu bar optimizations
configure_menubar() {
    log_section "Menu Bar"

    log_info "Hiding keyboard/input source icon from menu bar"
    defaults write com.apple.menuextra.textinput ModeNameVisible -bool false
    defaults write com.apple.TextInputMenuAgent NSUIElement -bool true
    launchctl unload -w /System/Library/LaunchAgents/com.apple.TextInputMenuAgent.plist 2>/dev/null || true
    killall TextInputMenuAgent 2>/dev/null || true

    log_info "Hiding Spotlight search icon from menu bar"
    defaults write com.apple.Spotlight MenuItemHidden -int 1

    log_info "Hiding Apple Intelligence/Siri icon from menu bar"
    defaults write com.apple.Siri StatusMenuVisible -bool false
    defaults write com.apple.assistant.support "Assistant Enabled" -bool false
    defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false

    log_success "Menu bar optimizations complete"
}

# Security and privacy optimizations
configure_security() {
    log_section "Security & Privacy"

    log_info "Enabling firewall"
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

    log_info "Disabling remote apple events"
    sudo systemsetup -setremoteappleevents off 2>/dev/null || true

  
    configure_terminal_access

    log_success "Security optimizations complete"
}

# Check if terminal has Full Disk Access
check_full_disk_access() {
    local test_file="/Users/hemantv/Library/Safari/Bookmarks.plist"

    if [[ -r "$test_file" ]]; then
        log_success "✅ Terminal has Full Disk Access"
        return 0
    else
        log_warning "⚠️  Terminal does NOT have Full Disk Access"
        return 1
    fi
}

# Show Full Disk Access instructions and open settings
show_full_disk_access_instructions() {
    local terminal_app=""
    local terminal_path=""

    # Detect current terminal
    if [[ -n "${ITERM_SESSION_ID:-}" ]]; then
        terminal_app="iTerm2"
        terminal_path="/Applications/iTerm.app"
    elif [[ -n "${TERM_PROGRAM:-}" ]] && [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        terminal_app="Terminal"
        terminal_path="/Applications/Utilities/Terminal.app"
    else
        terminal_app="your terminal application"
        terminal_path="/Applications/[Your Terminal].app"
    fi

    echo ""
    log_error "❌ Full Disk Access Required for Terminal"
    echo ""
    log_info "Your terminal ($terminal_app) needs Full Disk Access to:"
    echo " • Configure system security settings"
    echo " • Access Safari bookmarks and other protected files"
    echo " • Complete the macOS optimization"
    echo ""
    log_info "📋 Manual Setup Instructions:"
    echo " 1. Security Settings will open automatically"
    echo " 2. Click the 🔒 lock and enter your password"
    echo " 3. Click '+' button below the app list"
    echo " 4. Navigate to: $terminal_path"
    echo " 5. Select $terminal_app and click 'Open'"
    echo " 6. Ensure $terminal_app is checked (✅)"
    echo " 7. Close System Settings"
    echo " 8. Restart your terminal"
    echo ""
    log_warning "⚠️  After granting access, restart your terminal and run this script again"

    # Open Security Settings
    if command -v open >/dev/null 2>&1; then
        log_info "🔍 Opening Security Settings..."
        open "/System/Library/PreferencePanes/Security.prefPane"
        sleep 2

        # Try to navigate to Full Disk Access using AppleScript
        osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
    tell process "System Settings"
        keystroke "Full Disk Access" using command down
        delay 1
        key code 36 -- return key
    end tell
end tell
EOF
    fi

    echo ""
    log_info "💡 Tip: You can also manually navigate to:"
    echo "  System Settings → Privacy & Security → Full Disk Access"
    echo ""
    return 1
}

# Configure Full Disk Access for terminal applications
configure_terminal_access() {
    log_section "Terminal Full Disk Access"

    # First check if terminal already has Full Disk Access
    if ! check_full_disk_access; then
        show_full_disk_access_instructions
        return 1
    fi

    # TCC (Transparency, Consent, and Control) database path
    local tcc_db="/Library/Application Support/com.apple.TCC/TCC.db"

    # Check if we can access the TCC database
    if [[ ! -r "$tcc_db" ]]; then
        log_warning "Cannot access TCC database directly"
        log_info "Manual Full Disk Access setup is recommended"
        return 0
    fi

    log_info "Configuring Full Disk Access for terminal applications..."

    # Common terminal applications to grant access
    local -a terminal_apps=(
        "/Applications/iTerm.app"
        "/Applications/Utilities/Terminal.app"
        "/Applications/Alacritty.app"
        "/Applications/Kitty.app"
        "/Applications/Hyper.app"
    )

    for app_path in "${terminal_apps[@]}"; do
        if [[ -d "$app_path" ]]; then
            local app_name=$(basename "$app_path" .app)
            log_info "Granting Full Disk Access to $app_name"

            # Get the app bundle identifier
            local bundle_id
            bundle_id=$(plutil -p "$app_path/Contents/Info.plist" | grep CFBundleIdentifier | sed 's/.*=> "\(.*\)"/\1/')

            if [[ -n "$bundle_id" ]]; then
                # Add to TCC database for Full Disk Access (kTCCServiceSystemPolicyAllFiles)
                sudo sqlite3 "$tcc_db" "INSERT OR REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','$bundle_id',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1541440109);" 2>/dev/null || {
                    log_warning "Could not automatically grant access to $app_name"
                    log_info "Please add $app_path manually in System Preferences"
                }
            fi
        fi
    done

    # Special handling for current terminal session
    if [[ -n "${ITERM_SESSION_ID:-}" ]]; then
        log_info "✅ iTerm2 detected - ensuring Full Disk Access"
    elif [[ -n "${TERM_PROGRAM:-}" ]] && [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        log_info "✅ Apple Terminal detected - ensuring Full Disk Access"
    fi

    log_success "Terminal Full Disk Access configuration complete"
    log_info "ℹ️  You may need to restart your terminal for changes to take effect"
}

# Performance optimizations with device-aware settings
configure_performance() {
    log_section "Performance"

    # Use common power management
    mac_configure_desktop_power "performance"

    log_info "Speeding up wake from sleep"
    sudo pmset -a standbydelay 0          # No delay for standby
    sudo pmset -a autopoweroff 0          # Disable auto power off
    sudo pmset -a hibernatemode 0         # Disable hibernation (faster wake)
    sudo pmset -a powernap 0              # Disable Power Nap for faster wake
    sudo pmset -a networkoversleep 0       # Prevent network activity during sleep

    log_info "Disabling local Time Machine snapshots"
    sudo tmutil disablelocal 2>/dev/null || true

    log_info "Preventing Time Machine from prompting for new disks"
    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

    log_info "Optimizing sleep settings for faster wake"
    defaults write com.apple.PowerManagement DesktopStandbyTime -int 0
    defaults write com.apple.PowerManagement MobileStandbyTime -int 0

    # Device-specific performance tweaks
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        # Prevent system sleep on desktops (for background services like LM Studio, tunnels, etc.)
        # But allow display sleep to protect OLED screens from burn-in
        log_info "Desktop: Disabling system sleep to keep background services running"
        sudo pmset -a sleep 0                 # Disable system sleep completely

        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                log_info "High-performance desktop: Always-on with OLED protection"
                sudo pmset -a displaysleep 5         # Display sleep after 5 minutes (OLED protection)
                sudo pmset -a disksleep 0            # Never sleep disks
                ;;
            *)
                log_info "Desktop: Standard always-on with OLED protection"
                sudo pmset -a displaysleep 5         # Display sleep after 5 minutes (OLED protection)
                sudo pmset -a disksleep 0            # Never sleep disks
                ;;
        esac
    else
        log_info "Laptop: Battery-optimized sleep settings"
        sudo pmset -b displaysleep 5               # Display sleep after 5 minutes on battery
        sudo pmset -b sleep 15                     # Sleep after 15 minutes on battery
        sudo pmset -c displaysleep 15              # Display sleep after 15 minutes on power
        sudo pmset -c sleep 30                     # Sleep after 30 minutes on power
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

    # Safari
    if [[ -d "/Applications/Safari.app" ]]; then
        log_info "Configuring Safari preferences and developer settings"

        # Developer menu settings
        defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
        defaults write com.apple.Safari IncludeDevelopMenu -bool true
        defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
        defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

        # General preferences
        defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true
        defaults write com.apple.Safari NewWindowBehavior -int 1  # Homepage
        defaults write com.apple.Safari NewTabBehavior -int 1     # Homepage
        defaults write com.apple.Safari HomePage -string "https://www.google.com/"
        defaults write com.apple.Safari HistoryAgeInDaysLimit -int 30  # Remove history after one month
        defaults write com.apple.Safari DownloadsPath -string "~/Downloads"
        defaults write com.apple.Safari DownloadsClearingPolicy -int 1  # Remove download items after one day

        # Tabs preferences
        defaults write com.apple.Safari TabCreationPolicy -int 1  # Open pages in tabs instead of windows: Automatically
        defaults write com.apple.Safari ShowColorInTabBar -bool true
        defaults write com.apple.Safari ShowWebsiteTitlesInTabs -bool true

        # Navigation preferences
        defaults write com.apple.Safari CommandClickMakesTabs -bool true    # ⌘-click opens link in new tab
        defaults write com.apple.Safari OpenNewTabsInFront -bool true       # Make new tabs/windows active
        defaults write com.apple.Safari Command1Through9SwitchesTabs -bool true  # Use ⌘-1 through ⌘-9 to switch tabs

        log_success "Safari configuration complete"
    fi

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
    echo " • UI/UX improvements (faster animations, better defaults)"
    echo " • Keyboard and trackpad optimizations (fast key repeat)"
    echo " • Display and screen settings"
    echo " • Finder enhancements (show extensions, hidden files)"
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        echo " • Desktop-optimized Dock settings (larger size, always visible, reduced corner radius)"
        echo " • Desktop-optimized power management"
    else
        echo " • Laptop-optimized Dock settings (smaller size, auto-hide, reduced corner radius)"
        echo " • Laptop-optimized power management"
    fi
    echo " • Menu bar cleanup (hide keyboard, search, and AI icons)"
    echo " • Security improvements (firewall, disable remote access)"
    echo " • Performance tweaks (faster wake from sleep, SSD optimization)"
    echo " • Developer settings (hidden files, locate database)"
    echo " • Application-specific optimizations"
    echo " • Productivity-focused hot corners"
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
    echo "• Dock improvements (reduced window corner radius for sharper appearance)"
    echo "• Security improvements (enable firewall, disable remote access)"
    echo "• Performance tweaks (disable motion sensor, optimize sleep)"
    echo "• Developer settings (show hidden files, enable locate database)"
    echo "• Application-specific optimizations (Safari, Chrome, TextEdit, etc.)"
    echo ""
    
    if [[ "$DEVICE_TYPE" == "desktop" ]]; then
        echo "🖥️  Desktop-specific optimizations:"
        case "$DEVICE_MODEL" in
            *"Mac Pro"*|*"Mac Studio"*)
                echo " • Large Dock icons (64px) for high-performance workstation"
                echo " • Extended sleep delays (24 hours) for heavy workloads"
                ;;
            *"iMac"*)
                echo " • Medium Dock icons (56px) optimized for built-in display"
                ;;
            *)
                echo " • Standard Dock icons (48px)"
                ;;
        esac
        echo " • Dock always visible for productivity"
        echo " • Desktop power management (no hibernation, extended standby)"
        echo " • Productivity-focused hot corners"
    else
        echo "🔋 Laptop-specific optimizations:"
        echo " • Smaller Dock icons (42px) to save screen space"
        echo " • Auto-hiding Dock for maximum screen real estate"
        echo " • Battery-optimized power management"
        echo " • Balanced performance and battery life"
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

    # Check Full Disk Access first - critical for security configuration
    if ! check_full_disk_access; then
        log_warning "⚠️  Cannot proceed without Full Disk Access"
        log_info "Please grant Full Disk Access and restart your terminal"
        show_full_disk_access_instructions
        exit 1
    fi

    configure_ui_ux
    configure_input
    configure_display
    configure_finder
    configure_dock
    configure_menubar
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