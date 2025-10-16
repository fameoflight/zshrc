# frozen_string_literal: true

# Centralized error handling utilities for all scripts and services
module ErrorUtils
  # Enhanced error logging with detailed information
  def log_error_with_context(error, context = {})
    error_type = error.class.name
    error_message = error.message
    error_backtrace = error.backtrace

    # Build detailed error message
    details = []
    details << "Error Type: #{error_type}"
    details << "Message: #{error_message}"

    # Add context information
    context.each do |key, value|
      details << "#{key.to_s.capitalize}: #{value}"
    end

    # Add backtrace information (limited to avoid too much output)
    if error_backtrace && !error_backtrace.empty?
      details << "Backtrace (first 5 lines):"
      error_backtrace.first(5).each_with_index do |line, index|
        details << "  #{index + 1}. #{line}"
      end
    end

    # Log the error with all details
    log_error(details.join("\n"))
  end

  # Wrapper for methods with automatic error handling
  def with_error_handling(operation_name = "Operation", context = {}, &block)
    begin
      log_debug("Starting #{operation_name}")
      result = yield
      log_debug("Completed #{operation_name} successfully")
      result
    rescue => e
      error_context = context.merge(operation: operation_name)
      log_error_with_context(e, error_context)
      nil
    end
  end

  # Retry mechanism for transient failures
  def with_retry(max_retries = 3, base_delay = 1, operation_name = "Operation", context = {}, &block)
    attempt = 0

    loop do
      attempt += 1
      result = with_error_handling("#{operation_name} (attempt #{attempt}/#{max_retries})", context, &block)

      return result if result || attempt >= max_retries

      if attempt < max_retries
        delay = base_delay * (2 ** (attempt - 1)) # Exponential backoff
        log_warning("Retrying #{operation_name} in #{delay} seconds...")
        sleep(delay)
      end
    end
  end

  # Validate required parameters
  def validate_required(params, required_keys, operation_name = "Operation")
    missing_keys = required_keys - params.keys

    if missing_keys.any?
      error_msg = "Missing required parameters for #{operation_name}: #{missing_keys.join(', ')}"
      log_error(error_msg)
      raise ArgumentError, error_msg
    end
  end

  # Check file accessibility
  def check_file_access(file_path, operation = "read", operation_name = "File operation")
    return true unless file_path # Skip if no file path provided

    case operation.to_sym
    when :read, :exist
      unless File.exist?(file_path)
        log_error("File not found for #{operation_name}: #{file_path}")
        raise Errno::ENOENT, "File not found: #{file_path}"
      end
    when :write
      directory = File.dirname(file_path)
      unless File.directory?(directory)
        log_error("Directory not found for #{operation_name}: #{directory}")
        raise Errno::ENOENT, "Directory not found: #{directory}"
      end
      unless File.writable?(directory)
        log_error("Directory not writable for #{operation_name}: #{directory}")
        raise Errno::EACCES, "Directory not writable: #{directory}"
      end
    when :execute
      unless File.exist?(file_path)
        log_error("File not found for #{operation_name}: #{file_path}")
        raise Errno::ENOENT, "File not found: #{file_path}"
      end
      unless File.executable?(file_path)
        log_error("File not executable for #{operation_name}: #{file_path}")
        raise Errno::EACCES, "File not executable: #{file_path}"
      end
    end

    true
  end

  # Safe file operations with error handling
  def safe_file_read(file_path, operation_name = "File read")
    with_error_handling(operation_name, { file: file_path }) do
      check_file_access(file_path, :read, operation_name)
      File.read(file_path)
    end
  end

  def safe_file_write(file_path, content, operation_name = "File write")
    with_error_handling(operation_name, { file: file_path }) do
      check_file_access(file_path, :write, operation_name)
      File.write(file_path, content)
    end
  end

  # Safe system command execution
  def safe_system_execute(command, operation_name = "System command", timeout: 30)
    with_error_handling(operation_name, { command: command }) do
      require 'open3'

      stdout, stderr, status = Open3.capture3(command, timeout: timeout)

      unless status.success?
        raise "Command failed with exit code #{status.exitcode}: #{stderr}"
      end

      { stdout: stdout, stderr: stderr, status: status }
    end
  end

  # HTTP request with error handling
  def safe_http_request(uri, request_class, operation_name = "HTTP request", timeout: 30, &block)
    with_error_handling(operation_name, { url: uri.to_s }) do
      require 'net/http'

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = timeout
      http.open_timeout = 10

      if uri.is_a?(URI::HTTPS)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      request = request_class.new(uri)
      yield(request) if block_given?

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "HTTP request failed: #{response.code} #{response.message}"
      end

      response
    end
  end

  # Memory usage monitoring
  def log_memory_usage(context = "")
    require 'getoptlong'

    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i # in KB
    memory_mb = (memory_usage / 1024.0).round(2)

    log_debug("Memory usage#{context.empty? ? '' : " (#{context})"}: #{memory_mb} MB")
  end

  # Performance timing
  def measure_time(operation_name = "Operation", &block)
    start_time = Time.now
    result = yield
    end_time = Time.now

    duration = end_time - start_time
    log_debug("#{operation_name} completed in #{duration.round(2)} seconds")

    result
  end
end