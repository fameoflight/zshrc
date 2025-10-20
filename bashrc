# Minimal bash configuration for systems where default shell can't be changed

# Basic environment setup
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"
export WORKSPACE="$HOME/workspace"

# Basic PATH setup
export PATH=$HOME/bin:$PATH
export PATH=/usr/local/sbin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=/usr/local/bin:$PATH

# Yarn PATH
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
# Add Qt to PATH if available
if brew --prefix qt@5 >/dev/null 2>&1; then
    export PATH="$(brew --prefix qt@5)/bin:$PATH"
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/hemantv/.lmstudio/bin"
# End of LM Studio CLI section

# NVM (Node Version Manager) - Bash compatible setup
export NVM_DIR="$HOME/.config/nvm"

# Load NVM if available
if [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    if [ -s "$NVM_DIR/bash_completion" ]; then
        source "$NVM_DIR/bash_completion"
    fi
fi

# Add default Node version to PATH (if it exists)
NODE_DEFAULT_PATH="${NVM_DIR}/versions/default/bin"
if [ -d "$NODE_DEFAULT_PATH" ]; then
    PATH="${NODE_DEFAULT_PATH}:${PATH}"
fi


