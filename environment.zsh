# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# Basic environment settings related to the zsh compiliation (not private)

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZSH_CONFIG="${ZSH_CONFIG:-$XDG_CONFIG_HOME/zsh}"

source "$ZSH_CONFIG/shell/env.shared.sh"

typeset -gU path PATH
export RUSTC_WRAPPER=/opt/homebrew/bin/sccache

############################### BEGIN METAWORK CONFIG ###############################
export METAWORK_HOME="/Users/hemantv/.metawork"
if [ -f "$METAWORK_HOME/shell/setup.sh" ]; then
    . "$METAWORK_HOME/shell/setup.sh"
fi
############################### END METAWORK CONFIG ###############################
