# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.2.4'

# Core utilities for scripts
gem 'fileutils', '~> 1.7'
gem 'optparse', '~> 0.4'
# System interaction and process management
gem 'etc', '~> 1.4'
gem 'open3', '~> 0.2'

# JSON and configuration handling
gem 'json', '~> 2.7'

gem 'tty'

# Terminal output and formatting
gem 'fastimage'
gem 'pastel', '~> 0.8'
gem 'tty-box', '~> 0.7'        # Frames and boxes
gem 'tty-command', '~> 0.10'   # Pretty command execution
gem 'tty-font', '~> 0.5'       # Large stylized text
gem 'tty-logger', '~> 0.6'     # Structured logging
gem 'tty-markdown', '~> 0.7' # Beautiful markdown rendering in terminal
gem 'tty-progressbar', '~> 0.18'
gem 'tty-prompt', '~> 0.23'
gem 'tty-spinner', '~> 0.9'
gem 'tty-table', '~> 0.12' # Beautiful tables
gem 'tty-tree', '~> 0.4' # Directory trees
gem 'tty-which', '~> 0.5'

# File operations and utilities
gem 'find', '~> 0.2'
gem 'tempfile', '~> 0.2'

# HTTP requests and web operations
gem 'net-http', '~> 0.4'
gem 'uri', '~> 0.13'

# SQLite for database operations (TCC database, etc.)
gem 'sqlite3', '~> 1.6'

# XML/Plist handling for macOS preferences
gem 'plist', '~> 3.7'
gem 'rexml', '~> 3.2'

# PDF manipulation
gem 'combine_pdf', '~> 1.0'
gem 'pdf-reader', '~> 2.11'

# Image processing for icon generation and perceptual hashing
gem 'chunky_png', '~> 1.3.7'
gem 'oily_png', '~> 1.2'

# Computer vision for similar image search
# Note: Native C++ binding gems (ruby-opencv, phashion) have build issues on Apple Silicon
# For advanced image processing, use Python scripts with OpenCV in bin/python-cli/
# For Ruby image processing, ChunkyPNG and FastImage provide sufficient functionality

# Web scraping and EPUB creation
gem 'ferrum', '~> 0.14'          # Chrome headless browser for JavaScript rendering
gem 'gepub', '~> 1.0'            # EPUB creation
gem 'httparty', '~> 0.21'        # HTTP requests with retries
gem 'nokogiri', '~> 1.15'        # HTML/XML parsing
gem 'ruby-readability', '~> 0.7' # Content extraction (reader view)

# Google API for Gmail integration
gem 'google-api-client', '~> 0.53'
gem 'googleauth', '~> 1.2'

group :development, :test do
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.56'
  gem 'rubocop-rails', '~> 2.21'
  gem 'rubocop-rspec', '~> 2.24'
end
