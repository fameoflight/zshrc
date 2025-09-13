# frozen_string_literal: true

require 'tty-prompt'
require 'tty-box'

# Universal interactive menu service for all scripts
# Provides consistent UX patterns and settings management across scripts
class InteractiveMenuService
  attr_reader :script_instance

  def initialize(script_instance)
    @script_instance = script_instance
    @prompt = TTY::Prompt.new
  end

  # Universal post-action menu: Use It | Cancel | Settings
  def show_action_menu(title, options = {})
    choices = []

    # Add script-specific primary action
    if options[:primary_action]
      choices << {
        name: "✅ #{options[:primary_action][:label]}",
        value: :primary_action
      }
    end

    # Universal options in preferred order
    choices << { name: '❌ Cancel', value: :cancel }
    choices << { name: '⚙️  Settings', value: :settings }

    result = @prompt.select(title, choices, cycle: true)

    case result
    when :primary_action
      options[:primary_action][:callback].call if options[:primary_action][:callback]
    when :settings
      show_settings_menu
    when :cancel
      @script_instance.log_info('Operation cancelled')
      false
    end
  end

  # Universal settings menu
  def show_settings_menu
    loop do
      show_current_settings_display

      choices = build_settings_menu_choices

      selection = @prompt.select(
        '⚙️  Settings Menu',
        choices,
        cycle: true,
        per_page: 10
      )

      case selection
      when :back
        break
      when :reset_settings
        if @prompt.yes?('🗑️  Reset all settings to defaults?', default: false)
          @script_instance.reset_settings!
          @script_instance.log_success('Settings reset to defaults')
        end
      when :show_settings_file
        @script_instance.log_info("Settings file: #{@script_instance.settings_file_path}")
        @script_instance.show_settings_summary
      else
        # Handle script-specific setting changes
        handle_setting_change(selection)
      end
    end
  end

  # Show current settings in a nice box
  def show_current_settings_display
    settings = @script_instance.load_saved_settings

    if settings.empty?
      puts "\n💡 No saved settings found - using defaults\n\n"
      return
    end

    # Format settings for display
    setting_lines = []
    settings.each do |key, value|
      display_value = format_setting_value(value)
      setting_lines << "#{format_setting_name(key)}: #{display_value}"
    end

    box = TTY::Box.frame(
      setting_lines.join("\n"),
      title: { top_left: ' Current Settings ' },
      border: :light,
      padding: [0, 1],
      style: {
        fg: :cyan,
        border: { fg: :cyan }
      }
    )

    puts box
    puts
  end

  # Get description from user with nice prompt
  def get_task_description(prompt_text = '📝 What do you want to do?')
    @prompt.ask(prompt_text) do |q|
      q.required(true)
      q.messages[:required?] = 'Description cannot be empty'
      q.modify :strip
    end
  end

  # Confirm yes/no with custom text
  def confirm(message, default: false)
    @prompt.yes?(message, default: default)
  end

  # Select from choices with nice formatting
  def select_from_choices(title, choices, default: nil)
    @prompt.select(title, choices, default: default, cycle: true)
  end

  # Show a progress indicator
  def with_progress(message)
    spinner = @prompt.spinner(message, format: :dots)
    spinner.auto_spin
    result = yield
    spinner.success
    result
  rescue StandardError => e
    spinner.error
    raise e
  end

  private

  def build_settings_menu_choices
    choices = []

    # Script-specific settings
    script_settings = get_script_specific_settings
    script_settings.each do |setting|
      choices << {
        name: "#{setting[:icon]} #{setting[:label]}",
        value: setting[:key]
      }
    end

    # Universal settings
    choices << { name: '', disabled: '────────────────────' }
    choices << { name: '📄 Show settings file location', value: :show_settings_file }
    choices << { name: '🗑️  Reset all settings', value: :reset_settings }
    choices << { name: '⬅️  Back', value: :back }

    choices
  end

  def get_script_specific_settings
    puts "Getting script specific settings #{@script_instance.respond_to?(:interactive_settings_menu)}"
    # Script can override this method to provide custom settings
    if @script_instance.respond_to?(:interactive_settings_menu)
      @script_instance.interactive_settings_menu
    else
      []
    end
  end

  def handle_setting_change(setting_key)
    puts "Handling setting change for #{setting_key} in #{@script_instance.class.name} #{@script_instance}"

    puts "Script instance responds to handle_setting_change: #{@script_instance.respond_to?(:handle_setting_change)}"
    # Script can override this method to handle custom settings
    if @script_instance.respond_to?(:handle_setting_change)
      @script_instance.handle_setting_change(setting_key, self)
    else
      @script_instance.log_warning("Setting '#{setting_key}' not implemented")
    end
  end

  def format_setting_name(key)
    key.to_s.split('_').map(&:capitalize).join(' ')
  end

  def format_setting_value(value)
    case value
    when true, false
      value ? '✅ Yes' : '❌ No'
    when Symbol
      value.to_s.capitalize
    when String
      value.length > 30 ? "#{value[0..27]}..." : value
    else
      value.to_s
    end
  end

  # Class methods for convenience
  class << self
    def for_script(script_instance)
      new(script_instance)
    end
  end
end
