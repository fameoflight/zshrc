#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/archive/script_base'

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

    validate_display_count(displays_info)
    main_monitor, left_bottom, left_top, portrait_monitor = identify_displays(displays_info)

    # Always show current configuration in box style first
    display_monitor_config_box("🖥️  Current Monitor Configuration:", displays_info, show_current_positions: true)

    # Show current spatial layout
    display_spatial_layout(displays_info, "📍 Current Monitor Layout")

    # Show detailed debug info if requested
    show_current_setup(displays_info) if debug_mode?

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
    puts "\n🔍 DETAILED MONITOR DEBUG INFO"
    puts '=' * 50

    puts "\n📊 Detailed Display Information:"
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

    # Position left stack to the left of main monitor (touching)
    left_stack_x = -left_width

    # Calculate left stack positioning - stack monitors touching each other
    # Position left top monitor at 1/3 of main display height
    left_top_y = main_height / 3
    left_top[:origin] = "#{left_stack_x},#{left_top_y}"

    # Position left bottom monitor directly below left top (touching)
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

  def display_monitor_config_box(title, monitors, show_current_positions: false)
    puts "\n#{title}"
    puts "┌" + "─" * 78 + "┐"

    monitors.each_with_index do |monitor, index|
      label = (index + 1).to_s
      name = monitor[:type] || "Unknown Monitor"
      resolution = monitor[:resolution] || "Unknown"
      rotation = monitor[:rotation] || "0"

      # Add rotation indicator
      rotation_indicator = case rotation.to_i
                           when 90
                             " ↻90°"
                           when 180
                             " ↻180°"
                           when 270
                             " ↻270°"
                           else
                             ""
                           end

      # Format position info
      position_info = if show_current_positions && monitor[:origin]
                        " at (#{monitor[:origin]})"
                      elsif !show_current_positions && monitor[:calculated_origin]
                        " → (#{monitor[:calculated_origin]})"
                      else
                        ""
                      end

      # Create the line with proper spacing
      line_content = "#{label}. #{name} - #{resolution}#{rotation_indicator}#{position_info}"
      padding = 76 - line_content.length
      padding = [0, padding].max # Ensure non-negative padding

      puts "│ #{line_content}" + " " * padding + " │"
    end

    puts "└" + "─" * 78 + "┘"
  end

  def display_spatial_layout(monitors, title = "📍 Spatial Monitor Layout")
    puts "\n#{title}"

    # Parse positions and find bounds
    monitor_positions = monitors.map do |monitor|
      x, y = if monitor[:origin]
               monitor[:origin].split(',').map(&:to_i)
             else
               [0, 0]
             end
      width, height = parse_resolution(monitor[:resolution])
      rotation = (monitor[:rotation] || "0").to_i

      # Don't swap dimensions - displayplacer already reports correct pixel dimensions
      # The resolution already reflects the actual screen orientation

      {
        monitor: monitor,
        x: x,
        y: y,
        width: width,
        height: height,
        right: x + width,
        bottom: y + height,
        rotation: rotation
      }
    end

    # Find layout bounds
    min_x = monitor_positions.map { |m| m[:x] }.min
    max_x = monitor_positions.map { |m| m[:right] }.max
    min_y = monitor_positions.map { |m| m[:y] }.min
    max_y = monitor_positions.map { |m| m[:bottom] }.max

    # Scale factor for ASCII representation (pixels per character)
    scale_x = [(max_x - min_x) / 60.0, 1].max
    scale_y = [(max_y - min_y) / 20.0, 1].max

    # Create ASCII grid
    grid_width = 70
    grid_height = 25
    grid = Array.new(grid_height) { Array.new(grid_width, ' ') }

    # Draw each monitor on the grid
    monitor_positions.each_with_index do |pos, index|
      # Convert to grid coordinates
      grid_x = ((pos[:x] - min_x) / scale_x).round
      grid_y = ((pos[:y] - min_y) / scale_y).round
      grid_width_m = [((pos[:width] / scale_x).round), 1].max
      grid_height_m = [((pos[:height] / scale_y).round), 1].max

      label = (index + 1).to_s
      rotation = pos[:rotation]

      # Create rotation indicator
      rotation_char = case rotation
                      when 90
                        '↻'
                      when 180
                        '↺'
                      when 270
                        '↻'
                      else
                        label
                      end

      # Draw monitor box
      (0...grid_height_m).each do |dy|
        (0...grid_width_m).each do |dx|
          gx = grid_x + dx
          gy = grid_y + dy

          if gx >= 0 && gx < grid_width && gy >= 0 && gy < grid_height
            if dy == 0 || dy == grid_height_m - 1
              grid[gy][gx] = '─'
            elsif dx == 0 || dx == grid_width_m - 1
              grid[gy][gx] = '│'
            elsif dy == grid_height_m / 2 && dx == grid_width_m / 2
              grid[gy][gx] = rotation_char
            elsif rotation != 0 && dy == grid_height_m / 2 && dx == grid_width_m / 2 + 1
              grid[gy][gx] = label if gx < grid_width
            else
              grid[gy][gx] = ' ' if grid[gy][gx] == ' '
            end
          end
        end
      end

      # Draw corners
      corners = [
        [grid_x, grid_y, '┌'],
        [grid_x + grid_width_m - 1, grid_y, '┐'],
        [grid_x, grid_y + grid_height_m - 1, '└'],
        [grid_x + grid_width_m - 1, grid_y + grid_height_m - 1, '┘']
      ]

      corners.each do |x, y, char|
        if x >= 0 && x < grid_width && y >= 0 && y < grid_height
          grid[y][x] = char
        end
      end
    end

    # Print the grid
    puts "┌" + "─" * grid_width + "┐"
    grid.each do |row|
      puts "│" + row.join('') + "│"
    end
    puts "└" + "─" * grid_width + "┘"

    # Print legend
    puts "\nLegend:"
    monitors.each_with_index do |monitor, index|
      name = monitor[:type] || "Unknown Monitor"
      resolution = monitor[:resolution] || "Unknown"
      rotation = (monitor[:rotation] || "0").to_i

      rotation_info = case rotation
                      when 90
                        " - Portrait 90° ↻"
                      when 180
                        " - Inverted 180° ↺"
                      when 270
                        " - Portrait 270° ↻"
                      else
                        " - Landscape"
                      end

      puts "  #{index + 1}. #{name} (#{resolution})#{rotation_info}"
    end
  end

  def show_configuration(main_monitor, left_bottom, left_top, portrait_monitor)
    # Store calculated positions for box display
    monitors = [
      main_monitor.merge(calculated_origin: main_monitor[:origin]),
      left_bottom.merge(calculated_origin: left_bottom[:origin]),
      left_top.merge(calculated_origin: left_top[:origin]),
      portrait_monitor.merge(calculated_origin: portrait_monitor[:origin])
    ]

    display_monitor_config_box("📺 Final Monitor Configuration:", monitors)

    # Show spatial layout
    display_spatial_layout([main_monitor, left_bottom, left_top, portrait_monitor], "📍 Target Monitor Layout")

    puts "\n📍 Layout Description:"
    puts "  1. Main Display: Center position (#{main_monitor[:resolution]})"
    puts "  2. Left Stack Bottom: Left side, lower monitor (#{left_bottom[:resolution]})"
    puts "  3. Left Stack Top: Left side, upper monitor (#{left_top[:resolution]})"
    puts "  4. Portrait Monitor: Right side, vertical orientation (#{portrait_monitor[:resolution]})"
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
