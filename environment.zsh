# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# Basic environment settings related to the zsh compiliation (not private)

# XDG Base Directory Specification
# http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"
export ZSH_CACHE="$XDG_CACHE_HOME/zsh"
export WORKSPACE="$HOME/workspace"
export INK_CLI="$WORKSPACE/ink-cli"
mkdir -p $ZSH_CACHE

# Homebrew configuration
export HOMEBREW_NO_ENV_HINTS=1

# executable search path
export PATH=$HOME/bin:$PATH
export PATH=/usr/local/sbin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.local/sbin:$PATH
export PATH=/usr/local/bin:$PATH
export RUSTC_WRAPPER=/opt/homebrew/bin/sccache

############################### BEGIN METAWORK CONFIG ###############################
export METAWORK_HOME="/Users/hemantv/.metawork"
if [ -f "$METAWORK_HOME/shell/setup.sh" ]; then
    . "$METAWORK_HOME/shell/setup.sh"
fi
############################### END METAWORK CONFIG ###############################
