# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# the main RC file (will be linked to ~/.zshrc)
#

# first include of the environment
source $HOME/.config/zsh/environment.zsh

typeset -ga sources
sources+="$ZSH_CONFIG/environment.zsh"
sources+="$ZSH_CONFIG/options.zsh"
sources+="$ZSH_CONFIG/prompt.zsh"
sources+="$ZSH_CONFIG/functions.zsh"
sources+="$ZSH_CONFIG/aliases.zsh"
sources+="$ZSH_CONFIG/android.zsh"
sources+="$ZSH_CONFIG/mathalon.zsh"
sources+="$ZSH_CONFIG/git.zsh"
sources+="$ZSH_CONFIG/dropbox.zsh"
sources+="$ZSH_CONFIG/erlang.zsh"
sources+="$ZSH_CONFIG/rails.zsh"
sources+="$ZSH_CONFIG/picasso.zsh"

# highlights the live command line
# Cloned From: git://github.com/nicoulaj/zsh-syntax-highlighting.git
sources+="$ZSH_CONFIG/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# provides the package name of a non existing executable
# (sudo apt-get install command-not-found)
sources+="/etc/zsh_command_not_found"

# Check for a system specific file
systemFile=`uname -s | tr "[:upper:]" "[:lower:]"`
sources+="$ZSH_CONFIG/$systemFile.zsh"

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

