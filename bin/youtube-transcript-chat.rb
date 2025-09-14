#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/services/llm_service'
require_relative '.common/services/conversation_service'
require 'tempfile'
require 'json'

# YouTube Transcript Chat - Download transcripts and chat with video content using local LLM
class YouTubeTranscriptChat < ScriptBase
  def banner_text
    <<~BANNER
      🎥 YouTube Transcript Chat

      Download YouTube video transcripts and chat with the content using local LLM.

      Usage: #{script_name} [OPTIONS] <youtube-url>

      Features:
      • Download video transcripts automatically
      • Generate AI-powered summaries
      • Interactive chat with video content
      • Support for multiple transcript languages
      • Local LLM integration via LM Studio
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

    opts.on('-m', '--model MODEL', 'LLM model to use (if multiple available)') do |model|
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

    opts.on('--timeout SECONDS', Integer, 'Request timeout in seconds') do |timeout|
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

    opts.on('--configure', 'Show interactive settings menu') do
      @options[:configure] = true
    end

    opts.on('--markdown', 'Enable markdown formatting for output (default: true)') do
      @options[:markdown] = true
    end

    opts.on('--no-markdown', 'Disable markdown formatting, use plain text') do
      @options[:markdown] = false
    end
  end

  def default_options
    yt_defaults = {
      language: 'en',
      summary_only: false,
      output_file: nil,
      model: nil,
      list_models: false,
      temperature: 0.3,
      max_tokens: 1000,
      timeout: 120,
      min_context: nil,
      auto_reload: true,
      configure: false,
      markdown: true
    }

    # ScriptBase will handle loading saved settings automatically
    super.merge(yt_defaults)
  end

  def validate!
    if @options[:list_models]
      list_available_models
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
    unless valid_youtube_url?(@youtube_url)
      log_error("Invalid YouTube URL: #{@youtube_url}")
      exit 1
    end

    # Check if yt-dlp is available
    unless command_exists?('yt-dlp')
      log_error("yt-dlp is required but not installed. Run: brew install yt-dlp")
      exit 1
    end

    super
  end

  def run
    log_banner("YouTube Transcript Chat")

    # Show current configuration
    show_current_configuration

    # Initialize LLM service with configured options
    llm_options = {
      logger: self,
      debug: @options[:verbose] || @options[:debug],
      temperature: @options[:temperature],
      max_tokens: @options[:max_tokens],
      timeout: @options[:timeout]
    }
    llm_options[:model] = @options[:model] if @options[:model]

    @llm = LLMService.new(llm_options)

    unless @llm.available?
      log_error("LLM Studio is not available. Please start it and try again.")
      log_info("Start LM Studio and load a model, then run: lms-start")
      exit 1
    end

    # Download transcript
    transcript_data = download_transcript
    return unless transcript_data

    # Generate summary
    summary = generate_summary(transcript_data)
    return unless summary

    # Interactive chat (unless summary-only mode)
    unless @options[:summary_only]
      interactive_chat(transcript_data, summary)
    end

    show_completion("YouTube Transcript Chat")
  end

  private

  def download_transcript
    log_section("📥 Downloading Transcript")

    # Get video info first
    video_info = get_video_info
    return nil unless video_info

    log_info("Video: #{video_info[:title]}")
    log_info("Duration: #{video_info[:duration]}")

    # Create temporary directory for transcript
    @temp_dir = Dir.mktmpdir("youtube_transcript_")
    transcript_file = File.join(@temp_dir, "transcript.json")

    language = @options[:language] || 'en'

    # Download transcript using yt-dlp
    cmd = [
      'yt-dlp',
      '--write-auto-subs',
      '--sub-langs', language,
      '--sub-format', 'json3',
      '--skip-download',
      '--output', File.join(@temp_dir, '%(title)s.%(ext)s'),
      @youtube_url
    ]

    log_progress("Downloading transcript in #{language}")

    success = system(*cmd, out: '/dev/null', err: '/dev/null')

    unless success
      log_warning("Failed to download transcript in #{language}, trying English...")

      cmd[3] = 'en'  # Change language to English
      success = system(*cmd, out: '/dev/null', err: '/dev/null')

      unless success
        log_error("Failed to download transcript. Video may not have captions available.")
        return nil
      end
    end

    # Find the downloaded transcript file
    transcript_files = Dir.glob(File.join(@temp_dir, "*.json3"))

    if transcript_files.empty?
      log_error("No transcript files found after download")
      return nil
    end

    transcript_file = transcript_files.first
    log_success("Transcript downloaded successfully")

    # Parse transcript
    parse_transcript(transcript_file, video_info)
  end

  def get_video_info
    log_debug("Getting video information")

    cmd = ['yt-dlp', '--dump-json', '--no-download', @youtube_url]

    output = `#{cmd.join(' ')} 2>/dev/null`

    if $?.success? && !output.empty?
      begin
        info = JSON.parse(output)
        {
          title: info['title'],
          duration: format_duration(info['duration']),
          uploader: info['uploader'],
          upload_date: info['upload_date']
        }
      rescue JSON::ParserError => e
        log_error("Failed to parse video info: #{e.message}")
        nil
      end
    else
      log_error("Failed to get video information")
      nil
    end
  end

  def parse_transcript(transcript_file, video_info)
    log_debug("Parsing transcript file")

    begin
      content = File.read(transcript_file)
      transcript_json = JSON.parse(content)

      # Extract events (subtitle entries)
      events = transcript_json['events'] || []

      # Build full text from transcript segments
      full_text = ""
      segments = []

      events.each do |event|
        next unless event['segs'] # Skip events without segments

        segment_text = ""
        start_time = event['tStartMs'] / 1000.0 if event['tStartMs']

        event['segs'].each do |seg|
          segment_text += seg['utf8'] if seg['utf8']
        end

        next if segment_text.strip.empty?

        full_text += segment_text + " "
        segments << {
          text: segment_text.strip,
          start_time: start_time,
          formatted_time: format_time(start_time)
        }
      end

      # Save to file if requested
      if @options[:output_file]
        File.write(@options[:output_file], full_text)
        log_file_created(@options[:output_file])
      end

      transcript_data = {
        video_info: video_info,
        full_text: full_text.strip,
        segments: segments,
        word_count: full_text.split.length
      }

      log_info("Transcript parsed: #{transcript_data[:word_count]} words, #{segments.length} segments")
      transcript_data

    rescue JSON::ParserError => e
      log_error("Failed to parse transcript JSON: #{e.message}")
      nil
    rescue StandardError => e
      log_error("Error processing transcript: #{e.message}")
      nil
    end
  end

  def generate_summary(transcript_data)
    log_section("📝 Generating Summary")

    video_info = transcript_data[:video_info]
    text = transcript_data[:full_text]

    # Note: Not truncating transcript - using full content for better summarization
    log_info("Using full transcript: #{text.length} characters for summarization")

    system_prompt = <<~PROMPT
      You are an AI assistant that creates detailed, helpful summaries of YouTube video transcripts. Focus on the most valuable information.
    PROMPT

    user_prompt = <<~PROMPT
      Please summarize this YouTube video transcript:

      **Video Title:** #{video_info[:title]}
      **Duration:** #{video_info[:duration]}
      **Uploader:** #{video_info[:uploader]}

      **Transcript:**
      #{text}
    PROMPT

    log_progress("Generating summary with local LLM")

    # Check context before making request (if auto-reload enabled)
    if @options[:auto_reload]
      total_content = "#{system_prompt}\n#{user_prompt}"
      min_context = @options[:min_context] || nil
      unless @llm.ensure_sufficient_context(total_content.length, min_context, @options[:auto_reload])
        log_error("Insufficient context for transcript processing")
        return nil
      end
    end

    summary = @llm.complete(
      user_prompt,
      system: system_prompt,
      max_tokens: @options[:max_tokens],
      temperature: @options[:temperature],
      auto_reload: @options[:auto_reload],
      min_context: @options[:min_context]
    )

    if summary && !summary.empty?
      log_success("Summary generated successfully")

      display_summary(summary)
      summary
    else
      log_error("Failed to generate summary")
      nil
    end
  end

  def interactive_chat(transcript_data, summary)
    log_section("💬 Interactive Chat")

    video_info = transcript_data[:video_info]

    puts "\nYou can now ask questions about the video content."
    puts "Type 'exit', 'quit', or 'q' to end the conversation."
    puts "Type 'summary' to show the summary again."
    puts "Type 'history' to see conversation summary.\n"

    # Initialize conversation using ConversationService
    system_context = build_system_context(transcript_data, summary)
    @conversation = ConversationService.new(@llm, system_prompt: system_context)

    loop do
      print "\n🎥 Ask about the video: "
      question = STDIN.gets.chomp.strip

      break if ['exit', 'quit', 'q'].include?(question.downcase)

      if question.downcase == 'summary'
        display_summary(summary)
        next
      end

      if question.downcase == 'history'
        puts "\n📊 Conversation Summary:"
        summary_info = @conversation.summary
        puts "  Messages: #{summary_info[:total_messages]}"
        puts "  Your questions: #{summary_info[:user_messages]}"
        puts "  AI responses: #{summary_info[:assistant_messages]}"
        next
      end

      next if question.empty?

      log_progress("Thinking")

      # Send message using ConversationService
      response = @conversation.send_message(
        question,
        max_tokens: @options[:max_tokens],
        temperature: @options[:temperature],
        auto_reload: @options[:auto_reload],
        min_context: @options[:min_context]
      )

      if response && !response.empty?
        puts "\n🤖 "
        display_markdown_response(response)
        puts
      else
        log_error("Failed to get response from LLM")
      end
    end

    log_success("Chat session ended")
    log_info("Total conversation: #{@conversation.summary[:user_messages]} questions asked")
  end

  def build_system_context(transcript_data, summary)
    video_info = transcript_data[:video_info]

    <<~CONTEXT
      You are an AI assistant helping users understand and discuss a YouTube video.

      **Video Information:**
      - Title: #{video_info[:title]}
      - Duration: #{video_info[:duration]}
      - Uploader: #{video_info[:uploader]}

      **Video Summary:**
      #{summary}

      **Full Transcript:**
      #{transcript_data[:full_text][0..8000]}#{transcript_data[:full_text].length > 8000 ? "..." : ""}

      **Instructions:**
      - Answer questions based on the video content
      - Be specific and reference the actual content when possible
      - If asked about something not covered in the video, say so clearly
      - Keep responses concise but informative
      - You can quote specific parts of the transcript when relevant
    CONTEXT
  end

  def list_available_models
    llm = LLMService.new(debug: true)

    if llm.available?
      models = llm.models

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
  end

  def valid_youtube_url?(url)
    # Basic YouTube URL validation
    url.match?(/(?:youtube\.com\/watch\?v=|youtu\.be\/)[\w-]+/)
  end

  def command_exists?(command)
    system("which #{command} > /dev/null 2>&1")
  end

  def format_duration(seconds)
    return "Unknown" unless seconds

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    seconds = seconds % 60

    if hours > 0
      "%d:%02d:%02d" % [hours, minutes, seconds]
    else
      "%d:%02d" % [minutes, seconds]
    end
  end

  def format_time(seconds)
    return "0:00" unless seconds

    minutes = (seconds / 60).to_i
    seconds = (seconds % 60).to_i

    "%d:%02d" % [minutes, seconds]
  end

  def show_examples
    puts <<~EXAMPLES
      Examples:
        # Basic usage
        #{script_name} https://youtu.be/8dqU27oqkuE

        # Different language transcript
        #{script_name} --language es https://youtu.be/8dqU27oqkuE

        # Summary only with transcript save
        #{script_name} --summary-only --output transcript.txt https://youtu.be/8dqU27oqkuE

        # Use specific model with custom settings
        #{script_name} --model "llama-3.1-8b" --temp 0.5 --max-tokens 2000 https://youtu.be/8dqU27oqkuE

        # Disable auto-reload for smaller models
        #{script_name} --no-auto-reload --min-context 16384 https://youtu.be/8dqU27oqkuE

        # Configuration and models
        #{script_name} --list-models

      Configuration is automatically saved between sessions.
    EXAMPLES
  end

  # Cleanup method
  def cleanup
    if @temp_dir && Dir.exist?(@temp_dir)
      FileUtils.remove_entry(@temp_dir)
      log_debug("Cleaned up temporary directory")
    end
  end

  # Override exit to ensure cleanup
  def exit(code = 0)
    cleanup
    super(code)
  end

  # =========================================================================
  # MARKDOWN DISPLAY AND FORMATTING
  # =========================================================================

  def display_summary(summary)
    if @options[:markdown]
      begin
        require 'tty-markdown'

        puts "\n"
        puts TTY::Markdown.parse(summary, width: 100)
        puts "\n"
        return
      rescue LoadError
        log_debug("tty-markdown not available, using plain text")
      rescue StandardError => e
        log_debug("Markdown rendering failed: #{e.message}")
      end
    end

    # Fallback to simple text display
    puts "\n" + "="*80
    puts "📋 SUMMARY"
    puts "="*80
    puts summary
    puts "="*80 + "\n"
  end

  def display_markdown_response(text)
    if @options[:markdown]
      begin
        require 'tty-markdown'

        puts TTY::Markdown.parse(text, width: 100)
        return
      rescue LoadError, StandardError
        # Fall through to plain text
      end
    end

    # Plain text display
    puts text
  end

  # =========================================================================
  # INTERACTIVE SETTINGS AND CONFIGURATION DISPLAY
  # =========================================================================

  def show_current_configuration
    require 'tty-box'

    # Better formatted configuration
    config_sections = []

    # LLM Settings
    config_sections << '╭─ 🤖 LLM Settings ─────────────────────────'
    config_sections << "│  Model:        #{@options[:model] || 'Auto-detect'}"
    config_sections << "│  Temperature:  #{@options[:temperature]}"
    config_sections << "│  Max Tokens:   #{@options[:max_tokens]}"
    config_sections << "│  Timeout:      #{@options[:timeout]}s"
    config_sections << '╰────────────────────────────────────────'

    # Transcript Settings
    config_sections << '╭─ 🎥 Transcript Settings ──────────────────'
    config_sections << "│  Language:     #{@options[:language]}"
    config_sections << "│  Summary Only: #{@options[:summary_only] ? '✅ Yes' : '❌ No'}"
    config_sections << "│  Auto-reload:  #{@options[:auto_reload] ? '✅ Yes' : '❌ No'}"
    config_sections << '╰────────────────────────────────────────'

    # Context Management
    if @options[:min_context] || !@options[:auto_reload]
      config_sections << '╭─ 🧠 Context Management ───────────────────'
      config_sections << "│  Min Context:  #{@options[:min_context] || 'Auto'}"
      config_sections << "│  Auto-reload:  #{@options[:auto_reload] ? '✅ Enabled' : '❌ Disabled'}"
      config_sections << '╰────────────────────────────────────────'
    end

    # File Output
    if @options[:output_file]
      config_sections << '╭─ 📄 Output Settings ──────────────────────'
      config_sections << "│  Save To:      #{@options[:output_file]}"
      config_sections << '╰────────────────────────────────────────'
    end

    box_content = config_sections.join("\n")

    box = TTY::Box.frame(
      box_content,
      title: { top_left: ' 🎛️  Current Configuration ' },
      border: :thick,
      padding: [1, 2],
      style: {
        fg: :bright_white,
        bg: :black,
        border: {
          fg: :magenta,
          bg: :black
        }
      }
    )

    puts box
    puts
  end

  def show_interactive_settings_menu
    require 'tty-prompt'

    prompt = TTY::Prompt.new

    loop do
      show_current_configuration

      choices = [
        { name: '🤖 Model Settings', value: :model_settings },
        { name: '🎥 Transcript Settings', value: :transcript_settings },
        { name: '🧠 Context Management', value: :context_settings },
        { name: '📄 Output Settings', value: :output_settings },
        { name: '💾 Save Current Settings', value: :save_settings },
        { name: '🔄 Reset to Defaults', value: :reset_settings },
        { name: '❌ Exit Settings', value: :exit }
      ]

      selection = prompt.select('⚙️  YouTube Transcript Chat Settings', choices, cycle: true)

      case selection
      when :model_settings
        configure_model_settings(prompt)
      when :transcript_settings
        configure_transcript_settings(prompt)
      when :context_settings
        configure_context_settings(prompt)
      when :output_settings
        configure_output_settings(prompt)
      when :save_settings
        save_current_settings
        log_success('Settings saved successfully!')
      when :reset_settings
        if prompt.yes?('🗑️  Reset all settings to defaults?', default: false)
          reset_settings!
          log_success('Settings reset to defaults!')
        end
      when :exit
        break
      end
    end
  end

  def configure_model_settings(prompt)
    # Initialize LLM to get available models
    begin
      temp_llm = LLMService.new(debug: false)
      models = temp_llm.available? ? temp_llm.models : []
    rescue
      models = []
    end

    choices = []

    if models.any?
      choices << { name: "🤖 Model: #{@options[:model] || 'Auto-detect'}", value: :model }
    end

    choices.concat([
      { name: "🌡️  Temperature: #{@options[:temperature]}", value: :temperature },
      { name: "🔢 Max Tokens: #{@options[:max_tokens]}", value: :max_tokens },
      { name: "⏱️  Timeout: #{@options[:timeout]}s", value: :timeout },
      { name: '← Back to Main Menu', value: :back }
    ])

    selection = prompt.select('🤖 Model Settings', choices, cycle: true)

    case selection
    when :model
      if models.any?
        model_choices = [{ name: 'Auto-detect', value: nil }] +
                       models.map { |m| { name: m, value: m } }
        @options[:model] = prompt.select('Select model:', model_choices)
      end
    when :temperature
      @options[:temperature] = prompt.slider('Temperature (creativity)', min: 0.0, max: 1.0, step: 0.1, default: @options[:temperature])
    when :max_tokens
      @options[:max_tokens] = prompt.slider('Max tokens to generate', min: 100, max: 4000, step: 100, default: @options[:max_tokens])
    when :timeout
      @options[:timeout] = prompt.slider('Request timeout (seconds)', min: 30, max: 600, step: 30, default: @options[:timeout])
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
      lang_choices = [
        { name: 'English (en)', value: 'en' },
        { name: 'Spanish (es)', value: 'es' },
        { name: 'French (fr)', value: 'fr' },
        { name: 'German (de)', value: 'de' },
        { name: 'Japanese (ja)', value: 'ja' },
        { name: 'Korean (ko)', value: 'ko' },
        { name: 'Portuguese (pt)', value: 'pt' },
        { name: 'Other (specify)', value: :custom }
      ]

      lang = prompt.select('Select transcript language:', lang_choices)

      if lang == :custom
        @options[:language] = prompt.ask('Enter language code (e.g., zh, ru, ar):')
      else
        @options[:language] = lang
      end
    when :summary_only
      @options[:summary_only] = prompt.yes?('Generate summary only (skip chat)?', default: @options[:summary_only])
    when :back
      return
    end
  end

  def configure_context_settings(prompt)
    choices = [
      { name: "🔄 Auto-reload: #{@options[:auto_reload] ? 'Enabled' : 'Disabled'}", value: :auto_reload },
      { name: "🧠 Min Context: #{@options[:min_context] || 'Auto'}", value: :min_context },
      { name: '← Back to Main Menu', value: :back }
    ]

    selection = prompt.select('🧠 Context Management', choices, cycle: true)

    case selection
    when :auto_reload
      @options[:auto_reload] = prompt.yes?('Enable automatic model reloading?', default: @options[:auto_reload])
    when :min_context
      if prompt.yes?('Set minimum context length?', default: @options[:min_context] != nil)
        @options[:min_context] = prompt.slider('Minimum context tokens', min: 2048, max: 131072, step: 1024, default: @options[:min_context] || 8192)
      else
        @options[:min_context] = nil
      end
    when :back
      return
    end
  end

  def configure_output_settings(prompt)
    choices = [
      { name: "📄 Output File: #{@options[:output_file] || 'None'}", value: :output_file },
      { name: "🎨 Markdown Format: #{@options[:markdown] ? 'Enabled' : 'Disabled'}", value: :markdown },
      { name: '← Back to Main Menu', value: :back }
    ]

    selection = prompt.select('📄 Output Settings', choices, cycle: true)

    case selection
    when :output_file
      if prompt.yes?('Save transcript to file?', default: @options[:output_file] != nil)
        @options[:output_file] = prompt.ask('Enter output file path:', default: @options[:output_file] || 'transcript.txt')
      else
        @options[:output_file] = nil
      end
    when :markdown
      @options[:markdown] = prompt.yes?('Enable markdown formatting for summaries and responses?', default: @options[:markdown])
    when :back
      return
    end
  end

  def save_current_settings
    # Use ScriptBase's built-in settings persistence
    save_settings(@options.select { |k, v| default_options.key?(k) && v != default_options[k] })
  end
end

# Ensure cleanup on script termination
at_exit do
  if defined?(@temp_dir) && @temp_dir && Dir.exist?(@temp_dir)
    FileUtils.remove_entry(@temp_dir) rescue nil
  end
end

# Execute the script
YouTubeTranscriptChat.execute if __FILE__ == $0