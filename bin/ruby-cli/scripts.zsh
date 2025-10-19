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
    (cd "$ruby_cli_dir" && bundle exec ruby "bin/$script_name" "$@")
  else
    # Fallback to system ruby
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

  echo "🎮 Gaming:"
  echo "   game-mode               - Optimize system settings for gaming"
  echo ""

  echo "🤖 AI & Chat:"
  echo "   youtube-transcript-chat - Chat with YouTube video transcripts using AI"
  echo "   openrouter-usage        - Track OpenRouter API usage and costs"
  echo "   llm-generate            - Generate content using LLM"
  echo ""

  echo "📁 File Utilities:"
  echo "   change-extension        - Bulk change file extensions"
  echo "   check-camera-mic        - Check camera/mic privacy settings"
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
  echo "   auto-retry               - Retry failed commands with backoff strategy"
  echo "   setup-dev-tools         - Setup development tools environment"
  echo "   uninstall-app           - Comprehensive application uninstaller"
  echo ""

  echo "💡 Usage Examples:"
  echo "   xcode-add-file MyViewController.swift              # Add to Xcode project"
  echo "   game-mode                                            # Enable gaming performance"
  echo "   youtube-transcript-chat https://youtu.be/dQw4w9WgXcQ"
  echo "   openrouter-usage --period month                     # Show monthly usage"
  echo "   change-extension .txt .md ./documents              # Change extensions"
  echo "   merge-pdf chapter1.pdf chapter2.pdf -o book.pdf"
  echo "   git-compress --keep-last 12                         # Compress to last 12 commits"
}