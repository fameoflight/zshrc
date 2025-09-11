# frozen_string_literal: true

require_relative 'element_detector_service'

# Element finder and analyzer utility for browser automation
class ElementAnalyzer
  def initialize(browser, options = {})
    @browser = browser
    @use_llm = options[:use_llm] || false
    @logger = options[:logger]
    @debug = options[:debug] || false
    
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
    text_elements = find_elements_with_text(['next', 'more', 'read more', 'load more', 'show more', 'previous', 'prev'])
    
    # Strategy 3: Look for specific patterns and classes (fallback)
    specific_elements = find_load_more_elements
    pattern_elements = find_elements_with_patterns
    
    # Combine all strategies, prioritizing LLM findings first
    all_elements = llm_elements + text_elements + (specific_elements + pattern_elements).reject { |el| (llm_elements + text_elements).include?(el) }
    
    all_elements.uniq
  end

  def click_read_more_element(element)
    return false unless element

    puts "🔄 Method 2: JavaScript evaluate click"
    
    begin
      puts "⏱️  Executing click..."
      start_click = Time.now
      @browser.evaluate("arguments[0].click();", element)
      click_time = Time.now - start_click
      puts "✅ Click executed in #{click_time.round(3)} seconds"
      return true
      
    rescue => e
      puts "❌ Method failed: #{e.class.name} - #{e.message}"
      return false
    end
  end

  def wait_for_content_change(initial_counts, timeout: 30)
    require 'tty-progressbar'
    
    total_initial = initial_counts.values.max || 0
    start_time = Time.now
    
    # Create progress bar for waiting
    bar = TTY::ProgressBar.new("      ⏳ [:bar] :percent :elapsed :status", 
                              total: timeout, 
                              width: 20,
                              incomplete: '·',
                              complete: '█')
    
    # Continuously check document.readyState and content changes
    while (Time.now - start_time) < timeout
      elapsed = (Time.now - start_time)
      
      begin
        # Update progress bar
        bar.advance(0.5) if elapsed > bar.current
        
        # Check document ready state continuously (the main magic!)
        ready_state = @browser.evaluate("document.readyState")
        
        # Check for loading indicators
        loading_indicators = @browser.css('.loading, .spinner, .loader, [data-loading]').size
        status = loading_indicators > 0 ? "loading..." : ready_state
        bar.update(status: status)
        
        # Check content changes
        new_counts = count_content_elements
        total_new = new_counts.values.max || 0
        
        # Also check for new links as an indicator of content change
        current_link_count = @browser.css('a[href]').size
        initial_link_count = initial_counts['links'] || 0
        
        if total_new > total_initial
          bar.finish
          puts "\n      🎉 SUCCESS! New content loaded (+#{total_new - total_initial} items)"
          
          # Show which selector had the increase
          initial_counts.each do |selector, initial_count|
            if new_counts[selector] > initial_count
              increase = new_counts[selector] - initial_count
              puts "         #{selector}: +#{increase} new items"
            end
          end
          
          return true
        end
        
        # Check if new links were added (fallback detection)
        if current_link_count > initial_link_count
          bar.finish
          puts "\n      🎉 SUCCESS! New links detected (+#{current_link_count - initial_link_count} links)"
          return true
        end
        
        # Progressive sleep - start with shorter intervals
        sleep_interval = elapsed < 2 ? 0.5 : (elapsed < 5 ? 1 : 2)
        sleep(sleep_interval)
        
      rescue => e
        bar.update(status: "error")
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
      '.archive-entry', '.archive-results li', '.posthaven-archive-entry'
    ]
    counts = {}
    
    content_selectors.each do |selector|
      begin
        counts[selector] = @browser.css(selector).size
      rescue
        counts[selector] = 0
      end
    end
    
    # Also count total links as a fallback indicator
    begin
      counts['links'] = @browser.css('a[href]').size
    rescue
      counts['links'] = 0
    end
    
    counts
  end

  def analyze_element(element, index = 1)
    puts "   \n   📋 Element #{index} Analysis:"
    
    begin
      text = element.text.strip
      tag_name = element.tag_name rescue "unknown"
      classes = element.attribute('class') rescue "unknown"
      href = element.attribute('href') rescue "unknown"
      id = element.attribute('id') rescue "unknown"
      visible = element.displayed? rescue "unknown"
      
      puts "      Text: '#{text}'"
      puts "      Tag: #{tag_name}"
      puts "      Visible: #{visible}"
      puts "      Classes: #{classes}" if classes != "unknown"
      puts "      ID: #{id}" if id != "unknown" && !id.empty?
      puts "      Href: #{href}" if href != "unknown" && !href.empty?
      
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
        tag_name = el.tag_name
        
        # Check each pattern
        text_patterns.each do |pattern|
          if element_text.downcase.include?(pattern.downcase)
            # Check if disabled (but don't filter based on it)
            is_disabled = element_classes.downcase.include?('disabled')
            is_hidden = element_classes.downcase.include?('hidden') || element_href.include?('display:none')
            
            puts "   Found #{pattern}: [#{index+1}] <#{tag_name}> '#{element_text}' | Classes: #{element_classes} | Disabled: #{is_disabled} | Hidden: #{is_hidden}"
            
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
      '[class*="load"]', 
      '[class*="more"]', 
      '[id*="load"]', 
      '[id*="more"]',
      '.pagination a',
      '.next',
      '[class*="next"]',  # Added to catch posthaven-archive-next
      '[data-next]',
      '.prev',
      '[class*="prev"]'   # Also added prev for completeness
    ]
    
    elements = []
    pattern_selectors.each do |selector|
      found = @browser.css(selector)  # Get all matching elements, any tag type
      elements.concat(found) if found.any?
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