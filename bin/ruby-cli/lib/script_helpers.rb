#!/usr/bin/env ruby
# frozen_string_literal: true

# Simplified script helper for common ZSH utility scripts
# Replaces the complex ScriptBase framework for simple use cases
#
# Usage:
#   require_relative 'script_helpers'
#
#   class MyScript
#     include ScriptHelpers
#
#     def initialize
#       parse_options
#     end
#
#     def run
#       log_banner("My Script")
#       # Your script logic here
#       log_success("Operation completed")
#     end
#   end
#
#   MyScript.new.run if __FILE__ == $0

require 'optparse'
require 'fileutils'
require 'json'

# Simple logging functions - use these directly in your scripts
def log_info(msg)
  puts "ℹ️  #{msg}"
end

def log_success(msg)
  puts "✅ #{msg}"
end

def log_warning(msg)
  puts "⚠️  #{msg}"
end

def log_error(msg)
  $stderr.puts "❌ #{msg}"
end

def log_debug(msg)
  return unless ENV['DEBUG'] == '1'
  puts "🐛 #{msg}"
end

def log_banner(title)
  puts
  puts "🔧 #{title}"
  puts "=" * 50
end

def log_section(title)
  puts
  puts "🔧 #{title}"
  puts "-" * 30
end

module ScriptHelpers
  attr_reader :options, :args

  def initialize
    @options = {
      dry_run: false,
      force: false,
      verbose: false,
      help: false
    }
    @args = []
    parse_options
  end

  # Parse common command line options
  def parse_options
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{script_name} [OPTIONS] #{script_arguments}"

      opts.on('-h', '--help', 'Show this help message') do
        @options[:help] = true
        puts opts
        show_examples if respond_to?(:show_examples)
        exit 0
      end

      opts.on('-f', '--force', 'Force operation without confirmation') do
        @options[:force] = true
      end

      opts.on('-d', '--dry-run', 'Show what would be done without making changes') do
        @options[:dry_run] = true
      end

      opts.on('-v', '--verbose', 'Verbose output') do
        @options[:verbose] = true
        ENV['VERBOSE'] = '1'
      end

      # Allow scripts to add custom options
      add_custom_options(opts) if respond_to?(:add_custom_options)
    end

    begin
      @args = parser.parse(ARGV)
    rescue OptionParser::InvalidOption => e
      log_error "#{e.message}"
      puts parser
      exit 1
    end
  end

  # Script metadata - override these in your script
  def script_name
    File.basename($0, '.rb')
  end

  def script_arguments
    ''
  end

  def script_description
    'A utility script'
  end

  def script_title
    script_name.split('-').map(&:capitalize).join(' ')
  end

  # Helper methods
  def dry_run?
    @options[:dry_run]
  end

  def force?
    @options[:force]
  end

  def verbose?
    @options[:verbose]
  end

  # Confirm action with user (unless --force)
  def confirm_action(message)
    return true if force?
    return true if ENV['FORCE'] == '1'

    print "#{message} [y/N]: "
    gets.strip.downcase.match?(/^y(es)?$/)
  end

  # Execute system command with logging
  def execute_cmd(command, description: nil)
    if dry_run?
      log_info "[DRY-RUN] Would execute: #{command}"
      return true
    end

    log_info description || "Running: #{command}" if verbose?

    if system(command)
      log_debug "Command succeeded: #{command}" if verbose?
      true
    else
      log_error "Command failed: #{command}"
      false
    end
  end

  # File operations with logging
  def remove_file(path)
    return log_info("[DRY-RUN] Would remove: #{path}") if dry_run?

    if File.exist?(path)
      FileUtils.rm_f(path)
      log_success "Removed: #{File.basename(path)}"
    end
  end

  def backup_file(path)
    return unless File.exist?(path)

    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_path = "#{path}.backup_#{timestamp}"

    if dry_run?
      log_info "[DRY-RUN] Would backup: #{path} → #{backup_path}"
    else
      FileUtils.cp(path, backup_path)
      log_success "Backed up: #{File.basename(path)}"
    end

    backup_path
  end

  # Find files by pattern
  def find_files(pattern, base_dir = '.')
    Dir.glob(File.join(base_dir, pattern))
  end

  # Validate directory argument exists
  def validate_directory_arg(name = "directory")
    if @args.empty?
      log_error "#{name} is required"
      exit 1
    end

    dir_path = File.expand_path(@args.first)

    unless Dir.exist?(dir_path)
      log_error "Directory not found: #{dir_path}"
      exit 1
    end

    dir_path
  end

  # Show completion message
  def show_completion(process_name = nil)
    process_name ||= script_title

    if dry_run?
      log_info "Dry-run completed. No changes were made."
    else
      log_success "#{process_name} completed!"
    end
  end

  # Load JSON config file
  def load_json_config(path)
    return {} unless File.exist?(path)

    begin
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      log_error "Invalid JSON in #{path}: #{e.message}"
      {}
    end
  end

  # Save JSON config file
  def save_json_config(path, data)
    if dry_run?
      log_info "[DRY-RUN] Would save config to: #{path}"
      return
    end

    File.write(path, JSON.pretty_generate(data))
    log_success "Saved config: #{path}"
  end

  # Get ZSH config directory
  def zsh_config_dir
    ENV['ZSH_CONFIG'] || File.expand_path('~/.config/zsh')
  end

  # Common directories
  def home_dir
    Dir.home
  end

  def current_dir
    Dir.pwd
  end

  # Check if command exists
  def command_exists?(cmd)
    system("which #{cmd} > /dev/null 2>&1")
  end
end

# Example of how to use this helper:
if __FILE__ == $0 && ARGV.include?('--example')
  class ExampleScript
    include ScriptHelpers

    def add_custom_options(opts)
      opts.on('-c', '--custom VALUE', 'Custom option value') do |v|
        @options[:custom] = v
      end
    end

    def show_examples
      puts "\nExamples:"
      puts "  #{script_name} /path/to/directory    # Process directory"
      puts "  #{script_name} --dry-run             # Preview changes"
      puts "  #{script_name} --force               # Skip confirmations"
    end

    def run
      log_banner(script_title)

      if @args.empty?
        log_error "Please provide a directory to process"
        return
      end

      dir = validate_directory_arg
      log_info "Processing directory: #{dir}"

      if confirm_action("Continue processing #{dir}?")
        log_success "Processing complete!"
      else
        log_info "Operation cancelled"
      end

      show_completion
    end
  end

  ExampleScript.new.run
end