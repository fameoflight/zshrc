#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'base_service'
require 'uri'

# Service for validating and processing URLs
class URLValidationService < BaseService
  def initialize(options = {})
    super(options)
  end

  # Validate YouTube URL
  def valid_youtube_url?(url)
    return false unless url

    # Various YouTube URL patterns
    youtube_patterns = [
      /youtube\.com\/watch\?v=[\w-]+/,
      /youtu\.be\/[\w-]+/,
      /youtube\.com\/embed\/[\w-]+/,
      /youtube\.com\/v\/[\w-]+/,
      /youtube\.com\/shorts\/[\w-]+/
    ]

    youtube_patterns.any? { |pattern| url.match?(pattern) }
  end

  # Extract video ID from YouTube URL
  def extract_youtube_video_id(url)
    return nil unless url

    patterns = [
      /youtube\.com\/watch\?v=([\w-]+)/,
      /youtu\.be\/([\w-]+)/,
      /youtube\.com\/embed\/([\w-]+)/,
      /youtube\.com\/v\/([\w-]+)/,
      /youtube\.com\/shorts\/([\w-]+)/
    ]

    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end

    nil
  end

  # Validate general URL
  def valid_url?(url)
    return false unless url

    begin
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end

  # Validate specific domain
  def valid_domain?(url, domain)
    return false unless url && domain

    begin
      uri = URI.parse(url)
      uri.host&.include?(domain)
    rescue URI::InvalidURIError
      false
    end
  end

  # Get URL domain
  def get_domain(url)
    return nil unless url

    begin
      uri = URI.parse(url)
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end

  # Clean URL (remove tracking parameters, etc.)
  def clean_url(url)
    return nil unless url

    begin
      uri = URI.parse(url)
      query_params = URI.decode_www_form(uri.query || "").to_h

      # Remove tracking parameters
      tracking_params = %w[utm_source utm_medium utm_campaign utm_term utm_content ref src feature]
      tracking_params.each { |param| query_params.delete(param) }

      # Rebuild URL
      uri.query = URI.encode_www_form(query_params) if query_params.any?
      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end

  # Check if URL is accessible
  def url_accessible?(url, timeout: 10)
    return false unless valid_url?(url)

    require 'net/http'
    require 'timeout'

    begin
      Timeout.timeout(timeout) do
        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        response.is_a?(Net::HTTPSuccess)
      end
    rescue
      false
    end
  end

  # Get URL type
  def get_url_type(url)
    return :unknown unless url

    case url
    when /youtube\.com|youtu\.be/
      :youtube
    when /vimeo\.com/
      :vimeo
    when /dailymotion\.com/
      :dailymotion
    when /twitch\.tv/
      :twitch
    when /spotify\.com/
      :spotify
    when /soundcloud\.com/
      :soundcloud
    when /podcast\.|\.rss|feed:/
      :podcast
    when /\.(mp4|mov|avi|mkv|webm|flv)$/i
      :video_file
    when /\.(mp3|wav|flac|aac|ogg)$/i
      :audio_file
    when /\.(pdf|epub|txt|md|docx?|pptx?)$/i
      :document
    else
      :website
    end
  end

  # Validate multiple URL patterns
  def valid_urls?(urls)
    return false unless urls.is_a?(Array)

    urls.all? { |url| valid_url?(url) }
  end

  # Extract URLs from text
  def extract_urls_from_text(text)
    return [] unless text

    # Common URL patterns
    url_pattern = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/i
    text.scan(url_pattern).uniq
  end

  # Sanitize URL for safe processing
  def sanitize_url(url)
    return nil unless url

    # Remove potentially dangerous characters
    sanitized = url.gsub(/[<>"'|\\^`\[\]]/, '')

    # Ensure it starts with http:// or https://
    unless sanitized.match?(/^https?:\/\//)
      sanitized = "https://#{sanitized}"
    end

    sanitized
  end
end