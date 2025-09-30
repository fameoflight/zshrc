#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ferrum'

puts "🔍 Testing nav.al Read More button clicking..."

browser = Ferrum::Browser.new(headless: false, timeout: 60)

begin
  # Load the page
  puts "📄 Loading https://nav.al..."
  browser.goto('https://nav.al')
  sleep(3)

  # Count initial URLs
  initial_links = browser.css('a[href]')
  initial_count = initial_links.size
  puts "📊 Initial links found: #{initial_count}"

  # Find the Read More button specifically
  puts "\n🎯 Looking for Read More button..."

  # Try multiple selectors for the Read More button
  read_more_selectors = [
    'a:contains("Read More")', # This won't work in CSS, need to use text search
    '.load-more-post-handle',
    '.trigger-load-more',
    '.extra-pagination-link',
    '[class*="load-more"]',
    '[class*="read-more"]'
  ]

  read_more_elements = []

  # Search by text content (most reliable)
  all_links = browser.css('a, button, div, span')
  all_links.each do |element|
    begin
      text = element.text&.strip || ""
      if text.downcase.include?('read more')
        read_more_elements << element
        puts "  Found by text: '#{text[0..30]}...'"

        # Show element details
        tag_name = element.tag_name rescue "unknown"
        classes = element.attribute('class') rescue ""
        href = element.attribute('href') rescue ""
        puts "    Tag: #{tag_name}, Classes: #{classes}, Href: #{href}"
      end
    rescue
      next
    end
  end

  # Also try CSS selectors
  read_more_selectors.each do |selector|
    begin
      elements = browser.css(selector)
      elements.each do |element|
        text = element.text&.strip || ""
        puts "  Found by CSS '#{selector}': '#{text[0..30]}...'"
        read_more_elements << element unless read_more_elements.include?(element)
      end
    rescue
      next
    end
  end

  if read_more_elements.empty?
    puts "❌ No Read More button found!"
    exit 1
  end

  puts "\n🎯 Found #{read_more_elements.size} Read More candidates"

  # Try clicking each candidate
  read_more_elements.each_with_index do |element, index|
    puts "\n🔄 Testing candidate #{index + 1}..."

    begin
      text = element.text&.strip || ""
      puts "  Text: '#{text[0..50]}...'"

      # Try different click methods
      click_methods = [
        { name: "JavaScript click", method: -> { browser.evaluate("arguments[0].click();", element) } },
        { name: "Element click", method: -> { element.click } },
        { name: "Force visible + click", method: -> {
          element.evaluate("this.style.visibility = 'visible'; this.style.display = 'block';")
          sleep(0.2)
          browser.evaluate("arguments[0].click();", element)
        } }
      ]

      click_success = false
      click_methods.each do |method|
        begin
          puts "    Trying: #{method[:name]}..."
          method[:method].call
          click_success = true
          puts "    ✅ #{method[:name]} succeeded!"
          break
        rescue => e
          puts "    ❌ #{method[:name]} failed: #{e.message}"
        end
      end

      next unless click_success

      # Wait for new content
      puts "  ⏳ Waiting for new content..."
      max_wait = 15
      start_time = Time.now

      while (Time.now - start_time) < max_wait
        sleep(1)
        current_links = browser.css('a[href]')
        current_count = current_links.size

        if current_count > initial_count
          new_count = current_count - initial_count
          puts "  🎉 SUCCESS! Found #{new_count} new links! (#{initial_count} → #{current_count})"

          # Show some new URLs
          puts "  🆕 Sample new links:"
          current_links.last(5).each do |link|
            href = link.attribute('href') rescue ""
            text = link.text&.strip || ""
            puts "    • #{href} - '#{text[0..30]}...'" if href && !href.empty?
          end

          break
        else
          print "."
        end
      end

      if (Time.now - start_time) >= max_wait
        puts "\n  ⚠️  No new content appeared after #{max_wait} seconds"
      end

      # Only test first successful click
      break if click_success
    rescue => e
      puts "  ❌ Error testing element: #{e.message}"
    end
  end
ensure
  puts "\n🔒 Closing browser..."
  browser.quit rescue nil
end

puts "✅ Test complete!"
