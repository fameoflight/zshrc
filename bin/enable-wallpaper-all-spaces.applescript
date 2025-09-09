#!/usr/bin/osascript

-- Enable "Show on all Spaces" for wallpaper in System Settings
-- This script automates the System Settings interface to enable the checkbox

tell application "System Events"
    tell application "System Settings"
        launch
    end tell
    delay 3
    
    tell process "System Settings"
        try
            -- Navigate to Wallpaper section
            click menu item "Wallpaper" of menu "View" of menu bar 1
            delay 2
            
            -- Look for "Show on all Spaces" checkbox in the wallpaper settings
            tell window 1
                repeat with i from 1 to 10
                    try
                        set allCheckboxes to every checkbox whose name contains "Show on all Spaces"
                        if (count of allCheckboxes) > 0 then
                            set showOnAllSpacesCheckbox to item 1 of allCheckboxes
                            if value of showOnAllSpacesCheckbox is false then
                                click showOnAllSpacesCheckbox
                                exit repeat
                            end if
                        end if
                    end try
                    delay 0.5
                end repeat
            end tell
        on error
            -- Fallback: try different UI path
            try
                tell window 1
                    click checkbox "Show on all Spaces"
                end tell
            end try
        end try
    end tell
    
    delay 1
    tell application "System Settings" to quit
end tell