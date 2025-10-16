#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'base_service'

# Service for displaying configuration information and interactive settings
class ConfigurationDisplayService < BaseService
  def initialize(options = {})
    super(options)
    @width = options[:width] || 80
  end

  # Display multi-section configuration box
  def show_configuration_box(title, sections)
    puts "\n#{title}"
    puts "=" * @width

    sections.each do |section|
      puts "\n#{section[:icon]} #{section[:title]}"
      puts section[:separator]

      section[:items].each do |item|
        puts "  #{item}"
      end
    end

    puts "=" * @width
    puts
  end

  # Display current configuration with organized sections
  def display_app_configuration(config, cache_service = nil)
    cache_stats = cache_service&.stats if cache_service

    sections = build_configuration_sections(config, cache_stats)
    show_configuration_box("🎛️  Current Configuration", sections)
  end

  # Build configuration sections based on available config
  def build_configuration_sections(config, cache_stats = nil)
    sections = []

    # LLM Settings section
    if config.key?(:model) || config.key?(:temperature) || config.key?(:max_tokens)
      sections << {
        icon: "🤖",
        title: "LLM Settings",
        separator: "───────────────────────────────",
        items: [
          "Model: #{config[:model] || 'Auto-detect'}",
          "Temperature: #{config[:temperature]}",
          "Max Tokens: #{config[:max_tokens]}",
          "Timeout: #{config[:timeout] || 300}s"
        ].compact
      }
    end

    # Processing Settings section
    if config.key?(:language) || config.key?(:chunk_size) || config.key?(:summary_only)
      sections << {
        icon: "📋",
        title: "Processing Settings",
        separator: "───────────────────────────────",
        items: [
          "Language: #{config[:language] || 'en'}",
          "Summary Only: #{config[:summary_only] ? '✅ Yes' : '❌ No'}",
          "Chunking: #{config[:no_chunking] ? '❌ Disabled' : '✅ Enabled'}",
          "Chunk Size: #{config[:chunk_size] || 12000} chars"
        ].compact
      }
    end

    # Cache Settings section
    if config.key?(:cache_ttl) || config.key?(:no_cache) || cache_stats
      sections << {
        icon: "💾",
        title: "Cache Settings",
        separator: "───────────────────────────────",
        items: [
          "Caching: #{config[:no_cache] ? '❌ Disabled' : '✅ Enabled'}",
          "Cache TTL: #{config[:cache_ttl] || 7} days",
          "Cached Files: #{cache_stats&.dig(:total_entries) || 0}",
          "Cache Size: #{format_bytes(cache_stats&.dig(:total_size) || 0)}"
        ].compact
      }
    end

    # Context Management section
    if config.key?(:min_context) || config.key?(:auto_reload)
      sections << {
        icon: "🧠",
        title: "Context Management",
        separator: "───────────────────────────────",
        items: [
          "Min Context: #{config[:min_context] || 'Auto'}",
          "Auto-reload: #{config[:auto_reload] ? '✅ Enabled' : '❌ Disabled'}"
        ].compact
      }
    end

    # Output Settings section
    if config.key?(:output_file) || config.key?(:markdown)
      sections << {
        icon: "📄",
        title: "Output Settings",
        separator: "───────────────────────────────",
        items: [
          "Save To: #{config[:output_file] || 'None'}",
          "Markdown: #{config[:markdown] ? '✅ Enabled' : '❌ Disabled'}"
        ].compact
      }
    end

    sections
  end

  # Display cache information
  def show_cache_info(cache_dir, file_pattern = '*')
    puts "\n💾 Cache Information"
    puts "─" * 40
    puts "Cache Directory: #{cache_dir}"

    unless Dir.exist?(cache_dir)
      puts "Status: ❌ Cache directory does not exist"
      return
    end

    files = Dir.glob(File.join(cache_dir, file_pattern))

    if files.empty?
      puts "Status: ✅ Cache is empty"
      return
    end

    total_size = files.sum { |f| File.size(f) if File.exist?(f) }.to_i
    oldest_file = files.min_by { |f| File.mtime(f) }
    newest_file = files.max_by { |f| File.mtime(f) }

    puts "Status: 📊 #{files.length} cached files"
    puts "Total Size: #{format_bytes(total_size)}"
    puts "Oldest: #{File.basename(oldest_file)} (#{format_relative_time(File.mtime(oldest_file))})"
    puts "Newest: #{File.basename(newest_file)} (#{format_relative_time(File.mtime(newest_file))})"

    # Show recent files
    puts "\nRecent Files:"
    recent_files = files.sort_by { |f| File.mtime(f) }.last(5)
    recent_files.each do |file|
      age = format_relative_time(File.mtime(file))
      size = format_bytes(File.size(file))
      puts "  • #{File.basename(file)} (#{size}, #{age})"
    end
  end

  # Display menu choices in a formatted way
  def display_menu_choices(title, choices)
    puts "\n#{title}"
    puts "─" * 40

    choices.each_with_index do |choice, index|
      puts "#{index + 1}. #{choice[:name]}"
    end

    puts
  end

  # Display settings confirmation
  def display_settings_confirmation(settings)
    puts "\n✅ Settings Updated"
    puts "─" * 30

    settings.each do |key, value|
      puts "  #{key.to_s.gsub('_', ' ').titlecase}: #{format_setting_value(value)}"
    end

    puts
  end

  # Display help information
  def display_help_info(script_name, examples)
    puts "\n📖 Examples:"
    puts "─" * 40

    examples.each do |example|
      puts "  #{example}"
    end

    puts
    puts "💡 Configuration is automatically saved between sessions."
    puts "💡 Use --configure to interactively change settings."
  end

  private

  def format_bytes(bytes)
    return "0 B" unless bytes && bytes > 0

    units = %w[B KB MB GB TB]
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def format_relative_time(time)
    seconds = Time.now - time

    if seconds < 60
      "#{seconds.to_i}s ago"
    elsif seconds < 3600
      "#{(seconds / 60).to_i}m ago"
    elsif seconds < 86400
      "#{(seconds / 3600).to_i}h ago"
    else
      "#{(seconds / 86400).to_i}d ago"
    end
  end

  def format_setting_value(value)
    case value
    when true
      "✅ Enabled"
    when false
      "❌ Disabled"
    when nil
      "Auto/None"
    when Numeric
      value.to_s
    else
      value.to_s
    end
  end
end