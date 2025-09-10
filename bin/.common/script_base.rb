# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'fileutils'
require_relative 'logger'
require_relative 'system'

# Base class for all ZSH configuration scripts
# Provides common functionality, option parsing, and standardized structure
#
# ============================================================================
# STANDARD SCRIPT INTERFACE
# ============================================================================
#
# All scripts inheriting from ScriptBase should follow this structure:
#
# class MyScript < ScriptBase
#   # REQUIRED: Implement these methods
#   def run
#     log_banner(script_title)
#     # ... main script logic ...
#     show_completion(script_title)
#   end
#
#   # RECOMMENDED: Override these for better help text
#   def script_emoji; '🔧'; end
#   def script_title; 'My Script Tool'; end 
#   def script_description; 'Description of what this script does'; end
#   def script_arguments; '[OPTIONS] <required_arg>'; end
#
#   # OPTIONAL: Override these as needed
#   def validate!
#     # Custom validation logic
#     super
#   end
#
#   def add_custom_options(opts)
#     opts.on('-c', '--custom', 'Custom option') do
#       @options[:custom] = true
#     end
#   end
#
#   def show_examples
#     puts "Examples:"
#     puts "  #{script_name} arg1          # Description"
#     puts "  #{script_name} --verbose     # Verbose mode"
#   end
# end
#
# # Execute with proper error handling
# MyScript.execute if __FILE__ == $0
#
# ============================================================================
class ScriptBase
  PROJECT_ROOT = ENV['ZSH_CONFIG'] || File.expand_path('../..', __dir__)
  attr_reader :options, :args

  def initialize
    @options = default_options
    @args = []
    setup_bundler
    parse_arguments
  end

  # Default options for all scripts
  def default_options
    {
      dry_run: false,
      force: false,
      verbose: false,
      help: false,
      debug: ENV['DEBUG'] == '1' # Initialize from environment
    }
  end

  # Parse command line arguments
  def parse_arguments
    parser = OptionParser.new do |opts|
      opts.banner = banner_text

      opts.on('-h', '--help', 'Show this help message') do
        @options[:help] = true
      end

      opts.on('-f', '--force', 'Force operation without confirmation') do
        @options[:force] = true
        ENV['FORCE'] = '1'
      end

      opts.on('-d', '--dry-run', 'Show what would be done without making changes') do
        @options[:dry_run] = true
      end

      opts.on('-v', '--verbose', 'Verbose output') do
        @options[:verbose] = true
        ENV['VERBOSE'] = '1'
      end

      opts.on('--debug', 'Enable debug output') do
        @options[:debug] = true
        ENV['DEBUG'] = '1'
      end

      # Also check if DEBUG was set before script started
      @options[:debug] = true if ENV['DEBUG'] == '1'

      # Allow subclasses to add custom options
      add_custom_options(opts) if respond_to?(:add_custom_options, true)
    end

    begin
      @args = parser.parse(ARGV)
    rescue OptionParser::InvalidOption => e
      log_error("#{e.message}")
      puts parser
      exit 1
    end

    return unless @options[:help]

    puts parser
    puts
    show_examples if respond_to?(:show_examples, true)
    exit 0
  end

  # Banner text for help - subclasses should override these methods
  def banner_text
    <<~BANNER
      #{script_emoji} #{script_title}

      #{script_description}

      Usage: #{script_name} [OPTIONS] #{script_arguments}
    BANNER
  end

  # Script metadata methods - override in subclasses
  def script_emoji
    '🔧'
  end

  def script_title
    script_name.tr('-', ' ').split.map(&:capitalize).join(' ')
  end

  def script_description
    'A utility script for ZSH configuration management'
  end

  def script_arguments
    ''
  end

  # Get script name from filename
  def script_name
    File.basename($0, '.rb')
  end

  # =========================================================================
  # REQUIRED METHODS - Subclasses MUST implement these
  # =========================================================================

  # Main entry point - override in subclasses
  def run
    raise NotImplementedError, 'Subclasses must implement #run method'
  end

  # =========================================================================
  # OPTIONAL OVERRIDE METHODS - Subclasses can customize these
  # =========================================================================

  # Validation - override in subclasses for custom validation
  def validate!
    # Override in subclasses for custom validation
    true
  end

  # Add script-specific command line options
  def add_custom_options(opts)
    # Override in subclasses to add custom options
    # Example:
    # opts.on('-c', '--custom', 'Custom option') do
    #   @options[:custom] = true
    # end
  end

  # Show usage examples in help
  def show_examples
    # Override in subclasses to show usage examples
    puts "Examples:"
    puts "  #{script_name}                # Basic usage"
  end

  # Show restart notice after completion (optional)
  def show_restart_notice
    # Override in subclasses if restart/reload is needed
    # log_info("Restart your shell: exec zsh")
  end

  # Setup bundler to use project gems
  def setup_bundler
    zsh_config_dir = ENV['ZSH_CONFIG'] || File.expand_path('../..', __dir__)
    gemfile_path = File.join(zsh_config_dir, 'Gemfile')

    if File.exist?(gemfile_path)
      ENV['BUNDLE_GEMFILE'] = gemfile_path
      require 'bundler/setup' if defined?(Bundler)
    end
  rescue LoadError
    # Bundler not available, continue without it
  end

  # Execute with proper error handling
  def self.execute
    script = new

    begin
      script.validate!
      script.run
    rescue Interrupt
      log_warning("\nOperation cancelled by user")
      exit 130
    rescue StandardError => e
      log_error("Script failed: #{e.message}")
      log_debug("Backtrace: #{e.backtrace.join("\n")}") if ENV['DEBUG'] == '1'
      exit 1
    end
  end

  protected

  # Utility methods for subclasses
  def dry_run?
    @options[:dry_run]
  end

  def force?
    @options[:force]
  end

  def verbose?
    @options[:verbose]
  end

  def debug?
    @options[:debug]
  end

  def confirm_action(message)
    return true if force?
    return true if ENV['FORCE'] == '1'

    require 'tty-prompt'
    prompt = TTY::Prompt.new
    prompt.yes?(message)
  end

  def execute_cmd(command, description: nil)
    System.execute(command, description: description, dry_run: dry_run?, verbose: verbose?)
  end

  def execute_cmd?(command, description: nil)
    System.execute?(command, description: description, dry_run: dry_run?, verbose: verbose?)
  end

  # File operations with logging
  def remove_file(path)
    return log_info("[DRY-RUN] Would remove: #{path}") if dry_run?

    return unless File.exist?(path)

    FileUtils.rm_rf(path)
    log_success("Removed: #{File.basename(path)}")
    log_debug("Path: #{path}") if verbose?
  end

  def remove_files(paths, skip_confirmation: false)
    return if paths.empty?

    if verbose?
      log_info("Removing #{paths.length} file(s)/directory(ies):")
      paths.each do |path|
        puts "  📄 #{File.basename(path)}"
        log_debug("Path: #{path}")
      end
    end

    return if !skip_confirmation && !confirm_action('Remove these files?')

    paths.each { |path| remove_file(path) }
    log_success("Removed #{paths.length} files")
  end

  # Directory operations
  def find_in_directories(directories, pattern)
    System.find_files(directories, pattern)
  end

  # Show completion message
  def show_completion(process_name)
    if dry_run?
      log_info('Dry-run completed. No changes were made.')
    else
      log_complete(process_name)
      show_restart_notice if respond_to?(:show_restart_notice, true)
    end
  end

  # Common directory patterns
  def user_library_dirs
    home = System.home_dir
    [
      "#{home}/Library/Preferences",
      "#{home}/Library/Application Support",
      "#{home}/Library/Caches",
      "#{home}/Library/Logs",
      "#{home}/Library/Saved Application State",
      "#{home}/Library/WebKit"
    ]
  end

  def system_library_dirs
    [
      '/Library/Preferences',
      '/Library/Application Support',
      '/Library/Caches',
      '/Library/Logs'
    ]
  end

  def application_dirs
    home = System.home_dir
    [
      '/Applications',
      '/System/Applications',
      "#{home}/Applications",
      '/Applications/Utilities',
      '/System/Applications/Utilities'
    ]
  end

  def launch_dirs
    home = System.home_dir
    [
      "#{home}/Library/LaunchAgents",
      '/Library/LaunchAgents',
      '/Library/LaunchDaemons',
      '/System/Library/LaunchAgents',
      '/System/Library/LaunchDaemons'
    ]
  end
end
