# @author     Hemant Verma <fameoflight@gmail.com>
# @license    http://opensource.org/licenses/gpl-license.php
#
# Centralized logging functions with colors and emojis
# This file should be loaded first in zshrc to make functions available everywhere

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================

# Color codes for consistent usage across all files
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_NC='\033[0m' # No Color

# Legacy color names for backward compatibility
readonly RED="$COLOR_RED"
readonly GREEN="$COLOR_GREEN"
readonly YELLOW="$COLOR_YELLOW"
readonly BLUE="$COLOR_BLUE"
readonly MAGENTA="$COLOR_MAGENTA"
readonly CYAN="$COLOR_CYAN"
readonly WHITE="$COLOR_WHITE"
readonly BOLD="$COLOR_BOLD"
readonly DIM="$COLOR_DIM"
readonly NC="$COLOR_NC"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Success messages - green with checkmark
log_success() {
  echo -e "${COLOR_BOLD}${COLOR_GREEN}✅ $1${COLOR_NC}"
}

# Error messages - red with X, output to stderr
log_error() {
  echo -e "${COLOR_RED}❌ $1${COLOR_NC}" >&2
}

# Warning messages - yellow with warning triangle
log_warning() {
  echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_NC}"
}

# Info messages - blue with info icon
log_info() {
  echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_NC}"
}

# Progress messages - cyan with spinning arrow
log_progress() {
  echo -e "${COLOR_CYAN}🔄 $1${COLOR_NC}"
}

# Section headers - bold magenta with tool icon and separator
log_section() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_MAGENTA}🔧 $1${COLOR_NC}"
  echo "═══════════════════════════════════════════════════════════"
}

# Debug messages - dim with bug icon (only shown if DEBUG=1)
log_debug() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo -e "${COLOR_DIM}🐛 DEBUG: $1${COLOR_NC}"
  fi
}

# =============================================================================
# SPECIALIZED LOGGING FUNCTIONS
# =============================================================================

# File operations
log_file_created() {
  echo -e "${COLOR_GREEN}📄 Created: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_file_updated() {
  echo -e "${COLOR_BLUE}📝 Updated: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_file_deleted() {
  echo -e "${COLOR_RED}🗑️  Deleted: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_file_backed_up() {
  echo -e "${COLOR_CYAN}💾 Backed up: ${COLOR_BOLD}$1${COLOR_NC}"
}

# Network operations
log_download() {
  echo -e "${COLOR_BLUE}⬇️  Downloading: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_upload() {
  echo -e "${COLOR_BLUE}⬆️  Uploading: ${COLOR_BOLD}$1${COLOR_NC}"
}

# Git operations
log_git() {
  echo -e "${COLOR_MAGENTA}🐙 Git: $1${COLOR_NC}"
}

log_git_push() {
  echo -e "${COLOR_BLUE}🚀 Pushing: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_git_pull() {
  echo -e "${COLOR_BLUE}⬇️  Pulling: ${COLOR_BOLD}$1${COLOR_NC}"
}

# Process operations
log_process_start() {
  echo -e "${COLOR_GREEN}🚀 Starting: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_process_stop() {
  echo -e "${COLOR_RED}🛑 Stopping: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_process_kill() {
  echo -e "${COLOR_RED}🔥 Killing: ${COLOR_BOLD}$1${COLOR_NC}"
}

# System operations
log_clean() {
  echo -e "${COLOR_CYAN}🧹 Cleaning: $1${COLOR_NC}"
}

log_install() {
  echo -e "${COLOR_GREEN}📦 Installing: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_uninstall() {
  echo -e "${COLOR_RED}📦 Uninstalling: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_update() {
  echo -e "${COLOR_BLUE}🔄 Updating: ${COLOR_BOLD}$1${COLOR_NC}"
}

# Archive operations
log_archive_create() {
  echo -e "${COLOR_BLUE}📦 Creating archive: ${COLOR_BOLD}$1${COLOR_NC}"
}

log_archive_extract() {
  echo -e "${COLOR_BLUE}📦 Extracting: ${COLOR_BOLD}$1${COLOR_NC}"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Print a separator line
log_separator() {
  echo "───────────────────────────────────────────────────────────"
}

# Print a thick separator line
log_separator_thick() {
  echo "═══════════════════════════════════════════════════════════"
}

# Print completion message with celebration
log_complete() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_GREEN}🎉 $1 complete!${COLOR_NC}"
}

# Print startup banner
log_banner() {
  echo -e "${COLOR_BOLD}${COLOR_BLUE}$1${COLOR_NC}"
  log_separator_thick
}

# Ask for confirmation with colored prompt
log_confirm() {
  local message="$1"
  local default="${2:-n}"
  
  if [[ "$default" == "y" ]]; then
    echo -e -n "${COLOR_YELLOW}❓ $message [Y/n]: ${COLOR_NC}"
  else
    echo -e -n "${COLOR_YELLOW}❓ $message [y/N]: ${COLOR_NC}"
  fi
}

# =============================================================================
# PLATFORM-SPECIFIC HELPERS
# =============================================================================

# macOS specific logging
log_macos() {
  echo -e "${COLOR_BLUE}🍎 macOS: $1${COLOR_NC}"
}

# Linux specific logging  
log_linux() {
  echo -e "${COLOR_BLUE}🐧 Linux: $1${COLOR_NC}"
}

# Homebrew specific logging
log_brew() {
  echo -e "${COLOR_YELLOW}🍺 Homebrew: $1${COLOR_NC}"
}

# Docker specific logging
log_docker() {
  echo -e "${COLOR_BLUE}🐳 Docker: $1${COLOR_NC}"
}

# Python specific logging
log_python() {
  echo -e "${COLOR_BLUE}🐍 Python: $1${COLOR_NC}"
}

# Node.js specific logging
log_node() {
  echo -e "${COLOR_GREEN}🟢 Node.js: $1${COLOR_NC}"
}

# Ruby specific logging
log_ruby() {
  echo -e "${COLOR_RED}💎 Ruby: $1${COLOR_NC}"
}

# =============================================================================
# FILE LOGGING
# =============================================================================

# Generic function to log a message to a specified file
log_to_file() {
  local log_file_path="$1"
  local message="$2"
  
  # Ensure the directory exists
  mkdir -p "$(dirname "$log_file_path")"
  
  # Ensure the file exists
  touch "$log_file_path"
  
  # Get the name of the script that called this function
  local script_name
  script_name=$(basename "$0")

  # Log to file with timestamp and calling script name
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [$script_name] - $message" >> "$log_file_path"
}

# =============================================================================
# HOOK LOGGING
# =============================================================================

# Log hook executions to a centralized file
log_hook() {
  local hook_name="$1"
  local message="$2"
  
  # Determine the absolute path of the script that is running
  local script_path
  script_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  local script_dir
  script_dir=$(dirname "$script_path")
  
  # Log file will be in the same directory as the script
  local log_file="$script_dir/hooks.log"
  
  # Use the generic file logger
  log_to_file "$log_file" "[$hook_name] - $message"

  # Also log to console for immediate feedback
  echo -e "${COLOR_CYAN}훅  Hook [${COLOR_BOLD}$hook_name${COLOR_NC}${COLOR_CYAN}]: $message${COLOR_NC}"
}

# =============================================================================
# EXPORT FOR SHELL SCRIPTS
# =============================================================================

# Export color constants for use in bash scripts
export COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_MAGENTA COLOR_CYAN COLOR_WHITE COLOR_BOLD COLOR_DIM COLOR_NC
export RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BOLD DIM NC