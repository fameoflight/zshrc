# Bun CLI scripts and compatibility wrappers
# Loaded from the main bin/scripts.zsh file when Bun is available.

_bun_cli_binary_path() {
  local bun_cli_dir="${ZSH_CONFIG:-$HOME/.config/zsh}/bin/bun-cli"
  local compiled_binary="$bun_cli_dir/dist/zsh-utils"

  if [[ -x "$compiled_binary" ]]; then
    echo "$compiled_binary"
    return 0
  fi

  return 1
}

_execute_bun_cli() {
  local bun_cli_dir="${ZSH_CONFIG:-$HOME/.config/zsh}/bin/bun-cli"
  local cli_entrypoint="$bun_cli_dir/src/cli.ts"
  local compiled_binary

  compiled_binary="$(_bun_cli_binary_path)"
  if [[ -n "$compiled_binary" ]]; then
    "$compiled_binary" "$@"
    return $?
  fi

  if command -v bun >/dev/null 2>&1; then
    bun run "$cli_entrypoint" "$@"
    return $?
  fi

  log_error "Bun CLI is not available. Install Bun or build $bun_cli_dir/dist/zsh-utils"
  return 1
}

_execute_bun_script() {
  local category="$1"
  local command="$2"
  shift 2

  _execute_bun_cli "$category" "$command" "$@"
}

zsh-utils() {
  _execute_bun_cli "$@"
}

auto-retry() {
  _execute_bun_script "utils" "auto-retry" "$@"
}

battery-info() {
  _execute_bun_script "macos" "battery-info" "$@"
}

change-extension() {
  _execute_bun_script "files" "change-extension" "$@"
}

check-camera-mic() {
  _execute_bun_script "macos" "check-camera-mic" "$@"
}

clip-video() {
  _execute_bun_script "media" "clip-video" "$@"
}

comment-only-changes() {
  _execute_bun_script "git" "comment-only-changes" "$@"
}

console-log-remover() {
  _execute_bun_script "files" "console-log-remover" "$@"
}

electron-icon-generator() {
  _execute_bun_script "media" "electron-icon-generator" "$@"
}

game-mode() {
  _execute_bun_script "macos" "game-mode" "$@"
}

gmail-inbox() {
  _execute_bun_script "ai" "gmail-inbox" "$@"
}

git-commit-deletes() {
  _execute_bun_script "git" "commit-deletes" "$@"
}

git-commit-dir() {
  _execute_bun_script "git" "commit-dir" "$@"
}

git-commit-renames() {
  _execute_bun_script "git" "commit-renames" "$@"
}

git-commit-splitter() {
  _execute_bun_script "git" "commit-splitter" "$@"
}

git-common() {
  _execute_bun_script "git" "common" "$@"
}

git-compress() {
  _execute_bun_script "git" "compress" "$@"
}

git-history() {
  _execute_bun_script "git" "file-history" "$@"
}

git-smart-rebase() {
  _execute_bun_script "git" "smart-rebase" "$@"
}

git-template() {
  _execute_bun_script "git" "template" "$@"
}

internal-find-orphaned-targets() {
  _execute_bun_script "utils" "find-orphaned-targets" "$@"
}

largest-files() {
  _execute_bun_script "utils" "largest-files" "$@"
}

llm-generate() {
  _execute_bun_script "ai" "llm-generate" "$@"
}

investigate-naval-js() {
  _execute_bun_script "browser" "investigate-naval-js" "$@"
}

merge-markdown() {
  _execute_bun_script "files" "merge-markdown" "$@"
}

merge-pdf() {
  _execute_bun_script "utils" "merge-pdf" "$@"
}

network-speed() {
  _execute_bun_script "network" "speed" "$@"
}

openrouter-usage() {
  _execute_bun_script "ai" "openrouter-usage" "$@"
}

safari-epub() {
  _execute_bun_script "epub" "safari-epub" "$@"
}

setup-dev-tools() {
  _execute_bun_script "utils" "setup-dev-tools" "$@"
}

spotlight-manage() {
  _execute_bun_script "macos" "spotlight-manage" "$@"
}

stacked-monitor() {
  _execute_bun_script "macos" "stacked-monitor" "$@"
}

test-click-naval() {
  _execute_bun_script "browser" "test-click-naval" "$@"
}

uninstall-app() {
  _execute_bun_script "macos" "uninstall-app" "$@"
}

website-epub() {
  _execute_bun_script "epub" "website-epub" "$@"
}

xcode-add-file() {
  _execute_bun_script "xcode" "add-file" "$@"
}

xcode-delete-file() {
  _execute_bun_script "xcode" "delete-file" "$@"
}

xcode-icon-generator() {
  _execute_bun_script "xcode" "icon-generator" "$@"
}

xcode-list-categories() {
  _execute_bun_script "xcode" "list-categories" "$@"
}

xcode-view-files() {
  _execute_bun_script "xcode" "view-files" "$@"
}

youtube-transcript-chat() {
  _execute_bun_script "ai" "youtube-transcript-chat" "$@"
}

list-bun-cli-scripts() {
  echo "🟨 Bun CLI Commands:"
  echo ""
  echo "Primary entrypoint: zsh-utils <category> <command> [args...]"
  echo "Compatibility wrappers are available for migrated commands."
  echo ""
  _execute_bun_cli list
}
