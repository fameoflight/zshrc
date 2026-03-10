# Shared environment bootstrap for zsh, bash, and login shells.

if [ -n "${ZSH_SHARED_ENV_LOADED:-}" ]; then
  return 0
fi
export ZSH_SHARED_ENV_LOADED=1

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"

export XDG_CONFIG_HOME
export XDG_CACHE_HOME
export ZSH_CONFIG="${ZSH_CONFIG:-$XDG_CONFIG_HOME/zsh}"
export ZSH_CACHE="${ZSH_CACHE:-$XDG_CACHE_HOME/zsh}"
export WORKSPACE="${WORKSPACE:-$HOME/workspace}"
export INK_CLI="${INK_CLI:-$WORKSPACE/ink-cli}"
export PYTHON_CLI_CACHE="${PYTHON_CLI_CACHE:-$XDG_CACHE_HOME/zshrc/python-cli}"
export RUBY_CLI_CACHE="${RUBY_CLI_CACHE:-$XDG_CACHE_HOME/zshrc/ruby-cli}"
export HOMEBREW_NO_ENV_HINTS=1

prepend_path() {
  [ -n "${1:-}" ] || return 0
  [ -d "$1" ] || return 0
  case ":${PATH:-}:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

append_path() {
  [ -n "${1:-}" ] || return 0
  [ -d "$1" ] || return 0
  case ":${PATH:-}:" in
    *":$1:"*) ;;
    *) PATH="${PATH:+$PATH:}$1" ;;
  esac
}

dedupe_path() {
  old_ifs=$IFS
  IFS=:
  set -- ${PATH:-}
  IFS=$old_ifs

  deduped_path=""
  for entry in "$@"; do
    [ -n "$entry" ] || continue
    case ":$deduped_path:" in
      *":$entry:"*) ;;
      *) deduped_path="${deduped_path:+$deduped_path:}$entry" ;;
    esac
  done

  PATH="$deduped_path"
}

mkdir -p "$ZSH_CACHE" "$PYTHON_CLI_CACHE" "$RUBY_CLI_CACHE"

prepend_path "$HOME/bin"
prepend_path "/usr/local/sbin"
prepend_path "$HOME/.local/bin"
prepend_path "$HOME/.local/sbin"
prepend_path "/usr/local/bin"

dedupe_path
export PATH
