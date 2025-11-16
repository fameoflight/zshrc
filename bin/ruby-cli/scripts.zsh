# Ruby CLI Scripts and Functions
# This file contains Ruby-specific utility scripts and automation functionality
# Loaded from the main scripts.zsh file

# Note: Color logging functions are loaded from logging.zsh

# =============================================================================
# RUBY CLI UTILITY FUNCTIONS
# =============================================================================

# Execute a Ruby script with proper path and bundler setup
_execute_ruby_cli_script() {
  local script_name="$1"
  local script_path="$ZSH_CONFIG/bin/ruby-cli/bin/$1"
  shift # Remove script name from arguments

  if [[ ! -f "$script_path" ]]; then
    log_error "$script_name not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making $script_name executable..."
    chmod +x "$script_path"
  fi

  # Set BUNDLE_GEMFILE to ruby-cli Gemfile
  local ruby_cli_dir="$ZSH_CONFIG/bin/ruby-cli"
  local gemfile_path="$ruby_cli_dir/Gemfile"

  if [[ -f "$gemfile_path" ]]; then
    # Preserve current working directory by running from original dir
    local original_dir="$(pwd)"
    # Export SSH environment variables for the subshell
    (cd "$ruby_cli_dir" && \
      export SSH_AUTH_SOCK="$SSH_AUTH_SOCK" && \
      export SSH_AGENT_PID="$SSH_AGENT_PID" && \
      export ORIGINAL_WORKING_DIR="$original_dir" && \
      source $HOME/.rvm/scripts/rvm && \
      rvm use 3.2.4 && \
      bundle exec ruby "bin/$script_name" "$@")
  else
    # Fallback to system ruby, also set ORIGINAL_WORKING_DIR and SSH environment
    local original_dir="$(pwd)"
    export SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
    export SSH_AGENT_PID="$SSH_AGENT_PID"
    export ORIGINAL_WORKING_DIR="$original_dir"
    ruby "$script_path" "$@"
  fi
}

# =============================================================================
# DEVELOPMENT TOOLS FUNCTIONS
# =============================================================================

# Xcode project file management with automatic category detection
xcode-add-file() {
  _execute_ruby_cli_script "xcode-add-file.rb" "$@"
}

# Safe file deletion with Xcode project awareness
xcode-delete-file() {
  _execute_ruby_cli_script "xcode-delete-file.rb" "$@"
}

# View Xcode project structure organized by category
xcode-view-files() {
  _execute_ruby_cli_script "xcode-view-files.rb" "$@"
}

# List available Xcode file categories
xcode-list-categories() {
  _execute_ruby_cli_script "xcode-list-categories.rb" "$@"
}

# Generate app icons for Xcode projects in multiple sizes
xcode-icon-generator() {
  _execute_ruby_cli_script "xcode-icon-generator.rb" "$@"
}

# Generate app icons for Electron applications
electron-icon-generator() {
  _execute_ruby_cli_script "electron-icon-generator.rb" "$@"
}

# Auto-generate categories.yml from script metadata headers
generate-categories() {
  _execute_ruby_cli_script "generate-categories.rb" "$@"
}

# =============================================================================
# GAME MODE FUNCTION
# =============================================================================

# Optimize system settings for gaming performance
game-mode() {
  _execute_ruby_cli_script "game-mode.rb" "$@"
}

# =============================================================================
# AI AND CHAT FUNCTIONS
# =============================================================================

# YouTube transcript chat with AI integration
youtube-transcript-chat() {
  _execute_ruby_cli_script "youtube-transcript-chat.rb" "$@"
}

# OpenRouter API usage tracking and analysis
openrouter-usage() {
  _execute_ruby_cli_script "openrouter-usage.rb" "$@"
}

# =============================================================================
# FILE AND SYSTEM UTILITIES
# =============================================================================

# Remove single-line console.log statements from source files
console-log-remover() {
  _execute_ruby_cli_script "console-log-remover.rb" "$@"
}

# Bulk change file extensions across directories
change-extension() {
  _execute_ruby_cli_script "change-extension.rb" "$@"
}

# Check camera and microphone privacy settings on macOS
check-camera-mic() {
  _execute_ruby_cli_script "check-camera-mic.rb" "$@"
}

# Merge multiple PDF files into a single document
merge-pdf() {
  _execute_ruby_cli_script "merge-pdf.rb" "$@"
}

# Find largest files while respecting .gitignore patterns
largest-files() {
  _execute_ruby_cli_script "largest-files.rb" "$@"
}

# Merge multiple markdown files into one
merge-markdown() {
  _execute_ruby_cli_script "merge-markdown.rb" "$@"
}

# Create EPUB from website content
website-epub() {
  _execute_ruby_cli_script "website-epub.rb" "$@"
}

# Create EPUB from Safari reading list
safari-epub() {
  _execute_ruby_cli_script "safari-epub.rb" "$@"
}

# =============================================================================
# GIT UTILITIES
# =============================================================================

# Show only comment-based changes in git diff
comment-only-changes() {
  _execute_ruby_cli_script "comment-only-changes.rb" "$@"
}

# Git commit for deleted files
git-commit-deletes() {
  _execute_ruby_cli_script "git-commit-deletes.rb" "$@"
}

# Git commit for directory changes
git-commit-dir() {
  _execute_ruby_cli_script "git-commit-dir.rb" "$@"
}

# Git commit for renamed files
git-commit-renames() {
  _execute_ruby_cli_script "git-commit-renames.rb" "$@"
}

# Compress git repository by cleaning history
git-compress() {
  local original_dir="$(pwd)"
  ORIGINAL_WORKING_DIR="$original_dir" _execute_ruby_cli_script "git-compress.rb" "$@"
}

# Find files by extension in git history with view commands
git-history() {
  _execute_ruby_cli_script "git-history.rb" "$@"
}

# Split a git commit by selecting files for separate commits
git-commit-splitter() {
  _execute_ruby_cli_script "git-commit-splitter.rb" "$@"
}

# Show common files between two git commits
git-common() {
  _execute_ruby_cli_script "git-common.rb" "$@"
}

# Interactive git template manager for creating private repos from templates
git-template() {
  _execute_ruby_cli_script "git-template.rb" "$@"
}

# Smart git rebase with auto-resolution of permission/whitespace conflicts
git-smart-rebase() {
  _execute_ruby_cli_script "git-smart-rebase.rb" "$@"
}

# =============================================================================
# EMAIL UTILITIES
# =============================================================================

# Gmail inbox management and processing
gmail-inbox() {
  _execute_ruby_cli_script "gmail-inbox.rb" "$@"
}

# =============================================================================
# VIDEO PROCESSING
# =============================================================================

# Clip video segments with precision
clip-video() {
  _execute_ruby_cli_script "clip-video.rb" "$@"
}

# =============================================================================
# MONITOR AND DISPLAY UTILITIES
# =============================================================================

# Configure stacked monitor setup
stacked-monitor() {
  _execute_ruby_cli_script "stacked-monitor.rb" "$@"
}

# Manage macOS spotlight indexing
spotlight-manage() {
  _execute_ruby_cli_script "spotlight-manage.rb" "$@"
}

# =============================================================================
# SYSTEM UTILITIES
# =============================================================================

# Show battery and power charger information
battery-info() {
  _execute_ruby_cli_script "battery-info.rb" "$@"
}

# Retry failed commands with backoff strategy
auto-retry() {
  _execute_ruby_cli_script "auto-retry.rb" "$@"
}

# Setup development tools environment
setup-dev-tools() {
  _execute_ruby_cli_script "setup-dev-tools.rb" "$@"
}

# Comprehensive application uninstaller
uninstall-app() {
  _execute_ruby_cli_script "uninstall-app.rb" "$@"
}

# =============================================================================
# AI CONTENT GENERATION
# =============================================================================

# Generate content using LLM
llm-generate() {
  _execute_ruby_cli_script "llm-generate.rb" "$@"
}

# =============================================================================
# NETWORK UTILITIES
# =============================================================================

# Test network speed and connectivity
network-speed() {
  _execute_ruby_cli_script "network-speed.rb" "$@"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# List all Ruby CLI scripts and functions
list-ruby-cli-scripts() {
  echo "💎 Ruby CLI Scripts and Functions:"
  echo ""

  echo "🔧 Xcode Development:"
  echo "   xcode-add-file          - Add file to Xcode project with auto-categorization"
  echo "   xcode-delete-file       - Safely delete file from Xcode project"
  echo "   xcode-view-files        - View Xcode project structure by category"
  echo "   xcode-list-categories   - List available Xcode file categories"
  echo "   xcode-icon-generator    - Generate app icons for Xcode projects"
  echo ""

  echo "⚛️  Electron Development:"
  echo "   electron-icon-generator - Generate app icons for Electron applications"
  echo ""

  echo "📋 Repository Organization:"
  echo "   generate-categories     - Generate categories.yml from script metadata headers"
  echo ""

  echo "🎮 Gaming:"
  echo "   game-mode               - Optimize system settings for gaming"
  echo ""

  echo "🤖 AI & Chat:"
  echo "   youtube-transcript-chat - Chat with YouTube video transcripts using AI"
  echo "   openrouter-usage        - Track OpenRouter API usage and costs"
  echo "   llm-generate            - Generate content using LLM"
  echo ""

  echo "🌐 Network:"
  echo "   network-speed           - Test network speed and connectivity"
  echo ""

  echo "📁 File Utilities:"
  echo "   console-log-remover     - Remove single-line console.log statements from source files"
  echo "   change-extension        - Bulk change file extensions"
  echo "   check-camera-mic        - Check camera/mic privacy settings"
  echo "   largest-files           - Find largest files by lines (default) or size"
  echo "   merge-pdf               - Merge multiple PDF files"
  echo "   merge-markdown          - Merge multiple markdown files"
  echo ""

  echo "📚 E-book Generation:"
  echo "   website-epub            - Create EPUB from website content"
  echo "   safari-epub             - Create EPUB from Safari reading list"
  echo ""

  echo "🐙 Git Utilities:"
  echo "   comment-only-changes    - Show only comment-based changes in git diff"
  echo "   git-commit-deletes      - Git commit for deleted files"
  echo "   git-commit-dir          - Git commit for directory changes"
  echo "   git-commit-renames      - Git commit for renamed files"
  echo "   git-compress            - Compress git repository history"
  echo "   git-history             - Find files by extension in git history"
  echo "   git-commit-splitter     - Split a git commit by selecting files for separate commits"
  echo "   git-common              - Show common files between two git commits"
  echo "   git-template            - Interactive template manager for creating private repos"
  echo "   git-smart-rebase        - Smart rebase with auto-resolution of permission/whitespace conflicts"
  echo ""

  echo "📧 Email:"
  echo "   gmail-inbox             - Gmail inbox management and processing"
  echo ""

  echo "🎬 Video Processing:"
  echo "   clip-video              - Clip video segments with precision"
  echo ""

  echo "🖥️ Display & Monitor:"
  echo "   stacked-monitor          - Configure stacked monitor setup"
  echo "   spotlight-manage        - Manage macOS spotlight indexing"
  echo ""

  echo "⚙️ System:"
  echo "   battery-info            - Show battery and power charger information"
  echo "   auto-retry               - Retry failed commands with backoff strategy"
  echo "   setup-dev-tools         - Setup development tools environment"
  echo "   uninstall-app           - Comprehensive application uninstaller"
  echo ""

  echo "💡 Usage Examples:"
  echo "   xcode-add-file MyViewController.swift              # Add to Xcode project"
  echo "   xcode-icon-generator --input icon.svg --include-logo  # Generate Xcode icons"
  echo "   electron-icon-generator --input icon.svg --ico --icns  # Generate Electron icons"
  echo "   game-mode                                            # Enable gaming performance"
  echo "   youtube-transcript-chat https://youtu.be/dQw4w9WgXcQ"
  echo "   openrouter-usage --period month                     # Show monthly usage"
  echo "   change-extension .txt .md ./documents              # Change extensions"
  echo "   merge-pdf chapter1.pdf chapter2.pdf -o book.pdf"
  echo "   largest-files -n 10                                  # Show 10 files with most lines"
  echo "   largest-files -s -n 10 -m 5M                       # Show 10 largest files over 5MB"
  echo "   git-compress --keep-last 12                         # Compress to last 12 commits"
  echo "   git-history rb                                       # Find Ruby files in git history"
  echo "   git-template                                         # Interactive template setup"
}