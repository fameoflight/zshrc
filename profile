[ -x /usr/bin/byobu-launch ] && _byobu_sourced=1 . /usr/bin/byobu-launch
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -s "$HOME/.rvm/scripts/rvm" ] && . "$HOME/.rvm/scripts/rvm"

# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/Users/hemantv/.lmstudio/bin"
