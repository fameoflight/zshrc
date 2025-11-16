#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: Investigate nav.al JavaScript and Read More functionality
# @tags: testing, web-scraping, debugging

require 'ferrum'

puts "🔍 Investigating nav.al JavaScript and Read More functionality..."

browser = Ferrum::Browser.new(headless: false, timeout: 60)

begin
  puts "📄 Loading https://nav.al..."
  browser.goto('https://nav.al')
  sleep(5) # Wait for all JavaScript to load

  # Check if jQuery or other libraries are loaded
  puts "\n📚 Checking JavaScript libraries..."
  jquery_version = browser.evaluate("typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'not loaded'") rescue 'error'
  puts "  jQuery: #{jquery_version}"

  dollar_available = browser.evaluate("typeof $ !== 'undefined'") rescue false
  puts "  $ available: #{dollar_available}"

  # Check what JavaScript events might be attached
  puts "\n🔧 Investigating Read More button..."

  # Find the specific button
  trigger_element = browser.css('.trigger-load-more').first

  if trigger_element
    puts "  ✅ Found trigger-load-more element"

    # Check its properties
    href = trigger_element.attribute('href') rescue ""
    classes = trigger_element.attribute('class') rescue ""
    onclick = trigger_element.attribute('onclick') rescue ""

    puts "    Href: #{href}"
    puts "    Classes: #{classes}"
    puts "    OnClick: #{onclick.empty? ? 'none' : onclick}"

    # Check if it has jQuery event handlers
    has_click_handlers = browser.evaluate("
      var element = arguments[0];
      var events = $._data ? $._data(element, 'events') : null;
      return events && events.click ? events.click.length : 0;
    ", trigger_element) rescue 0

    puts "    jQuery click handlers: #{has_click_handlers}"

    # Check for data attributes that might indicate AJAX behavior
    data_attrs = browser.evaluate("
      var element = arguments[0];
      var data = {};
      for (var i = 0; i < element.attributes.length; i++) {
        var attr = element.attributes[i];
        if (attr.name.startsWith('data-')) {
          data[attr.name] = attr.value;
        }
      }
      return data;
    ", trigger_element) rescue {}

    puts "    Data attributes: #{data_attrs}"

    # Check what happens when we scroll to the element
    puts "\n🔄 Scrolling to Read More button..."
    trigger_element.evaluate("this.scrollIntoView({behavior: 'smooth', block: 'center'})")
    sleep(2)

    # Check if the button becomes different after scrolling
    visible_after_scroll = trigger_element.displayed? rescue false
    puts "    Visible after scroll: #{visible_after_scroll}"

    # Try to trigger any scroll-based loading
    puts "\n📜 Testing scroll-based loading..."
    initial_height = browser.evaluate("document.body.scrollHeight")
    browser.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    sleep(3)

    new_height = browser.evaluate("document.body.scrollHeight")
    puts "    Scroll height: #{initial_height} → #{new_height}"

    if new_height > initial_height
      puts "    🎉 Infinite scroll detected!"

      # Count links again
      new_links = browser.css('a[href]').size
      puts "    New link count: #{new_links}"
    else
      puts "    No infinite scroll detected"
    end

    # Try clicking with more aggressive event simulation
    puts "\n🎯 Testing aggressive click simulation..."

    # First try: Multiple event types
    result1 = browser.evaluate("
      var element = arguments[0];
      var events = ['mousedown', 'mouseup', 'click'];
      var results = [];

      events.forEach(function(eventType) {
        var event = new MouseEvent(eventType, {
          view: window,
          bubbles: true,
          cancelable: true,
          button: 0
        });
        var dispatched = element.dispatchEvent(event);
        results.push(eventType + ':' + dispatched);
      });

      return results.join(', ');
    ", trigger_element) rescue 'error'

    puts "    Mouse events result: #{result1}"
    sleep(3)

    # Check for any network activity or DOM changes
    link_count_after = browser.css('a[href]').size
    puts "    Links after mouse events: #{link_count_after}"

    # Second try: Focus and keyboard events
    result2 = browser.evaluate("
      var element = arguments[0];
      element.focus();

      var enterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        bubbles: true,
        cancelable: true
      });

      return element.dispatchEvent(enterEvent);
    ", trigger_element) rescue 'error'

    puts "    Keyboard event result: #{result2}"
    sleep(3)

    link_count_after2 = browser.css('a[href]').size
    puts "    Links after keyboard events: #{link_count_after2}"

    # Third try: Check if there are any AJAX requests we can trigger manually
    puts "\n🌐 Checking for AJAX endpoints..."

    # Look for any fetch or XMLHttpRequest patterns in the page source
    page_source = browser.evaluate("document.documentElement.outerHTML")

    ajax_patterns = [
      /fetch\s*\(\s*['"](.*?)['"]/,
      /XMLHttpRequest.*open\s*\(\s*['"]GET['"],\s*['"](.*?)['"]/,
      /\$\.get\s*\(\s*['"](.*?)['"]/,
      /\$\.ajax.*url\s*:\s*['"](.*?)['"]/
    ]

    ajax_urls = []
    ajax_patterns.each do |pattern|
      matches = page_source.scan(pattern)
      ajax_urls.concat(matches.flatten) if matches.any?
    end

    if ajax_urls.any?
      puts "    Found potential AJAX URLs:"
      ajax_urls.uniq.each { |url| puts "      #{url}" }
    else
      puts "    No obvious AJAX patterns found"
    end

    # Fourth try: Check for any load-more specific JavaScript functions
    load_more_functions = browser.evaluate("
      var functions = [];
      for (var prop in window) {
        if (typeof window[prop] === 'function' &&
            (prop.toLowerCase().includes('load') ||
             prop.toLowerCase().includes('more') ||
             prop.toLowerCase().includes('next'))) {
          functions.push(prop);
        }
      }
      return functions;
    ") rescue []

    if load_more_functions.any?
      puts "    Load-more related functions: #{load_more_functions.join(', ')}"

      # Try calling them
      load_more_functions.each do |func|
        begin
          puts "    Trying to call #{func}()..."
          browser.evaluate("if (typeof #{func} === 'function') #{func}();")
          sleep(2)

          link_count_after_func = browser.css('a[href]').size
          puts "      Links after #{func}: #{link_count_after_func}"
        rescue => e
          puts "      #{func} failed: #{e.message}"
        end
      end
    else
      puts "    No load-more functions found in global scope"
    end

  else
    puts "  ❌ trigger-load-more element not found"
  end
ensure
  puts "\n🔒 Closing browser..."
  browser.quit rescue nil
end

puts "✅ Investigation complete!"
