# frozen_string_literal: true

require_relative '../services/system_profiler_service'

# Hardware and system detection utilities for optimal performance
module DeviceUtils
  # Get system information for performance optimization
  def system_info
    {
      cpu: cpu_info,
      memory: memory_info,
      os: os_info,
      arch: architecture_info,
      load: system_load
    }
  end

  # Get optimal worker count based on system capabilities
  # @param task_type [Symbol] Type of task: :cpu_intensive, :io_intensive, :mixed
  # @param memory_per_worker [Integer] Estimated memory usage per worker in MB
  # @return [Integer] Optimal number of workers
  def optimal_worker_count(task_type: :mixed, memory_per_worker: 100)
    cpu_cores = processor_count
    available_memory_mb = available_memory / (1024 * 1024)
    system_load_avg = system_load[:avg_1min]

    # Calculate workers based on CPU
    cpu_workers = case task_type
                  when :cpu_intensive
                    [cpu_cores - 4, 1].max # Leave one core free
                  when :io_intensive
                    cpu_cores * 2 # I/O bound tasks can use more workers than cores
                  when :mixed
                    [cpu_cores - 2, 1].max
                  else
                    [cpu_cores - 2, 1].max
                  end

    # Calculate workers based on memory constraints
    memory_workers = memory_per_worker > 0 ? (available_memory_mb / memory_per_worker).to_i : Float::INFINITY

    # Adjust based on system load (reduce workers if system is busy)
    load_factor = system_load_avg > 0 ? [1.0 - (system_load_avg / cpu_cores), 0.25].max : 1.0

    # Choose the most restrictive constraint
    optimal_workers = [cpu_workers, memory_workers].min
    optimal_workers = (optimal_workers * load_factor).round
    [optimal_workers, 1].max
  end

  # Get processor count with detailed detection
  def processor_count
    case RbConfig::CONFIG['host_os']
    when /darwin/
      # macOS: use physical cores for CPU-intensive tasks, logical cores for I/O
      darwin_processor_count
    when /linux/
      linux_processor_count
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      windows_processor_count
    else
      4 # Reasonable fallback
    end
  rescue StandardError
    4 # Fallback if detection fails
  end

  # Get CPU model and capabilities
  def cpu_info
    case RbConfig::CONFIG['host_os']
    when /darwin/
      darwin_cpu_info
    when /linux/
      linux_cpu_info
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      windows_cpu_info
    else
      { model: 'Unknown', cores: processor_count, frequency: nil }
    end
  rescue StandardError
    { model: 'Unknown', cores: processor_count, frequency: nil }
  end

  # Get memory information
  def memory_info
    case RbConfig::CONFIG['host_os']
    when /darwin/
      darwin_memory_info
    when /linux/
      linux_memory_info
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      windows_memory_info
    else
      { total: nil, available: nil, used: nil }
    end
  rescue StandardError
    { total: nil, available: nil, used: nil }
  end

  # Get OS information
  def os_info
    {
      name: RbConfig::CONFIG['host_os'],
      version: os_version,
      kernel: RbConfig::CONFIG['host_vendor']
    }
  end

  # Get architecture information
  def architecture_info
    {
      platform: RbConfig::CONFIG['host_cpu'],
      ruby_platform: RUBY_PLATFORM,
      bits: ruby_bits
    }
  end

  # Get system load averages
  def system_load
    case RbConfig::CONFIG['host_os']
    when /darwin|linux/
      system_load_unix
    else
      { avg_1min: 0, avg_5min: 0, avg_15min: 0 }
    end
  rescue StandardError
    { avg_1min: 0, avg_5min: 0, avg_15min: 0 }
  end

  # Check if running on Apple Silicon
  def apple_silicon?
    RbConfig::CONFIG['host_cpu'] =~ /arm64|aarch64/ && RbConfig::CONFIG['host_os'] =~ /darwin/
  end

  # Check if GPU acceleration is available
  def gpu_available?
    case RbConfig::CONFIG['host_os']
    when /darwin/
      # Check for Metal support on macOS
      apple_silicon? || metal_supported?
    when /linux/
      # Check for CUDA or OpenCL
      cuda_available? || opencl_available?
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      # Check for DirectX or CUDA
      directx_available? || cuda_available?
    else
      false
    end
  rescue StandardError
    false
  end

  # Get available memory in bytes
  def available_memory
    memory_info[:available] || (memory_info[:total] * 0.2) # Fallback: assume 20% available
  end

  # Check if system is under high load
  def system_busy?
    load_avg = system_load[:avg_1min]
    cpu_cores = processor_count
    load_avg > (cpu_cores * 0.8) # Consider busy if load > 80% of CPU cores
  end

  # Get recommended batch size for parallel processing
  def recommended_batch_size(total_items, worker_count: nil)
    worker_count ||= optimal_worker_count
    # Aim for 2-4 batches per worker for optimal load balancing
    [total_items / (worker_count * 3), 1].max
  end

  private

  def ruby_bits
    if RUBY_PLATFORM =~ /64/
      64
    elsif RUBY_PLATFORM =~ /32/
      32
    else
      nil # Unknown
    end
  end

  # macOS specific methods
  def darwin_processor_count
    # Get physical cores for better performance
    physical_cores = `sysctl -n hw.physicalcpu`.to_i
    logical_cores = `sysctl -n hw.logicalcpu`.to_i

    if physical_cores > 0
      physical_cores
    else
      logical_cores > 0 ? logical_cores : 4
    end
  end

  def darwin_cpu_info
    model = begin
      `sysctl -n machdep.cpu.brand_string`.strip
    rescue StandardError
      'Unknown Apple Silicon'
    end
    frequency = begin
      `sysctl -n hw.cpufrequency`.to_i / 1_000_000
    rescue StandardError
      nil
    end # Convert to MHz

    {
      model: model,
      cores: darwin_processor_count,
      frequency: frequency,
      architecture: apple_silicon? ? 'ARM64' : 'x86_64'
    }
  end

  def darwin_memory_info
    total_bytes = `sysctl -n hw.memsize`.to_i
    return nil if total_bytes <= 0

    total_mb = total_bytes / (1024 * 1024)

    # Get memory pressure info
    memory_pressure = `memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}'`.to_f
    free_percentage = memory_pressure > 0 ? memory_pressure : 20.0

    available_mb = (total_mb * free_percentage / 100).to_i
    used_mb = total_mb - available_mb

    {
      total: total_bytes,
      available: available_mb * 1024 * 1024,
      used: used_mb * 1024 * 1024
    }
  rescue StandardError
    # Fallback with reasonable defaults for Apple Silicon
    {
      total: 128 * 1024 * 1024 * 1024, # 128GB fallback
      available: 32 * 1024 * 1024 * 1024, # 32GB available
      used: 96 * 1024 * 1024 * 1024 # 96GB used
    }
  end

  def metal_supported?
    # Check if Metal is supported (macOS 10.11+ on Metal-capable hardware)
    service = SystemProfilerService.new
    displays_data = service.get_single_data_type('SPDisplaysDataType', use_cache: true)

    # Check if any display mentions Metal in the data
    displays_json = displays_data.to_json.downcase
    displays_json.include?('metal')
  rescue
    # Fallback to original method if service fails
    `system_profiler SPDisplaysDataType 2>/dev/null | grep -i metal`
    $?.success?
  end

  module_function :metal_supported?

  # Linux specific methods
  def linux_processor_count
    `nproc`.to_i
  end

  def linux_cpu_info
    cpuinfo = begin
      File.read('/proc/cpuinfo')
    rescue StandardError
      ''
    end
    model = cpuinfo[/model name\s*:\s*(.+)/, 1] || 'Unknown'
    cores = cpuinfo.scan(/^processor\s*:/).length

    {
      model: model.strip,
      cores: cores > 0 ? cores : 4,
      frequency: nil
    }
  end

  def linux_memory_info
    meminfo = begin
      File.read('/proc/meminfo')
    rescue StandardError
      ''
    end

    total_kb = meminfo[/MemTotal:\s*(\d+)/, 1].to_i
    available_kb = meminfo[/MemAvailable:\s*(\d+)/, 1].to_i
    used_kb = total_kb - available_kb

    {
      total: total_kb * 1024,
      available: available_kb * 1024,
      used: used_kb * 1024
    }
  end

  def system_load_unix
    loadavg = begin
      File.read('/proc/loadavg')
    rescue StandardError
      '0 0 0'
    end
    loads = loadavg.split.map(&:to_f)

    {
      avg_1min: loads[0] || 0,
      avg_5min: loads[1] || 0,
      avg_15min: loads[2] || 0
    }
  end

  def cuda_available?
    `nvidia-smi 2>/dev/null`
    $?.success?
  end

  def opencl_available?
    `clinfo 2>/dev/null`
    $?.success?
  end

  # Windows specific methods
  def windows_processor_count
    ENV['NUMBER_OF_PROCESSORS'].to_i
  end

  def windows_cpu_info
    cpuinfo = begin
      `wmic cpu get name /value`
    rescue StandardError
      ''
    end
    model = cpuinfo[/Name=(.+)/, 1] || 'Unknown'

    {
      model: model.strip,
      cores: windows_processor_count,
      frequency: nil
    }
  end

  def windows_memory_info
    meminfo = begin
      `wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /value`
    rescue StandardError
      ''
    end

    total_kb = meminfo[/TotalVisibleMemorySize=(\d+)/, 1].to_i
    free_kb = meminfo[/FreePhysicalMemory=(\d+)/, 1].to_i
    used_kb = total_kb - free_kb

    {
      total: total_kb * 1024,
      available: free_kb * 1024,
      used: used_kb * 1024
    }
  end

  def directx_available?
    # Check for DirectX 12+ support
    `dxdiag /t dxdiag_output.txt 2>/dev/null && grep -i "direct.*12" dxdiag_output.txt`
    result = $?.success?
    begin
      File.delete('dxdiag_output.txt')
    rescue StandardError
      nil
    end
    result
  end

  def os_version
    case RbConfig::CONFIG['host_os']
    when /darwin/
      begin
        `sw_vers -productVersion`.strip
      rescue StandardError
        'Unknown'
      end
    when /linux/
      begin
        `lsb_release -rs 2>/dev/null || cat /etc/os-release | grep VERSION_ID | cut -d= -f2`.strip
      rescue StandardError
        'Unknown'
      end
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      begin
        `ver`.strip
      rescue StandardError
        'Unknown'
      end
    else
      'Unknown'
    end
  rescue StandardError
    'Unknown'
  end
end
