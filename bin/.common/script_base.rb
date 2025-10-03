# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'fileutils'
require 'time'
require_relative 'logger'
require_relative 'system'
require_relative 'utils/error_utils'
require_relative 'services/settings_service'
require_relative 'services/interactive_menu_service'

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
  include ErrorUtils
  PROJECT_ROOT = ENV['ZSH_CONFIG'] || File.expand_path('../..', __dir__)
  attr_reader :options, :args

  def initialize
    @settings_service = SettingsService.for_script(script_name)
    @interactive_menu = InteractiveMenuService.for_script(self)
    @options = default_options
    @args = []
    @session_log = []
    @original_working_dir = ENV['ORIGINAL_WORKING_DIR'] || Dir.pwd
    setup_bundler
    setup_session_logging
    parse_arguments
  end

  # Default options for all scripts - can be overridden with saved settings
  def default_options
    base_defaults = {
      dry_run: false,
      force: false,
      verbose: false,
      help: false,
      debug: ENV['DEBUG'] == '1', # Initialize from environment
      log_session: ENV['LOG_SESSIONS'] == '1' # Can be enabled globally
    }

    # Load saved settings and merge with defaults
    saved_settings = load_saved_settings
    base_defaults.merge(saved_settings)
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

      opts.on('--log-session', 'Log session to file') do
        @options[:log_session] = true
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

      # Try to require bundler/setup, but handle gracefully if not available
      begin
        require 'bundler/setup'
      rescue LoadError
        # If bundler/setup fails, try to auto-install bundler and gems
        setup_bundler_fallback(zsh_config_dir)
      end
    end
  rescue LoadError
    # Bundler not available, continue without it
  end

  private

  # Fallback bundler setup - tries to bootstrap the environment
  def setup_bundler_fallback(zsh_config_dir)
    return unless File.exist?(File.join(zsh_config_dir, 'Gemfile'))

    # Check if we're in the right directory context
    original_dir = Dir.pwd

    begin
      Dir.chdir(zsh_config_dir)

      # Try to install bundler if missing
      unless system('gem list bundler -i > /dev/null 2>&1')
        puts "📦 Installing bundler..."
        system('gem install bundler')
      end

      # Try bundle install if Gemfile.lock is missing or outdated
      gemfile_lock = File.join(zsh_config_dir, 'Gemfile.lock')
      gemfile = File.join(zsh_config_dir, 'Gemfile')

      if !File.exist?(gemfile_lock) || File.mtime(gemfile) > File.mtime(gemfile_lock)
        puts "📚 Installing gems with bundle install..."
        system('bundle install --path vendor/bundle --quiet')
      end

      # Now try to require bundler/setup again
      require 'bundler/setup'
    rescue StandardError => e
      # If all else fails, just continue - the script might work without bundler
      puts "⚠️  Warning: Could not setup bundler: #{e.message}" if ENV['DEBUG']
    ensure
      Dir.chdir(original_dir)
    end
  end

  # Setup session logging
  def setup_session_logging
    @session_start_time = Time.now
    @session_id = Time.now.strftime('%Y%m%d_%H%M%S')
    @session_log_file = nil

    # Create logs directory if logging is enabled
    if @options[:log_session] || ENV['LOG_SESSIONS'] == '1'
      logs_dir = File.join(PROJECT_ROOT, 'logs')
      FileUtils.mkdir_p(logs_dir) unless Dir.exist?(logs_dir)

      @session_log_file = File.join(logs_dir, "#{script_name}_#{@session_id}.log")
      write_session_log("=== Session started at #{@session_start_time} ===")
      write_session_log("Script: #{script_name}")
      write_session_log("Arguments: #{ARGV.join(' ')}")
      write_session_log("Working directory: #{Dir.pwd}")
    end
  end

  # Execute with proper error handling
  def self.execute
    script = new

    begin
      script.validate!
      # Execute all script logic from the original working directory
      script.execute_from_original_dir
    rescue Interrupt
      script.log_warning("\nOperation cancelled by user")
      script.finalize_session_log
      exit 130
    rescue StandardError => e
      script.log_error("Script failed: #{e.message}")
      script.log_debug("Backtrace: #{e.backtrace.join("\n")}") if ENV['DEBUG'] == '1'
      script.finalize_session_log
      exit 1
    end

    script.finalize_session_log
  end

  public

  # Execute script logic from the original working directory
  def execute_from_original_dir
    # Change to the original working directory where the script was called from
    Dir.chdir(original_working_dir) do
      run
    end
  end

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

  def original_working_dir
    @original_working_dir
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

  # Execute ZSH script with proper environment loading
  def execute_zsh_script(script_name, *args, description: nil)
    zsh_config = ENV['ZSH_CONFIG'] || File.expand_path('~/.config/zsh')

    # Check if script exists in ZSH config bin directory first
    script_path = File.join(zsh_config, 'bin', script_name)

    # If not found there, check relative to current script directory
    unless File.exist?(script_path)
      script_path = File.join(File.dirname(__FILE__), script_name)
    end

    unless File.exist?(script_path)
      raise "ZSH script not found: #{script_name}"
    end

    command = "ZSH_CONFIG=#{zsh_config} #{script_path} #{args.map { |arg| "\"#{arg}\"" }.join(' ')}"
    execute_cmd(command, description: description)
  end

  # Execute ZSH script and return boolean result
  def execute_zsh_script?(script_name, *args, description: nil)
    zsh_config = ENV['ZSH_CONFIG'] || File.expand_path('~/.config/zsh')

    # Check if script exists in ZSH config bin directory first
    script_path = File.join(zsh_config, 'bin', script_name)

    # If not found there, check relative to current script directory
    unless File.exist?(script_path)
      script_path = File.join(File.dirname(__FILE__), script_name)
    end

    unless File.exist?(script_path)
      raise "ZSH script not found: #{script_name}"
    end

    command = "ZSH_CONFIG=#{zsh_config} #{script_path} #{args.map { |arg| "\"#{arg}\"" }.join(' ')}"
    execute_cmd?(command, description: description)
  end

  # Find files in directory by extension pattern
  def find_files_by_extensions(directory, extensions)
    extensions = Array(extensions).map { |ext| ext.downcase.start_with?('.') ? ext : ".#{ext}" }

    Dir.glob(File.join(directory, "**/*")).select do |file|
      File.file?(file) && extensions.include?(File.extname(file).downcase)
    end
  end

  # Validate directory argument exists and is readable
  def validate_directory_arg(directory_name = "directory")
    if args.empty?
      log_error "#{directory_name} is required"
      puts
      puts option_parser
      exit 1
    end

    dir_path = File.expand_path(args.first)

    unless Dir.exist?(dir_path)
      log_error "Directory not found: #{dir_path}"
      exit 1
    end

    dir_path
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

  # =========================================================================
  # LOGGER INTERFACE - Compatible with LLMService and other services
  # =========================================================================

  public

  def log_info(message)
    log_to_session("INFO", message)
    super(message)
  end

  def log_warning(message)
    log_to_session("WARN", message)
    super(message)
  end

  def log_error(message)
    log_to_session("ERROR", message)
    super(message)
  end

  def log_debug(message)
    return unless debug?

    log_to_session("DEBUG", message)
    super(message)
  end

  def log_success(message)
    log_to_session("SUCCESS", message)
    super(message)
  end

  def log_progress(message)
    log_to_session("PROGRESS", message)
    super(message)
  end

  # =========================================================================
  # SESSION LOGGING - Persistent logs for script sessions
  # =========================================================================

  # Keep these methods public for the class execute method
  def finalize_session_log
    return unless @session_log_file

    duration = Time.now - @session_start_time
    write_session_log("=== Session ended at #{Time.now} (duration: #{duration.round(2)}s) ===")

    if verbose?
      log_info("Session log saved to: #{@session_log_file}")
    end
  end

  private

  def log_to_session(level, message)
    return unless @session_log_file

    timestamp = Time.now.strftime('%H:%M:%S')
    log_entry = "[#{timestamp}] #{level}: #{message}"

    @session_log << log_entry
    write_session_log(log_entry)
  end

  def write_session_log(entry)
    return unless @session_log_file

    File.open(@session_log_file, 'a') do |f|
      f.puts(entry)
    end
  rescue StandardError => e
    # Don't fail the script if logging fails
    puts "Warning: Failed to write to session log: #{e.message}" if debug?
  end

  # Enable session logging for this script instance
  def enable_session_logging
    return if @session_log_file

    logs_dir = File.join(PROJECT_ROOT, 'logs')
    FileUtils.mkdir_p(logs_dir) unless Dir.exist?(logs_dir)

    @session_log_file = File.join(logs_dir, "#{script_name}_#{@session_id}.log")
    write_session_log("=== Session logging enabled at #{Time.now} ===")
  end

  # Get path to current session log file
  def session_log_path
    @session_log_file
  end

  # Get current session log contents
  def session_log_contents
    @session_log.dup
  end

  # =========================================================================
  # SETTINGS PERSISTENCE - Save and load user preferences
  # =========================================================================

  public

  # Load saved settings for this script
  def load_saved_settings
    @settings_service.load_settings
  end

  # Save current options as settings (filtered for persistence)
  def save_current_settings
    @settings_service.save_settings(@options)
  end

  # Update specific settings
  def update_settings(new_settings)
    @settings_service.update_settings(new_settings)
  end

  # Get a specific setting
  def get_setting(key, default = nil)
    @settings_service.get_setting(key, default)
  end

  # Set a specific setting
  def set_setting(key, value)
    @settings_service.set_setting(key, value)
  end

  # Reset all saved settings
  def reset_settings!
    @settings_service.reset_settings!
  end

  # Check if settings file exists
  def has_saved_settings?
    @settings_service.settings_exist?
  end

  # Show settings summary
  def show_settings_summary
    puts @settings_service.settings_summary
  end

  # Get settings file path
  def settings_file_path
    @settings_service.settings_path
  end

  # =========================================================================
  # INTERACTIVE MENUS - Universal UX patterns
  # =========================================================================

  # Show the universal action menu: Use It | Cancel | Settings
  def show_action_menu(title, options = {})
    @interactive_menu.show_action_menu(title, options)
  end

  # Show universal settings menu
  def show_settings_menu
    @interactive_menu.show_settings_menu
  end

  # Get task description with nice prompt
  def get_task_description(prompt_text = "📝 What do you want to do?")
    @interactive_menu.get_task_description(prompt_text)
  end

  # Confirm with user
  def interactive_confirm(message, default: false)
    @interactive_menu.confirm(message, default: default)
  end

  # Select from choices
  def interactive_select(title, choices, default: nil)
    @interactive_menu.select_from_choices(title, choices, default: default)
  end

  # Show progress with spinner
  def with_progress(message, &block)
    @interactive_menu.with_progress(message, &block)
  end

  # =========================================================================
  # SCRIPT-SPECIFIC OVERRIDES - Subclasses can override these
  # =========================================================================

  # Override this to provide script-specific settings menu items
  def interactive_settings_menu
    # Default implementation - subclasses should override
    [
      {
        key: :example_setting,
        label: "Example Setting",
        icon: "🔧"
      }
    ]
  end

  # =========================================================================
  # SAFE FILE DELETION UTILITIES - Always use trash instead of permanent deletion
  # =========================================================================

  # Safely remove a file by moving it to trash
  def safe_remove_file(file_path)
    file_path = Pathname.new(file_path) unless file_path.is_a?(Pathname)

    return true unless file_path.exist?

    begin
      # Try to use rmtrash if available
      if system('which rmtrash > /dev/null 2>&1')
        result = system("rmtrash #{Shellwords.escape(file_path.to_s)}")
        if result
          log_info "🗑️  Moved to trash: #{file_path}"
          return true
        end
      end
    rescue StandardError => e
      log_warning "Failed to use rmtrash: #{e}"
    end

    # Fallback: use FileUtils with warning
    begin
      log_warning "⚠️  Permanently deleting (trash unavailable): #{file_path}"
      FileUtils.rm_f(file_path)
      return true
    rescue StandardError => e
      log_error "Failed to delete file: #{e}"
      return false
    end
  end

  # Safely remove a directory by moving it to trash
  def safe_remove_directory(dir_path)
    dir_path = Pathname.new(dir_path) unless dir_path.is_a?(Pathname)

    return true unless dir_path.exist?

    begin
      # Try to use rmtrash if available
      if system('which rmtrash > /dev/null 2>&1')
        result = system("rmtrash -rf #{Shellwords.escape(dir_path.to_s)}")
        if result
          log_info "🗑️  Moved directory to trash: #{dir_path}"
          return true
        end
      end
    rescue StandardError => e
      log_warning "Failed to use rmtrash: #{e}"
    end

    # Fallback: use FileUtils with warning
    begin
      log_warning "⚠️  Permanently deleting directory (trash unavailable): #{dir_path}"
      FileUtils.rm_rf(dir_path)
      return true
    rescue StandardError => e
      log_error "Failed to delete directory: #{e}"
      return false
    end
  end

  # Backward compatibility aliases
  alias safe_remove safe_remove_file
  alias safe_rmtree safe_remove_directory

  # Override this to handle script-specific setting changes
  def handle_setting_change(setting_key, menu_service)
    # Default implementation - subclasses should override
    log_warning("Setting '#{setting_key}' not implemented in #{self.class}")
  end
end
