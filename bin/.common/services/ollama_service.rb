# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require_relative 'base_service'

# Service for interacting with Ollama
class OllamaService < BaseService
  DEFAULT_MODEL = ENV['OLLAMA_MODEL'] || 'MichelRosselli/GLM-4.5-Air:latest'
  DEFAULT_ENDPOINT = 'http://localhost:11434'

  def initialize(options = {})
    super(options)
    @endpoint = options[:endpoint] || DEFAULT_ENDPOINT
    @model = options[:model] || DEFAULT_MODEL
    @timeout = options[:timeout] || 120
    @temperature = options[:temperature] || 0.1
    @max_tokens = options[:max_tokens] || 1000
  end

  def available?
    @available ||= test_connection
  end

  def complete(prompt, options = {})
    return nil unless available?

    system_message = options[:system] || 'You are a helpful assistant.'
    temp = options[:temperature] || @temperature
    stream = options[:stream] || false

    messages = [
      { role: 'system', content: system_message },
      { role: 'user', content: prompt }
    ]

    if stream
      send_chat_request_streaming(messages, temperature: temp)
    else
      send_chat_request(messages, temperature: temp)
    end
  end

  def chat(messages, options = {})
    return nil unless available?

    temp = options[:temperature] || @temperature
    send_chat_request(messages, temperature: temp)
  end

  def models
    return [] unless available?

    uri = URI("#{@endpoint}/api/tags")

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        result['models']&.map { |m| m['name'] } || []
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

  def pull_model(model_name)
    return false unless available?

    log_info("Pulling model: #{model_name}")

    uri = URI("#{@endpoint}/api/pull")

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 300 # 5 minutes for model download
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = { name: model_name }.to_json

      response = http.request(request)

      if response.code == '200'
        log_success("Model #{model_name} pulled successfully")
        true
      else
        log_error("Failed to pull model: #{response.code}")
        false
      end
    rescue StandardError => e
      log_error("Error pulling model: #{e.class.name} - #{e.message}")
      false
    end
  end

  private

  def test_connection
    uri = URI("#{@endpoint}/api/tags")

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'

      response = http.request(request)

      if response.code == '200'
        models_data = JSON.parse(response.body)
        available_models = models_data['models']&.map { |m| m['name'] } || []

        log_debug("Ollama available. Models: #{available_models.join(', ')}")

        # Check if our preferred model is available
        if available_models.include?(@model)
          log_debug("Target model '#{@model}' is available")
        elsif available_models.any?
          log_warning("Target model '#{@model}' not found, using first available: #{available_models.first}")
          @model = available_models.first
        else
          log_error('No models available in Ollama')
          return false
        end

        true
      else
        log_warning("Ollama responded with status: #{response.code}")
        false
      end
    rescue Errno::ECONNREFUSED
      log_debug('Ollama not running (connection refused)')
      false
    rescue StandardError => e
      log_debug("Ollama connection failed: #{e.class.name} - #{e.message}")
      false
    end
  end

  def send_chat_request(messages, temperature:)
    with_error_handling("Ollama chat request", {
      model: @model,
      messages_count: messages.length,
      temperature: temperature
    }) do
      uri = URI("#{@endpoint}/api/chat")

      payload = {
        model: @model,
        messages: messages,
        stream: false,  # Explicitly disable streaming for non-streaming requests
        options: {
          temperature: temperature
        }
      }

      # Use longer timeout and ensure we read the full response
      response = safe_http_request(uri, Net::HTTP::Post, "Ollama API request", timeout: @timeout + 30) do |request|
        request['Content-Type'] = 'application/json'
        request.body = payload.to_json
        request['Connection'] = 'close'  # Ensure connection closes after response
      end

      # Check if response body is empty or truncated
      if response.body.nil? || response.body.strip.empty?
        log_error("Received empty response body from Ollama")
        return nil
      end

      # Check if response looks truncated (common with JSON parsing issues)
      if response.body.count('{') != response.body.count('}') || response.body.count('[') != response.body.count(']')
        log_warning("Response appears to be truncated - unmatched brackets")
        log_debug("Raw response body: '#{response.body}'")
      end

      # Better error handling for JSON parsing
      begin
        result = JSON.parse(response.body)
      rescue JSON::ParserError => e
        log_error("Failed to parse JSON response: #{e.message}")
        log_debug("Raw response body: '#{response.body}'")
        log_debug("Response body length: #{response.body.length}")
        log_debug("Response headers: #{response.to_hash}")

        # Try to see if this is a streaming response that wasn't properly handled
        if response.body.include?('"model"') && response.body.include?('"message"')
          log_warning("Response looks like partial streaming data - you may need to use streaming mode")
        end

        return nil
      end

      content = result.dig('message', 'content')

      if content && !content.empty?
        log_debug("Ollama response received: #{content.length} characters")
        log_debug("Response preview: #{content[0..100]}...") if content.length > 100
        content
      else
        log_error("Ollama returned empty response for model #{@model}")
        log_debug("Full API response body: #{response.body}")
        log_debug("Parsed result: #{result}")
        nil
      end
    end
  end

  def send_chat_request_streaming(messages, temperature:)
    uri = URI("#{@endpoint}/api/chat")

    payload = {
      model: @model,
      messages: messages,
      stream: true,
      options: {
        temperature: temperature
      }
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

            chunk.split("\n").each do |line|
              next if line.strip.empty?

              begin
                data = JSON.parse(line)

                # Check if this is the final message or intermediate chunk
                if data['done']
                  # Final response - get the complete message
                  final_content = data.dig('message', 'content')
                  if final_content && !final_content.empty?
                    full_content = final_content
                  end
                else
                  # Intermediate chunk - accumulate content
                  content_delta = data.dig('message', 'content')
                  if content_delta
                    full_content += content_delta
                    update_progress_indicator
                  end
                end
              rescue JSON::ParserError => e
                log_debug("Skipping invalid JSON line: #{line.inspect} (#{e.message})")
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