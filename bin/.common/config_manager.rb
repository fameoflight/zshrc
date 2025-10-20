# frozen_string_literal: true

require 'json'
require 'fileutils'

# ConfigManager for handling API keys and configuration storage
# Specifically designed to store configuration in ~/.config/ruby-cli/{command_name}.json
class ConfigManager
  attr_reader :command_name, :config_file, :config_dir

  def initialize(command_name)
    @command_name = command_name
    @config_dir = File.expand_path('~/.config/ruby-cli')
    @config_file = File.join(@config_dir, "#{command_name}.json")
    ensure_config_directory
  end

  # Load configuration from file, returning empty hash if file doesn't exist
  def load_config
    return {} unless File.exist?(@config_file)

    begin
      content = File.read(@config_file)
      JSON.parse(content, symbolize_names: true)
    rescue JSON::ParserError => e
      warn "Failed to parse config file #{@config_file}: #{e.message}"
      {}
    rescue StandardError => e
      warn "Failed to load config file #{@config_file}: #{e.message}"
      {}
    end
  end

  # Save configuration to file
  def save_config(config)
    begin
      File.write(@config_file, JSON.pretty_generate(config))
      true
    rescue StandardError => e
      warn "Failed to save config to #{@config_file}: #{e.message}"
      false
    end
  end

  # Get a specific configuration value with optional default
  def get(key, default = nil)
    config = load_config
    config.fetch(key, default)
  end

  # Set a specific configuration value
  def set(key, value)
    config = load_config
    config[key] = value
    save_config(config)
  end

  # Get API key for the command
  def get_api_key
    get(:api_key)
  end

  # Set API key for the command
  def set_api_key(api_key)
    set(:api_key, api_key)
  end

  # Check if API key exists
  def has_api_key?
    !get_api_key.nil? && !get_api_key.empty?
  end

  # Prompt user for API key and save it
  def prompt_and_save_api_key(service_name = nil)
    service_label = service_name || @command_name.upcase
    print "Please enter your #{service_label} API key: "

    # Disable echo for API key input
    begin
      require 'io/console'
      api_key = STDIN.noecho(&:gets).chomp
      puts # Add newline after the hidden input
    rescue LoadError
      # Fallback if io/console is not available
      api_key = gets.chomp
    end

    if api_key && !api_key.empty?
      set_api_key(api_key)
      log_success("API key saved successfully")
      true
    else
      log_error("API key cannot be empty")
      false
    end
  end

  # Delete configuration file
  def delete_config!
    return true unless File.exist?(@config_file)

    begin
      File.delete(@config_file)
      true
    rescue StandardError => e
      warn "Failed to delete config file #{@config_file}: #{e.message}"
      false
    end
  end

  # Check if config file exists
  def config_exists?
    File.exist?(@config_file)
  end

  # Get config file path for debugging
  def config_path
    @config_file
  end

  # Display configuration summary
  def config_summary
    config = load_config

    if config.empty?
      puts "No configuration found for #{@command_name}"
    else
      puts "Configuration for #{@command_name}:"
      config.each do |key, value|
        # Hide API keys in output
        display_value = key.to_s.include?('key') ? '***' + value.to_s[-4..-1].to_s : value
        puts "  #{key}: #{display_value}"
      end
    end
  end

  private

  def ensure_config_directory
    FileUtils.mkdir_p(@config_dir) unless Dir.exist?(@config_dir)
  end

  # Simple logging methods (using basic terminal output)
  def log_success(message)
    puts "✅ #{message}"
  end

  def log_error(message)
    warn "❌ #{message}"
  end
end