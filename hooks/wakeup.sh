#!/bin/zsh

# Debug logging
echo "$(date): Wakeup script triggered" >> ~/logs/sleepwatcher.log

# Source the main zsh configuration to ensure functions and paths are available
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc"
fi

# Log the event
log_hook "wakeup" "System waking up, triggering monitor setup."

# Run the stack-monitors command
sleep 3
stack-monitors

# Debug logging
echo "$(date): Wakeup script completed" >> ~/logs/sleepwatcher.log
