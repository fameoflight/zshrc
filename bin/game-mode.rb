#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '.common/script_base'

# Script to configure game mode by enabling only the LG OLED monitor
class GameMode < ScriptBase
  # Script metadata for standardized help text
  def script_emoji
    '🎮'
  end

  def script_title
    'Game Mode Setup'
  end

  def script_description
    'Toggle game mode by default - switches between single display gaming mode and multi-display setup. Use "on"/"off" for explicit control.'
  end

  def script_arguments
    '[on|off] [--restore] [--dry-run] [--debug] [--display <index>]'
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name}                    # Toggle game mode (default behavior)"
    puts "  #{script_name} on                 # Enable game mode (auto-detect LG OLED)"
    puts "  #{script_name} off                # Restore all monitors"
    puts "  #{script_name} --display 1        # Use display #1 for game mode"
    puts "  #{script_name} --restore          # Restore all monitors"
    puts "  #{script_name} --dry-run          # Preview what would be configured"
    puts "  #{script_name} --debug            # Show current setup and debug info"
  end

  def validate!
    unless System.command?('displayplacer')
      log_error('displayplacer is not installed')
      log_info('Install with: brew install jakehilborn/jakehilborn/displayplacer')
      exit(1)
    end
    log_debug('displayplacer found')
    super
  end

  def add_custom_options(opts)
    opts.on('-r', '--restore', 'Restore all displays') do
      @options[:restore] = true
    end

    opts.on('--display INDEX', 'Use specific display by index (1-based)') do |index|
      @options[:display] = index
    end
  end

  def parse_arguments
    # Handle simple on/off commands by modifying ARGV before calling super
    case ARGV.first&.downcase
    when 'on'
      @options[:on] = true
      ARGV.shift
    when 'off'
      @options[:restore] = true
      ARGV.shift
    end

    super
  end

  def run
    log_banner(script_title)

    displays_info = get_display_info

    if @options[:restore] || @options[:on]
      # Explicit commands
      if @options[:restore]
        restore_all_displays(displays_info)
      else
        enable_game_mode(displays_info)
      end
    else
      # Default behavior: toggle
      if game_mode_active?(displays_info)
        log_info('🔄 Game mode is currently active - disabling...')
        restore_all_displays(displays_info)
      else
        log_info('🔄 Game mode is currently inactive - enabling...')
        enable_game_mode(displays_info)
      end
    end

    show_completion(script_title)
  end

  private

  def game_mode_active?(displays_info)
    # Game mode is active if only one display is enabled and it's likely a gaming display
    enabled_displays = displays_info.select { |d| d[:enabled] }

    # If only one display is enabled, assume game mode is active
    if enabled_displays.length == 1
      log_debug("Game mode active: only one display enabled (#{enabled_displays.first[:type]})")
      return true
    end

    # If multiple displays are enabled, check if they match typical game mode patterns
    # Game mode typically has the main display at origin (0,0) and others might be disabled
    main_display = enabled_displays.find { |d| d[:main] }
    if main_display && enabled_displays.length == 1
      log_debug("Game mode active: single main display enabled (#{main_display[:type]})")
      return true
    end

    log_debug("Game mode inactive: #{enabled_displays.length} displays enabled")
    false
  end

  def get_display_info
    log_debug('Getting display information...')

    # Simple approach: just use displayplacer
    displayplacer_output = execute_cmd('displayplacer list', description: 'Getting displayplacer information')

    unless displayplacer_output
      log_error('Failed to get display list')
      return []
    end

    # Parse displayplacer output for current configuration
    displayplacer_displays = displayplacer_output.split("\n\n").select do |block|
      block.include?('Persistent screen id:')
    end
    parsed_displays = displayplacer_displays.map { |display| parse_display_info(display) }

    log_debug("Found #{parsed_displays.length} displays")
    parsed_displays.each_with_index do |display, i|
      log_debug("Display #{i + 1}: #{display[:type]} - #{display[:resolution]} (#{display[:enabled] ? 'enabled' : 'disabled'})")
    end

    parsed_displays
  end

  def get_all_displays_info
    log_debug('Getting all displays including disabled ones...')

    # For now, return current displays since we can't reliably detect disabled ones
    # In the future, we could try to use system_profiler or other methods
    current_displays = get_display_info

    log_debug("Found #{current_displays.length} total displays")
    current_displays
  end

  def parse_system_profiler_displays(system_profiler_output)
    displays = []
    current_display = {}

    return displays unless system_profiler_output.is_a?(String)

    system_profiler_output.split("\n").each do |line|
      line = line.strip

      if line.empty?
        displays << current_display if current_display.any?
        current_display = {}
        next
      end

      case line
      when /^Displays:$/i
        next
      when /^\w+:/
        key, value = line.split(':', 2).map(&:strip)
        current_display[key.downcase.gsub(' ', '_')] = value
      when /^\s+/ # Indented lines (continuation of previous value)
        next
      end
    end

    # Add the last display if there's no trailing newline
    displays << current_display if current_display.any?

    log_debug("System profiler found #{displays.length} displays")
    displays.each_with_index do |display, i|
      log_debug("System Display #{i + 1}: #{display.inspect}")
    end

    displays
  end

  def merge_display_info(displayplacer_displays, system_displays)
    # Start with displayplacer displays (more accurate current info)
    merged = displayplacer_displays.dup

    return merged unless system_displays.is_a?(Array)

    # Add any displays from system_profiler that aren't in displayplacer
    system_displays.each do |system_display|
      next unless system_display.is_a?(Hash)

      # Try to match by display type/resolution or serial number
      matching_display = merged.find do |dp_display|
        display_type = system_display['display_type'] || system_display['type']
        dp_display[:type].downcase.include?(display_type&.downcase || '') ||
          dp_display[:resolution] == system_display['resolution']
      end

      next if matching_display

      # Create a new display entry for system-detected display
      new_display = create_display_from_system_profiler(system_display)
      merged << new_display if new_display
    end

    merged
  end

  def create_display_from_system_profiler(system_display)
    # Ensure system_display is a hash and has expected keys
    return nil unless system_display.is_a?(Hash)

    {
      persistent_id: system_display['display_serial_number'] || "system-#{system_display.to_s.hash}",
      contextual_id: system_display['display_serial_number'] || "system-#{system_display.to_s.hash}",
      main: false,
      type: system_display['display_type'] || system_display['type'] || 'Unknown Display',
      resolution: system_display['resolution'] || '1920x1080',
      hertz: system_display['refresh_rate'] || '60',
      color_depth: '8',
      scaling: 'on',
      origin: nil,
      rotation: '0',
      enabled: false # Assume disabled if not in displayplacer
    }
  end

  def create_placeholder_display(display_id, index)
    # Create a placeholder display entry for known but disabled displays
    {
      persistent_id: display_id,
      contextual_id: index.to_s,
      main: false,
      type: "External Display #{index}",
      resolution: '1920x1080', # Default resolution
      hertz: '60',
      color_depth: '8',
      scaling: 'on',
      origin: nil,
      rotation: '0',
      enabled: false
    }
  end

  def parse_display_info(display)
    type_match = display.match(/Type: (.+)/)
    type_str = type_match ? type_match[1] : 'Unknown'

    {
      persistent_id: display.match(/Persistent screen id: (.+)/)&.[](1),
      contextual_id: display.match(/Contextual screen id: (.+)/)&.[](1),
      main: display.include?(' - main display'),
      type: type_str,
      resolution: display.match(/Resolution: (.+)/)&.[](1),
      hertz: display.match(/Hertz: (.+)/)&.[](1),
      color_depth: display.match(/Color Depth: (.+)/)&.[](1),
      scaling: display.match(/Scaling: (.+)/)&.[](1),
      origin: display.match(/Origin: \(([^)]+)\)/)&.[](1),
      rotation: display.match(/Rotation: (.+)/)&.[](1),
      enabled: display.include?('Enabled: true')
    }
  end

  def save_display_config(displays_info)
    config_file = File.expand_path('~/.config/zsh/.game_mode_saved_displays.json')
    config_dir = File.dirname(config_file)

    # Ensure config directory exists
    FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)

    # Save simple list of displays (just their IDs and basic info)
    simple_config = {
      timestamp: Time.now.iso8601,
      display_ids: displays_info.map { |d| d[:persistent_id] },
      displays: displays_info.map do |d|
        {
          id: d[:persistent_id],
          type: d[:type],
          resolution: d[:resolution],
          hertz: d[:hertz],
          scaling: d[:scaling],
          rotation: d[:rotation],
          origin: d[:origin]
        }
      end,
      total_displays: displays_info.length,
      version: '1.0'
    }

    File.write(config_file, JSON.pretty_generate(simple_config))
    log_success("💾 Saved #{displays_info.length} displays to configuration")
  end

  def load_saved_display_config
    config_file = File.expand_path('~/.config/zsh/.game_mode_saved_displays.json')

    unless File.exist?(config_file)
      log_warning('No saved display configuration found')
      return nil
    end

    begin
      config_data = JSON.parse(File.read(config_file))
      log_info("📂 Loading saved configuration from #{File.mtime(config_file)}")
      log_debug("Saved #{config_data['total_displays']} displays")

      # Convert back to display format
      config_data['displays'].map do |display|
        {
          persistent_id: display['id'],
          type: display['type'],
          resolution: display['resolution'],
          hertz: display['hertz'],
          color_depth: '8',
          scaling: display['scaling'],
          rotation: display['rotation'],
          origin: display['origin'],
          enabled: true # Assume we want to enable them
        }
      end
    rescue JSON::ParserError => e
      log_error("Failed to parse saved configuration: #{e.message}")
      nil
    end
  end

  def enable_game_mode(displays_info)
    log_info('🎮 Enabling Game Mode - Single Display Mode')

    # Show current configuration
    display_current_config(displays_info)

    # Find target display (LG OLED or manually specified)
    target_display = find_target_display(displays_info)
    other_displays = displays_info.reject { |d| d == target_display }

    if target_display.nil?
      log_error('❌ Target display not found!')
      log_info('Available displays:')
      displays_info.each_with_index do |display, i|
        status = display[:enabled] ? '✅' : '❌'
        main_indicator = display[:main] ? '👑' : '  '
        puts "  #{i + 1}. #{main_indicator} #{status} #{display[:type]} - #{display[:resolution]}"
      end
      log_info('Use --display <index> to specify which display to use')
      exit(1)
    end

    display_name = if @options[:display]
                     "Display ##{@options[:display]}"
                   else
                     'Auto-detected display'
                   end

    log_success("✅ Using #{display_name}: #{target_display[:type]} (#{target_display[:resolution]})")

    # Disable other displays one by one (don't fail if command fails)
    unless dry_run?
      log_info('🔄 Disabling other displays...')
      other_displays.each do |display|
        command = build_disable_command(display)
        execute_cmd?(command, description: "Disabling #{display[:type]}")
      end

      # Configure target display first
      command = build_target_display_command(target_display)
      execute_display_command(command, target_display, other_displays, 'Game Mode')

      # Then enable HDR on the configured gaming display
      enable_hdr

      # Disable hot corners for gaming
      disable_hot_corners_for_gaming
    end

    return unless dry_run?

    # Show dry run output
    command = build_target_display_command(target_display)
    show_dry_run(command, target_display, other_displays, 'Game Mode')
  end

  def restore_all_displays(displays_info)
    log_info('🔄 Restoring all displays')

    # Show current configuration
    display_current_config(displays_info)

    unless dry_run?

      # Use Python script to restore all displays
      enable_displays_script = File.expand_path('enable_displays.py', __dir__)

      if File.exist?(enable_displays_script)
        log_info('🔄 Using Python script to enable all displays...')
        execute_cmd("python3 #{enable_displays_script}", description: 'Enabling all displays')

        log_progress('⏳ Waiting for displays to initialize...')
        execute_cmd('sleep 3', description: 'Waiting for display initialization')

        execute_cmd('defaults write com.apple.dock autohide -bool true', description: 'Re-enabling Dock auto-hide')

        # Disable HDR first (restore normal mode)
        disable_hdr

        # Restore hot corners configuration
        restore_hot_corners_configuration

        # Run stack-monitors to arrange them properly
        stacked_monitor_script = File.expand_path('stacked-monitor.rb', __dir__)
        if File.exist?(stacked_monitor_script)
          log_info('🖥️  Running stack-monitors to arrange monitors...')
          stack_cmd = "BUNDLE_GEMFILE=/Users/hemantv/zshrc/Gemfile bundle exec ruby #{stacked_monitor_script}"
          success = execute_cmd?(stack_cmd)
          if success
            log_success('✅ Stack monitors configuration applied')
            log_info(execute_cmd(stack_cmd))
          else
            log_warning('⚠️  Could not run stack-monitors automatically')
          end
        else
          log_warning('⚠️  stacked-monitor.rb script not found')
        end
      else
        log_error('❌ Python enable_displays script not found')
      end
    end

    # Show final configuration
    return if dry_run?

    log_info('🔍 Checking final display configuration...')
    sleep(1)
    final_displays = get_display_info
    display_current_config(final_displays)
  end

  def try_enable_display(display)
    log_debug("Trying to enable display: #{display[:type]} (#{display[:persistent_id]})")

    command = build_display_command(display)

    if execute_cmd?(command, description: "Enabling display #{display[:type]}")
      log_success("✅ Successfully enabled #{display[:type]}")
      true
    else
      log_warning("⚠️  Failed to enable #{display[:type]} - trying USB power cycle")
      try_enable_with_usb_reset(display)
    end
  rescue StandardError => e
    log_warning("⚠️  Error enabling #{display[:type]}: #{e.message}")
    false
  end

  def try_enable_with_usb_reset(display)
    # Try Core Graphics display reset first (more reliable)
    if try_core_graphics_reset
      log_progress('⏳ Waiting for displays to re-detect...')
      execute_cmd('sleep 2', description: 'Waiting for display detection')

      # Try to enable the display again after CG reset
      command = build_display_command(display)
      if execute_cmd?(command, description: "Re-enabling display #{display[:type]} after CG reset")
        log_success("✅ Successfully enabled #{display[:type]} after Core Graphics reset")
        return true
      else
        log_warning("⚠️  Still unable to enable #{display[:type]} after Core Graphics reset")
      end
    end

    # Fallback to USB power cycling if Core Graphics reset failed
    if System.command?('uhubctl')
      log_info('🔄 Trying USB power cycle as fallback...')

      if execute_cmd?('uhubctl --action cycle --delay 2', description: 'USB power cycle')
        log_progress('⏳ Waiting for displays to re-detect...')
        execute_cmd('sleep 3', description: 'Waiting for display detection')

        # Try to enable the display again after USB reset
        command = build_display_command(display)
        if execute_cmd?(command, description: "Re-enabling display #{display[:type]} after USB reset")
          log_success("✅ Successfully enabled #{display[:type]} after USB reset")
          return true
        else
          log_warning("⚠️  Still unable to enable #{display[:type]} after USB reset")
        end
      else
        log_warning('⚠️  USB power cycle failed')
      end
    end

    false
  rescue StandardError => e
    log_warning("⚠️  Display reset error: #{e.message}")
    false
  end

  def try_core_graphics_reset
    enable_displays_script = File.expand_path('enable_displays.py', __dir__)

    if File.exist?(enable_displays_script)
      log_info('🔄 Using Core Graphics to reset displays...')
      result = execute_cmd("python3 #{enable_displays_script}", description: 'Core Graphics display reset')
      result && result.include?('Successfully enabled')
    else
      log_debug("Core Graphics reset script not found at #{enable_displays_script}")
      false
    end
  rescue StandardError => e
    log_debug("Core Graphics reset error: #{e.message}")
    false
  end

  def build_display_command(display)
    display_id = display[:persistent_id]
    origin = display[:origin] || '0,0'

    # Build command to enable just this display
    command = "displayplacer \"id:#{display_id} res:#{display[:resolution]} hz:#{display[:hertz]} color_depth:#{display[:color_depth]} scaling:#{display[:scaling]} origin:(#{origin}) degree:#{display[:rotation]} enabled:true\""

    log_info("[Dry Run] Would try: #{command}") if dry_run?

    command
  end

  def find_target_display(displays_info)
    # If display index is specified, use that display
    if @options[:display]
      display_index = @options[:display].to_i - 1 # Convert to 0-based index
      return displays_info[display_index] if display_index >= 0 && display_index < displays_info.length

      log_error("Display index #{@options[:display]} is out of range")
      return nil
    end

    # Auto-detect: First try to find by name (LG OLED/Ultrafine)
    by_name = displays_info.find do |display|
      display[:type].downcase.include?('lg') &&
        (display[:type].downcase.include?('oled') || display[:type].downcase.include?('ultrafine'))
    end

    return by_name if by_name

    # Fallback: identify by resolution patterns common for gaming monitors
    gaming_candidates = displays_info.select do |display|
      %w[3200x1800 3840x2160 4096x2304 5120x2880 3840x1600 3440x1440
         2560x1440].include?(display[:resolution]) ||
        (display[:resolution].include?('3840') && display[:resolution].include?('2160')) ||
        (display[:resolution].include?('5120') && display[:resolution].include?('2880')) ||
        (display[:resolution].include?('3200') && display[:resolution].include?('1800'))
    end

    # If multiple candidates, prefer the main display or the largest one
    main_candidate = gaming_candidates.find { |d| d[:main] }
    return main_candidate if main_candidate

    # Otherwise, prefer the largest resolution
    gaming_candidates.max_by do |display|
      width, height = display[:resolution].split('x').map(&:to_i)
      width * height
    end
  end

  def build_disable_command(display)
    "displayplacer \"id:#{display[:persistent_id]} enabled:false\""
  end

  def build_target_display_command(target_display)
    enabled_display = target_display.merge(origin: '0,0') # Position at origin

    command = "displayplacer \"id:#{enabled_display[:persistent_id]} " +
              "res:#{enabled_display[:resolution]} " +
              "hz:#{enabled_display[:hertz]} " +
              "color_depth:#{enabled_display[:color_depth]} " +
              "scaling:#{enabled_display[:scaling]} " +
              "origin:(#{enabled_display[:origin]}) " +
              "degree:#{enabled_display[:rotation]} " +
              'enabled:true"'

    log_debug("Target display command: #{command}")
    command
  end

  def build_force_enable_command(displays_info)
    # Force enable all displays, using safe defaults for disabled ones
    command_parts = displays_info.map do |display|
      origin = display[:origin] || '0,0'

      if display[:enabled]
        # Use current settings for enabled displays
        "id:#{display[:persistent_id]} " +
          "res:#{display[:resolution]} " +
          "hz:#{display[:hertz]} " +
          "color_depth:#{display[:color_depth]} " +
          "scaling:#{display[:scaling]} " +
          "origin:(#{origin}) " +
          "degree:#{display[:rotation]} " +
          'enabled:true'
      else
        # Use safe defaults for disabled displays
        safe_origin = calculate_safe_origin(display, displays_info)
        "id:#{display[:persistent_id]} " +
          "res:#{display[:resolution]} " +
          "hz:#{display[:hertz]} " +
          "color_depth:#{display[:color_depth]} " +
          "scaling:#{display[:scaling]} " +
          "origin:(#{safe_origin}) " +
          "degree:#{display[:rotation]} " +
          'enabled:true'
      end
    end

    'displayplacer ' + command_parts.map { |part| "\"#{part}\"" }.join(' ')
  end

  def calculate_safe_origin(_display, all_displays)
    # Calculate a safe position for newly enabled displays
    # Place them to the right of existing displays to avoid overlap

    enabled_displays = all_displays.select { |d| d[:enabled] }
    return '0,0' if enabled_displays.empty?

    # Find the rightmost edge of enabled displays
    max_x = enabled_displays.map do |d|
      x = (d[:origin] || '0,0').split(',').first.to_i
      width = d[:resolution].split('x').first.to_i
      x + width
    end.max || 0

    # Position this display to the right
    "#{max_x + 100},0"
  end

  def build_restore_command(displays_info)
    # Enable all displays with their current settings
    command_parts = displays_info.map do |display|
      origin = display[:origin] || '0,0'
      "id:#{display[:persistent_id]} " +
        "res:#{display[:resolution]} " +
        "hz:#{display[:hertz]} " +
        "color_depth:#{display[:color_depth]} " +
        "scaling:#{display[:scaling]} " +
        "origin:(#{origin}) " +
        "degree:#{display[:rotation]}"
    end

    'displayplacer ' + command_parts.map { |part| "\"#{part}\"" }.join(' ')
  end

  def display_current_config(displays_info)
    puts "\n🖥️  Current Display Configuration:"
    puts '┌' + '─' * 78 + '┐'

    displays_info.each_with_index do |display, index|
      label = (index + 1).to_s
      name = display[:type] || 'Unknown Display'
      resolution = display[:resolution] || 'Unknown'
      status = display[:enabled] ? '✅ ON ' : '❌ OFF'
      main_indicator = display[:main] ? '👑' : '  '
      position = display[:origin] ? " at (#{display[:origin]})" : ''

      line_content = "#{label}. #{main_indicator} #{status} #{name} - #{resolution}#{position}"
      padding = 76 - line_content.length
      padding = [0, padding].max

      puts "│ #{line_content}" + ' ' * padding + ' │'
    end

    puts '└' + '─' * 78 + '┘'
  end

  def show_dry_run(command, enabled_display, disabled_displays, mode_name)
    puts "\n🔍 Dry Run Mode - #{mode_name}"
    puts '=' * 50

    if enabled_display
      puts "\n✅ Display to enable:"
      puts "  📺 #{enabled_display[:type]} (#{enabled_display[:resolution]})"
      puts '  📍 Position: (0,0)'
    end

    if disabled_displays && !disabled_displays.empty?
      puts "\n❌ Displays to disable:"
      disabled_displays.each_with_index do |display, i|
        puts "  #{i + 1}. #{display[:type]} (#{display[:resolution]})"
      end
    end

    puts "\n🚀 Command to execute:"
    puts command
    puts "\nRun without --dry-run to execute automatically"
  end

  def execute_display_command(command, enabled_display, _disabled_displays, mode_name)
    puts "\n🔄 #{mode_name} - Applying configuration..."
    log_debug("Command: #{command}")

    success = execute_cmd?(command, description: "#{mode_name} configuration")
    if success
      log_success("#{mode_name} completed successfully!")

      if enabled_display
        log_success("🎮 Game Mode Active: #{enabled_display[:type]}")
      else
        log_success('🔄 All displays restored')
      end
    else
      log_error("Failed to execute #{mode_name} configuration")
      exit(1)
    end
  end

  def enable_hdr
    log_info('🌟 Enabling HDR...')

    unless System.command?('toggle-hdr')
      log_warning('⚠️  toggle-hdr command not found')
      return
    end

    if dry_run?
      log_info('[Dry Run] Would run: toggle-hdr all on')
    else
      result = execute_cmd('toggle-hdr all on', description: 'Enabling HDR')
      log_debug("toggle-hdr output: #{result}")

      if result && (result.include?('Enabling HDR') || result.include?('HDR is already enabled') || result.include?('true'))
        log_success('✅ HDR enabled successfully')
      else
        log_warning('⚠️  Could not enable HDR automatically')
      end
    end
  end

  def disable_hdr
    log_info('🌟 Disabling HDR...')

    unless System.command?('toggle-hdr')
      log_warning('⚠️  toggle-hdr command not found')
      return
    end

    if dry_run?
      log_info('[Dry Run] Would run: toggle-hdr all off')
    else
      result = execute_cmd('toggle-hdr all off', description: 'Disabling HDR')
      log_debug("toggle-hdr output: #{result}")

      if result && (result.include?('Disabling HDR') || result.include?('HDR is already disabled') || result.include?('false'))
        log_success('✅ HDR disabled successfully')
      else
        log_warning('⚠️  Could not disable HDR automatically')
      end
    end
  end

  def dry_run?
    @options[:'dry-run'] || ENV['DRY_RUN'] == '1'
  end

  def debug_mode?
    @options[:debug] || ENV['DEBUG'] == '1'
  end

  # Disable hot corners for gaming to prevent accidental activations
  def disable_hot_corners_for_gaming
    log_info('🎮 Disabling hot corners for gaming...')

    if dry_run?
      log_info('[Dry Run] Would save current hot corners configuration and disable all hot corners')
      return
    end

    # Source the mac utilities and handle hot corners
    mac_utils_file = File.expand_path('.common/mac.zsh', __dir__)

    if File.exist?(mac_utils_file)
      # First save the current configuration
      log_info('💾 Saving current hot corners configuration...')
      save_cmd = "source '#{mac_utils_file}' && mac_save_hot_corners_config"
      execute_cmd?(save_cmd, description: 'Saving hot corners configuration')

      # Then disable hot corners
      log_info('🔧 Disabling all hot corners for gaming...')
      disable_cmd = "source '#{mac_utils_file}' && mac_disable_hot_corners"

      if execute_cmd?(disable_cmd, description: 'Disabling hot corners')
        log_success('✅ Hot corners disabled for gaming')
      else
        log_warning('⚠️  Could not disable hot corners automatically')
      end
    else
      log_warning('⚠️  macOS utilities not found - cannot disable hot corners')
    end
  end

  # Restore hot corners configuration
  def restore_hot_corners_configuration
    log_info('🔄 Restoring hot corners configuration...')

    if dry_run?
      log_info('[Dry Run] Would restore hot corners configuration')
      return
    end

    # Source the mac utilities and restore hot corners
    mac_utils_file = File.expand_path('.common/mac.zsh', __dir__)

    if File.exist?(mac_utils_file)
      # Use bash to source the utilities and call the function
      cmd = "source '#{mac_utils_file}' && mac_restore_hot_corners_config"

      if execute_cmd?(cmd, description: 'Restoring hot corners')
        log_success('✅ Hot corners configuration restored')
      else
        log_warning('⚠️  Could not restore hot corners automatically')
      end
    else
      log_warning('⚠️  macOS utilities not found - cannot restore hot corners')
    end
  end

  def show_examples
    puts <<~EXAMPLES
      Examples:
        #{script_name}                    # Toggle game mode (default behavior)
        #{script_name} on                 # Enable game mode (auto-detect gaming display)
        #{script_name} off                # Restore all monitors
        #{script_name} --display 1        # Use display #1 for game mode
        #{script_name} --restore          # Restore all monitors
        #{script_name} --dry-run          # Preview what would be configured
        #{script_name} --debug            # Show detailed setup analysis
        #{script_name} --restore --dry-run # Preview restore configuration
    EXAMPLES
  end
end

# Execute the script
GameMode.execute if __FILE__ == $0
