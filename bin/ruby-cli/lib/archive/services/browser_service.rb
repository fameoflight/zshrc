# frozen_string_literal: true

require_relative 'base_service'
require_relative 'url_collector'
require_relative 'element_analyzer'

# Browser service that coordinates URL collection and element interaction
class BrowserService < BaseService
  attr_reader :url_collector, :element_analyzer

  def initialize(url, options = {})
    super(options)
    @url_collector = URLCollector.new(url, options)
    @element_analyzer = nil
    @options = options.merge(max_clicks: 5)
  end

  def collect_urls_with_read_more
    # Load page and collect initial URLs
    @url_collector.load_page
    @url_collector.collect_and_dedupe_urls

    # Set up element analyzer with LLM support if requested
    @element_analyzer = ElementAnalyzer.new(@url_collector.browser, {
                                              use_llm: @options[:use_llm],
                                              logger: @options[:logger],
                                              debug: @options[:debug]
                                            })

    # Track all URLs found (starting with initial collection)
    initial_count = @url_collector.urls.size

    puts '🔄 Clicking read more buttons...'

    click_count = 0
    max_clicks = @options[:max_clicks]

    while click_count < max_clicks
      # Find read more elements
      read_more_elements = @element_analyzer.find_read_more_elements

      if read_more_elements.empty?
        puts '⚠️  No more buttons found'
        break
      end

      # Get initial content counts for change detection
      initial_counts = @element_analyzer.count_content_elements

      # Store current URLs before click
      urls_before_click = @url_collector.urls.dup

      # Try to click the first available read more button
      element = read_more_elements.first

      click_successful = @element_analyzer.click_read_more_element(element)

      if click_successful
        click_count += 1
        puts "🎯 Click #{click_count}/#{max_clicks}"

        # Wait for new content to load after clicking
        if @element_analyzer.wait_for_content_change(initial_counts, timeout: 45)
          # Re-collect ALL URLs from the entire updated page
          puts '         🔄 Re-scanning entire page for URLs...'

          # Wait for async loading to complete and scan multiple times
          sleep(2)
          @url_collector.reload_and_collect

          # Additional scan for better coverage
          sleep(2)
          @url_collector.reload_and_collect

          # Compare with URLs from before the click
          original_urls = urls_before_click.map { |u| u[:url] }
          current_urls = @url_collector.urls
          truly_new_urls = current_urls.select { |u| !original_urls.include?(u[:url]) }

          puts "         📊 New URLs discovered after click: #{truly_new_urls.size}"

          # Display new URLs by category
          if truly_new_urls.any?
            # Group new URLs by type
            new_external_urls = truly_new_urls.select do |u|
              u[:url].start_with?('http') && !u[:url].include?(@url_collector.domain)
            end
            new_internal_urls = truly_new_urls.select do |u|
              u[:url].include?(@url_collector.domain) || u[:url].start_with?('/')
            end
            new_other_urls = truly_new_urls - new_external_urls - new_internal_urls

            if new_external_urls.any?
              puts "\n         🌐 NEW External URLs (#{new_external_urls.size}):"
              new_external_urls.first(3).each do |url_info|
                puts "            ➤ #{url_info[:url]}"
                puts "               Text: \"#{url_info[:text]}\"" unless url_info[:text].empty?
              end
              puts "            ... (showing first 3 of #{new_external_urls.size})" if new_external_urls.size > 3
            end

            if new_internal_urls.any?
              puts "\n         🏠 NEW Internal/#{@url_collector.domain.capitalize} URLs (#{new_internal_urls.size}):"
              new_internal_urls.first(3).each do |url_info|
                puts "            ➤ #{url_info[:url]}"
                puts "               Text: \"#{url_info[:text]}\"" unless url_info[:text].empty?
              end
              puts "            ... (showing first 3 of #{new_internal_urls.size})" if new_internal_urls.size > 3
            end

            if new_other_urls.any?
              puts "\n         📎 NEW Other URLs (#{new_other_urls.size}):"
              new_other_urls.first(3).each do |url_info|
                puts "            ➤ #{url_info[:url]}"
                puts "               Text: \"#{url_info[:text]}\"" unless url_info[:text].empty?
              end
              puts "            ... (showing first 3 of #{new_other_urls.size})" if new_other_urls.size > 3
            end
          else
            puts '         ⚠️  No completely new URLs found'
            puts "         💡 Total links: #{urls_before_click.size} → #{current_urls.size}"
          end

        else
          puts '⚠️  No new content loaded'
          break
        end
      else
        puts '❌ Click failed'
        break
      end
    end

    final_count = @url_collector.urls.size
    puts "✅ Collection complete! #{final_count} total URLs (+#{final_count - initial_count} new)"

    @url_collector.to_simple_list
  end

  def display_results
    @url_collector.display_summary
    @url_collector.display_all_urls
  end

  def close
    @url_collector.close
  end
end
