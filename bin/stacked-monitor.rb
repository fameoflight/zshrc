#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Script to quickly setup stacked monitors
# Configuration: Non-16" monitor (primary, left, centered between stack), 16" Monitor 2 above 16" Monitor 1
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
    'Configures a 3-monitor setup with a non-16" monitor as primary (left side,
centered between stack) and two 16" monitors stacked vertically on the right.'
  end

  def script_arguments
    ''
  end

  def add_custom_options(opts)
    opts.on('--debug', 'Enable debug output with current setup analysis') do
      @options[:debug] = true
      ENV['DEBUG'] = '1'
    end
  end

  def show_examples
    puts "Examples:"
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
    primary_display, monitor_1, monitor_2 = identify_displays(displays_info)
    configure_positions(primary_display, monitor_1, monitor_2)
    
    command = build_command([primary_display, monitor_1, monitor_2])
    
    if dry_run?
      show_dry_run(command, primary_display, monitor_1, monitor_2)
    else
      execute_monitor_setup(command, primary_display, monitor_1, monitor_2)
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
    return if displays_info.length == 3
    
    log_error("Found #{displays_info.length} displays, expected 3")
    log_info('Available displays:')
    displays_info.each_with_index do |display, i|
      puts "  #{i + 1}. #{display[:type]} - #{display[:resolution]}"
    end
    exit(1)
  end

  def identify_displays(displays_info)
    sixteen_inch_displays = displays_info.select { |display| display[:size_inches] == 16 }
    other_display = displays_info.reject { |display| display[:size_inches] == 16 }.first

    validate_sixteen_inch_count(sixteen_inch_displays, displays_info)
    validate_primary_display(other_display, displays_info)

    primary_display = other_display
    monitor_1 = sixteen_inch_displays[0]  # Bottom 16-inch monitor
    monitor_2 = sixteen_inch_displays[1]  # Top 16-inch monitor

    log_debug("Primary: #{primary_display[:type]}")
    log_debug("Monitor 1: #{monitor_1[:type]}")
    log_debug("Monitor 2: #{monitor_2[:type]}")

    [primary_display, monitor_1, monitor_2]
  end

  def validate_sixteen_inch_count(sixteen_inch_displays, displays_info)
    return unless sixteen_inch_displays.length != 2

    log_error("Found #{sixteen_inch_displays.length} 16-inch displays, expected 2")
    show_available_displays(displays_info)
    exit(1)
  end

  def validate_primary_display(other_display, displays_info)
    return unless other_display.nil?

    log_error('Could not find a non-16-inch display to use as primary')
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
    if main_display && main_display[:size_inches] == 16
      puts '  🚨 Main display is a 16-inch monitor (should be the non-16" display)'
    end

    # Check if displays are overlapping or have gaps
    puts "\n🔧 RECOMMENDED CONFIGURATION:"
    sixteen_inch = displays_info.select { |d| d[:size_inches] == 16 }
    non_sixteen = displays_info.reject { |d| d[:size_inches] == 16 }.first

    if sixteen_inch.length == 2 && non_sixteen
      puts "  Primary: #{non_sixteen[:type]} should be at (0,0)"
      puts '  Stack: Two 16" monitors should be to the right, vertically stacked'
    else
      puts '  ❌ Unexpected display configuration'
    end

    puts "\n" + '=' * 50
  end

  def configure_positions(primary_display, monitor_1, monitor_2)
    log_debug('Calculating monitor positions...')

    # Parse resolutions
    primary_width, primary_height = parse_resolution(primary_display[:resolution])
    _, mon1_height = parse_resolution(monitor_1[:resolution])
    _, mon2_height = parse_resolution(monitor_2[:resolution])

    # Position primary display at origin
    primary_display[:origin] = '0,0'

    # Position monitors to the right of primary, stacked
    stack_x = primary_width + SPACING

    # Calculate stack positioning
    total_stack_height = mon1_height + mon2_height

    if debug_mode?
      log_debug("Primary display: #{primary_width}x#{primary_height} (Y: 0 to #{primary_height})")
      log_debug("Stack total height: #{total_stack_height} (#{mon1_height} + #{mon2_height})")
      log_debug("Stack position X: #{stack_x} (primary width #{primary_width} + spacing #{SPACING})")
    end

    # Center the stack vertically relative to primary display center
    primary_center_y = primary_height / 2
    stack_center_y = primary_center_y - (total_stack_height / 2)

    log_debug("Primary center Y: #{primary_center_y}, Stack will start at Y: #{stack_center_y}") if debug_mode?

    # Monitor 1 (bottom of stack) - starts at stack_center_y
    monitor_1_y = stack_center_y + mon2_height # Bottom monitor goes below top monitor
    monitor_1[:origin] = "#{stack_x},#{monitor_1_y}"

    # Monitor 2 (top of stack) - goes above monitor 1
    monitor_2_y = stack_center_y
    monitor_2[:origin] = "#{stack_x},#{monitor_2_y}"

    if debug_mode?
      log_debug("Monitor 2 (top): Y #{monitor_2_y} to #{monitor_2_y + mon2_height}")
      log_debug("Monitor 1 (bottom): Y #{monitor_1_y} to #{monitor_1_y + mon1_height}")
    end

    log_debug("Primary position: #{primary_display[:origin]}")
    log_debug("Monitor 1 position: #{monitor_1[:origin]}")
    log_debug("Monitor 2 position: #{monitor_2[:origin]}")
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

  def show_configuration(primary_display, monitor_1, monitor_2)
    puts "\n📺 Monitor Configuration:"
    puts "  Primary Display (#{primary_display[:type]}): Left side, centered between stack"
    puts "  Monitor 1 (#{monitor_1[:type]}): Right side, bottom of stack"
    puts "  Monitor 2 (#{monitor_2[:type]}): Right side, top of stack"

    puts "\n📍 Calculated Positions:"
    puts "  Primary: #{primary_display[:origin]} (#{primary_display[:resolution]})"
    puts "  Monitor 1: #{monitor_1[:origin]} (#{monitor_1[:resolution]})"
    puts "  Monitor 2: #{monitor_2[:origin]} (#{monitor_2[:resolution]})"
  end

  def show_dry_run(command, primary_display, monitor_1, monitor_2)
    show_configuration(primary_display, monitor_1, monitor_2)

    puts "\n🚀 Command to execute:"
    puts command
    puts "\nRun without --dry-run to execute automatically"
  end

  def execute_monitor_setup(command, primary_display, monitor_1, monitor_2)
    show_configuration(primary_display, monitor_1, monitor_2)

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
