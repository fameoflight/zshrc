# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require_relative 'base_service'

# Service for interacting with LM Studio
class LMStudioService < BaseService
  DEFAULT_MODEL = ENV['LOCAL_MODEL'] || 'gemma-2-27b-it'
  DEFAULT_ENDPOINT = 'http://localhost:1234/v1'

  def initialize(options = {})
    super(options)
    @endpoint = options[:endpoint] || DEFAULT_ENDPOINT
    @model = options[:model] || DEFAULT_MODEL
    @timeout = options[:timeout] || 120
    @temperature = options[:temperature] || 0.1
    @max_tokens = options[:max_tokens] || 1000
    @reasoning_effort = options[:reasoning_effort] || 3
  end

  def available?
    @available ||= test_connection
  end

  # Check if model needs to be reloaded with larger context for the given content
  def ensure_sufficient_context(content_length, min_context_needed = nil, auto_reload = true)
    return true unless available?

    # Estimate tokens needed (rough approximation: 4 chars per token)
    estimated_tokens = (content_length / 4.0).ceil

    # Use provided min_context or calculate based on content with buffer
    target_context = if min_context_needed
                       min_context_needed.to_i
                     else
                       # Add 50% buffer for safety, but ensure minimum of 8192
                       [estimated_tokens * 1.5, 8192].max.to_i
                     end

    current_context = get_current_context_length

    # Only reload if we can get current context and it's insufficient
    if current_context && current_context < target_context
      log_info("Current context (#{current_context}) insufficient for content (#{estimated_tokens} tokens, need #{target_context})")

      if auto_reload
        log_info("Attempting to reload model with larger context (#{target_context})")
        return reload_model_with_context(target_context)
      else
        log_warning("Auto-reload disabled. Current context (#{current_context}) may be insufficient for content (needs #{target_context}).")
        log_info('To enable auto-reload, use --auto-reload flag')
        return false
      end
    elsif !current_context
      # This is normal when no models are loaded or when lms is not available
      log_debug('Could not determine current context length (no models loaded or lms unavailable). Proceeding without auto-reload.')
      return true
    end

    log_debug("Current context (#{current_context}) sufficient for content (#{estimated_tokens} tokens)")
    true
  end

  # Get the current model's context length
  def get_current_context_length
    return nil unless command_exists?('lms')

    output = `#{lms_command} ps 2>/dev/null`
    return nil unless $?.success?

    # Check if no models are loaded
    if output.include?('No models are currently loaded')
      log_debug('No models currently loaded in LM Studio')
      return nil
    end

    lines = output.split("\n")
    # Find the line with our current model
    model_line = lines.find { |line| line.include?(@model) }
    if model_line
      # Parse context from the line. Actual format varies, look for numeric context value
      # Example: "openai/gpt-oss-120b    openai/gpt-oss-120b    IDLE      63.39 GB    9669"
      parts = model_line.split(/\s+/)

      # Look for the context number (usually the last numeric field or before TTL)
      context = nil

      # Try different parsing strategies
      # Strategy 1: Last numeric field (excluding sizes with GB/MB)
      numeric_parts = parts.select { |part| part.match(/^\d+$/) }
      context = numeric_parts.last.to_i if numeric_parts.length > 0

      # Strategy 2: Look for specific positions based on common formats
      if !context || context == 0
        # Try position 4 (0-indexed) which is often context
        potential_context = parts[4]&.to_i
        context = potential_context if potential_context && potential_context > 0
      end

      if context && context > 0
        log_debug("Found current context length: #{context}")
        return context
      else
        log_debug("Could not parse context length from model line: #{model_line.strip}")
      end
    else
      log_debug("Current model '#{@model}' not found in loaded models")
    end

    nil
  end

  # Reload the current model with a larger context length
  def reload_model_with_context(context_length)
    return false unless command_exists?('lms')

    begin
      log_info('Unloading current model...')
      unload_result = system("#{lms_command} unload #{@model} >/dev/null 2>&1")

      log_warning('Failed to unload model, continuing anyway...') unless unload_result

      log_info("Reloading model with #{context_length} context length...")
      load_result = system("#{lms_command} load #{@model} --context-length #{context_length} >/dev/null 2>&1")

      if load_result
        log_success('Model reloaded successfully with larger context')
        # Reset connection test to recheck availability
        @available = nil
        available?
      else
        log_error('Failed to reload model with larger context')
        false
      end
    rescue StandardError => e
      log_error("Error reloading model: #{e.message}")
      false
    end
  end

  # Get the lms command path
  def lms_command
    @lms_command ||= begin
      # Try common locations for lms
      candidates = [
        '~/.lmstudio/bin/lms',
        '/usr/local/bin/lms',
        'lms'
      ]

      candidates.each do |cmd|
        expanded = File.expand_path(cmd)
        return expanded if File.exist?(expanded) && File.executable?(expanded)
      end

      # Fallback to system PATH
      'lms'
    end
  end

  # Check if a command exists
  def command_exists?(command)
    system("which #{command} > /dev/null 2>&1")
  end

  def complete(prompt, options = {})
    return nil unless available?

    system_message = options[:system] || 'You are a helpful assistant.'
    temp = options[:temperature] || @temperature
    max_tokens = options[:max_tokens] || @max_tokens
    stream = options[:stream] || false

    # Check if we need larger context and auto-reload if necessary
    total_content = "#{system_message}\n#{prompt}"
    auto_reload = options[:auto_reload].nil? || options[:auto_reload]
    min_context = options[:min_context]

    unless ensure_sufficient_context(total_content.length, min_context, auto_reload)
      log_error('Unable to ensure sufficient context for request')
      return nil
    end

    messages = [
      { role: 'system', content: system_message },
      { role: 'user', content: prompt }
    ]

    if stream
      send_chat_request_streaming(messages, temperature: temp, max_tokens: max_tokens)
    else
      send_chat_request(messages, temperature: temp, max_tokens: max_tokens)
    end
  end

  def chat(messages, options = {})
    return nil unless available?

    temp = options[:temperature] || @temperature
    max_tokens = options[:max_tokens] || @max_tokens

    # Check if we need larger context for all messages combined
    total_content = messages.map { |msg| msg[:content] || msg['content'] }.join("\n")
    auto_reload = options[:auto_reload].nil? || options[:auto_reload]
    min_context = options[:min_context]

    unless ensure_sufficient_context(total_content.length, min_context, auto_reload)
      log_error('Unable to ensure sufficient context for chat request')
      return nil
    end

    send_chat_request(messages, temperature: temp, max_tokens: max_tokens)
  end

  def models
    return [] unless available?

    uri = URI("#{@endpoint}/models")

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        result.dig('data')&.map { |m| m['id'] } || []
      else
        log_error("Failed to fetch models: #{response.code}")
        []
      end
    rescue StandardError => e
      log_error("Error fetching models: #{e.class.name} - #{e.message}")
      []
    end
  end

  def set_model(model_name)
    available_models = models

    if available_models.include?(model_name)
      @model = model_name
      log_info("Switched to model: #{model_name}")
      true
    else
      log_error("Model '#{model_name}' not available. Available: #{available_models.join(', ')}")
      false
    end
  end

  private

  def test_connection
    uri = URI("#{@endpoint}/models")

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'

      response = http.request(request)

      if response.code == '200'
        models_data = JSON.parse(response.body)
        available_models = models_data.dig('data')&.map { |m| m['id'] } || []

        log_debug("LM Studio available. Models: #{available_models.join(', ')}")

        # Check if our preferred model is available
        if available_models.include?(@model)
          log_debug("Target model '#{@model}' is available")
        elsif available_models.any?
          log_warning("Target model '#{@model}' not found, using first available: #{available_models.first}")
          @model = available_models.first
        else
          log_error('No models available in LM Studio')
          return false
        end

        true
      else
        log_warning("LM Studio responded with status: #{response.code}")
        false
      end
    rescue Errno::ECONNREFUSED
      log_debug('LM Studio not running (connection refused)')
      false
    rescue StandardError => e
      log_debug("LM Studio connection failed: #{e.class.name} - #{e.message}")
      false
    end
  end

  def send_chat_request(messages, temperature:, max_tokens:)
    with_error_handling("LM Studio chat request", {
      model: @model,
      messages_count: messages.length,
      temperature: temperature,
      max_tokens: max_tokens
    }) do
      uri = URI("#{@endpoint}/chat/completions")

      payload = {
        model: @model,
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens,
        reasoning_effort: @reasoning_effort
      }

      response = safe_http_request(uri, Net::HTTP::Post, "LM Studio API request", timeout: @timeout) do |request|
        request['Content-Type'] = 'application/json'
        request.body = payload.to_json
      end

      result = JSON.parse(response.body)
      content = result.dig('choices', 0, 'message', 'content')

      if content && !content.empty?
        log_debug("LM Studio response received: #{content.length} characters")
        log_debug("Response preview: #{content[0..100]}...") if content.length > 100
        content
      else
        log_error("LM Studio returned empty response for model #{@model}")
        log_debug("Full API response body: #{response.body}")

        # Try to parse and log more details about the response
        begin
          parsed_response = JSON.parse(response.body)
          log_debug("Parsed response: #{parsed_response}")
          if parsed_response['choices'] && parsed_response['choices'].first
            choice = parsed_response['choices'].first
            log_debug("Choice content: #{choice.dig('message', 'content')}")
            log_debug("Choice finish reason: #{choice['finish_reason']}")
          end
        rescue JSON::ParserError => e
          log_debug("Failed to parse JSON response: #{e.message}")
        end
        nil
      end
    end
  end

  def send_chat_request_streaming(messages, temperature:, max_tokens:)
    uri = URI("#{@endpoint}/chat/completions")

    payload = {
      model: @model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens,
      stream: true,
      reasoning_effort: @reasoning_effort
    }

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = @timeout
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      log_debug("Sending streaming chat request to #{uri} with model #{@model}")

      full_content = ''
      start_time = Time.now

      print_progress_indicator('Generating')

      http.request(request) do |response|
        if response.code == '200'
          response.read_body do |chunk|
            next if chunk.strip.empty?

            # Process SSE (Server-Sent Events) format
            chunk.split("\n").each do |line|
              next unless line.start_with?('data: ')

              data_str = line[6..-1] # Remove 'data: ' prefix
              next if data_str.strip == '[DONE]'

              begin
                data = JSON.parse(data_str)
                content_delta = data.dig('choices', 0, 'delta', 'content')
                if content_delta
                  full_content += content_delta
                  update_progress_indicator
                end
              rescue JSON::ParserError
                # Skip invalid JSON lines
              end
            end
          end
        else
          clear_progress_indicator
          log_error("Streaming request failed with status #{response.code}: #{response.body}")
          return nil
        end
      end

      clear_progress_indicator
      duration = Time.now - start_time
      log_debug("Streaming response completed in #{duration.round(2)}s: #{full_content.length} characters")
      full_content
    rescue StandardError => e
      clear_progress_indicator
      log_error("Streaming request error: #{e.class.name} - #{e.message}")
      nil
    end
  end

  def print_progress_indicator(message)
    @progress_chars = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    @progress_index = 0
    @progress_message = message
    @progress_active = true

    Thread.new do
      while @progress_active
        print "\r#{@progress_chars[@progress_index]} #{@progress_message}..."
        @progress_index = (@progress_index + 1) % @progress_chars.length
        sleep 0.1
      end
    end
  end

  def update_progress_indicator
    # Progress is updated by the animation thread
  end

  def clear_progress_indicator
    @progress_active = false
    print "\r" + ' ' * 50 + "\r"
  end
end