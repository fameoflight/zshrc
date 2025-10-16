#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'base_service'
require 'json'

# Service for extracting video information from YouTube and other video platforms
class VideoInfoService < BaseService
  def initialize(options = {})
    super(options)
    @yt_dlp_path = options[:yt_dlp_path] || 'yt-dlp'
  end

  # Extract video metadata from YouTube URL
  def get_video_info(url)
    log_debug("Getting video information for: #{url}")

    cmd = [@yt_dlp_path, '--dump-json', '--no-download', url]

    output = System.execute(cmd.join(' '), description: "Getting video info")

    if output && !output.empty?
      begin
        info = JSON.parse(output)
        {
          title: info['title'],
          duration: format_duration(info['duration']),
          duration_seconds: info['duration'],
          uploader: info['uploader'],
          upload_date: info['upload_date'],
          view_count: info['view_count'],
          like_count: info['like_count'],
          description: info['description'],
          tags: info['tags'],
          categories: info['categories']
        }
      rescue JSON::ParserError => e
        log_error("Failed to parse video info: #{e.message}")
        nil
      end
    else
      log_error("Failed to get video information: #{output[:stderr]}")
      nil
    end
  end

  # Check if yt-dlp is available
  def yt_dlp_available?
    System.command?(@yt_dlp_path)
  end

  # Get available formats for a video
  def get_available_formats(url)
    log_debug("Getting available formats for: #{url}")

    cmd = [@yt_dlp_path, '--list-formats', '--no-download', url]
    output = System.execute(cmd.join(' '), description: "Getting available formats")

    if output
      parse_formats(output)
    else
      log_error("Failed to get formats")
      []
    end
  end

  # Extract video ID from YouTube URL
  def extract_video_id(url)
    return nil unless url

    # Match various YouTube URL formats
    patterns = [
      /youtube\.com\/watch\?v=([\w-]+)/,
      /youtu\.be\/([\w-]+)/,
      /youtube\.com\/embed\/([\w-]+)/,
      /youtube\.com\/v\/([\w-]+)/
    ]

    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end

    nil
  end

  private

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

  def parse_formats(output)
    formats = []
    lines = output.split("\n")

    lines.each do |line|
      # Parse format lines (skip headers)
      next unless line.match?(/^\s*\d+/)

      # Extract format code, extension, resolution, and other info
      parts = line.strip.split(/\s{2,}/)
      next if parts.empty?

      format_info = {
        format_code: parts[0],
        extension: parts[1],
        resolution: parts[2],
        fps: parts[3],
        size: parts[4],
        bitrate: parts[5]
      }

      formats << format_info
    end

    formats
  end
end