#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'base_service'
require 'json'

# Service for parsing and processing YouTube transcript data
class TranscriptParsingService < BaseService
  def initialize(options = {})
    super(options)
  end

  # Parse YouTube transcript JSON and extract structured data
  def parse_transcript(transcript_content, options = {})
    log_debug("Parsing transcript content")

    begin
      transcript_json = JSON.parse(transcript_content)

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
          formatted_time: format_time(start_time),
          end_time: calculate_end_time(start_time, segment_text)
        }
      end

      # Save to file if requested
      if options[:output_file]
        save_transcript(full_text.strip, options[:output_file])
      end

      transcript_data = {
        full_text: full_text.strip,
        segments: segments,
        word_count: full_text.split.length,
        character_count: full_text.length,
        segment_count: segments.length,
        duration: calculate_total_duration(segments)
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

  # Parse transcript from file
  def parse_transcript_file(file_path, options = {})
    log_debug("Parsing transcript file: #{file_path}")

    unless File.exist?(file_path)
      log_error("Transcript file not found: #{file_path}")
      return nil
    end

    content = File.read(file_path)
    parse_transcript(content, options)
  end

  # Extract text segments within time range
  def extract_time_range(transcript_data, start_time, end_time)
    return "" unless transcript_data && transcript_data[:segments]

    segments = transcript_data[:segments].select do |segment|
      segment[:start_time] >= start_time && segment[:start_time] <= end_time
    end

    segments.map { |s| s[:text] }.join(" ")
  end

  # Find segments containing specific keywords
  def find_segments_with_keywords(transcript_data, keywords, case_sensitive: false)
    return [] unless transcript_data && transcript_data[:segments]

    keyword_patterns = keywords.map do |keyword|
      case_sensitive ? keyword : keyword.downcase
    end

    transcript_data[:segments].select do |segment|
      text = case_sensitive ? segment[:text] : segment[:text].downcase
      keyword_patterns.any? { |pattern| text.include?(pattern) }
    end
  end

  # Generate text chunks for processing large transcripts
  def create_text_chunks(transcript_data, chunk_size: 12000, overlap: 1000)
    return [] unless transcript_data && transcript_data[:full_text]

    text = transcript_data[:full_text]
    chunks = []

    return [text] if text.length <= chunk_size

    start_index = 0
    while start_index < text.length
      end_index = [start_index + chunk_size, text.length].min

      # Try to break at word boundary
      if end_index < text.length
        while end_index > start_index && text[end_index] != ' '
          end_index -= 1
        end
        end_index += 1 if end_index > start_index
      end

      chunk = text[start_index...end_index].strip
      chunks << chunk if chunk.length > 0

      start_index = end_index - overlap
      break if start_index >= text.length
    end

    chunks
  end

  # Get transcript statistics
  def get_transcript_stats(transcript_data)
    return {} unless transcript_data

    {
      word_count: transcript_data[:word_count] || 0,
      character_count: transcript_data[:character_count] || 0,
      segment_count: transcript_data[:segment_count] || 0,
      duration: transcript_data[:duration] || "0:00",
      average_words_per_segment: transcript_data[:segment_count] && transcript_data[:segment_count] > 0 ?
        (transcript_data[:word_count] || 0).to_f / transcript_data[:segment_count] : 0,
      average_segment_duration: calculate_average_segment_duration(transcript_data[:segments])
    }
  end

  private

  def format_time(seconds)
    return "0:00" unless seconds

    minutes = (seconds / 60).to_i
    seconds = (seconds % 60).to_i

    "%d:%02d" % [minutes, seconds]
  end

  def calculate_end_time(start_time, text)
    # Estimate end time based on average speaking rate (150 words per minute)
    return nil unless start_time && text

    words = text.split.length
    estimated_duration = (words / 150.0) * 60 # seconds
    start_time + estimated_duration
  end

  def calculate_total_duration(segments)
    return "0:00" unless segments && segments.any?

    last_segment = segments.last
    format_time(last_segment[:start_time])
  end

  def calculate_average_segment_duration(segments)
    return 0 unless segments && segments.length > 1

    durations = []
    segments.each_with_index do |segment, index|
      next if index == segments.length - 1

      next_segment = segments[index + 1]
      duration = next_segment[:start_time] - segment[:start_time]
      durations << duration if duration > 0
    end

    durations.empty? ? 0 : durations.sum / durations.length
  end

  def save_transcript(content, file_path)
    File.write(file_path, content)
    log_file_created(file_path)
  end
end