# frozen_string_literal: true

require 'json'
require 'fileutils'

# Service for managing script settings persistence
# Provides saving, loading, and merging of user preferences for scripts
class SettingsService
  attr_reader :script_name, :settings_file

  def initialize(script_name, settings_dir: nil)
    @script_name = script_name
    @settings_dir = settings_dir || default_settings_dir
    @settings_file = File.join(@settings_dir, "#{script_name}.json")
    ensure_settings_directory
  end

  # Load settings from file, returning empty hash if file doesn't exist or is invalid
  def load_settings
    return {} unless File.exist?(@settings_file)

    begin
      content = File.read(@settings_file)
      settings = JSON.parse(content, symbolize_names: true)
      validate_settings(settings)
      settings
    rescue JSON::ParserError, StandardError
      # If file is corrupted or invalid, return empty hash
      {}
    end
  end

  # Save settings to file with timestamp
  def save_settings(settings)
    # Filter out settings that shouldn't be persisted
    persistent_settings = filter_persistent_settings(settings)

    # Add metadata
    settings_with_metadata = {
      settings: persistent_settings,
      updated_at: Time.now.iso8601,
      script_version: script_version
    }

    begin
      File.write(@settings_file, JSON.pretty_generate(settings_with_metadata))
      true
    rescue StandardError => e
      warn "Failed to save settings: #{e.message}"
      false
    end
  end

  # Update specific settings without overwriting entire file
  def update_settings(new_settings)
    current_settings = load_settings
    merged_settings = current_settings.merge(new_settings)
    save_settings(merged_settings)
  end

  # Get a specific setting with optional default
  def get_setting(key, default = nil)
    settings = load_settings
    settings.fetch(key, default)
  end

  # Set a specific setting
  def set_setting(key, value)
    update_settings({ key => value })
  end

  # Check if settings file exists
  def settings_exist?
    File.exist?(@settings_file)
  end

  # Reset settings (delete the file)
  def reset_settings!
    File.delete(@settings_file) if File.exist?(@settings_file)
    true
  rescue StandardError
    false
  end

  # Get settings file path for debugging
  def settings_path
    @settings_file
  end

  # Show settings summary
  def settings_summary
    settings = load_settings

    if settings.empty?
      "No saved settings"
    else
      summary = ["Saved settings:"]
      settings.each do |key, value|
        summary << "  #{key}: #{value}"
      end
      summary.join("\n")
    end
  end

  private

  def default_settings_dir
    # Use ZSH config directory for settings
    zsh_config = ENV['ZSH_CONFIG'] || File.expand_path('~/.config/zsh')
    File.join(zsh_config, '.settings')
  end

  def ensure_settings_directory
    FileUtils.mkdir_p(@settings_dir) unless Dir.exist?(@settings_dir)
  end

  def script_version
    # Simple version based on file modification time
    File.mtime($0).to_i.to_s
  rescue StandardError
    '1'
  end

  def validate_settings(settings)
    # Basic validation - ensure it's a hash
    raise ArgumentError, 'Settings must be a hash' unless settings.is_a?(Hash)

    # Could add more specific validations here based on script needs
    settings
  end

  def filter_persistent_settings(settings)
    # Filter out settings that shouldn't be saved
    non_persistent_keys = [
      :help, :dry_run, :force, :verbose, :debug,
      :list_models, :interactive, :output_file
    ]

    settings.reject { |key, _| non_persistent_keys.include?(key) }
  end

  # Class methods for convenience
  class << self
    def for_script(script_name)
      new(script_name)
    end

    def load_for_script(script_name)
      for_script(script_name).load_settings
    end

    def save_for_script(script_name, settings)
      for_script(script_name).save_settings(settings)
    end
  end
end