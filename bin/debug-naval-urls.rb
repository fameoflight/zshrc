#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require 'ferrum'
require 'uri'

# Debug script to understand why nav.al URLs are missing
class DebugNavalUrls < ScriptBase
  def script_emoji
    '🔍'
  end

  def script_title
    'Debug Naval URLs'
  end

  def script_description
    'Comprehensive debugging of nav.al URL collection'
  end

  def add_custom_options(opts)
    opts.on('--[no-]headless', 'Run browser in headless mode (default: false for debugging)') do |headless|
      @options[:headless] = headless
    end

    opts.on('--timeout SECONDS', Integer, 'Browser timeout in seconds (default: 60)') do |timeout|
      @options[:timeout] = timeout
    end

    opts.on('--max-clicks COUNT', Integer, 'Maximum clicks to try (default: 15)') do |count|
      @options[:max_clicks] = count
    end
  end

  def default_options
    super.merge({
                  headless: false,
                  timeout: 60,
                  max_clicks: 15
                })
  end

  def run
    log_banner("#{script_emoji} Naval URL Debug Session")

    url = "https://nav.al"
    log_info("Debugging: #{url}")

    browser = nil

    begin
      # Setup browser
      log_section("🌐 Browser Setup")
      browser_options = {
        headless: @options[:headless],
        timeout: @options[:timeout],
        window_size: [1920, 1080],
        browser_options: {
          'no-sandbox' => nil,
          'disable-gpu' => nil,
          'disable-dev-shm-usage' => nil
        }
      }

      browser = Ferrum::Browser.new(browser_options)
      log_success("Browser created successfully")

      # Load the page
      log_section("📄 Loading Page")
      browser.goto(url)
      sleep(3)  # Wait for initial load
      log_success("Page loaded")

      # Initial analysis
      log_section("🔍 Initial Page Analysis")
      analyze_page_completely(browser)

      # Find and analyze all potential read more buttons
      log_section("🎯 Read More Button Analysis")
      buttons = find_all_potential_buttons(browser)
      log_info("Found #{buttons.size} potential buttons")

      buttons.each_with_index do |button, index|
        analyze_button_completely(browser, button, index + 1)
      end

      # Try clicking each button and see what happens
      log_section("🔄 Click Testing")
      initial_urls = collect_all_urls(browser)
      log_info("Initial URL count: #{initial_urls.size}")

      buttons.first(@options[:max_clicks]).each_with_index do |button, click_index|
        test_button_click(browser, button, click_index + 1, initial_urls)

        # Wait between clicks
        sleep(2)
      end

      # Final URL collection
      log_section("📊 Final URL Analysis")
      final_urls = collect_all_urls(browser)
      log_info("Final URL count: #{final_urls.size}")

      # Show what we found
      show_url_breakdown(final_urls)

      # Compare with expected
      check_missing_articles(browser, final_urls)

    rescue StandardError => e
      log_error("Debug failed: #{e.message}")
      log_debug("Backtrace: #{e.backtrace.join("\n")}") if debug?
    ensure
      browser&.quit
      log_info('Browser closed')
    end

    show_completion('Naval URL debug')
  end

  private

  def analyze_page_completely(browser)
    begin
      title = browser.evaluate("document.title")
      log_info("Page title: #{title}")

      # Count different elements
      counts = {
        'Total links' => browser.css('a[href]').size,
        'Internal links' => browser.css('a[href^="/"], a[href*="nav.al"]').size,
        'External links' => browser.css('a[href^="http"]:not([href*="nav.al"])').size,
        'Paragraphs' => browser.css('p').size,
        'Divs' => browser.css('div').size,
        'Articles' => browser.css('article').size,
        'Headings (h1-h6)' => browser.css('h1, h2, h3, h4, h5, h6').size
      }

      counts.each { |type, count| puts "  #{type}: #{count}" }

      # Check for any pagination or infinite scroll indicators
      pagination_selectors = [
        '.pagination', '[class*="pagination"]',
        '.load-more', '[class*="load-more"]', '[class*="loadmore"]',
        '.infinite-scroll', '[class*="infinite"]',
        '.read-more', '[class*="read-more"]',
        '[data-load]', '[data-more]', '[data-next]'
      ]

      pagination_selectors.each do |selector|
        elements = browser.css(selector)
        if elements.any?
          log_info("Found #{elements.size} elements with selector: #{selector}")
          elements.first(3).each_with_index do |el, i|
            text = el.text&.strip || ""
            classes = el.attribute('class') || ""
            puts "    #{i+1}. '#{text[0..50]}' (#{classes})"
          end
        end
      end

    rescue => e
      log_error("Page analysis failed: #{e.message}")
    end
  end

  def find_all_potential_buttons(browser)
    all_buttons = []

    # Strategy 1: Text-based search (most comprehensive)
    text_patterns = [
      'read more', 'load more', 'show more', 'view more', 'see more',
      'more posts', 'more articles', 'more content', 'more entries',
      'next', 'next page', 'continue', 'load next',
      'previous', 'prev', 'back',
      'older', 'newer', 'older posts', 'newer posts',
      'expand', 'show all', 'view all',
      'load', 'more'
    ]

    # Get all potentially interactive elements
    interactive_elements = browser.css('a, button, div, span, input, [onclick], [role="button"], [tabindex]')

    log_info("Checking #{interactive_elements.size} interactive elements for text patterns...")

    interactive_elements.each do |element|
      begin
        text = element.text&.strip&.downcase || ""
        href = element.attribute('href') || ""
        classes = element.attribute('class') || ""

        text_patterns.each do |pattern|
          if text.include?(pattern)
            all_buttons << {
              element: element,
              method: 'text',
              pattern: pattern,
              text: element.text&.strip || "",
              href: href,
              classes: classes
            }
          end
        end
      rescue => e
        # Skip problematic elements
      end
    end

    # Strategy 2: CSS selector search
    css_selectors = [
      '[class*="load"]', '[class*="more"]', '[class*="next"]', '[class*="prev"]',
      '[id*="load"]', '[id*="more"]', '[id*="next"]', '[id*="prev"]',
      '.pagination a', '.pagination button',
      'button[onclick]', 'a[href="#"]'
    ]

    css_selectors.each do |selector|
      begin
        elements = browser.css(selector)
        elements.each do |element|
          all_buttons << {
            element: element,
            method: 'css',
            pattern: selector,
            text: element.text&.strip || "",
            href: element.attribute('href') || "",
            classes: element.attribute('class') || ""
          }
        end
      rescue => e
        # Skip selector errors
      end
    end

    # Remove duplicates and return elements
    unique_buttons = all_buttons.uniq { |b| b[:element] }
    log_info("Found #{unique_buttons.size} unique potential buttons")

    unique_buttons
  end

  def analyze_button_completely(browser, button_info, index)
    element = button_info[:element]

    puts "\n🔍 Button #{index} Analysis:"
    puts "  Detection: #{button_info[:method]} (#{button_info[:pattern]})"
    puts "  Text: '#{button_info[:text]}'"
    puts "  Classes: #{button_info[:classes]}"
    puts "  Href: #{button_info[:href]}"

    begin
      tag_name = element.tag_name
      visible = element.displayed?
      enabled = !element.attribute('disabled')

      puts "  Tag: #{tag_name}"
      puts "  Visible: #{visible}"
      puts "  Enabled: #{enabled}"

      # Get position info
      location = element.attribute('getBoundingClientRect') rescue nil
      puts "  Position: #{location}" if location

      # Check for click handlers
      onclick = element.attribute('onclick') rescue nil
      puts "  OnClick: #{onclick}" if onclick

    rescue => e
      puts "  Analysis error: #{e.message}"
    end
  end

  def test_button_click(browser, button_info, click_number, initial_urls)
    element = button_info[:element]

    puts "\n🎯 Testing Click #{click_number}: '#{button_info[:text]}'"

    # Count URLs before click
    urls_before = collect_all_urls(browser)
    puts "  URLs before: #{urls_before.size}"

    # Try clicking
    click_success = false
    click_methods = [
      { name: "JavaScript click", method: -> { browser.evaluate("arguments[0].click();", element) } },
      { name: "Direct click", method: -> { element.click } },
      { name: "Mouse events", method: -> {
        element.evaluate("function() {
          ['mousedown', 'mouseup', 'click'].forEach(eventType => {
            this.dispatchEvent(new MouseEvent(eventType, { bubbles: true, cancelable: true }));
          });
        }")
      }}
    ]

    click_methods.each do |method|
      begin
        puts "  Trying: #{method[:name]}"
        method[:method].call
        click_success = true
        puts "  ✅ #{method[:name]} succeeded"
        break
      rescue => e
        puts "  ❌ #{method[:name]} failed: #{e.message}"
      end
    end

    return unless click_success

    # Wait for changes
    puts "  ⏳ Waiting for page changes..."
    wait_time = 10
    (1..wait_time).each do |second|
      print "."
      sleep(1)
    end
    puts ""

    # Check for new URLs
    urls_after = collect_all_urls(browser)
    new_urls = urls_after - urls_before

    puts "  📊 URLs after: #{urls_after.size} (+#{new_urls.size} new)"

    if new_urls.any?
      puts "  🆕 New URLs found:"
      new_urls.first(5).each { |url| puts "     • #{url}" }
      puts "     ... (showing first 5)" if new_urls.size > 5
    else
      puts "  ⚠️  No new URLs found"

      # Check if anything changed on the page
      current_link_count = browser.css('a[href]').size
      current_content_count = browser.css('p, div, article, h1, h2, h3').size
      puts "  📊 Link count: #{current_link_count}, Content elements: #{current_content_count}"
    end
  end

  def collect_all_urls(browser)
    urls = []

    begin
      link_elements = browser.css('a[href]')
      link_elements.each do |link|
        href = link.attribute('href')
        if href && !href.empty?
          # Convert relative URLs to absolute
          absolute_url = href.start_with?('http') ? href : URI.join('https://nav.al/', href).to_s
          urls << absolute_url unless urls.include?(absolute_url)
        end
      end
    rescue => e
      log_error("URL collection failed: #{e.message}")
    end

    urls.uniq.sort
  end

  def show_url_breakdown(urls)
    naval_urls = urls.select { |url| url.include?('nav.al') && !url.end_with?('nav.al') && !url.end_with?('nav.al/') }
    external_urls = urls.select { |url| url.start_with?('http') && !url.include?('nav.al') }

    puts "\n📊 URL Breakdown:"
    puts "  Total URLs: #{urls.size}"
    puts "  Naval articles: #{naval_urls.size}"
    puts "  External links: #{external_urls.size}"

    if naval_urls.any?
      puts "\n📝 Naval Articles Found:"
      naval_urls.first(10).each_with_index { |url, i| puts "  #{i+1}. #{url}" }
      puts "  ... (showing first 10)" if naval_urls.size > 10
    end
  end

  def check_missing_articles(browser, found_urls)
    # Try to estimate expected article count by looking at the archive page or sitemap
    puts "\n🔍 Checking for potentially missing articles..."

    begin
      # Look for any indicators of total article count
      page_text = browser.evaluate("document.body.innerText")

      # Check if there's an archive link or sitemap
      archive_links = browser.css('a[href*="archive"], a[href*="sitemap"], a[href*="all"]')
      if archive_links.any?
        puts "  Found potential archive links:"
        archive_links.each { |link| puts "    • #{link.attribute('href')} - '#{link.text&.strip}'" }
      end

      # Estimate based on what we found
      naval_articles = found_urls.select { |url| url.include?('nav.al') && url.match?(/\/[^\/]+$/) }.size
      puts "  Estimated Naval articles found: #{naval_articles}"

      if naval_articles < 50  # Naval likely has more than 50 posts
        log_warning("⚠️  This seems low - Naval probably has more articles")
        log_info("Consider checking:")
        log_info("  • Archive pages")
        log_info("  • Different pagination mechanisms")
        log_info("  • JavaScript-loaded content")
        log_info("  • RSS feeds or sitemaps")
      end

    rescue => e
      puts "  Error checking missing articles: #{e.message}"
    end
  end
end

# Execute the script
DebugNavalUrls.execute if __FILE__ == $0