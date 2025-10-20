# frozen_string_literal: true

require_relative '../system'
require_relative 'base_service'

# Service for interacting with macOS system_profiler command
# Provides a clean, structured interface to system_profiler data
class SystemProfilerService < BaseService
  # Available data types that can be queried
  DATA_TYPES = {
    hardware: 'SPHardwareDataType',
    software: 'SPSoftwareDataType',
    network: 'SPNetworkDataType',
    bluetooth: 'SPBluetoothDataType',
    usb: 'SPUSBDataType',
    firewire: 'SPFireWireDataType',
    thunderbolt: 'SPThunderboltDataType',
    audio: 'SPAudioDataType',
    displays: 'SPDisplaysDataType',
    graphics: 'SPGraphicsDataType',
    memory: 'SPMemoryDataType',
    pci: 'SPPCIDataType',
    storage: 'SPStorageDataType',
    power: 'SPPowerDataType',
    parallel_ata: 'SPPARALLELATADisplayType',
    parallel_scsi: 'SPPARALLELSCSIDisplayType',
    serial_ata: 'SPSATADataType',
    serial_scsi: 'SPSerialSCSIDisplayType'
  }.freeze

  def initialize(options = {})
    super(options)
    @cache = {}
    @cache_ttl = options[:cache_ttl] || 300 # 5 minutes default cache
  end

  # Get system profiler data for specified data types
  # @param data_types [Array<Symbol, String>] Data types to retrieve
  # @param use_cache [Boolean] Whether to use cached data
  # @return [Hash] Parsed system profiler data
  def get_data(data_types = [:hardware, :software], use_cache: true)
    Array(data_types).map do |type|
      type_sym = type.to_sym
      type_str = DATA_TYPES[type_sym] || type.to_s

      log_debug "Getting system profiler data for #{type_str}" if debug_enabled?
      data = get_single_data_type(type_str, use_cache)
      [type_sym, data]
    end.to_h
  end

  # Get specific data type
  # @param data_type [String, Symbol] The data type to retrieve
  # @param use_cache [Boolean] Whether to use cached data
  # @return [Hash] Parsed data for the specified type
  def get_single_data_type(data_type, use_cache = true)
    cache_key = "system_profiler_#{data_type}"

    if use_cache && cached_data_available?(cache_key)
      log_debug "Using cached data for #{data_type}" if debug_enabled?
      return @cache[cache_key]
    end

    log_debug "Fetching fresh data for #{data_type}" if debug_enabled?
    raw_output = System.execute("system_profiler #{data_type}", description: "Getting #{data_type} data")

    parsed_data = parse_system_profiler_output(raw_output)

    if use_cache
      @cache[cache_key] = {
        data: parsed_data,
        timestamp: Time.now
      }
    end

    parsed_data
  end

  # Get hardware information
  def hardware_info(use_cache: true)
    get_data(:hardware, use_cache: use_cache)[:hardware]
  end

  # Get software information
  def software_info(use_cache: true)
    get_data(:software, use_cache: use_cache)[:software]
  end

  # Get power information (battery, charger, etc.)
  def power_info(use_cache: true)
    get_data(:power, use_cache: use_cache)[:power]
  end

  # Get storage information
  def storage_info(use_cache: true)
    get_data(:storage, use_cache: use_cache)[:storage]
  end

  # Get network information
  def network_info(use_cache: true)
    get_data(:network, use_cache: true)[:network]
  end

  # Clear cache
  def clear_cache
    @cache.clear
    log_debug "System profiler cache cleared" if debug_enabled?
  end

  # Get cache statistics
  def cache_stats
    {
      entries: @cache.size,
      total_memory_estimate: @cache.size * 1024 # Rough estimate
    }
  end

  private

  def cached_data_available?(cache_key)
    return false unless @cache.key?(cache_key)

    cached_entry = @cache[cache_key]
    Time.now - cached_entry[:timestamp] < @cache_ttl
  end

  # Parse system_profiler output into structured data
  def parse_system_profiler_output(output)
    return {} if output.nil? || output.strip.empty?

    data = {}
    current_section = nil
    current_subsection = nil
    section_indent_level = 0

    output.each_line do |line|
      line = line.rstrip
      next if line.empty?

      # Determine indentation level
      indent_level = line[/^ */].length

      # Remove indentation and store trimmed line
      trimmed_line = line.lstrip

      # Handle section headers (lines ending with ":")
      if trimmed_line.end_with?(':')
        section_name = trimmed_line[0..-2].strip

        if current_section.nil?
          # Top-level section
          current_section = section_name
          current_subsection = nil
          section_indent_level = indent_level
          data[normalize_key(section_name)] = {}
        elsif indent_level > section_indent_level
          # Subsection
          current_subsection = section_name
          data[normalize_key(current_section)][normalize_key(section_name)] = {}
        else
          # Back to top level
          current_section = section_name
          current_subsection = nil
          section_indent_level = indent_level
          data[normalize_key(section_name)] = {}
        end

        next
      end

      # Parse key-value pairs
      if trimmed_line.include?(':')
        key, value = trimmed_line.split(':', 2).map(&:strip)
        next unless key && value

        normalized_key = normalize_key(key)
        processed_value = process_value(value)

        if current_subsection && data.dig(normalize_key(current_section), normalize_key(current_subsection))
          data[normalize_key(current_section)][normalize_key(current_subsection)][normalized_key] = processed_value
        elsif data[normalize_key(current_section)]
          data[normalize_key(current_section)][normalized_key] = processed_value
        end
      else
        # Handle list items or simple values
        if current_subsection && data.dig(normalize_key(current_section), normalize_key(current_subsection))
          # Add to array if exists, create if not
          target = data[normalize_key(current_section)][normalize_key(current_subsection)]
          if target.is_a?(Array)
            target << trimmed_line
          else
            data[normalize_key(current_section)][normalize_key(current_subsection)] = [trimmed_line]
          end
        elsif data[normalize_key(current_section)]
          # Add to array if exists, create if not
          target = data[normalize_key(current_section)]
          if target.is_a?(Array)
            target << trimmed_line
          else
            data[normalize_key(current_section)] = [trimmed_line]
          end
        end
      end
    end

    data
  end

  # Normalize keys to be consistent (snake_case)
  def normalize_key(key)
    key.downcase.gsub(/[^\w]/, '_').gsub(/_+/, '_').gsub(/^_|_$/, '')
  end

  # Process and clean values
  def process_value(value)
    # Remove extra whitespace
    value = value.strip

    # Handle common value patterns
    case value
    when /^Yes$/i
      true
    when /^No$/i
      false
    when /^\d+$/
      value.to_i
    when /^\d+\.\d+$/
      value.to_f
    when /^(\d+)\s*([KMGT]?B)$/i
      # Parse sizes like "256 GB" or "512 MB"
      size = $1.to_i
      unit = $2.upcase
      "#{size} #{unit}"
    else
      value
    end
  end
end