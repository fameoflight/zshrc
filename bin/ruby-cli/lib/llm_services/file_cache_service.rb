# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'base_service'

# Generic file-based caching service with TTL support
class FileCacheService < BaseService
  DEFAULT_TTL_DAYS = 7

  def initialize(cache_dir, options = {})
    super(options)
    @cache_dir = File.expand_path(cache_dir)
    @ttl_days = options[:ttl_days] || DEFAULT_TTL_DAYS
    @enabled = options.fetch(:enabled, true)

    initialize_cache_dir if @enabled
  end

  # Store data in cache with optional custom TTL
  def set(key, data, ttl_days: nil)
    return false unless @enabled

    ttl_days ||= @ttl_days
    cache_file = cache_file_path(key)

    begin
      cache_data = {
        key: key,
        data: data,
        created_at: Time.now.to_f,
        ttl_days: ttl_days,
        expires_at: (Time.now + (ttl_days * 24 * 60 * 60)).to_f
      }

      File.write(cache_file, JSON.pretty_generate(cache_data))
      log_debug("Cached data for key: #{key} (TTL: #{ttl_days} days)") if @logger
      true
    rescue StandardError => e
      log_warning("Failed to cache data for #{key}: #{e.message}") if @logger
      false
    end
  end

  # Retrieve data from cache if valid
  def get(key)
    return nil unless @enabled

    cache_file = cache_file_path(key)
    return nil unless File.exist?(cache_file)

    begin
      content = File.read(cache_file)
      cache_data = JSON.parse(content)

      # Check if cache entry is expired
      if cache_expired?(cache_data)
        log_debug("Cache expired for key: #{key}") if @logger
        delete(key)
        return nil
      end

      log_debug("Cache hit for key: #{key}") if @logger
      cache_data['data']
    rescue JSON::ParserError, StandardError => e
      log_warning("Failed to read cache for #{key}: #{e.message}") if @logger
      # Remove corrupted cache file
      File.delete(cache_file) rescue nil
      nil
    end
  end

  # Check if key exists in cache and is valid
  def exists?(key)
    return false unless @enabled

    cache_file = cache_file_path(key)
    return false unless File.exist?(cache_file)

    begin
      content = File.read(cache_file)
      cache_data = JSON.parse(content)
      !cache_expired?(cache_data)
    rescue
      false
    end
  end

  # Delete specific cache entry
  def delete(key)
    cache_file = cache_file_path(key)
    if File.exist?(cache_file)
      File.delete(cache_file)
      log_debug("Deleted cache for key: #{key}") if @logger
      true
    else
      false
    end
  end

  # Clear all cache entries
  def clear
    return unless Dir.exist?(@cache_dir)

    cache_files = Dir.glob(File.join(@cache_dir, "*.json"))
    if cache_files.empty?
      log_info("Cache is already empty") if @logger
      return 0
    end

    count = cache_files.length
    FileUtils.rm_rf(@cache_dir)
    FileUtils.mkdir_p(@cache_dir) # Recreate empty directory

    log_info("Cleared #{count} cache entries") if @logger
    count
  end

  # Clean up expired cache entries
  def cleanup_expired
    return 0 unless Dir.exist?(@cache_dir)

    cache_files = Dir.glob(File.join(@cache_dir, "*.json"))
    expired_count = 0

    cache_files.each do |file|
      begin
        content = File.read(file)
        cache_data = JSON.parse(content)

        if cache_expired?(cache_data)
          File.delete(file)
          expired_count += 1
        end
      rescue
        # Delete corrupted files too
        File.delete(file) rescue nil
        expired_count += 1
      end
    end

    log_info("Cleaned up #{expired_count} expired cache entries") if @logger if expired_count > 0
    expired_count
  end

  # Get cache statistics
  def stats
    return { enabled: false } unless @enabled && Dir.exist?(@cache_dir)

    cache_files = Dir.glob(File.join(@cache_dir, "*.json"))

    if cache_files.empty?
      return {
        enabled: true,
        total_entries: 0,
        total_size: 0,
        expired_entries: 0
      }
    end

    total_size = cache_files.sum { |f| File.size(f) }
    expired_count = 0

    cache_files.each do |file|
      begin
        content = File.read(file)
        cache_data = JSON.parse(content)
        expired_count += 1 if cache_expired?(cache_data)
      rescue
        expired_count += 1 # Count corrupted files as expired
      end
    end

    oldest_file = cache_files.min_by { |f| File.mtime(f) }
    newest_file = cache_files.max_by { |f| File.mtime(f) }

    {
      enabled: true,
      total_entries: cache_files.length,
      total_size: total_size,
      expired_entries: expired_count,
      valid_entries: cache_files.length - expired_count,
      oldest_entry: oldest_file ? File.mtime(oldest_file) : nil,
      newest_entry: newest_file ? File.mtime(newest_file) : nil,
      cache_dir: @cache_dir
    }
  end

  # List all cache keys
  def keys
    return [] unless @enabled && Dir.exist?(@cache_dir)

    cache_files = Dir.glob(File.join(@cache_dir, "*.json"))
    keys = []

    cache_files.each do |file|
      begin
        content = File.read(file)
        cache_data = JSON.parse(content)
        keys << cache_data['key'] unless cache_expired?(cache_data)
      rescue
        # Skip corrupted files
      end
    end

    keys
  end

  # Enable/disable caching
  def enabled=(value)
    @enabled = value
    initialize_cache_dir if @enabled
  end

  def enabled?
    @enabled
  end

  private

  def initialize_cache_dir
    return unless @enabled

    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
    log_debug("Cache directory: #{@cache_dir}") if @logger
  end

  def cache_file_path(key)
    # Sanitize key for filename
    safe_key = key.to_s.gsub(/[^\w\-_.]/, '_')
    File.join(@cache_dir, "#{safe_key}.json")
  end

  def cache_expired?(cache_data)
    return true unless cache_data.is_a?(Hash)
    return true unless cache_data['expires_at']

    Time.now.to_f > cache_data['expires_at'].to_f
  end

end