# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# the main RC file (will be linked to ~/.zshrc)
#

# first include of the environment
source $HOME/.config/zsh/environment.zsh

# Load logging functions first so they're available everywhere
source $HOME/.config/zsh/logging.zsh

typeset -ga sources
sources+="$ZSH_CONFIG/environment.zsh"
sources+="$ZSH_CONFIG/options.zsh"
sources+="$ZSH_CONFIG/prompt.zsh"
sources+="$ZSH_CONFIG/functions.zsh"
sources+="$ZSH_CONFIG/aliases.zsh"
sources+="$ZSH_CONFIG/android.zsh"
sources+="$ZSH_CONFIG/mathalon.zsh"
sources+="$ZSH_CONFIG/git.zsh"
sources+="$ZSH_CONFIG/erlang.zsh"
sources+="$ZSH_CONFIG/rails.zsh"
sources+="$ZSH_CONFIG/ai-env.zsh"
sources+="$ZSH_CONFIG/claude.zsh"
sources+="$ZSH_CONFIG/gemini.zsh"
sources+="$ZSH_CONFIG/ai.zsh"
sources+="$ZSH_CONFIG/monorepo.zsh"
sources+="$ZSH_CONFIG/bin/scripts.zsh"

# highlights the live command line
# Cloned From: git://github.com/nicoulaj/zsh-syntax-highlighting.git
sources+="$ZSH_CONFIG/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# provides the package name of a non existing executable
# (sudo apt-get install command-not-found)
sources+="/etc/zsh_command_not_found"

# Check for a system specific file
systemFile=`uname -s | tr "[:upper:]" "[:lower:]"`
sources+="$ZSH_CONFIG/$systemFile.zsh"

# SAFE RM OVERRIDE - Must be loaded after functions.zsh to ensure our rm() function takes precedence
if command -v rmtrash >/dev/null 2>&1; then
else
  log_warning "⚠️  rmtrash not found - install with 'brew install rmtrash' for safe file deletion"
fi

# Private aliases and adoptions
sources+="$ZSH_CONFIG/private.zsh"

# completion config needs to be after system and private config
sources+="$ZSH_CONFIG/completion.zsh"

# fasd integration and config
sources+="$ZSH_CONFIG/fasd.zsh"

# Private aliases and adoptions added at the very end (e.g. to start byuobu)
sources+="$ZSH_CONFIG/private.final.zsh"




# try to include all sources
foreach file (`echo $sources`)
    if [[ -a $file ]]; then
        source $file
    fi
end

# Simple SSH key loading - run silently to avoid notifications
{
    ssh-add ~/.ssh/id_rsa > /dev/null 2>&1
    ssh-add ~/.ssh/id_hemantv > /dev/null 2>&1
    ssh-add ~/.ssh/do_hemantv > /dev/null 2>&1
} 2>/dev/null || true

export PATH="$PATH:$HOME/.rvm/bin"

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/hemantv/mambaforge/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/hemantv/mambaforge/etc/profile.d/conda.sh" ]; then
        . "/Users/hemantv/mambaforge/etc/profile.d/conda.sh"
    else
        export PATH="/Users/hemantv/mambaforge/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# export PATH=~/anaconda3/bin:$PATH
export PATH=~/anaconda3/envs/tf/bin:$PATH


# pnpm
export PNPM_HOME="/Users/hemantv/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/hemantv/.lmstudio/bin"
# End of LM Studio CLI section



# NVM (Node Version Manager) - Optimized lazy loading with .nvmrc support
export NVM_DIR="$HOME/.config/nvm"

# Optimized NVM lazy loading function
function _load_nvm() {
    # Remove all lazy loading functions
    for cmd in nvm node npm npx yarn npxl; do
        unset -f $cmd 2>/dev/null
    done

    # Load NVM with --no-use for better performance
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        \. "$NVM_DIR/nvm.sh" --no-use
        if [[ -s "$NVM_DIR/bash_completion" ]]; then
            \. "$NVM_DIR/bash_completion"
        fi
        return 0
    else
        echo "NVM not found. Please install NVM first."
        return 1
    fi
}

# Lazy load NVM and handle .nvmrc
function nvm() {
    _load_nvm
    command nvm "$@"
}

# Lazy load Node.js tools
function node() {
    _load_nvm
    command node "$@"
}

function npm() {
    _load_nvm
    command npm "$@"
}

function npx() {
    _load_nvm
    command npx "$@"
}

function yarn() {
    _load_nvm
    command yarn "$@"
}

function npxl() {
    _load_nvm
    command npxl "$@"
}

# Add default Node version to PATH (if it exists) - cached for performance
NODE_DEFAULT_PATH="${NVM_DIR}/versions/default/bin"
if [[ -d "$NODE_DEFAULT_PATH" ]]; then
    PATH="${NODE_DEFAULT_PATH}:${PATH}"
fi

# Lightweight .nvmrc support - only check when directory actually changes
_last_nvmrc_dir=""
_last_node_version=""

switchNode() {
    local current_dir="$(pwd)"

    # Skip if directory hasn't changed since last check
    if [[ "$current_dir" == "$_last_nvmrc_dir" ]]; then
        return 0
    fi

    _last_nvmrc_dir="$current_dir"

    # Quick check for .nvmrc without loading NVM
    local nvmrc_file="$current_dir/.nvmrc"
    if [[ -f "$nvmrc_file" ]]; then
        local target_version="$(cat "$nvmrc_file")"

        # Only switch if different from last used version
        if [[ "$target_version" != "$_last_node_version" ]]; then
            # Load NVM if not already loaded
            if ! command -v nvm >/dev/null 2>&1; then
                _load_nvm >/dev/null 2>&1
            fi

            # Use nvm to switch version
            if command -v nvm >/dev/null 2>&1; then
                nvm use "$target_version" >/dev/null 2>&1
                _last_node_version="$target_version"
                echo "📦 Switched to Node $target_version"
            fi
        fi
    fi
}

# Set up lightweight directory change hook for .nvmrc support
if autoload -Uz add-zsh-hook; then
    add-zsh-hook chpwd switchNode
fi

# Added by Antigravity
export PATH="/Users/hemantv/.antigravity/antigravity/bin:$PATH"
