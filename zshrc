# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# the main RC file (will be linked to ~/.zshrc)
#

# first include of the environment
source "$HOME/.config/zsh/environment.zsh"

# Load logging functions first so they're available everywhere
source "$HOME/.config/zsh/logging.zsh"

source_if_exists() {
  [[ -r "$1" ]] && source "$1"
}

add_path_front() {
  [[ -d "$1" ]] && path=("$1" $path)
}

add_path_back() {
  [[ -d "$1" ]] && path+=("$1")
}

typeset -ga sources=(
  "$ZSH_CONFIG/options.zsh"
  "$ZSH_CONFIG/functions.zsh"
  "$ZSH_CONFIG/android.zsh"
  "$ZSH_CONFIG/git.zsh"
  "$ZSH_CONFIG/erlang.zsh"
  "$ZSH_CONFIG/rails.zsh"
  "$ZSH_CONFIG/ai-env.zsh"
  "$ZSH_CONFIG/claude.zsh"
  "$ZSH_CONFIG/gemini.zsh"
  "$ZSH_CONFIG/ai.zsh"
  "$ZSH_CONFIG/monorepo.zsh"
  "$ZSH_CONFIG/bin/scripts.zsh"
  "/etc/zsh_command_not_found"
  "$ZSH_CONFIG/$(uname -s | tr '[:upper:]' '[:lower:]').zsh"
  "$ZSH_CONFIG/private.zsh"
)

typeset -ga interactive_sources=(
  "$ZSH_CONFIG/prompt.zsh"
  "$ZSH_CONFIG/aliases.zsh"
  "$ZSH_CONFIG/completion.zsh"
  "$ZSH_CONFIG/fasd.zsh"
  "$ZSH_CONFIG/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  "$ZSH_CONFIG/private.final.zsh"
)

for file in "${sources[@]}"; do
  source_if_exists "$file"
done

if [[ -o interactive ]]; then
  for file in "${interactive_sources[@]}"; do
    source_if_exists "$file"
  done

  if ! command -v rmtrash >/dev/null 2>&1; then
    log_warning "rmtrash not found; install with 'brew install rmtrash' for safe file deletion"
  fi
fi

if [[ -o interactive ]]; then
  for ssh_key in "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_hemantv" "$HOME/.ssh/do_hemantv"; do
    [[ -f "$ssh_key" ]] && ssh-add "$ssh_key" >/dev/null 2>&1
  done
fi

add_path_back "$HOME/.rvm/bin"
add_path_front "$HOME/.config/yarn/global/node_modules/.bin"
add_path_front "$HOME/.yarn/bin"

# >>> conda initialize >>>
CONDA_HOME="$HOME/mambaforge"
if [[ -x "$CONDA_HOME/bin/conda" ]]; then
  __conda_setup="$("$CONDA_HOME/bin/conda" shell.zsh hook 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__conda_setup"
  else
    source_if_exists "$CONDA_HOME/etc/profile.d/conda.sh" || add_path_front "$CONDA_HOME/bin"
  fi
  unset __conda_setup
fi
# <<< conda initialize <<<

add_path_front "$HOME/anaconda3/envs/tf/bin"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
add_path_front "$PNPM_HOME"
# pnpm end

# Added by LM Studio CLI (lms)
add_path_back "$HOME/.lmstudio/bin"
# End of LM Studio CLI section

# NVM (Node Version Manager) - lazy loading with .nvmrc support
export NVM_DIR="$HOME/.config/nvm"
typeset -gi _nvm_loaded=0 _nvm_missing_warned=0
typeset -g _last_nvmrc_path="" _last_node_version=""

set_default_node_path() {
  local default_alias_file="$NVM_DIR/alias/default"
  [[ -r "$default_alias_file" ]] || return 0

  local default_alias
  default_alias="$(<"$default_alias_file")"
  default_alias="${default_alias//$'\n'/}"

  local -a candidates=(
    "$NVM_DIR/versions/node/${default_alias}/bin"
    "$NVM_DIR/versions/node/v${default_alias}/bin"
    ${NVM_DIR}/versions/node/v${default_alias}*/bin(N)
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -d "$candidate" ]] && add_path_front "$candidate" && return 0
  done
}

_load_nvm() {
  (( _nvm_loaded )) && return 0

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    if (( ! _nvm_missing_warned )); then
      log_warning "NVM not found at $NVM_DIR"
      _nvm_missing_warned=1
    fi
    return 1
  fi

  unfunction nvm node npm npx yarn npxl 2>/dev/null
  source "$NVM_DIR/nvm.sh" --no-use
  source_if_exists "$NVM_DIR/bash_completion"
  _nvm_loaded=1
}

_lazy_nvm_exec() {
  local cmd="$1"
  shift
  _load_nvm || return 1
  "$cmd" "$@"
}

find_nvmrc_file() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.nvmrc" ]]; then
      print -r -- "$dir/.nvmrc"
      return 0
    fi
    dir="${dir:h}"
  done
  return 1
}

switch_node_version() {
  local nvmrc_file=""
  local target_version

  nvmrc_file="$(find_nvmrc_file 2>/dev/null)" || nvmrc_file=""
  [[ "$nvmrc_file" == "$_last_nvmrc_path" ]] && return 0
  _last_nvmrc_path="$nvmrc_file"

  [[ -n "$nvmrc_file" ]] || return 0

  target_version="$(<"$nvmrc_file")"
  target_version="${target_version//$'\n'/}"

  [[ -n "$target_version" && "$target_version" != "$_last_node_version" ]] || return 0

  _load_nvm >/dev/null 2>&1 || return 0
  if nvm use "$target_version" >/dev/null 2>&1; then
    _last_node_version="$target_version"
    log_info "Using Node $target_version"
  fi
}

function nvm() { _lazy_nvm_exec nvm "$@"; }
function node() { _lazy_nvm_exec node "$@"; }
function npm() { _lazy_nvm_exec npm "$@"; }
function npx() { _lazy_nvm_exec npx "$@"; }
function yarn() { _lazy_nvm_exec yarn "$@"; }
function npxl() { _lazy_nvm_exec npxl "$@"; }

set_default_node_path

if [[ -o interactive ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd switch_node_version
  switch_node_version
fi

add_path_front "$HOME/.antigravity/antigravity/bin"

# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/Users/hemantv/.lmstudio/bin"
