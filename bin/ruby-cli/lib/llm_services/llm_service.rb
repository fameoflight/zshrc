# frozen_string_literal: true

require_relative 'unified_llm_service'

# Legacy LLM service that wraps the new UnifiedLLMService for backward compatibility
# This maintains the old interface while using the new MODEL specification system
class LLMService < UnifiedLLMService
  # For backward compatibility, maintain the old provider constants
  PROVIDERS = %i[lm_studio ollama].freeze

  def initialize(options = {})
    # Convert old-style options to new MODEL format if needed
    if options[:provider] && !options[:model]
      # If only provider is specified, use default model for that provider
      model_spec = case options[:provider].to_sym
                   when :lm_studio
                     "lm_studio:#{ENV['LOCAL_MODEL'] || 'gemma-2-27b-it'}"
                   when :ollama
                     "ollama:#{ENV['OLLAMA_MODEL'] || 'llama3:70b'}"
                   else
                     options[:provider].to_s
                   end
      options = options.merge(model: model_spec)
    end

    super(options)
  end

  # Legacy method: Get the active service (for backward compatibility)
  def active_service
    @service
  end

  # Legacy method: Get service by provider name
  def get_service(provider)
    case provider.to_sym
    when :lm_studio
      return @service if current_provider == :lm_studio
    when :ollama
      return @service if current_provider == :ollama
    end

    nil
  end

  # Legacy method: List all available providers and their status
  def provider_status
    # Return basic status - for full functionality, use the unified service directly
    { current_provider => available? }
  end

  # Legacy method: Set the preferred provider
  def set_provider(provider)
    provider_sym = provider.to_sym
    unless PROVIDERS.include?(provider_sym)
      log_error("Unknown provider: #{provider}. Available: #{PROVIDERS.join(', ')}")
      return false
    end

    # Switch to the new provider using default model
    model_spec = case provider_sym
                 when :lm_studio
                   "lm_studio:#{ENV['LOCAL_MODEL'] || 'gemma-2-27b-it'}"
                 when :ollama
                   "ollama:#{ENV['OLLAMA_MODEL'] || 'llama3:70b'}"
                 end

    switch_provider(model_spec)
  end
end
