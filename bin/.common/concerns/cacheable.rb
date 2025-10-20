# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'

# Caching concern for services
module Cacheable
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def cache_config
      @cache_config ||= {
        enabled: true,
        dir: File.expand_path('~/.cache/website-epub'),
        ttl: 24 * 60 * 60, # 24 hours
        namespace: base_cache_namespace
      }
    end

    def configure_cache(**options)
      cache_config.merge!(options)
    end

    private

    def base_cache_namespace
      name.downcase.gsub('::', '_')
    end
  end

  def cache_enabled?
    self.class.cache_config[:enabled]
  end

  def cache_get(key, namespace: nil)
    return nil unless cache_enabled?

    cache_file = cache_file_path(key, namespace: namespace)
    return nil unless File.exist?(cache_file)

    begin
      data = JSON.parse(File.read(cache_file), symbolize_names: true)
      
      # Check TTL
      if cache_expired?(data)
        cache_delete(key, namespace: namespace)
        return nil
      end
      
      data[:payload]
    rescue => e
      # If cache file is corrupted, delete it
      cache_delete(key, namespace: namespace)
      nil
    end
  end

  def cache_set(key, value, namespace: nil, ttl: nil)
    return value unless cache_enabled?

    cache_file = cache_file_path(key, namespace: namespace)
    cache_data = {
      key: key,
      payload: value,
      timestamp: Time.now.to_i,
      ttl: ttl || self.class.cache_config[:ttl]
    }

    begin
      File.write(cache_file, JSON.pretty_generate(cache_data))
    rescue => e
      puts "⚠️  Cache write failed: #{e.message}" if respond_to?(:verbose?) && verbose?
    end

    value
  end

  def cache_delete(key, namespace: nil)
    cache_file = cache_file_path(key, namespace: namespace)
    File.delete(cache_file) if File.exist?(cache_file)
  end

  def cache_clear(namespace: nil)
    cache_dir = cache_directory(namespace: namespace)
    if Dir.exist?(cache_dir)
      FileUtils.rm_rf(cache_dir)
      puts "🧹 Cache cleared: #{namespace || 'all'}"
    end
  end

  def cache_stats(namespace: nil)
    return { enabled: false } unless cache_enabled?

    cache_dir = cache_directory(namespace: namespace)
    files = Dir.glob(File.join(cache_dir, '**', '*.json'))
    
    total_size = files.sum { |f| File.size(f) }
    
    {
      enabled: true,
      namespace: namespace || 'default',
      files: files.size,
      total_size_bytes: total_size,
      total_size_mb: (total_size / 1_048_576.0).round(2),
      cache_dir: cache_dir
    }
  end

  def with_cache(key, namespace: nil, ttl: nil, &block)
    # Try to get from cache first
    cached_result = cache_get(key, namespace: namespace)
    return cached_result if cached_result

    # Execute block and cache result
    result = yield
    cache_set(key, result, namespace: namespace, ttl: ttl) if result
    result
  end

  private

  def cache_directory(namespace: nil)
    base_dir = self.class.cache_config[:dir]
    ns = namespace || self.class.cache_config[:namespace]
    File.join(base_dir, ns)
  end

  def cache_file_path(key, namespace: nil)
    cache_key = cache_safe_key(key)
    cache_dir = cache_directory(namespace: namespace)
    FileUtils.mkdir_p(cache_dir)
    File.join(cache_dir, "#{cache_key}.json")
  end

  def cache_safe_key(key)
    # Create a safe filename from key
    Digest::SHA256.hexdigest(key.to_s)
  end

  def cache_expired?(data)
    return false unless data[:ttl] && data[:timestamp]
    
    age = Time.now.to_i - data[:timestamp]
    age > data[:ttl]
  end
end