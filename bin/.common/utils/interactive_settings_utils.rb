# frozen_string_literal: true

# Interactive settings utilities using TTY gems for rich terminal interfaces
# Provides reusable helper functions for building interactive configuration menus
module InteractiveSettingsUtils
  # Display configuration in a formatted box
  def show_configuration_box(title, sections)
    require 'tty-box'

    config_content = sections.map do |section|
      lines = ["╭─ #{section[:icon]} #{section[:title]} #{section[:separator]}"]
      section[:items].each { |item| lines << "│  #{item}" }
      lines << '╰' + section[:separator]
      lines.join("\n")
    end.join("\n")

    box = TTY::Box.frame(
      config_content,
      title: { top_left: " #{title} " },
      border: :thick,
      padding: [1, 2],
      style: {
        fg: :bright_white,
        bg: :black,
        border: {
          fg: :magenta,
          bg: :black
        }
      }
    )

    puts box
    puts
  end

  # Create an interactive settings menu
  def interactive_settings_menu(title, menu_items, &block)
    require 'tty-prompt'
    prompt = TTY::Prompt.new

    loop do
      yield(:show_config) if block_given?

      selection = prompt.select(title, menu_items, cycle: true)

      break if selection == :exit

      if block_given?
        result = yield(selection, prompt)
        break if result == :exit
      end
    end
  end

  # Generic settings submenu handler
  def settings_submenu(title, settings_config, current_values, prompt)
    choices = settings_config.map do |key, config|
      current = format_setting_value(current_values[key], config)
      { name: "#{config[:icon]} #{config[:label]}: #{current}", value: key }
    end
    choices << { name: '← Back to Main Menu', value: :back }

    selection = prompt.select(title, choices, cycle: true)
    return :back if selection == :back

    handle_setting_input(selection, settings_config[selection], current_values, prompt)
  end

  # Handle different types of setting inputs
  def handle_setting_input(key, config, current_values, prompt)
    case config[:type]
    when :boolean
      current_values[key] = prompt.yes?(config[:prompt], default: current_values[key])

    when :select
      choices = config[:choices].map do |choice|
        case choice
        when Hash
          choice
        when Array
          { name: choice[0], value: choice[1] }
        else
          { name: choice.to_s, value: choice }
        end
      end
      current_values[key] = prompt.select(config[:prompt], choices)

    when :slider
      current_values[key] = prompt.slider(
        config[:prompt],
        min: config[:min],
        max: config[:max],
        step: config[:step] || 1,
        default: current_values[key]
      )

    when :input
      opts = { default: current_values[key] }
      opts[:convert] = config[:convert] if config[:convert]
      current_values[key] = prompt.ask(config[:prompt], **opts)

    when :custom
      # Allow custom handling via block
      if config[:handler]
        config[:handler].call(current_values, key, prompt)
      end
    end
  end

  # Format setting values for display
  def format_setting_value(value, config)
    case config[:type]
    when :boolean
      value ? (config[:true_text] || 'Yes') : (config[:false_text] || 'No')
    when :select
      # Find display name for the value
      if config[:choices]
        choice = config[:choices].find do |c|
          case c
          when Hash
            c[:value] == value
          when Array
            c[1] == value
          else
            c == value
          end
        end

        case choice
        when Hash
          choice[:name]
        when Array
          choice[0]
        else
          choice || value
        end
      else
        value
      end
    else
      value.to_s
    end
  end

  # Create cache info display
  def show_cache_info(cache_dir, file_pattern = "*.json")
    require 'tty-table'

    unless Dir.exist?(cache_dir)
      puts "Cache directory does not exist"
      return
    end

    cache_files = Dir.glob(File.join(cache_dir, file_pattern))

    if cache_files.empty?
      puts "Cache is empty"
      return
    end

    puts "\n📊 Cache Information"
    puts "=" * 50

    # Show cache statistics
    total_size = cache_files.sum { |f| File.size(f) }
    oldest_file = cache_files.min_by { |f| File.mtime(f) }
    newest_file = cache_files.max_by { |f| File.mtime(f) }

    puts "Total files: #{cache_files.length}"
    puts "Total size: #{format_bytes(total_size)}"
    puts "Oldest file: #{format_file_age(File.mtime(oldest_file))} old"
    puts "Newest file: #{format_file_age(File.mtime(newest_file))} old"

    # Show recent files
    puts "\n📁 Recent Cache Files:"
    table = TTY::Table.new(
      ['Age', 'Size', 'File'],
      cache_files.sort_by { |f| -File.mtime(f).to_i }.first(5).map do |file|
        [
          format_file_age(File.mtime(file)),
          format_bytes(File.size(file)),
          File.basename(file)
        ]
      end
    )

    puts table.render(:unicode, padding: [0, 1], alignments: [:left, :right, :left])
  end

  # Format file sizes
  def format_bytes(bytes)
    return '0 B' if bytes == 0

    units = %w[B KB MB GB]
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  # Format file ages
  def format_file_age(file_time)
    age_seconds = Time.now - file_time
    age_minutes = age_seconds / 60
    age_hours = age_minutes / 60
    age_days = age_hours / 24

    if age_days > 0
      "#{age_days.to_i} day#{age_days > 1 ? 's' : ''}"
    elsif age_hours > 0
      "#{age_hours.to_i} hour#{age_hours > 1 ? 's' : ''}"
    elsif age_minutes > 0
      "#{age_minutes.to_i} minute#{age_minutes > 1 ? 's' : ''}"
    else
      "less than a minute"
    end
  end

  # Confirmation dialogs
  def confirm_action(message, default: false)
    require 'tty-prompt'
    prompt = TTY::Prompt.new
    prompt.yes?(message, default: default)
  end

  def show_info_and_wait(message, wait_message: 'Press any key to continue...')
    puts message
    require 'tty-prompt'
    prompt = TTY::Prompt.new
    prompt.keypress(wait_message)
  end
end