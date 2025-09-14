#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Script to quickly setup stacked monitors for 4-monitor configuration
# Configuration: Two 1920x1080 monitors stacked on left, main monitor in center, portrait monitor on right
class StackedMonitor < ScriptBase
  SPACING = 20 # Pixels between monitors

  # Script metadata for standardized help text
  def script_emoji
    '📺'
  end

  def script_title
    'Stacked Monitor Setup'
  end

  def script_description
    'Configures a 4-monitor setup: two 1920x1080 monitors stacked on left side,
main 3200x1800 monitor in center, and 1800x3200 portrait monitor on right.'
  end

  def script_arguments
    ''
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name}                    # Configure stacked monitors"
    puts "  #{script_name} --debug           # Show current setup and debug info"
    puts "  #{script_name} --dry-run         # Preview what would be configured"
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

  def run
    log_banner(script_title)

    displays_info = get_display_info
    show_current_setup(displays_info) if debug_mode?

    validate_display_count(displays_info)
    main_monitor, left_bottom, left_top, portrait_monitor = identify_displays(displays_info)
    configure_positions(main_monitor, left_bottom, left_top, portrait_monitor)

    command = build_command([main_monitor, left_bottom, left_top, portrait_monitor])

    if dry_run?
      show_dry_run(command, main_monitor, left_bottom, left_top, portrait_monitor)
    else
      execute_monitor_setup(command, main_monitor, left_bottom, left_top, portrait_monitor)
    end

    show_completion(script_title)
  end

  private

  def debug_mode?
    @options[:debug] || ENV['DEBUG'] == '1'
  end

  def validate_display_dependency
    return if System.command?('displayplacer')

    log_error('displayplacer is not installed')
    log_info('Install with: brew install jakehilborn/jakehilborn/displayplacer')
    exit(1)
  end

  def get_display_info
    log_debug('Getting display information...')

    display_list = execute_cmd('displayplacer list', description: 'Getting display information')
    unless display_list
      log_error('Failed to get display list')
      exit(1)
    end

    displays = display_list.split("\n\n").select { |block| block.include?('Persistent screen id:') }
    displays.map { |display| parse_display_info(display) }
  end

  def parse_display_info(display)
    type_match = display.match(/Type: (.+)/)
    type_str = type_match ? type_match[1] : 'Unknown'
    size_match = type_str.match(/(\d+)\s*inch/)
    size_inches = size_match ? size_match[1].to_i : 0

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
      size_inches: size_inches
    }
  end

  def validate_display_count(displays_info)
    return if displays_info.length == 4

    log_error("Found #{displays_info.length} displays, expected 4")
    log_info('Available displays:')
    displays_info.each_with_index do |display, i|
      puts "  #{i + 1}. #{display[:type]} - #{display[:resolution]}"
    end
    exit(1)
  end

  def identify_displays(displays_info)
    # Find displays by resolution patterns
    left_monitors = displays_info.select { |d| d[:resolution] == '1920x1080' }
    main_monitor = displays_info.find { |d| d[:resolution] == '3200x1800' }
    portrait_monitor = displays_info.find { |d| d[:resolution] == '1800x3200' }

    validate_monitor_config(left_monitors, main_monitor, portrait_monitor, displays_info)

    # Return all four monitors
    left_bottom = left_monitors[0]  # Bottom left monitor
    left_top = left_monitors[1]     # Top left monitor

    log_debug("Main (center): #{main_monitor[:type]}")
    log_debug("Portrait (right): #{portrait_monitor[:type]}")
    log_debug("Left bottom: #{left_bottom[:type]}")
    log_debug("Left top: #{left_top[:type]}")

    [main_monitor, left_bottom, left_top, portrait_monitor]
  end

  def validate_monitor_config(left_monitors, main_monitor, portrait_monitor, displays_info)
    errors = []

    errors << "Expected 2 monitors with 1920x1080 resolution, found #{left_monitors.length}" if left_monitors.length != 2
    errors << "Could not find main monitor (3200x1800)" if main_monitor.nil?
    errors << "Could not find portrait monitor (1800x3200)" if portrait_monitor.nil?

    return if errors.empty?

    errors.each { |error| log_error(error) }
    show_available_displays(displays_info)
    exit(1)
  end

  def show_available_displays(displays_info)
    log_info('Available displays:')
    displays_info.each_with_index do |display, i|
      puts "  #{i + 1}. #{display[:type]} - #{display[:resolution]} (#{display[:size_inches]}\")"
    end
  end

  def show_current_setup(displays_info)
    puts "\n🔍 CURRENT MONITOR SETUP DEBUG INFO"
    puts '=' * 50

    displays_info.each_with_index do |display, i|
      puts "\nDisplay #{i + 1}:"
      puts "  Type: #{display[:type]}"
      puts "  Size: #{display[:size_inches]}\" #{display[:size_inches] == 16 ? '(16-inch monitor)' : '(primary candidate)'}"
      puts "  Resolution: #{display[:resolution]}"
      puts "  Current Position: #{display[:origin] || 'Unknown'}"
      puts "  Persistent ID: #{display[:persistent_id]}"
      puts "  Main Display: #{display[:main] ? '✅ Yes' : '❌ No'}"
      puts "  Hertz: #{display[:hertz]}"
      puts "  Color Depth: #{display[:color_depth]}"
      puts "  Scaling: #{display[:scaling]}"
      puts "  Rotation: #{display[:rotation]}"
    end

    # Show spatial arrangement
    puts "\n📍 SPATIAL ARRANGEMENT:"
    sorted_displays = displays_info.sort_by do |d|
      [d[:origin]&.split(',')&.first&.to_i || 0, d[:origin]&.split(',')&.last&.to_i || 0]
    end

    sorted_displays.each do |display|
      x, y = display[:origin]&.split(',')&.map(&:to_i) || [0, 0]
      width, height = parse_resolution(display[:resolution])
      puts "  #{display[:type]} (#{display[:size_inches]}\"):"
      puts "    Position: (#{x}, #{y})"
      puts "    Size: #{width} x #{height}"
      puts "    Right edge: #{x + width}, Bottom edge: #{y + height}"
      puts "    #{display[:main] ? '👑 MAIN DISPLAY' : ''}"
    end

    # Analyze potential issues
    puts "\n⚠️  POTENTIAL ISSUES:"
    main_display = displays_info.find { |d| d[:main] }
    expected_main = displays_info.find { |d| d[:resolution] == '3200x1800' }
    if main_display && main_display[:resolution] != '3200x1800'
      puts "  🚨 Main display is #{main_display[:resolution]} (should be 3200x1800)"
    end

    # Check if displays are overlapping or have gaps
    puts "\n🔧 RECOMMENDED CONFIGURATION:"
    left_monitors = displays_info.select { |d| d[:resolution] == '1920x1080' }
    main_monitor = displays_info.find { |d| d[:resolution] == '3200x1800' }
    portrait_monitor = displays_info.find { |d| d[:resolution] == '1800x3200' }

    if left_monitors.length == 2 && main_monitor && portrait_monitor
      puts "  Main (#{main_monitor[:type]}): Should be at center (0,0)"
      puts '  Left Stack: Two 1920x1080 monitors stacked on left side'
      puts "  Portrait (#{portrait_monitor[:type]}): Should be on right side"
    else
      puts '  ❌ Unexpected display configuration'
    end

    puts "\n" + '=' * 50
  end

  def configure_positions(main_monitor, left_bottom, left_top, portrait_monitor)
    log_debug('Calculating monitor positions...')

    # Parse resolutions
    left_width, left_height = parse_resolution(left_bottom[:resolution])  # 1920x1080
    main_width, main_height = parse_resolution(main_monitor[:resolution]) # 3200x1800
    portrait_width, portrait_height = parse_resolution(portrait_monitor[:resolution]) # 1800x3200

    # Position main monitor at origin (center)
    main_monitor[:origin] = '0,0'

    # Position left stack to the left of main monitor
    left_stack_x = -(left_width + SPACING)

    # Calculate left stack positioning - monitor 2 (top) at 1/3 of main display height
    # Monitor 2 (left top) starts at 1/3 of main display height
    left_top_y = main_height / 3
    left_top[:origin] = "#{left_stack_x},#{left_top_y}"

    # Monitor 1 (left bottom) positioned below monitor 2
    left_bottom_y = left_top_y + left_height
    left_bottom[:origin] = "#{left_stack_x},#{left_bottom_y}"

    # Portrait monitor to the right of main monitor
    portrait_x = main_width + SPACING
    # Center portrait monitor vertically with main monitor
    main_center_y = main_height / 2
    portrait_y = main_center_y - (portrait_height / 2)
    portrait_monitor[:origin] = "#{portrait_x},#{portrait_y}"

    if debug_mode?
      log_debug("Main monitor: #{main_width}x#{main_height} at (0,0)")
      log_debug("Left stack: 2x #{left_width}x#{left_height} monitors at X: #{left_stack_x}")
      log_debug("Left top: Y #{left_top_y} to #{left_top_y + left_height} (at 1/3 of main height: #{main_height / 3})")
      log_debug("Left bottom: Y #{left_bottom_y} to #{left_bottom_y + left_height}")
      log_debug("Portrait: #{portrait_width}x#{portrait_height} at (#{portrait_x}, #{portrait_y})")
    end

    log_debug("Main position: #{main_monitor[:origin]}")
    log_debug("Left top position: #{left_top[:origin]}")
    log_debug("Left bottom position: #{left_bottom[:origin]}")
    log_debug("Portrait position: #{portrait_monitor[:origin]}")
  end

  def parse_resolution(resolution)
    width, height = resolution.split('x').map(&:to_i)
    [width, height]
  end

  def build_command(displays)
    command_parts = displays.map do |display|
      "id:#{display[:persistent_id]} " +
        "res:#{display[:resolution]} " +
        "hz:#{display[:hertz]} " +
        "color_depth:#{display[:color_depth]} " +
        "scaling:#{display[:scaling]} " +
        "origin:(#{display[:origin]}) " +
        "degree:#{display[:rotation]}"
    end

    'displayplacer ' + command_parts.map { |part| "\"#{part}\"" }.join(' ')
  end

  def show_configuration(main_monitor, left_bottom, left_top, portrait_monitor)
    puts "\n📺 Monitor Configuration:"
    puts "  Main Display (#{main_monitor[:type]}): Center position"
    puts "  Left Stack Bottom (#{left_bottom[:type]}): Left side, lower monitor"
    puts "  Left Stack Top (#{left_top[:type]}): Left side, upper monitor"
    puts "  Portrait Monitor (#{portrait_monitor[:type]}): Right side, vertical orientation"

    puts "\n📍 Calculated Positions:"
    puts "  Main: #{main_monitor[:origin]} (#{main_monitor[:resolution]})"
    puts "  Left Bottom: #{left_bottom[:origin]} (#{left_bottom[:resolution]})"
    puts "  Left Top: #{left_top[:origin]} (#{left_top[:resolution]})"
    puts "  Portrait: #{portrait_monitor[:origin]} (#{portrait_monitor[:resolution]})"
  end

  def show_dry_run(command, main_monitor, left_bottom, left_top, portrait_monitor)
    show_configuration(main_monitor, left_bottom, left_top, portrait_monitor)

    puts "\n🚀 Command to execute:"
    puts command
    puts "\nRun without --dry-run to execute automatically"
  end

  def execute_monitor_setup(command, main_monitor, left_bottom, left_top, portrait_monitor)
    show_configuration(main_monitor, left_bottom, left_top, portrait_monitor)

    log_progress('🔄 Executing monitor setup...')
    log_debug("Command: #{command}")

    success = execute_cmd?(command, description: 'Applying monitor configuration')
    if success
      log_success('Monitor arrangement completed successfully!')
    else
      log_error('Failed to execute displayplacer command')
      exit(1)
    end
  end

  def show_examples
    puts <<~EXAMPLES
      Examples:
        #{script_name}                    # Run interactive setup
        #{script_name} --dry-run          # Show configuration without applying
        #{script_name} --debug            # Show detailed setup analysis
        #{script_name} --dry-run --debug  # Show everything without applying
    EXAMPLES
  end
end

# Execute the script
StackedMonitor.execute if __FILE__ == $0
