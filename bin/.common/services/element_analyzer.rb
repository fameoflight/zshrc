# frozen_string_literal: true

require_relative 'base_service'
require_relative 'element_detector_service'

# Element finder and analyzer utility for browser automation
class ElementAnalyzer < BaseService
  def initialize(browser, options = {})
    super(options)
    @browser = browser
    @use_llm = options[:use_llm] || false

    # Initialize LLM detector service if requested
    if @use_llm
      @llm_detector = ElementDetectorService.new(logger: @logger, debug: @debug)
      if @llm_detector.available?
        puts "🤖 LLM element detection enabled"
      else
        puts "⚠️  LLM not available, falling back to traditional detection"
        @use_llm = false
      end
    end
  end

  def find_read_more_elements
    # Strategy 1: LLM-enhanced detection (if available and enabled)
    llm_elements = []
    if @use_llm && @llm_detector&.available?
      llm_elements = find_elements_with_llm
      puts "🤖 LLM found #{llm_elements.size} potential elements"
    end
    
    # Strategy 2: PRIORITIZE text-based detection (most reliable)
    text_patterns = [
      'read more', 'load more', 'show more', 'view more', 'see more',
      'more posts', 'more articles', 'more content',
      'next', 'next page', 'continue',
      'previous', 'prev',
      'older posts', 'newer posts',
      'load', 'expand', 'show all'
    ]
    text_elements = find_elements_with_text(text_patterns)
    
    # Strategy 3: Look for specific patterns and classes (fallback)
    specific_elements = find_load_more_elements
    pattern_elements = find_elements_with_patterns
    
    # Combine all strategies, prioritizing LLM findings first
    all_elements = llm_elements + text_elements + (specific_elements + pattern_elements).reject { |el| (llm_elements + text_elements).include?(el) }

    # Filter elements to prioritize potentially clickable ones
    filtered_elements = []

    all_elements.uniq.each_with_index do |element, index|
      begin
        # Check basic element properties
        tag_name = element.tag_name.downcase rescue "unknown"
        text = element.text&.strip || ""
        href = element.attribute('href') rescue nil
        classes = element.attribute('class') || ""

        # Calculate element score for prioritization
        score = 0

        # Higher score for clickable tags
        score += 10 if %w[a button input].include?(tag_name)
        score += 5 if %w[div span li].include?(tag_name)

        # Higher score for elements with href
        score += 8 if href

        # Higher score for elements with click-related classes
        score += 5 if classes.downcase.match?(/(button|click|load|more|next|prev)/)

        # Higher score for meaningful text
        score += 3 if text.length > 0 && text.length < 50
        score -= 2 if text.length > 100  # Probably not a button

        # Prefer elements that are likely visible (but don't exclude invisible ones)
        begin
          is_displayed = element.displayed?
          score += 2 if is_displayed
          puts "   [#{index+1}] #{tag_name} '#{text[0..30]}' - Score: #{score}, Visible: #{is_displayed}"
        rescue
          puts "   [#{index+1}] #{tag_name} '#{text[0..30]}' - Score: #{score}, Visibility: unknown"
        end

        filtered_elements << { element: element, score: score }

      rescue => e
        puts "   Error evaluating element #{index+1}: #{e.message}"
        # Still include the element but with low score
        filtered_elements << { element: element, score: 0 }
      end
    end

    # Sort by score (highest first) and return just the elements
    sorted_elements = filtered_elements.sort_by { |item| -item[:score] }.map { |item| item[:element] }

    puts "🎯 Element prioritization complete: #{sorted_elements.size} elements ranked by likelihood"
    sorted_elements
  end

  def click_read_more_element(element)
    return false unless element

    puts "🔄 Attempting multiple click methods for element..."

    # ============================================================================
    # IMPORTANT NOTE ABOUT FERRUM JAVASCRIPT EXECUTION:
    # - Use browser.execute() for actions that don't return values (like clicks)
    # - Use browser.evaluate() for getting return values from JavaScript
    # - Use element.evaluate() for JavaScript that operates on the element itself
    # This distinction is CRITICAL for click actions to work properly!
    # ============================================================================

    # Analyze element first
    analyze_element(element)

    # Check element visibility and properties first
    is_visible = element.displayed? rescue false
    is_enabled = !element.attribute('disabled') rescue true
    puts "🔍 Element visibility: #{is_visible}, enabled: #{is_enabled}"

    # Try multiple click methods, starting with the most reliable for invisible elements
    click_methods = [
      {
        name: "JavaScript execute click (best for invisible elements)",
        method: -> {
          puts "⏱️  Method 1: JavaScript execute click..."
          start_click = Time.now
          # IMPORTANT: Use execute() not evaluate() for actions that don't return values
          # execute() runs JavaScript without expecting a return value
          # evaluate() is for getting return values from JavaScript
          @browser.execute("arguments[0].click();", element)
          click_time = Time.now - start_click
          puts "✅ JS execute click executed in #{click_time.round(3)} seconds"
          true
        }
      },
      {
        name: "Simulate mouse event with all handlers",
        method: -> {
          puts "⏱️  Method 2: Simulate comprehensive mouse event..."
          start_click = Time.now
          # Use element.evaluate for JavaScript that operates on the element itself
          element.evaluate("function() {
            // Trigger multiple events to ensure compatibility
            ['mousedown', 'mouseup', 'click'].forEach(eventType => {
              var event = new MouseEvent(eventType, {
                view: window,
                bubbles: true,
                cancelable: true,
                button: 0,
                buttons: 1,
                clientX: 0,
                clientY: 0
              });
              this.dispatchEvent(event);
            });
          }")
          click_time = Time.now - start_click
          puts "✅ Comprehensive mouse events executed in #{click_time.round(3)} seconds"
          true
        }
      },
      {
        name: "Force visible and click",
        method: -> {
          puts "⏱️  Method 3: Force visible and click..."
          start_click = Time.now
          # Force element to be visible and clickable using element.evaluate
          element.evaluate("function() {
            this.style.display = 'block';
            this.style.visibility = 'visible';
            this.style.opacity = '1';
            this.style.pointerEvents = 'auto';
            this.scrollIntoView({behavior: 'instant', block: 'center'});
          }")
          sleep(0.2)
          # CRITICAL: Use execute() not evaluate() for click actions
          @browser.execute("arguments[0].click();", element)
          click_time = Time.now - start_click
          puts "✅ Force visible+click executed in #{click_time.round(3)} seconds"
          true
        }
      },
      {
        name: "Direct element click (if visible)",
        method: -> {
          if is_visible
            puts "⏱️  Method 4: Direct element click..."
            start_click = Time.now
            element.click
            click_time = Time.now - start_click
            puts "✅ Direct click executed in #{click_time.round(3)} seconds"
            true
          else
            puts "⏭️  Skipping direct click - element not visible"
            false
          end
        }
      },
      {
        name: "JavaScript trigger with jQuery if available",
        method: -> {
          puts "⏱️  Method 5: jQuery trigger (if available)..."
          start_click = Time.now
          # Use evaluate() here because we need the return value to know which method worked
          result = @browser.evaluate("
            if (typeof jQuery !== 'undefined' || typeof $ !== 'undefined') {
              var jq = jQuery || $;
              jq(arguments[0]).trigger('click');
              return 'jquery';
            } else {
              arguments[0].click();
              return 'vanilla';
            }
          ", element)
          click_time = Time.now - start_click
          puts "✅ #{result.capitalize} click executed in #{click_time.round(3)} seconds"
          true
        }
      },
      {
        name: "Focus and keyboard activation",
        method: -> {
          puts "⏱️  Method 6: Focus and keyboard activation..."
          start_click = Time.now
          element.evaluate("function() {
            this.focus();
            // Try both Enter and Space
            ['Enter', ' '].forEach(key => {
              var event = new KeyboardEvent('keydown', {
                key: key,
                code: key === 'Enter' ? 'Enter' : 'Space',
                keyCode: key === 'Enter' ? 13 : 32,
                bubbles: true,
                cancelable: true
              });
              this.dispatchEvent(event);
            });
          }")
          click_time = Time.now - start_click
          puts "✅ Focus+keyboard executed in #{click_time.round(3)} seconds"
          true
        }
      }
    ]

    # Try each method until one succeeds
    click_methods.each_with_index do |method_info, index|
      begin
        puts "\n🎯 Trying #{method_info[:name]} (#{index + 1}/#{click_methods.size})"
        result = method_info[:method].call
        if result
          puts "✅ Click method succeeded: #{method_info[:name]}"
          return true
        end
      rescue => e
        puts "❌ #{method_info[:name]} failed: #{e.class.name} - #{e.message}"
        # Continue to next method
      end
    end

    puts "❌ All click methods failed for this element"
    false
  end

  def wait_for_content_change(initial_counts, timeout: 30)
    require 'tty-progressbar'

    start_time = Time.now
    initial_link_count = initial_counts['links'] || 0

    # Create progress bar for waiting
    bar = TTY::ProgressBar.new("      ⏳ [:bar] :percent :elapsed :status",
                              total: timeout,
                              width: 20,
                              incomplete: '·',
                              complete: '█')

    # Multiple strategies to detect content changes
    change_detected = false
    last_link_count = initial_link_count
    stable_count_checks = 0
    min_stable_checks = 3  # Wait for at least 3 stable readings

    # Continuously check document.readyState and content changes
    while (Time.now - start_time) < timeout && !change_detected
      elapsed = (Time.now - start_time)

      begin
        # Update progress bar
        bar.advance(0.5) if elapsed > bar.current

        # Check document ready state
        ready_state = @browser.evaluate("document.readyState")

        # Check for loading indicators
        loading_indicators = @browser.css('.loading, .spinner, .loader, [data-loading]').size

        # Check current link count (primary indicator)
        current_link_count = @browser.css('a[href]').size

        # Check for DOM changes using mutation observer results if available
        dom_changes_detected = false
        begin
          # Try to detect if DOM has been modified
          dom_timestamp = @browser.evaluate("document.lastModified || new Date().toISOString()")
          dom_changes_detected = true if dom_timestamp  # Simplified check
        rescue
          # Ignore DOM check errors
        end

        # Strategy 1: Direct link count increase (most reliable)
        if current_link_count > initial_link_count
          change_detected = true
          bar.finish
          puts "\n      🎉 SUCCESS! New links detected (+#{current_link_count - initial_link_count} links)"
          return true
        end

        # Strategy 2: Check content element changes
        new_counts = count_content_elements
        content_increased = initial_counts.any? { |selector, initial_count|
          new_counts[selector] > initial_count
        }

        if content_increased
          change_detected = true
          bar.finish
          puts "\n      🎉 SUCCESS! New content elements detected"

          # Show which selector had the increase
          initial_counts.each do |selector, initial_count|
            if new_counts[selector] > initial_count
              increase = new_counts[selector] - initial_count
              puts "         #{selector}: +#{increase} new items"
            end
          end
          return true
        end

        # Strategy 3: Link count stability check (for pages that update links in place)
        if current_link_count == last_link_count
          stable_count_checks += 1
        else
          stable_count_checks = 0
          last_link_count = current_link_count
        end

        # If we have a different (but not necessarily higher) link count and it's been stable
        if current_link_count != initial_link_count && stable_count_checks >= min_stable_checks
          change_detected = true
          bar.finish
          puts "\n      🎉 SUCCESS! Page content stabilized with changes (#{current_link_count} vs #{initial_link_count} links)"
          return true
        end

        # Update status
        if loading_indicators > 0
          status = "loading..."
        elsif current_link_count != last_link_count
          status = "updating..."
        else
          status = "#{ready_state} (#{stable_count_checks}/#{min_stable_checks})"
        end
        bar.update(status: status)

        # Progressive sleep - start with shorter intervals for better responsiveness
        sleep_interval = case elapsed
        when 0..1 then 0.2   # Very responsive first second
        when 1..3 then 0.5   # Quick checks for 3 seconds
        when 3..10 then 1    # Standard checks up to 10 seconds
        else 2               # Longer intervals after 10 seconds
        end

        sleep(sleep_interval)

      rescue => e
        bar.update(status: "error")
        puts "\n      ⚠️  Error during content change detection: #{e.message}" if elapsed > 10  # Only show errors after 10s
        sleep(1)
      end
    end

    bar.finish
    puts "\n      ⚠️  No new content detected after #{timeout} seconds"
    false
  end

  def collect_all_urls_after_click
    require 'tty-progressbar'
    
    # Collect ALL links from the updated page (like original debug script)
    new_link_elements = @browser.css('a[href]')
    
    # Progress bar for URL collection
    bar = TTY::ProgressBar.new("      🔗 [:bar] :percent Collecting URLs (:current/:total)", 
                              total: new_link_elements.size,
                              width: 20,
                              incomplete: '·',
                              complete: '█')
    
    new_urls_found = []
    new_link_elements.each_with_index do |link, index|
      bar.advance(1)
      
      begin
        href = link.attribute('href')
        text = link.text.strip
        
        if href && !href.empty?
          new_urls_found << {
            url: href,
            text: text.length > 50 ? "#{text[0..47]}..." : text,
            index: index + 1,
            full_text: text
          }
        end
      rescue => e
        # Silently skip errors during collection
      end
    end
    
    bar.finish
    puts "\n         📊 Total URLs collected: #{new_urls_found.size}"
    new_urls_found
  end

  def count_content_elements
    content_selectors = [
      'article', '.post', '.entry', '.item', '.content-item', '[data-post]',
      'h1', 'h2', 'h3',
      # Posthaven-specific selectors for archives
      '.archive-entry', '.archive-results li', '.posthaven-archive-entry',
      # Nav.al specific selectors (each blog post appears to be in its own structure)
      'p', 'div', 'section',
      # Look for content that contains article-like text patterns
      '[href*="/"]'  # Internal links which often indicate articles
    ]
    counts = {}

    content_selectors.each do |selector|
      begin
        counts[selector] = @browser.css(selector).size
      rescue
        counts[selector] = 0
      end
    end

    # Enhanced link counting for better detection
    begin
      counts['links'] = @browser.css('a[href]').size
      counts['internal_links'] = @browser.css('a[href^="/"], a[href*="nav.al"]').size
      counts['external_links'] = @browser.css('a[href^="http"]:not([href*="nav.al"])').size
    rescue
      counts['links'] = 0
      counts['internal_links'] = 0
      counts['external_links'] = 0
    end

    # Count potential article indicators
    begin
      counts['text_blocks'] = @browser.css('p').select { |p|
        text = p.text.strip rescue ""
        text.length > 50  # Substantial text blocks
      }.size
    rescue
      counts['text_blocks'] = 0
    end

    counts
  end

  def analyze_element(element, index = 1)
    puts "   \n   📋 Element #{index} Analysis:"
    
    begin
      text = (element.text&.strip || "")
      tag_name = element.tag_name rescue "unknown"
      classes = element.attribute('class') rescue nil
      href = element.attribute('href') rescue nil
      id = element.attribute('id') rescue nil
      visible = element.displayed? rescue "unknown"
      
      puts "      Text: '#{text}'"
      puts "      Tag: #{tag_name}"
      puts "      Visible: #{visible}"
      puts "      Classes: #{classes}" if classes && !classes.empty?
      puts "      ID: #{id}" if id && !id.empty?
      puts "      Href: #{href}" if href && !href.empty?
      
      # Additional attributes
      onclick = element.attribute('onclick') rescue nil
      puts "      OnClick: #{onclick}" if onclick
      
      # Data attributes
      begin
        data_attrs = element.evaluate("function() { 
          var attrs = {}; 
          for(var i = 0; i < this.attributes.length; i++) { 
            var attr = this.attributes[i]; 
            if(attr.name.startsWith('data-')) attrs[attr.name] = attr.value; 
          } 
          return attrs; 
        }")
        
        if data_attrs.any?
          data_list = data_attrs.map { |k, v| "#{k}=\"#{v}\"" }
          puts "      Data attributes: #{data_list.join(', ')}"
        end
      rescue
      end
      
    rescue => e
      puts "      ❌ Error analyzing element: #{e.class.name} - #{e.message}"
    end
  end

  private

  def find_elements_with_llm
    return [] unless @llm_detector&.available?
    
    begin
      # Get page HTML for LLM analysis
      page_html = @browser.evaluate("document.documentElement.outerHTML")
      current_url = @browser.evaluate("window.location.href")
      
      puts "🤖 Analyzing page with LLM for next buttons..."
      
      # Get LLM suggestions
      llm_buttons = @llm_detector.find_next_buttons(page_html, current_url)
      
      # Convert LLM suggestions to actual browser elements
      found_elements = []
      
      llm_buttons.each_with_index do |button_info, index|
        selector = button_info['selector']
        confidence = button_info['confidence']
        
        puts "   🎯 LLM suggestion #{index + 1}: '#{selector}' (confidence: #{confidence.round(2)})"
        
        begin
          elements = @browser.css(selector)
          if elements.any?
            # Add the first matching element
            element = elements.first
            puts "      ✅ Found element: '#{element.text.strip[0..30]}'"
            found_elements << element
            
            # Store LLM metadata on the element for later use
            element.instance_variable_set(:@llm_metadata, button_info)
          else
            puts "      ❌ No elements found with selector"
          end
        rescue => e
          puts "      ❌ Selector error: #{e.message}"
        end
      end
      
      puts "🤖 LLM detection complete: #{found_elements.size} elements found"
      found_elements
      
    rescue => e
      puts "❌ LLM detection failed: #{e.class.name} - #{e.message}"
      []
    end
  end

  def find_load_more_elements
    # Try multiple selectors for load more buttons
    selectors = [
      'a.trigger-load-more',
      'a[class*="trigger-load-more"]',
      '.trigger-load-more',
      '*[class*="load-more"]',
      'a[class*="load-more"]',
      'button[class*="load-more"]'
    ]
    
    elements = []
    selectors.each do |selector|
      found = @browser.css(selector)
      elements.concat(found) if found.any?
    end
    
    elements.uniq
  end

  def find_elements_with_text(text_patterns)
    # Get potentially interactive elements (broader than just a/button)
    interactive_elements = @browser.css('a, button, div, span, li, p, h1, h2, h3, h4, h5, h6, [onclick], [role="button"], [tabindex]')
    matching_elements = []

    puts "🔍 Examining #{interactive_elements.size} potentially interactive elements for text patterns..."

    interactive_elements.each_with_index do |el, index|
      begin
        element_text = el.text&.strip || ''
        element_classes = el.attribute('class') || ''
        element_href = el.attribute('href') || ''
        element_id = el.attribute('id') || ''
        tag_name = el.tag_name

        # Check each pattern
        text_patterns.each do |pattern|
          if element_text.downcase.include?(pattern.downcase)
            # Check if disabled (but don't filter based on it)
            is_disabled = element_classes.downcase.include?('disabled')
            is_hidden = element_classes.downcase.include?('hidden') || element_href.include?('display:none')

            puts "   Found #{pattern}: [#{index+1}] <#{tag_name}> '#{element_text}' | Classes: #{element_classes} | ID: #{element_id} | Href: #{element_href} | Disabled: #{is_disabled} | Hidden: #{is_hidden}"

            # Add ALL matching elements regardless of disabled/hidden state
            matching_elements << el
            puts "     ✅ Added to candidates (will attempt to click)"
          end
        end

      rescue => e
        puts "   Error examining element #{index+1}: #{e.message}"
      end
    end

    puts "🎯 Found #{matching_elements.uniq.size} valid text-based elements"
    matching_elements.uniq
  end

  def find_elements_with_patterns
    # Look for common pagination/load more patterns
    pattern_selectors = [
      '[class*="load"]', '[class*="more"]', '[class*="expand"]', '[class*="continue"]',
      '[id*="load"]', '[id*="more"]', '[id*="expand"]', '[id*="continue"]',
      '[class*="next"]', '[class*="prev"]', '[class*="older"]', '[class*="newer"]',
      '[data-load]', '[data-more]', '[data-next]', '[data-prev]',
      '.pagination a', '.pagination button',
      '.next', '.prev', '.load', '.more',
      'button[type="button"]', 'input[type="button"]',
      'a[href="#"]', 'button[onclick]'  # Common patterns for dynamic loading
    ]

    elements = []
    pattern_selectors.each do |selector|
      begin
        found = @browser.css(selector)
        elements.concat(found) if found.any?
      rescue => e
        # Skip selector errors and continue
      end
    end

    elements.uniq
  end

  def build_click_methods(element)
    [
      { name: "Direct element click", method: -> { element.click } },
      { name: "JavaScript evaluate click", method: -> { @browser.evaluate("arguments[0].click();", element) } },
      { name: "JavaScript execute click", method: -> { @browser.execute("arguments[0].click();", element) } },
      { name: "Element evaluate click", method: -> { element.evaluate("function() { this.click(); }") } },
      { name: "Simulate mouse click", method: -> { 
        element.evaluate("function() { 
          var event = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true
          });
          this.dispatchEvent(event);
        }")
      }}
    ]
  end
end