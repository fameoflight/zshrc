# This is mainly for linux boxes where I can't change default shell

sources+="$ZSH_CONFIG/ripping.zsh"
sources+="$ZSH_CONFIG/aliases.zsh"


foreach file (`echo $sources`)
    if [[ -a $file ]]; then
        source $file
    fi
end
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="$(brew --prefix qt@5.5)/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/hemantv/.lmstudio/bin"
# End of LM Studio CLI section


