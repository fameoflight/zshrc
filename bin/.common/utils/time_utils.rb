#!/usr/bin/env ruby
# frozen_string_literal: true

# Utility module for time formatting and duration calculations
module TimeUtils
  # Format duration in seconds to HH:MM:SS or MM:SS format
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

  # Format time in seconds to MM:SS format
  def format_time(seconds)
    return "0:00" unless seconds

    minutes = (seconds / 60).to_i
    seconds = (seconds % 60).to_i

    "%d:%02d" % [minutes, seconds]
  end

  # Format time in seconds to HH:MM:SS format (always show hours)
  def format_time_full(seconds)
    return "0:00:00" unless seconds

    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    seconds = (seconds % 60).to_i

    "%d:%02d:%02d" % [hours, minutes, seconds]
  end

  # Parse time string in HH:MM:SS or MM:SS format to seconds
  def parse_time_to_seconds(time_str)
    return 0 unless time_str

    parts = time_str.split(':').map(&:to_i)

    case parts.length
    when 1 # Seconds only
      parts[0]
    when 2 # MM:SS
      parts[0] * 60 + parts[1]
    when 3 # HH:MM:SS
      parts[0] * 3600 + parts[1] * 60 + parts[2]
    else
      0
    end
  end

  # Convert seconds to human-readable format (e.g., "2 hours 30 minutes")
  def humanize_duration(seconds)
    return "0 seconds" unless seconds && seconds > 0

    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    secs = (seconds % 60).to_i

    parts = []
    parts << "#{hours} hour#{'s' if hours != 1}" if hours > 0
    parts << "#{minutes} minute#{'s' if minutes != 1}" if minutes > 0
    parts << "#{secs} second#{'s' if secs != 1}" if secs > 0 || parts.empty?

    parts.join(' ')
  end

  # Format timestamp for file names (e.g., "20240101_123045")
  def format_timestamp(time = Time.now)
    time.strftime('%Y%m%d_%H%M%S')
  end

  # Format date for display (e.g., "January 1, 2024")
  def format_date(date = Date.today)
    date.strftime('%B %d, %Y')
  end

  # Format relative time (e.g., "2 hours ago")
  def format_relative_time(time)
    return "unknown" unless time

    seconds = Time.now - time

    if seconds < 60
      "#{seconds.to_i} seconds ago"
    elsif seconds < 3600
      "#{(seconds / 60).to_i} minutes ago"
    elsif seconds < 86400
      "#{(seconds / 3600).to_i} hours ago"
    elsif seconds < 604800
      "#{(seconds / 86400).to_i} days ago"
    elsif seconds < 2592000
      "#{(seconds / 604800).to_i} weeks ago"
    elsif seconds < 31536000
      "#{(seconds / 2592000).to_i} months ago"
    else
      "#{(seconds / 31536000).to_i} years ago"
    end
  end

  # Calculate time difference between two timestamps
  def time_diff(start_time, end_time)
    return 0 unless start_time && end_time

    (end_time - start_time).to_i
  end

  # Convert milliseconds to seconds
  def ms_to_seconds(milliseconds)
    return 0 unless milliseconds

    milliseconds / 1000.0
  end

  # Convert seconds to milliseconds
  def seconds_to_ms(seconds)
    return 0 unless seconds

    (seconds * 1000).to_i
  end

  # Estimate reading time based on word count (average 200 words per minute)
  def estimate_reading_time(word_count)
    return "0 minutes" unless word_count && word_count > 0

    minutes = (word_count / 200.0).ceil
    "#{minutes} minute#{'s' if minutes != 1}"
  end

  # Check if time is within range
  def time_in_range?(time, start_time, end_time)
    return false unless time && start_time && end_time

    time >= start_time && time <= end_time
  end

  # Get current time in ISO format
  def current_time_iso
    Time.now.iso8601
  end

  # Parse ISO time string to Time object
  def parse_iso_time(iso_string)
    return nil unless iso_string

    begin
      Time.parse(iso_string)
    rescue
      nil
    end
  end
end