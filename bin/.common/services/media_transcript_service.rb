# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'fileutils'
require_relative 'base_service'

# Service for downloading and parsing video transcripts from various platforms
class MediaTranscriptService < BaseService
  def initialize(options = {})
    super(options)
    @language = options[:language] || 'en'
    @output_file = options[:output_file]
    @temp_dir = nil
  end

  # Download transcript for a given URL
  def download_transcript(url)
    unless command_exists?('yt-dlp')
      raise "yt-dlp is required but not installed. Run: brew install yt-dlp"
    end

    video_id = extract_video_id(url)
    raise "Could not extract video ID from URL: #{url}" unless video_id

    # Get video info first
    video_info = get_video_info(url)
    return nil unless video_info

    log_info("Video: #{video_info[:title]}")
    log_info("Duration: #{video_info[:duration]}")

    # Create temporary directory for transcript
    @temp_dir = Dir.mktmpdir("media_transcript_")

    # Download transcript using yt-dlp
    transcript_file = download_transcript_file(url)
    return nil unless transcript_file

    # Parse transcript
    transcript_data = parse_transcript(transcript_file, video_info)

    # Save to file if requested
    save_transcript_file(transcript_data[:full_text]) if @output_file && transcript_data

    transcript_data
  ensure
    cleanup_temp_files
  end

  # Extract video ID from various URL formats
  def extract_video_id(url)
    patterns = [
      /youtube\.com\/watch\?v=([\w-]+)/,
      /youtu\.be\/([\w-]+)/,
      /youtube\.com\/embed\/([\w-]+)/
    ]

    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end

    nil
  end

  # Check if URL is supported
  def supported_url?(url)
    !extract_video_id(url).nil?
  end

  # Get available transcript languages for a video
  def available_languages(url)
    return [] unless command_exists?('yt-dlp')

    cmd = ['yt-dlp', '--list-subs', '--no-download', url]
    output = `#{cmd.join(' ')} 2>/dev/null`

    if $?.success?
      # Parse subtitle languages from output
      languages = []
      output.lines.each do |line|
        if line.match(/^(\w{2}(-\w{2})?)\s/)
          languages << $1
        end
      end
      languages.uniq
    else
      []
    end
  end

  private

  def get_video_info(url)
    log_debug("Getting video information")

    cmd = ['yt-dlp', '--dump-json', '--no-download', url]
    output = `#{cmd.join(' ')} 2>/dev/null`

    if $?.success? && !output.empty?
      begin
        info = JSON.parse(output)
        {
          title: info['title'],
          duration: format_duration(info['duration']),
          uploader: info['uploader'],
          upload_date: info['upload_date'],
          view_count: info['view_count'],
          description: info['description']&.slice(0, 500) # First 500 chars
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

  def download_transcript_file(url)
    cmd = [
      'yt-dlp',
      '--write-auto-subs',
      '--sub-langs', @language,
      '--sub-format', 'json3',
      '--skip-download',
      '--output', File.join(@temp_dir, '%(title)s.%(ext)s'),
      url
    ]

    log_progress("Downloading transcript in #{@language}")

    success = system(*cmd, out: '/dev/null', err: '/dev/null')

    unless success
      log_warning("Failed to download transcript in #{@language}, trying English...")
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
    transcript_file
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

      transcript_data = {
        video_info: video_info,
        full_text: full_text.strip,
        segments: segments,
        word_count: full_text.split.length,
        language: @language
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

  def save_transcript_file(text)
    return unless @output_file && text

    File.write(@output_file, text)
    log_file_created(@output_file) if @logger&.respond_to?(:log_file_created)
  end

  def cleanup_temp_files
    if @temp_dir && Dir.exist?(@temp_dir)
      FileUtils.remove_entry(@temp_dir)
      log_debug("Cleaned up temporary directory") if @logger
    end
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

end