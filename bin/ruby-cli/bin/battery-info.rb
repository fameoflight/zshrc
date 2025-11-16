#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: system
# @description: Display detailed battery and power charger information for macOS
# @tags: macos, monitoring, hardware

require_relative '../../.common/script_base'
require_relative '../../.common/services/system_profiler_service'

# Script to display battery and power charger information
class BatteryInfoScript < ScriptBase
  def script_emoji; '🔋'; end
  def script_title; 'Battery & Power Info'; end
  def script_description; 'Shows detailed battery and power charger information for macOS systems'; end
  def script_arguments; '[OPTIONS]'; end

  def add_custom_options(opts)
    opts.on('-j', '--json', 'Output information in JSON format') do
      @options[:json] = true
    end
    opts.on('-s', '--simple', 'Show simplified view without detailed hardware info') do
      @options[:simple] = true
    end
    opts.on('--no-color', 'Disable colored output') do
      @options[:no_color] = true
    end
    opts.on('--refresh SECONDS', Integer, 'Continuously refresh every N seconds') do |seconds|
      @options[:refresh] = seconds
    end
  end

  def validate!
    super

    unless System.macos?
      log_error "This script is designed for macOS systems only"
      exit 1
    end

    if @options[:refresh] && @options[:refresh] < 1
      log_error "Refresh interval must be at least 1 second"
      exit 1
    end

    @json_output = @options[:json] || false
    @simple_view = @options[:simple] || false
    @refresh_interval = @options[:refresh]
  end

  def run
    if @refresh_interval
      log_info "Continuously refreshing every #{@refresh_interval} seconds. Press Ctrl+C to stop."
      puts

      begin
        loop do
          clear_screen
          display_battery_info
          sleep(@refresh_interval)
        end
      rescue Interrupt
        puts "\n"
        log_info "Stopped refreshing"
      end
    else
      log_banner("Battery & Power Information")
      display_battery_info
      show_completion("Battery information display")
    end
  end

  private

  def clear_screen
    print "\e[2J\e[H"  # ANSI escape codes to clear screen and move cursor to top
  end

  def display_battery_info
    battery_data = collect_battery_data

    if @json_output
      puts JSON.pretty_generate(battery_data)
      return
    end

    display_overview(battery_data)
    display_battery_details(battery_data) unless @simple_view
    display_charger_info(battery_data)
    display_power_settings(battery_data) unless @simple_view
  end

  def collect_battery_data
    data = {}

    # Initialize system profiler service
    @system_profiler_service ||= SystemProfilerService.new(logger: self, debug: debug?)

    # Get battery information from system profiler service
    power_data = @system_profiler_service.power_info(use_cache: true)
    data[:system_profiler] = power_data

    # Get current battery status from pmset
    data[:pmset] = parse_pmset

    # Get power management settings
    data[:power_settings] = parse_pmset_settings

    # Get current timestamp
    data[:timestamp] = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    data
  end

  
  def parse_pmset
    output = System.execute("pmset -g batt", description: "Getting battery status")

    data = {
      power_source: "Unknown",
      battery_id: nil,
      charge_percent: 0,
      charging_state: "Unknown",
      time_remaining: "Unknown"
    }

    output.each_line do |line|
      next unless line.include?("Battery") || line.include?("drawing from")

      if line.include?("drawing from 'AC Power'")
        data[:power_source] = "AC Power"
      elsif line.include?("drawing from 'Battery Power'")
        data[:power_source] = "Battery Power"
      end

      # Parse battery line like: -InternalBattery-0 (id=34013283)	7%; charging; (no estimate) present: true
      if match = line.match(/-InternalBattery-\d+ \(id=(\d+)\)\s+(\d+)%;\s*(charging|discharging|finishing charge| charged);\s*(.*?)(?:\s+present: (true|false))?/)
        data[:battery_id] = match[1]
        data[:charge_percent] = match[2].to_i
        data[:charging_state] = match[3]
        data[:time_remaining] = match[4].strip.empty? ? "Calculating..." : match[4].strip
      end
    end

    data
  end

  def parse_pmset_settings
    output = System.execute("pmset -g", description: "Getting power settings")

    settings = {}
    current_power_source = nil

    output.each_line do |line|
      line = line.strip

      if line.include?("AC Power:")
        current_power_source = :ac
      elsif line.include?("Battery Power:")
        current_power_source = :battery
      elsif line.include?("Currently in use:")
        current_power_source = :current
      elsif current_power_source && line.include?(":")
        key, value = line.split(" ", 2)
        if value
          value = value.strip
          settings["#{current_power_source}_#{normalize_key(key)}"] = value
        end
      end
    end

    settings
  end

  def normalize_key(key)
    key.downcase.gsub(/[^\w]/, '_').gsub(/_+/, '_').gsub(/^_|_$/, '')
  end

  def display_overview(data)
    pmset = data[:pmset]
    power_data = data[:system_profiler]["power"] || {}
    health_info = power_data.dig("health_information") || {}
    charge_info = power_data.dig("charge_information") || {}

    puts "#{battery_emoji(pmset[:charging_state])} Battery Status"
    puts "=" * 50
    puts

    # Power source
    power_source_icon = pmset[:power_source] == "AC Power" ? "🔌" : "🔋"
    puts "#{power_source_icon} Power Source: #{pmset[:power_source]}"

    # Battery percentage with color
    percentage = pmset[:charge_percent]
    puts "#{get_percentage_emoji(percentage)} Charge: #{percentage}% #{get_battery_status_indicator(percentage)}"

    # Charging status
    charging_icon = charging_emoji(pmset[:charging_state])
    puts "#{charging_icon} Status: #{format_charging_state(pmset[:charging_state])}"

    # Time remaining
    time_icon = pmset[:charging_state] == "charging" ? "⏱️" : "⏰"
    puts "#{time_icon} Time: #{pmset[:time_remaining]}"

    # Health information from the health_information section
    max_capacity = health_info["maximum_capacity"]
    if max_capacity
      puts "#{health_emoji(max_capacity)} Health: #{max_capacity}"
    end

    cycle_count = health_info["cycle_count"]
    if cycle_count
      puts "#{cycle_emoji(cycle_count)} Cycles: #{cycle_count}"
    end

    condition = health_info["condition"]
    if condition
      puts "#{condition_emoji(condition)} Condition: #{condition}"
    end

    # Additional charge info
    state_of_charge = charge_info["state_of_charge"]
    if state_of_charge
      puts "📊 State of Charge: #{state_of_charge}%"
    end

    fully_charged = charge_info["fully_charged"]
    if fully_charged
      puts "#{fully_charged ? '✅' : '⏳'} Fully Charged: #{fully_charged ? 'Yes' : 'No'}"
    end

    puts
  end

  def display_battery_details(battery)
    power_data = battery[:system_profiler]["power"] || {}
    model_info = power_data.dig("model_information") || {}
    charge_info = power_data.dig("charge_information") || {}

    log_section "Battery Details"
    puts

    # Model Information
    puts "📱 Model Information:"
    has_model_info = false

    if model_info.any?
      model_info.each do |key, value|
        next if value.nil? || (value.is_a?(String) && value.empty?)

        # Format the key for display
        display_key = key.split('_').map(&:capitalize).join(' ')
        puts "  #{display_key}: #{value}"
        has_model_info = true
      end
    end

    puts "  No detailed model information available" unless has_model_info
    puts

    # Detailed Charge Information
    puts "⚡ Charge Information:"
    has_charge_info = false

    if charge_info.any?
      charge_info.each do |key, value|
        next if value.nil? || key == "state_of_charge" # Already shown in overview

        # Format the key for display
        display_key = key.split('_').map(&:capitalize).join(' ')

        # Special formatting for boolean values
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          puts "  #{display_key}: #{value ? 'Yes' : 'No'}"
        else
          puts "  #{display_key}: #{value}"
        end
        has_charge_info = true
      end
    end

    puts "  No detailed charge information available" unless has_charge_info
    puts
  end

  def display_charger_info(battery)
    power_data = battery[:system_profiler]["power"] || {}
    charger_info = power_data.dig("ac_charger_information") || {}
    pmset = battery[:pmset]

    log_section "Charger Information"
    puts

    if charger_info.empty?
      puts "ℹ️  No charger connected"
    else
      # Connection status
      connected = charger_info["connected"] == true
      puts "🔌 Connected: #{connected ? 'Yes' : 'No'}"

      if connected
        # Charger specs
        puts "⚡ Charger Specifications:"

        # Display wattage prominently
        wattage = charger_info["wattage_w"]
        if wattage
          puts "  🔋 Power: #{wattage}W"
        end

        # Other specs
        id = charger_info["id"]
        puts "  ID: #{id}" if id

        family = charger_info["family"]
        puts "  Family: #{family}" if family

        # Add estimated charging time if available
        if pmset[:charging_state] == "charging" && pmset[:time_remaining] != "Calculating..."
          puts "  ⏱️  Until Full: #{pmset[:time_remaining]}"
        end
      else
        puts "ℹ️  Charger not connected or not detected"
      end
    end

    puts
  end

  def display_power_settings(battery)
    power_data = battery[:system_profiler]["power"] || {}
    ac_power_settings = power_data.dig("ac_power") || {}
    battery_power_settings = power_data.dig("battery_power") || {}

    log_section "Power Management Settings"
    puts

    # AC Power Settings
    if ac_power_settings.any?
      puts "🔌 AC Power Settings:"
      ac_power_settings.each do |key, value|
        next if value.nil?

        # Format the key for display
        display_key = key.split('_').map(&:capitalize).join(' ')

        # Special formatting for boolean values and time values
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          puts "  #{display_key}: #{value ? 'Yes' : 'No'}"
        elsif key.include?("_minutes") && value.is_a?(Integer)
          puts "  #{display_key}: #{value} minutes"
        elsif key.include?("_timer") && value.is_a?(Integer)
          puts "  #{display_key}: #{value} minutes"
        else
          puts "  #{display_key}: #{value}"
        end
      end
      puts
    else
      puts "ℹ️  No AC power settings available"
      puts
    end

    # Battery Power Settings
    if battery_power_settings.any?
      puts "🔋 Battery Power Settings:"
      battery_power_settings.each do |key, value|
        next if value.nil?

        # Format the key for display
        display_key = key.split('_').map(&:capitalize).join(' ')

        # Special formatting for boolean values and time values
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          puts "  #{display_key}: #{value ? 'Yes' : 'No'}"
        elsif key.include?("_minutes") && value.is_a?(Integer)
          puts "  #{display_key}: #{value} minutes"
        elsif key.include?("_timer") && value.is_a?(Integer)
          puts "  #{display_key}: #{value} minutes"
        else
          puts "  #{display_key}: #{value}"
        end
      end
      puts
    else
      puts "ℹ️  No battery power settings available"
      puts
    end
  end

  def get_battery_status_indicator(percentage)
    if percentage >= 80
      "🟢"
    elsif percentage >= 50
      "🟡"
    elsif percentage >= 20
      "🟠"
    else
      "🔴"
    end
  end

  def get_percentage_emoji(percentage)
    case percentage
    when 90..100 then "🔋"
    when 70..89 then "🔋"
    when 50..69 then "🔋"
    when 30..49 then "🔋"
    when 10..29 then "🪫"
    else "🪫"
    end
  end

  def battery_emoji(charging_state)
    case charging_state
    when "charging", "finishing charge" then "⚡"
    when "charged" then "🔋"
    else "🪫"
    end
  end

  def charging_emoji(charging_state)
    case charging_state
    when "charging" then "⚡"
    when "discharging" then "📉"
    when "finishing charge" then "🔋"
    when "charged" then "✅"
    else "❓"
    end
  end

  def health_emoji(max_capacity)
    return "❓" unless max_capacity

    # Handle both string and integer inputs
    capacity = if max_capacity.is_a?(String)
                if match = max_capacity.match(/(\d+)%/)
                  match[1].to_i
                else
                  max_capacity.to_i
                end
              elsif max_capacity.is_a?(Integer)
                max_capacity
              else
                max_capacity.to_i
              end

    case capacity
    when 90..100 then "🟢"
    when 80..89 then "🟡"
    when 70..79 then "🟠"
    else "🔴"
    end
  end

  def condition_emoji(condition)
    case condition&.downcase
    when "normal" then "🟢"
    when "good" then "🟢"
    when "fair" then "🟡"
    when "poor" then "🟠"
    when "replace soon", "replace now", "service battery" then "🔴"
    else "❓"
    end
  end

  def cycle_emoji(cycle_count)
    return "❓" unless cycle_count

    # Handle both string and integer inputs
    cycles = if cycle_count.is_a?(String)
              if match = cycle_count.match(/(\d+)/)
                match[1].to_i
              else
                cycle_count.to_i
              end
            elsif cycle_count.is_a?(Integer)
              cycle_count
            else
              cycle_count.to_i
            end

    case cycles
    when 0..300 then "🟢"
    when 301..600 then "🟡"
    when 601..1000 then "🟠"
    else "🔴"
    end
  end

  def format_charging_state(state)
    case state
    when "charging" then "Charging ⚡"
    when "discharging" then "Discharging 📉"
    when "finishing charge" then "Finishing Charge 🔋"
    when "charged" then "Fully Charged ✅"
    else state.capitalize
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                           # Show battery and power information"
    puts "  #{script_name} --simple                  # Show simplified view"
    puts "  #{script_name} --json                    # Output in JSON format"
    puts "  #{script_name} --refresh 30              # Continuously refresh every 30 seconds"
    puts "  #{script_name} --no-color                # Disable colored output"
  end
end

BatteryInfoScript.execute if __FILE__ == $0