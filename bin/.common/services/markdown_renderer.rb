# frozen_string_literal: true

require_relative 'base_service'

# Service for rendering markdown text with fallback to plain text
class MarkdownRenderer < BaseService
  def initialize(options = {})
    super(options)
    @enabled = options.fetch(:enabled, true)
    @width = options[:width] || 120
    @indent = options[:indent] || 0
    @disabled = false
    @failure_count = 0
    @max_failures = options[:max_failures] || 3
  end

  # Render text with markdown formatting, fallback to plain text
  def render(text, type: :default)
    return render_plain(text, type: type) if disabled? || !@enabled || text.nil? || text.empty?

    begin
      require 'tty-markdown'

      # Validate and clean text
      cleaned_text = clean_text(text)
      return render_plain(text, type: type) if cleaned_text.nil? || cleaned_text.empty?

      # Parse markdown with error handling
      parsed = TTY::Markdown.parse(cleaned_text, width: @width, indent: @indent)

      # Reset failure count on success
      @failure_count = 0
      parsed
    rescue LoadError
      log_debug('tty-markdown not available, using plain text') if @logger
      disable_markdown!('tty-markdown gem not available')
      render_plain(text, type: type)
    rescue ArgumentError, IndexError => e
      handle_parsing_error(e, text, type)
    rescue StandardError => e
      handle_rendering_error(e, text, type)
    end
  end

  # Render summary with special formatting
  def render_summary(summary)
    render(summary, type: :summary)
  end

  # Render response text
  def render_response(text)
    render(text, type: :response)
  end

  # Check if markdown rendering is disabled
  def disabled?
    @disabled
  end

  # Force disable markdown
  def disable!
    @disabled = true
    @enabled = false
  end

  # Force enable markdown (reset failures)
  def enable!
    @disabled = false
    @enabled = true
    @failure_count = 0
  end

  # Get current status
  def status
    {
      enabled: @enabled,
      disabled: @disabled,
      failure_count: @failure_count,
      available: markdown_available?
    }
  end

  private

  def render_plain(text, type: :default)
    case type
    when :summary
      render_plain_summary(text)
    when :response
      puts text
    else
      puts text
    end
  end

  def render_plain_summary(summary)
    separator = '=' * 80
    puts "\n#{separator}"
    puts '📋 SUMMARY'
    puts separator
    puts summary
    puts "#{separator}\n"
  end

  def clean_text(text)
    return nil unless text.is_a?(String)

    # Force UTF-8 encoding and scrub invalid characters
    cleaned = text.dup.force_encoding('UTF-8').scrub('?')

    # Remove any control characters that might cause issues
    cleaned.gsub(/[\x00-\x1f\x7f]/, '')
  end

  def handle_parsing_error(error, text, type)
    @failure_count += 1
    log_debug("Markdown parsing error (#{@failure_count}/#{@max_failures}): #{error.message}") if @logger

    disable_markdown!('Too many parsing failures') if @failure_count >= @max_failures

    render_plain(text, type: type)
  end

  def handle_rendering_error(error, text, type)
    @failure_count += 1
    log_debug("Markdown rendering error (#{@failure_count}/#{@max_failures}): #{error.message}") if @logger

    disable_markdown!('Too many rendering failures') if @failure_count >= @max_failures

    render_plain(text, type: type)
  end

  def disable_markdown!(reason = nil)
    @disabled = true
    @enabled = false
    message = 'Markdown rendering disabled'
    message += ": #{reason}" if reason
    log_warning(message) if @logger
  end

  def markdown_available?
    require 'tty-markdown'
    true
  rescue LoadError
    false
  end
end
