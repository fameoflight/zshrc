#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../.common/script_base'

# Script to quickly setup stacked monitors for 4-monitor configuration
# Configuration: Two 1920x1080 monitors stacked on left or right side, main monitor in center, portrait monitor on opposite side
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
    'Configures two 1920x1080 16-inch external monitors to be stacked on left or right side.
Works with any number of total monitors (3, 4, 5+).'
  end

  def script_arguments
    '[right|left]'
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name}                    # Configure stacked monitors on right side (default)"
    puts "  #{script_name} right              # Configure stacked monitors on right side"
    puts "  #{script_name} left               # Configure stacked monitors on left side"
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

    # Validate stack direction argument
    direction = stack_direction_arg
    if direction && !['left', 'right'].include?(direction)
      log_error("Invalid direction '#{direction}'. Use 'left' or 'right'.")
      exit(1)
    end

    super
  end

  def run
    log_banner(script_title)

    displays_info = get_display_info

    external_monitors = find_external_monitors(displays_info)
    validate_external_monitors(external_monitors)

    # Always show current configuration in box style first
    display_monitor_config_box("🖥️  Current Monitor Configuration:", displays_info, show_current_positions: true)

    # Show current spatial layout
    display_spatial_layout(displays_info, "📍 Current Monitor Layout")

    # Show detailed debug info if requested
    show_current_setup(displays_info) if debug_mode?

    configure_external_monitors(external_monitors)

    # Build command for all displays, only positioning the external monitors
    command = build_external_command(displays_info, external_monitors)

    if dry_run?
      show_dry_run(command, external_monitors)
    else
      execute_monitor_setup(command, external_monitors)
    end

    show_completion(script_title)
  end

  private

  def debug_mode?
    @options[:debug] || ENV['DEBUG'] == '1'
  end

  def stack_direction_arg
    @stack_direction_arg ||= begin
      # Get the first non-option argument (not starting with --)
      args = ARGV.reject { |arg| arg.start_with?('--') }
      args.first
    end
  end

  def stack_direction
    @stack_direction ||= (stack_direction_arg || 'right').to_sym
  end

  def validate_display_dependency
    return if System.command?('displayplacer')

    log_error('displayplacer is not installed')
    log_info('Install with: brew install jakehilborn/jakehilborn/displayplacer')
    exit(1)
  end

  def get_display_info
    log_debug('Getting display information...')

    display_list = if dry_run?
                     `displayplacer list 2>/dev/null`
                   else
                     execute_cmd('displayplacer list', description: 'Getting display information')
                   end

    unless display_list && !display_list.empty?
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

  def find_external_monitors(displays_info)
    # Find the two 1920x1080 16-inch external monitors
    external_monitors = displays_info.select { |d| d[:resolution] == '1920x1080' && !d[:type].include?('MacBook') }
    log_debug("Found #{external_monitors.length} external 1920x1080 monitors")
    external_monitors
  end

  def validate_external_monitors(external_monitors)
    return if external_monitors.length == 2

    log_error("Found #{external_monitors.length} external 1920x1080 monitors, expected 2")
    log_info('This script only works with two 16-inch external monitors (1920x1080).')
    exit(1)
  end

  def configure_external_monitors(external_monitors)
    log_debug('Configuring external monitor positions...')

    # Parse resolutions
    width, height = parse_resolution(external_monitors.first[:resolution])  # 1920x1080

    # Find main display (MacBook) as reference point
    all_displays = get_display_info
    main_display = all_displays.find { |d| d[:main] || d[:type].include?('MacBook') }

    # Use main display position as reference, fallback to (0,0)
    if main_display && main_display[:origin]
      reference_x, reference_y = main_display[:origin].split(',').map(&:to_i)
    else
      reference_x, reference_y = 0, 0
    end

    # Position monitors based on direction
    if stack_direction == :right
      # Position to the right of main display
      stack_x = reference_x + 2056 + SPACING  # MacBook width is 2056
    else
      # Position to the left of main display
      stack_x = reference_x - width
    end

    # Stack the monitors vertically with touching edges
    # Bottom monitor aligned with 1/3 of main display height (current top goes to bottom)
    main_height = 1329  # MacBook height
    bottom_y = reference_y + (main_height / 3)
    external_monitors[0][:origin] = "#{stack_x},#{bottom_y}"

    # Top monitor directly above bottom (touching) - current bottom goes to top
    top_y = bottom_y - height
    external_monitors[1][:origin] = "#{stack_x},#{top_y}"

    if debug_mode?
      log_debug("Main display reference: #{reference_x},#{reference_y}")
      log_debug("Stack direction: #{stack_direction}")
      log_debug("External monitors: 2x #{width}x#{height} monitors")
      log_debug("Stack position: X: #{stack_x}")
      log_debug("Top monitor: Y #{top_y} to #{top_y + height}")
      log_debug("Bottom monitor: Y #{bottom_y} to #{bottom_y + height}")
    end

    log_debug("External monitor positions set:")
    external_monitors.each_with_index do |monitor, i|
      log_debug("  #{i + 1}. #{monitor[:type]}: #{monitor[:origin]}")
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

    # Analyze external monitors
    puts "\n⚠️  EXTERNAL MONITOR ANALYSIS:"
    external_monitors = displays_info.select { |d| d[:resolution] == '1920x1080' && !d[:type].include?('MacBook') }

    if external_monitors.length == 2
      puts "  ✅ Found 2 external 16-inch monitors (1920x1080)"
      external_monitors.each_with_index do |monitor, i|
        puts "    #{i + 1}. #{monitor[:type]} at (#{monitor[:origin]})"
      end
    else
      puts "  ❌ Found #{external_monitors.length} external monitors, expected 2"
    end

    # Check if displays are overlapping or have gaps
    puts "\n🔧 RECOMMENDED CONFIGURATION:"
    if external_monitors.length == 2
      puts "  Stack: Two 16-inch external monitors will be positioned vertically"
      puts "  Direction: #{stack_direction == :right ? 'Right side' : 'Left side'} of reference point"
      puts "  Other monitors: Will remain in their current positions"
    else
      puts '  ❌ This script requires exactly 2 external 16-inch monitors'
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

    # Position stack based on direction
    stack_x = if stack_direction == :right
                main_width + SPACING
              else
                -left_width
              end

    # Calculate stack positioning - stack monitors touching each other
    # Position top monitor at 1/3 of main display height
    top_y = main_height / 3
    left_top[:origin] = "#{stack_x},#{top_y}"

    # Position bottom monitor directly below top (touching)
    bottom_y = top_y + left_height
    left_bottom[:origin] = "#{stack_x},#{bottom_y}"

    # Position portrait monitor on opposite side from stack
    portrait_x = if stack_direction == :right
                   -left_width - SPACING - portrait_width
                 else
                   main_width + SPACING
                 end
    # Center portrait monitor vertically with main monitor
    main_center_y = main_height / 2
    portrait_y = main_center_y - (portrait_height / 2)
    portrait_monitor[:origin] = "#{portrait_x},#{portrait_y}"

    if debug_mode?
      log_debug("Main monitor: #{main_width}x#{main_height} at (0,0)")
      log_debug("Stack direction: #{stack_direction}")
      log_debug("Stack: 2x #{left_width}x#{left_height} monitors at X: #{stack_x}")
      log_debug("Stack top: Y #{top_y} to #{top_y + left_height} (at 1/3 of main height: #{main_height / 3})")
      log_debug("Stack bottom: Y #{bottom_y} to #{bottom_y + left_height}")
      log_debug("Portrait: #{portrait_width}x#{portrait_height} at (#{portrait_x}, #{portrait_y})")
    end

    log_debug("Main position: #{main_monitor[:origin]}")
    log_debug("Stack top position: #{left_top[:origin]}")
    log_debug("Stack bottom position: #{left_bottom[:origin]}")
    log_debug("Portrait position: #{portrait_monitor[:origin]}")
  end

  def parse_resolution(resolution)
    width, height = resolution.split('x').map(&:to_i)
    [width, height]
  end

  def build_external_command(all_displays, external_monitors)
    # Build displayplacer command ONLY for the two 16-inch external monitors
    # Completely ignore all other displays

    # Get the original displayplacer list output to get exact settings for external monitors
    # Always execute this command even in dry-run mode since we need current monitor info
    display_list = if dry_run?
                     `displayplacer list 2>/dev/null`
                   else
                     execute_cmd('displayplacer list', description: 'Getting external monitor configuration')
                   end
    return nil unless display_list && !display_list.empty?

    # Parse display blocks to find our external monitors
    display_blocks = display_list.split("\n\n").select { |block| block.include?('Persistent screen id:') }

    command_parts = display_blocks.map do |block|
      persistent_id = block.match(/Persistent screen id: (.+)/)&.[](1)

      # Check if this is one of our external monitors - ONLY process these
      external_monitor = external_monitors.find { |ext| ext[:persistent_id] == persistent_id }

      if external_monitor
        # For external monitors, use new position but preserve all other settings exactly
        build_display_config_from_block(block, external_monitor[:origin])
      else
        # Skip all other monitors completely - don't include them in the command at all
        nil
      end
    end.compact

    'displayplacer ' + command_parts.map { |part| "\"#{part}\"" }.join(' ')
  end

  def build_display_config_from_block(display_block, new_origin)
    # Extract configuration from the display block
    persistent_id = display_block.match(/Persistent screen id: (.+)/)&.[](1)
    resolution = display_block.match(/Resolution: (.+)/)&.[](1)
    hertz = display_block.match(/Hertz: (.+)/)&.[](1)
    color_depth = display_block.match(/Color Depth: (.+)/)&.[](1)
    scaling = display_block.match(/Scaling: (.+)/)&.[](1)
    origin = new_origin || display_block.match(/Origin: \(([^)]+)\)/)&.[](1)
    rotation = display_block.match(/Rotation: (.+)/)&.[](1)

    return nil unless persistent_id && resolution && hertz && color_depth && scaling && origin && rotation

    "id:#{persistent_id} res:#{resolution} hz:#{hertz} color_depth:#{color_depth} scaling:#{scaling} origin:(#{origin}) degree:#{rotation}"
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
      # Use custom name if provided, otherwise use monitor type
      name = monitor[:name] || monitor[:type] || "Unknown Monitor"
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
    stack_side = stack_direction == :right ? "Right" : "Left"
    portrait_side = stack_direction == :right ? "Left" : "Right"
    puts "  2. Stack Bottom: #{stack_side} side, lower monitor (#{left_bottom[:resolution]})"
    puts "  3. Stack Top: #{stack_side} side, upper monitor (#{left_top[:resolution]})"
    puts "  4. Portrait Monitor: #{portrait_side} side, vertical orientation (#{portrait_monitor[:resolution]})"
  end

  def show_external_configuration(external_monitors)
    # Store calculated positions for box display
    monitors = external_monitors.map.with_index do |monitor, i|
      label = i == 0 ? "Stack Bottom" : "Stack Top"  # Flipped labels
      monitor.merge(calculated_origin: monitor[:origin], name: label)
    end

    display_monitor_config_box("📺 External Monitor Configuration:", monitors)

    puts "\n📍 Configuration Description:"
    stack_side = stack_direction == :right ? "Right" : "Left"
    puts "  Stack Direction: #{stack_side} side"
    puts "  Stack Top: Upper external monitor (#{external_monitors[1][:resolution]})"  # Index 1 now top
    puts "  Stack Bottom: Lower external monitor (#{external_monitors[0][:resolution]})"  # Index 0 now bottom
    puts "  Other monitors: Will remain in current positions"
  end

  def show_dry_run(command, external_monitors)
    show_external_configuration(external_monitors)

    if command.nil?
      log_error('Failed to build displayplacer command')
      exit(1)
    end

    # Show target layout with all monitors in their positions
    puts "\n📍 Target Monitor Layout (After Configuration):"
    target_displays = get_target_display_layout(external_monitors)
    display_spatial_layout(target_displays, "📍 Complete Target Layout")

    puts "\n🚀 Command to execute:"
    puts command
    puts "\nRun without --dry-run to execute automatically"
  end

  def get_target_display_layout(external_monitors)
    # Get current displays again to build target layout
    displays_info = get_display_info

    # Update the external monitors with their new positions
    displays_info.map do |display|
      external_monitor = external_monitors.find { |ext| ext[:persistent_id] == display[:persistent_id] }
      if external_monitor
        # Use new position for external monitors
        display.merge(origin: external_monitor[:origin])
      else
        # Keep original position for other monitors
        display
      end
    end
  end

  def execute_monitor_setup(command, external_monitors)
    show_external_configuration(external_monitors)

    log_progress('🔄 Executing monitor setup...')
    log_debug("Command: #{command}")

    if command.nil?
      log_error('Failed to build displayplacer command')
      exit(1)
    end

    success = execute_cmd?(command, description: 'Applying monitor configuration')
    if success
      log_success('Monitor arrangement completed successfully!')

      # Show final layout with all monitors after successful configuration
      puts "\n🎯 Final Monitor Layout Applied:"
      final_displays = get_target_display_layout(external_monitors)
      display_spatial_layout(final_displays, "📍 Complete Final Layout")
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
