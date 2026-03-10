# Minimal bash configuration for systems where zsh is not the login shell.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZSH_CONFIG="${ZSH_CONFIG:-$XDG_CONFIG_HOME/zsh}"

if [ -r "$ZSH_CONFIG/shell/env.shared.sh" ]; then
  . "$ZSH_CONFIG/shell/env.shared.sh"
fi

if command -v brew >/dev/null 2>&1; then
  qt_prefix="$(brew --prefix qt@5 2>/dev/null || true)"
  [ -n "$qt_prefix" ] && prepend_path "$qt_prefix/bin"
fi

prepend_path "$HOME/.config/yarn/global/node_modules/.bin"
prepend_path "$HOME/.yarn/bin"
append_path "$HOME/.rvm/bin"
append_path "$HOME/.lmstudio/bin"

export NVM_DIR="$HOME/.config/nvm"

set_default_node_path() {
  [ -r "$NVM_DIR/alias/default" ] || return 0

  default_alias="$(tr -d '\r\n' < "$NVM_DIR/alias/default")"
  for candidate in \
    "$NVM_DIR/versions/node/$default_alias/bin" \
    "$NVM_DIR/versions/node/v$default_alias/bin" \
    "$NVM_DIR"/versions/node/v"$default_alias"*/bin
  do
    [ -d "$candidate" ] && prepend_path "$candidate" && return 0
  done
}

if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  if [ -s "$NVM_DIR/bash_completion" ]; then
    . "$NVM_DIR/bash_completion"
  fi
fi

set_default_node_path
export PATH


# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/Users/hemantv/.lmstudio/bin"
