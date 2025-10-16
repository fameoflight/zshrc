# frozen_string_literal: true

require_relative 'api_service'

# OpenAI-compatible service for AI/LLM API interactions
# Uses ApiService for HTTP requests and provides standard OpenAI interface
class OpenAIService
  def initialize(options = {})
    @base_url = options[:base_url]
    @api_key = options[:api_key]
    @api_key_header = options[:api_key_header] || 'Authorization'
    @model = options[:model]
    @debug = options[:debug] || false
    @timeout = options[:timeout] || 30
  end

  # Check if service is available
  def available?
    response = make_request('/models')
    !response.nil? && response.code.to_i == 200
  rescue
    false
  end

  # Get list of available models
  def models
    response = make_request('/models')
    return [] unless response

    data = ApiService.parse_json(response)
    return [] unless data

    data['data']&.map { |model| model['id'] } || []
  end

  # Chat completion (OpenAI compatible)
  def chat(messages, options = {})
    payload = {
      model: options[:model] || @model,
      messages: messages,
      temperature: options[:temperature] || 0.7,
      max_tokens: options[:max_tokens] || 2000,
      stream: false
    }

    # Add optional parameters
    payload[:top_p] = options[:top_p] if options[:top_p]
    payload[:frequency_penalty] = options[:frequency_penalty] if options[:frequency_penalty]
    payload[:presence_penalty] = options[:presence_penalty] if options[:presence_penalty]
    payload[:stop] = options[:stop] if options[:stop]

    response = make_request('/chat/completions', payload.to_json)
    return nil unless response

    data = ApiService.parse_json(response)
    return nil unless data

    # Extract the assistant's message
    choice = data['choices']&.first
    choice&.dig('message', 'content')
  end

  # Simple text completion
  def complete(prompt, options = {})
    messages = [{ role: 'user', content: prompt }]
    chat(messages, options)
  end

  # Streaming chat completion
  def chat_stream(messages, options = {}, &block)
    payload = {
      model: options[:model] || @model,
      messages: messages,
      temperature: options[:temperature] || 0.7,
      max_tokens: options[:max_tokens] || 2000,
      stream: true
    }

    response = make_request('/chat/completions', payload.to_json)
    return nil unless response

    if block_given?
      # Process streaming response line by line
      response.body.each_line do |line|
        next if line.strip.empty?
        next unless line.start_with?('data: ')

        data = line[6..-1].strip
        next if data == '[DONE]'

        begin
          json = JSON.parse(data)
          delta = json.dig('choices', 0, 'delta', 'content')
          yield delta if delta
        rescue JSON::ParserError
          # Skip malformed JSON in streaming
          next
        end
      end
    else
      response.body
    end
  end

  # Get current model info
  def model_info
    response = make_request('/models')
    return nil unless response

    data = ApiService.parse_json(response)
    return nil unless data

    # Find current model in the list
    models = data['data'] || []
    models.find { |model| model['id'] == @model }
  end

  # Change the active model
  def set_model(model_name)
    @model = model_name
    true
  end

  # Get current model
  def current_model
    @model
  end

  # Test connection and model availability
  def test_connection
    return { status: 'error', message: 'Service not available' } unless available?

    models = self.models
    if models.include?(@model)
      { status: 'success', message: "Service available with model: #{@model}", models: models }
    else
      { status: 'warning', message: "Service available but model '#{@model}' not found", available_models: models }
    end
  rescue => e
    { status: 'error', message: "Connection test failed: #{e.message}" }
  end

  private

  def make_request(endpoint, body = nil)
    url = "#{@base_url.chomp('/')}/#{endpoint.lstrip('/')}"
    headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }

    # Add API key if provided
    if @api_key
      case @api_key_header.downcase
      when 'authorization'
        headers['Authorization'] = "Bearer #{@api_key}"
      when 'x-api-key'
        headers['X-API-Key'] = @api_key
      else
        headers[@api_key_header] = @api_key
      end
    end

    puts "[DEBUG] #{body ? 'POST' : 'GET'} #{url}" if @debug
    puts "[DEBUG] Headers: #{headers}" if @debug
    puts "[DEBUG] Body: #{body[0..200]}#{'...' if body && body.length > 200}" if @debug && body

    case body
    when nil
      ApiService.get(url, headers)
    else
      ApiService.post(url, body, headers)
    end
  end
end

# Usage examples:
#
# # OpenAI Service
# openai = OpenAIService.new(
#   base_url: 'https://api.openai.com/v1',
#   api_key: 'your-openai-key',
#   model: 'gpt-4'
# )
#
# # LM Studio Service (just use OpenAI service with different config)
# lm_studio = OpenAIService.new(
#   base_url: 'http://localhost:1234/v1',
#   api_key: 'not-required',
#   model: 'openai/gpt-oss-120b'
# )
#
# if lm_studio.available?
#   response = lm_studio.complete("Hello!")
#   puts response
# end