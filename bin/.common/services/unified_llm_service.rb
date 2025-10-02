# frozen_string_literal: true

require_relative 'base_service'
require_relative 'lm_studio_service'
require_relative 'ollama_service'

# Unified LLM service that supports multiple providers through MODEL specification
# Usage: MODEL='ollama:llama3:70b' MODEL='lm_studio:gemma3' MODEL='anthropic:sonnet3'
class UnifiedLLMService < BaseService
  # Default model specification if none provided
  DEFAULT_MODEL = ENV['MODEL'] || 'ollama:llama3:70b'

  # Supported providers and their service classes
  PROVIDERS = {
    ollama: OllamaService,
    lm_studio: LMStudioService,
    anthropic: nil, # To be implemented
    openai: nil     # To be implemented
  }.freeze

  def initialize(options = {})
    super(options)

    # Parse model specification from options or environment
    model_spec = options[:model] || DEFAULT_MODEL
    @provider, @model_name = parse_model_specification(model_spec)

    # Initialize the appropriate service
    @service = create_service(@provider, @model_name, options)

    log_debug("Unified LLM service initialized with provider: #{@provider}, model: #{@model_name}")
  end

  # Check if the service is available
  def available?
    @service&.available? || false
  end

  # Get the active provider name
  def current_provider
    @provider
  end

  # Get the current model name
  def current_model
    @model_name
  end

  # Get the full model specification
  def model_specification
    "#{@provider}:#{@model_name}"
  end

  # Send a completion request
  def complete(prompt, options = {})
    return nil unless available?
    @service.complete(prompt, options)
  end

  # Send a chat request
  def chat(messages, options = {})
    return nil unless available?
    @service.chat(messages, options)
  end

  # Get available models from the current provider
  def models
    return [] unless available?
    @service.models
  end

  # Change model within the same provider
  def set_model(model_name)
    return false unless available?

    if @service.respond_to?(:set_model)
      success = @service.set_model(model_name)
      @model_name = model_name if success
      success
    else
      log_error("Provider #{@provider} does not support model switching")
      false
    end
  end

  # Switch to a completely different provider and model
  def switch_provider(model_spec, options = {})
    provider, model_name = parse_model_specification(model_spec)

    new_service = create_service(provider, model_name, options)

    if new_service&.available?
      @provider = provider
      @model_name = model_name
      @service = new_service
      log_info("Switched to provider: #{@provider}, model: #{@model_name}")
      true
    else
      log_error("Failed to switch to provider: #{provider}, model: #{model_name}")
      false
    end
  end

  # List all supported providers
  def supported_providers
    PROVIDERS.keys
  end

  # Check if a provider is supported
  def provider_supported?(provider)
    PROVIDERS.key?(provider.to_sym)
  end

  # Provider-specific methods (delegate to underlying service)

  # LM Studio specific methods
  def ensure_sufficient_context(content_length, min_context_needed = nil, auto_reload = true)
    return true unless @provider == :lm_studio
    @service.ensure_sufficient_context(content_length, min_context_needed, auto_reload)
  end

  def get_current_context_length
    return nil unless @provider == :lm_studio
    @service.get_current_context_length
  end

  def reload_model_with_context(context_length)
    return false unless @provider == :lm_studio
    @service.reload_model_with_context(context_length)
  end

  # Ollama specific methods
  def pull_model(model_name = nil)
    return false unless @provider == :ollama

    # Use provided model name or current model
    target_model = model_name || @model_name
    @service.pull_model(target_model)
  end

  private

  # Parse model specification string into provider and model components
  # Formats supported:
  #   provider:model (e.g., "ollama:llama3")
  #   provider:model:variant (e.g., "ollama:llama3:70b")
  #   model (defaults to ollama)
  def parse_model_specification(model_spec)
    return [:ollama, 'llama3:70b'] if model_spec.nil? || model_spec.empty?

    parts = model_spec.split(':')

    case parts.length
    when 1
      # Just model name, default to ollama
      [:ollama, parts[0]]
    when 2
      # provider:model
      provider = parts[0].to_sym
      model = parts[1]

      # Validate provider
      unless provider_supported?(provider)
        log_warning("Unsupported provider '#{provider}', falling back to ollama")
        provider = :ollama
      end

      [provider, model]
    when 3
      # provider:model:variant (e.g., ollama:llama3:70b)
      provider = parts[0].to_sym
      model = "#{parts[1]}:#{parts[2]}"

      # Validate provider
      unless provider_supported?(provider)
        log_warning("Unsupported provider '#{provider}', falling back to ollama")
        provider = :ollama
      end

      [provider, model]
    else
      # Too many parts, take first as provider and join rest as model
      provider = parts[0].to_sym
      model = parts[1..-1].join(':')

      # Validate provider
      unless provider_supported?(provider)
        log_warning("Unsupported provider '#{provider}', falling back to ollama")
        provider = :ollama
      end

      [provider, model]
    end
  end

  # Create the appropriate service instance
  def create_service(provider, model_name, options = {})
    service_class = PROVIDERS[provider]

    unless service_class
      log_error("Provider '#{provider}' not yet implemented")
      return nil
    end

    # Merge model into options for the service
    service_options = options.merge(model: model_name)

    begin
      service_class.new(service_options)
    rescue StandardError => e
      log_error("Failed to create #{provider} service: #{e.message}")
      nil
    end
  end

  # Get a human-readable provider name
  def provider_display_name
    case @provider
    when :lm_studio
      'LM Studio'
    when :ollama
      'Ollama'
    when :anthropic
      'Anthropic'
    when :openai
      'OpenAI'
    else
      @provider.to_s.capitalize
    end
  end
end