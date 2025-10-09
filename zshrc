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

ssh-add ~/.ssh/id_rsa > /dev/null 2>&1
ssh-add ~/.ssh/id_hemantv > /dev/null 2>&1
ssh-add ~/.ssh/do_hemantv > /dev/null 2>&1

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



export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
