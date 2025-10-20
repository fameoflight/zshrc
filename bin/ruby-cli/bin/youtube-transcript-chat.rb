#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../.common/script_base'
require_relative '../lib/archive/services/llm_service'
require_relative '../lib/archive/services/conversation_service'
require_relative '../lib/archive/services/llm_chain_processor'
require_relative '../lib/archive/services/media_transcript_service'
require_relative '../lib/archive/services/file_cache_service'
require_relative '../lib/archive/services/markdown_renderer'
require_relative '../lib/archive/services/video_info_service'
require_relative '../lib/archive/services/url_validation_service'
require_relative '../lib/archive/services/configuration_display_service'
require_relative '../lib/archive/services/summary_generation_service'
require_relative '../lib/archive/services/interactive_chat_service'
require_relative '../lib/archive/utils/progress_utils'
require_relative '../lib/archive/utils/interactive_settings_utils'
require_relative '../lib/archive/utils/time_utils'
include TimeUtils

# YouTube Transcript Chat - Refactored version using extracted services
class YouTubeTranscriptChat < ScriptBase
  include ProgressUtils
  include InteractiveSettingsUtils

  def banner_text
    <<~BANNER
      🎥 YouTube Transcript Chat (Refactored)

      Download YouTube video transcripts and chat with the content using local LLM.
      Uses modular services for better maintainability and reusability.

      Usage: #{script_name} [OPTIONS] <youtube-url>
    BANNER
  end

  def add_custom_options(opts)
    opts.on('-l', '--language LANG', 'Preferred transcript language (default: en)') do |lang|
      @options[:language] = lang
    end

    opts.on('-s', '--summary-only', 'Only generate summary, skip interactive chat') do
      @options[:summary_only] = true
    end

    opts.on('-o', '--output FILE', 'Save transcript to file') do |file|
      @options[:output_file] = file
    end

    opts.on('--force-refresh', 'Force re-download transcript, ignore cache') do
      @options[:force_refresh] = true
    end

    opts.on('--cache-ttl DAYS', Integer, 'Cache time-to-live in days (default: 7)') do |days|
      @options[:cache_ttl] = days
    end

    opts.on('--clear-cache', 'Clear all cached transcripts') do
      @options[:clear_cache] = true
    end

    opts.on('-m', '--model MODEL', 'LLM model to use') do |model|
      @options[:model] = model
    end

    opts.on('--list-models', 'List available LLM models and exit') do
      @options[:list_models] = true
    end

    opts.on('--temp TEMPERATURE', Float, 'Set temperature (0.0-1.0)') do |temp|
      @options[:temperature] = temp
    end

    opts.on('--max-tokens TOKENS', Integer, 'Maximum tokens to generate') do |tokens|
      @options[:max_tokens] = tokens
    end

    opts.on('--timeout SECONDS', Integer, 'Request timeout in seconds (default: 300)') do |timeout|
      @options[:timeout] = timeout
    end

    opts.on('--min-context TOKENS', Integer, 'Minimum context length to ensure') do |context|
      @options[:min_context] = context
    end

    opts.on('--auto-reload', 'Automatically reload model with larger context if needed (default: true)') do
      @options[:auto_reload] = true
    end

    opts.on('--no-auto-reload', 'Disable automatic model reloading') do
      @options[:auto_reload] = false
    end

    opts.on('--no-chunking', 'Force processing entire transcript without chunking (may cause timeouts for very large transcripts)') do
      @options[:no_chunking] = true
    end

    opts.on('--chunk-size CHARS', Integer, 'Set chunk size in characters for large transcripts (default: 12000)') do |size|
      @options[:chunk_size] = size
    end

    opts.on('--markdown', 'Enable markdown formatting for output (default: true)') do
      @options[:markdown] = true
    end

    opts.on('--no-markdown', 'Disable markdown formatting, use plain text') do
      @options[:markdown] = false
    end

    opts.on('--configure', 'Show interactive settings menu') do
      @options[:configure] = true
    end
  end

  def default_options
    {
      language: 'en',
      summary_only: false,
      output_file: nil,
      force_refresh: false,
      cache_ttl: 7,
      clear_cache: false,
      model: nil,
      list_models: false,
      temperature: 0.3,
      max_tokens: 1000,
      timeout: 300,
      min_context: nil,
      auto_reload: true,
      no_chunking: false,
      chunk_size: 12000,
      markdown: true,
      configure: false
    }
  end

  def validate!
    if @options[:clear_cache]
      @cache.clear if @cache
      log_success("Cache cleared successfully")
      exit 0
    end

    # Initialize essential services needed for validation and early operations
    @url_validation = URLValidationService.new
    @video_info = VideoInfoService.new(logger: self)

    if @options[:list_models]
      model_spec = @options[:model] || ENV['MODEL'] || 'ollama:llama3:70b'

      llm_options = {
        logger: self,
        debug: @options[:verbose] || @options[:debug],
        model: model_spec
      }

      @llm = LLMService.new(llm_options)

      if @llm.available?
        models = @llm.models

        if models.any?
          puts "Available LLM models:"
          models.each_with_index do |model, index|
            puts "  #{index + 1}. #{model}"
          end
        else
          puts "No models available in LLM Studio"
        end
      else
        puts "LLM Studio is not running or not accessible"
        puts "Start LM Studio and load a model, then run: lms-start"
      end
      exit 0
    end

    if @options[:configure]
      show_interactive_settings_menu
      exit 0
    end

    if @args.empty?
      log_error("YouTube URL is required")
      show_help
      exit 1
    end

    @youtube_url = @args[0]

    unless @url_validation.valid_youtube_url?(@youtube_url)
      log_error("Invalid YouTube URL: #{@youtube_url}")
      exit 1
    end

    initialize_services
    super
  end

  def run
    measure_time("YouTube Transcript Chat execution") do
      log_banner("YouTube Transcript Chat")

      # Show current configuration
      @config_display.display_app_configuration(@options, @cache)

      # Check LLM availability
      unless @llm.available?
        log_error("LLM Studio is not available. Please start it and try again.")
        exit 1
      end

      # Download and process transcript
      transcript_data = with_error_handling("Transcript download", { url: @youtube_url }) do
        download_transcript
      end
      return unless transcript_data

      # Generate summary
      log_debug("About to call generate_summary with transcript_data: #{transcript_data.keys}")
      log_debug("transcript_data[:full_text] class: #{transcript_data[:full_text].class}")
      log_debug("transcript_data[:full_text] value: #{transcript_data[:full_text].inspect}")

      summary = with_error_handling("Summary generation", {
        transcript_length: transcript_data[:full_text]&.length || 0,
        video_title: transcript_data.dig(:video_info, :title)
      }) do
        generate_summary(transcript_data)
      end
      return unless summary

      # Interactive chat (unless summary-only mode)
      unless @options[:summary_only]
        @chat_service.start_chat_session(transcript_data, summary, chat_options)
      end

      show_completion("YouTube Transcript Chat")
    end
  end

  private

  def initialize_services
    # Initialize LLM service with MODEL specification
    model_spec = @options[:model] || ENV['MODEL'] || 'ollama:llama3:70b'

    @llm = LLMService.new({
      logger: self,
      model: model_spec,
      debug: @options[:verbose] || @options[:debug],
      temperature: @options[:temperature],
      max_tokens: @options[:max_tokens],
      timeout: @options[:timeout]
    })

    # Initialize cache service
    cache_dir = File.expand_path('~/.cache/youtube-transcript-chat')
    @cache = FileCacheService.new(cache_dir, {
      ttl_days: @options[:cache_ttl],
      enabled: true,
      logger: self
    })

    # Initialize specialized services
    @config_display = ConfigurationDisplayService.new
    @summary_service = SummaryGenerationService.new(@llm, {
      temperature: @options[:temperature],
      max_tokens: @options[:max_tokens],
      chunk_size: @options[:chunk_size],
      timeout: @options[:timeout]
    })
    @chat_service = InteractiveChatService.new(@llm, {
      temperature: @options[:temperature],
      max_tokens: @options[:max_tokens],
      auto_reload: @options[:auto_reload],
      min_context: @options[:min_context]
    })

    # Initialize transcript service
    @transcript_service = MediaTranscriptService.new({
      language: @options[:language],
      output_file: @options[:output_file],
      logger: self
    })

    # Initialize markdown renderer
    @markdown = MarkdownRenderer.new({
      enabled: @options[:markdown],
      width: 120,
      logger: self
    })
  end

  def download_transcript
    log_section("📥 Downloading Transcript")

    # Extract video ID for caching
    video_id = @url_validation.extract_youtube_video_id(@youtube_url)
    unless video_id
      log_error("Could not extract video ID from URL")
      return nil
    end

    language = @options[:language] || 'en'
    cache_key = "#{video_id}_#{language}"

    # Check cache first
    if @cache.enabled? && !@options[:force_refresh]
      cached_data = @cache.get(cache_key)
      if cached_data
        log_info("📦 Using cached transcript")
        log_debug("Cached data type: #{cached_data.class}")
        log_debug("Cached data keys: #{cached_data.keys.join(', ')}") if cached_data.respond_to?(:keys)
        log_debug("Cached full_text type: #{cached_data['full_text'].class}") if cached_data['full_text']
        log_debug("Cached full_text (symbol) type: #{cached_data[:full_text].class}") if cached_data[:full_text]

        # Convert string keys to symbols if needed
        if cached_data.is_a?(Hash) && cached_data['full_text'] && !cached_data[:full_text]
          log_debug("Converting string keys to symbols")
          cached_data = cached_data.transform_keys(&:to_sym)
        end

        return cached_data
      end
    end

    # Download transcript using the transcript service
    begin
      # MediaTranscriptService returns parsed transcript data directly
      transcript_data = @transcript_service.download_transcript(@youtube_url)

      unless transcript_data
        log_error("Failed to download transcript")
        return nil
      end

      # Get video info if not already included
      unless transcript_data[:video_info]
        video_info = @video_info.get_video_info(@youtube_url)
        unless video_info
          log_error("Failed to get video information")
          return nil
        end
        transcript_data[:video_info] = video_info
      end

      # Cache the result if successful
      if transcript_data && @cache.enabled?
        @cache.set(cache_key, transcript_data, ttl_days: @options[:cache_ttl])
        log_success("💾 Transcript cached successfully")
      end

      transcript_data
    rescue => e
      log_error("Failed to download transcript: #{e.message}")
      nil
    end
  end

  def generate_summary(transcript_data)
    log_section("📝 Generating Summary")

    # Check if we have valid transcript data
    unless transcript_data
      log_error("Invalid transcript data: transcript_data is nil")
      return nil
    end

    full_text = transcript_data[:full_text]
    unless full_text && !full_text.empty?
      log_error("Invalid transcript data: full_text is missing or empty")
      log_debug("Transcript data keys: #{transcript_data.keys.join(', ')}")
      log_debug("Full text value: #{full_text.inspect}")
      return nil
    end

    log_debug("Transcript length: #{full_text.length} characters")
    log_debug("Video info: #{transcript_data[:video_info]}")

    # Use the summary generation service
    summary = @summary_service.generate_summary(
      transcript_data[:full_text],
      transcript_data[:video_info],
      {
        chunk_size: @options[:chunk_size],
        no_chunking: @options[:no_chunking],
        temperature: @options[:temperature],
        max_tokens: @options[:max_tokens],
        timeout: @options[:timeout],
        auto_reload: @options[:auto_reload],
        min_context: @options[:min_context]
      }
    )

    if summary && !summary.empty?
      log_success("Summary generated successfully")
      log_debug("Summary length: #{summary.length} characters")
      log_debug("Summary content preview: #{summary[0..200]}...") if summary.length > 200
      puts "\n" + "="*50
      puts "📝 VIDEO SUMMARY"
      puts "="*50
      puts summary
      puts "="*50 + "\n"
      @markdown.render_summary(summary)
      summary
    else
      log_error("Failed to generate summary - received empty or nil response")
      log_debug("Summary value: #{summary.inspect}")
      puts "\n❌ No summary was generated. This could indicate:"
      puts "   - LLM service timeout or connection issue"
      puts "   - Model response format problem"
      puts "   - Content filtering or safety restrictions"
      puts "   Try with a different model or check LLM Studio logs.\n"
      nil
    end
  end

  def chat_options
    {
      max_tokens: @options[:max_tokens],
      temperature: @options[:temperature],
      timeout: @options[:timeout],
      auto_reload: @options[:auto_reload],
      min_context: @options[:min_context]
    }
  end

  def show_interactive_settings_menu
    choices = [
      { name: '🤖 Model Settings', value: :model_settings },
      { name: '🎥 Transcript Settings', value: :transcript_settings },
      { name: '💾 Cache Settings', value: :cache_settings },
      { name: '📄 Output Settings', value: :output_settings },
      { name: '💾 Save Current Settings', value: :save_settings },
      { name: '🔄 Reset to Defaults', value: :reset_settings },
      { name: '❌ Exit Settings', value: :exit }
    ]

    interactive_settings_menu('⚙️  YouTube Transcript Chat Settings', choices) do |action, prompt|
      case action
      when :show_config
        @config_display.display_app_configuration(@options, @cache)
      when :model_settings
        configure_model_settings(prompt)
      when :transcript_settings
        configure_transcript_settings(prompt)
      when :cache_settings
        configure_cache_settings(prompt)
      when :output_settings
        configure_output_settings(prompt)
      when :save_settings
        save_current_settings
        log_success('Settings saved successfully!')
      when :reset_settings
        if confirm_action('🗑️  Reset all settings to defaults?', default: false)
          reset_settings!
          log_success('Settings reset to defaults!')
        end
      when :exit
        :exit
      end
    end
  end

  def configure_model_settings(prompt)
    choices = [
      { name: "🌡️  Temperature: #{@options[:temperature]}", value: :temperature },
      { name: "🔢 Max Tokens: #{@options[:max_tokens]}", value: :max_tokens },
      { name: '← Back to Main Menu', value: :back }
    ]

    selection = prompt.select('🤖 Model Settings', choices, cycle: true)

    case selection
    when :temperature
      @options[:temperature] =
        prompt.slider('Temperature (creativity)', min: 0.0, max: 1.0, step: 0.1, default: @options[:temperature])
    when :max_tokens
      token_choices = [
        { name: '1000 tokens (default)', value: 1000 },
        { name: '2000 tokens (longer responses)', value: 2000 },
        { name: '4000 tokens (maximum responses)', value: 4000 }
      ]
      @options[:max_tokens] = prompt.select('Select max tokens:', token_choices)
    when :back
      return
    end
  end

  def configure_transcript_settings(prompt)
    choices = [
      { name: "🌍 Language: #{@options[:language]}", value: :language },
      { name: "📋 Summary Only: #{@options[:summary_only] ? 'Yes' : 'No'}", value: :summary_only },
      { name: '← Back to Main Menu', value: :back }
    ]

    selection = prompt.select('🎥 Transcript Settings', choices, cycle: true)

    case selection
    when :language
      @options[:language] = prompt.ask('Enter language code:', default: @options[:language])
    when :summary_only
      @options[:summary_only] = prompt.yes?('Generate summary only (skip chat)?', default: @options[:summary_only])
    when :back
      return
    end
  end

  def configure_cache_settings(prompt)
    cache_stats = @cache.stats

    choices = [
      { name: "⏰ Cache TTL: #{@options[:cache_ttl]} days", value: :cache_ttl },
      { name: "📊 Cache Info: #{cache_stats[:total_entries]} files", value: :cache_info },
      { name: "🧹 Clear Cache Now", value: :clear_cache },
      { name: '← Back to Main Menu', value: :back }
    ]

    selection = prompt.select('💾 Cache Settings', choices, cycle: true)

    case selection
    when :cache_ttl
      @options[:cache_ttl] =
        prompt.slider('Cache time-to-live (days)', min: 1, max: 30, step: 1, default: @options[:cache_ttl])
    when :cache_info
      @config_display.show_cache_info(File.expand_path('~/.cache/youtube-transcript-chat'))
      prompt.keypress('Press any key to continue...')
    when :clear_cache
      if prompt.yes?('🗑️  Clear all cached transcripts?', default: false)
        @cache.clear
        log_success('Cache cleared successfully!')
      end
    when :back
      return
    end
  end

  def configure_output_settings(prompt)
    choices = [
      { name: "📄 Output File: #{@options[:output_file] || 'None'}", value: :output_file },
      { name: '← Back to Main Menu', value: :back }
    ]

    selection = prompt.select('📄 Output Settings', choices, cycle: true)

    case selection
    when :output_file
      if prompt.yes?('Save transcript to file?', default: @options[:output_file] != nil)
        @options[:output_file] =
          prompt.ask('Enter output file path:', default: @options[:output_file] || 'transcript.txt')
      else
        @options[:output_file] = nil
      end
    when :back
      return
    end
  end

  def save_current_settings
    save_settings(@options.select { |k, v| default_options.key?(k) && v != default_options[k] })
  end
end

# Execute the script
YouTubeTranscriptChat.execute if __FILE__ == $0
