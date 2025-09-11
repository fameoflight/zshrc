# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

# Generic service for interacting with local LLM Studio models
class LLMService
  DEFAULT_MODEL = ENV['LOCAL_MODEL'] || 'gemma-2-27b-it'
  DEFAULT_ENDPOINT = 'http://localhost:1234/v1'

  def initialize(options = {})
    @endpoint = options[:endpoint] || DEFAULT_ENDPOINT
    @model = options[:model] || DEFAULT_MODEL
    @timeout = options[:timeout] || 30
    @temperature = options[:temperature] || 0.1
    @max_tokens = options[:max_tokens] || 1000
    @logger = options[:logger]
    @debug = options[:debug] || false
  end

  # Test if LLM Studio is available and responsive
  def available?
    @available ||= test_connection
  end

  # Send a simple completion request
  def complete(prompt, options = {})
    return nil unless available?

    system_message = options[:system] || 'You are a helpful assistant.'
    temp = options[:temperature] || @temperature
    max_tokens = options[:max_tokens] || @max_tokens

    messages = [
      { role: 'system', content: system_message },
      { role: 'user', content: prompt }
    ]

    send_chat_request(messages, temperature: temp, max_tokens: max_tokens)
  end

  # Send a chat request with full message history
  def chat(messages, options = {})
    return nil unless available?

    temp = options[:temperature] || @temperature
    max_tokens = options[:max_tokens] || @max_tokens

    send_chat_request(messages, temperature: temp, max_tokens: max_tokens)
  end

  # Get available models from LLM Studio
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

  # Change the active model
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

        log_debug("LLM Studio available. Models: #{available_models.join(', ')}")

        # Check if our preferred model is available
        if available_models.include?(@model)
          log_debug("Target model '#{@model}' is available")
        elsif available_models.any?
          log_warning("Target model '#{@model}' not found, using first available: #{available_models.first}")
          @model = available_models.first
        else
          log_error('No models available in LLM Studio')
          return false
        end

        true
      else
        log_warning("LLM Studio responded with status: #{response.code}")
        false
      end
    rescue Errno::ECONNREFUSED
      log_debug('LLM Studio not running (connection refused)')
      false
    rescue StandardError => e
      log_debug("LLM Studio connection failed: #{e.class.name} - #{e.message}")
      false
    end
  end

  def send_chat_request(messages, temperature:, max_tokens:)
    uri = URI("#{@endpoint}/chat/completions")

    payload = {
      model: @model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = @timeout
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      log_debug("Sending chat request to #{uri} with model #{@model}")

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        content = result.dig('choices', 0, 'message', 'content')

        log_debug("LLM response received: #{content&.length || 0} characters")
        content
      else
        log_error("LLM request failed with status #{response.code}: #{response.body}")
        nil
      end
    rescue StandardError => e
      log_error("LLM request error: #{e.class.name} - #{e.message}")
      nil
    end
  end

  # Logging methods with fallbacks
  def log_info(message)
    if @logger&.respond_to?(:log_info)
      @logger.log_info(message)
    elsif @debug
      puts "ℹ️  #{message}"
    end
  end

  def log_warning(message)
    if @logger&.respond_to?(:log_warning)
      @logger.log_warning(message)
    elsif @debug
      puts "⚠️  #{message}"
    end
  end

  def log_error(message)
    if @logger&.respond_to?(:log_error)
      @logger.log_error(message)
    else
      puts "❌ #{message}"
    end
  end

  def log_debug(message)
    if @logger&.respond_to?(:log_debug)
      @logger.log_debug(message)
    elsif @debug
      puts "🐛 #{message}"
    end
  end
end
