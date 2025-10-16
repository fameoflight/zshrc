# frozen_string_literal: true

require_relative 'base_service'
require_relative 'llm_service'

# Service for detecting next/more buttons and other elements using LLM analysis
class ElementDetectorService < BaseService
  def initialize(options = {})
    super(options)
    @llm = LLMService.new(options)
  end

  # Check if the service is available (LLM is running)
  def available?
    @llm.available?
  end

  # Find next/more buttons in HTML content using LLM intelligence
  def find_next_buttons(html_content, url_context = nil)
    return [] unless available?

    prompt = build_next_button_prompt(html_content, url_context)
    system_message = "You are an expert web scraping assistant. Analyze HTML content to identify navigation buttons that lead to more content (next, more, load more, etc.). Be precise and confident in your analysis."
    
    log_debug("Sending HTML analysis request to LLM...")
    
    response = @llm.complete(prompt, 
      system: system_message,
      temperature: 0.1,
      max_tokens: 1500
    )
    
    return [] unless response

    parse_button_analysis(response)
  end

  # Analyze specific element to determine if it's a next button
  def analyze_element_context(element_html, surrounding_html = nil, url_context = nil)
    return { is_next_button: false, confidence: 0.0 } unless available?

    prompt = build_element_analysis_prompt(element_html, surrounding_html, url_context)
    system_message = "You are a web element analysis expert. Determine if HTML elements are navigation buttons for content pagination."
    
    log_debug("Analyzing specific element with LLM...")
    
    response = @llm.complete(prompt,
      system: system_message,
      temperature: 0.1,
      max_tokens: 800
    )
    
    return { is_next_button: false, confidence: 0.0 } unless response

    parse_element_analysis(response)
  end

  # Get CSS selector suggestions for better button detection
  def suggest_selectors(page_html, successful_elements = [], failed_elements = [])
    return [] unless available?

    prompt = build_selector_suggestion_prompt(page_html, successful_elements, failed_elements)
    system_message = "You are a CSS selector optimization expert. Suggest reliable selectors for finding navigation buttons on web pages."
    
    log_debug("Requesting CSS selector suggestions from LLM...")
    
    response = @llm.complete(prompt,
      system: system_message,
      temperature: 0.2,
      max_tokens: 1200
    )
    
    return [] unless response

    parse_selector_suggestions(response)
  end

  # Analyze page structure to understand content layout
  def analyze_page_structure(html_content, url_context = nil)
    return {} unless available?

    prompt = build_structure_analysis_prompt(html_content, url_context)
    system_message = "You are a web page structure analyst. Identify content patterns, navigation elements, and page organization."
    
    log_debug("Analyzing page structure with LLM...")
    
    response = @llm.complete(prompt,
      system: system_message,
      temperature: 0.1,
      max_tokens: 1000
    )
    
    return {} unless response

    parse_structure_analysis(response)
  end

  private

  def build_next_button_prompt(html_content, url_context)
    truncated_html = truncate_html_intelligently(html_content, max_length: 8000)
    
    <<~PROMPT
      I need you to analyze this HTML content and identify elements that are likely "next", "more", "load more", or pagination buttons.

      URL Context: #{url_context || 'Unknown'}

      HTML Content:
      #{truncated_html}

      Please identify potential next/more buttons and respond with a JSON array of objects, each containing:
      - "selector": CSS selector to find the element
      - "text": visible text of the element
      - "confidence": confidence score from 0.0 to 1.0
      - "reason": brief explanation of why this is likely a next button
      - "element_type": tag name (a, button, div, etc.)
      - "attributes": object with relevant attributes (class, id, href, etc.)

      Focus on:
      1. Elements with text like "Next", "More", "Load More", "Show More", "Continue", "→", "»"
      2. Elements with classes or IDs containing "next", "more", "load", "pagination"
      3. Elements that appear to be navigation controls
      4. Consider the context - blog pagination, infinite scroll triggers, etc.

      Only include elements with confidence >= 0.3.
      Respond only with valid JSON array.
    PROMPT
  end

  def build_element_analysis_prompt(element_html, surrounding_html, url_context)
    <<~PROMPT
      Analyze this specific HTML element to determine if it's a "next" or "more" button for content navigation.

      URL Context: #{url_context || 'Unknown'}

      Target Element:
      #{element_html}

      #{surrounding_html ? "Surrounding Context:\n#{truncate_html_intelligently(surrounding_html, max_length: 2000)}" : ''}

      Please analyze and respond with JSON containing:
      - "is_next_button": boolean
      - "confidence": score from 0.0 to 1.0
      - "reasons": array of strings explaining your decision
      - "button_type": estimated type ("pagination", "load_more", "infinite_scroll", "archive_navigation", "unknown")
      - "semantic_indicators": array of specific text/class/attribute clues
      - "interaction_method": suggested interaction ("click", "javascript", "form_submit")

      Consider:
      1. Text content and semantic meaning
      2. CSS classes and IDs
      3. Position and context within the page
      4. Common web patterns for navigation
      5. Accessibility attributes (aria-label, role, etc.)

      Respond only with valid JSON object.
    PROMPT
  end

  def build_selector_suggestion_prompt(page_html, successful_elements, failed_elements)
    truncated_html = truncate_html_intelligently(page_html, max_length: 10000)
    
    <<~PROMPT
      Analyze this webpage HTML to suggest better CSS selectors for finding next/more buttons.

      HTML Content:
      #{truncated_html}

      #{successful_elements.any? ? "Previously successful elements:\n#{successful_elements.join("\n")}\n" : ''}
      #{failed_elements.any? ? "Previously failed attempts:\n#{failed_elements.join("\n")}\n" : ''}

      Please suggest CSS selectors that would reliably find next/more/pagination buttons on this page.

      Respond with JSON array of objects containing:
      - "selector": CSS selector string
      - "confidence": confidence score 0.0 to 1.0
      - "description": what this selector targets
      - "specificity": "high", "medium", or "low" - how specific vs generic this selector is
      - "priority": integer 1-10 (higher = try first)
      - "fallback_selectors": array of alternative selectors

      Focus on selectors that:
      1. Are specific to this site's structure
      2. Would work for similar pages on the same domain
      3. Target semantic elements and meaningful class names
      4. Balance specificity with reusability

      Sort by priority (highest first).
      Only include selectors with confidence >= 0.4.
      Respond only with valid JSON array.
    PROMPT
  end

  def build_structure_analysis_prompt(html_content, url_context)
    truncated_html = truncate_html_intelligently(html_content, max_length: 12000)
    
    <<~PROMPT
      Analyze this webpage structure to understand its content organization and navigation patterns.

      URL Context: #{url_context || 'Unknown'}

      HTML Content:
      #{truncated_html}

      Please analyze and respond with JSON containing:
      - "content_type": type of page ("blog", "article_list", "archive", "search_results", "product_catalog", "unknown")
      - "pagination_style": pagination method ("numbered", "next_prev", "infinite_scroll", "load_more", "none")
      - "main_content_areas": array of CSS selectors for primary content
      - "navigation_patterns": array of objects with navigation element info
      - "site_framework": detected framework/CMS ("wordpress", "medium", "ghost", "custom", "unknown")
      - "accessibility_level": "high", "medium", "low" based on semantic HTML usage
      - "recommendations": array of suggestions for better element detection

      Focus on identifying:
      1. How content is organized and structured
      2. Navigation and pagination patterns
      3. Semantic HTML usage
      4. Site-specific patterns and conventions

      Respond only with valid JSON object.
    PROMPT
  end

  def parse_button_analysis(response)
    begin
      json_match = response.match(/\[.*\]/m)
      json_content = json_match ? json_match[0] : response
      
      buttons = JSON.parse(json_content)
      
      valid_buttons = buttons.select do |btn|
        btn.is_a?(Hash) && 
        btn['selector'] && 
        btn['confidence'].is_a?(Numeric) &&
        btn['confidence'] >= 0.3
      end
      
      log_info("LLM identified #{valid_buttons.size} potential next buttons")
      valid_buttons
      
    rescue JSON::ParserError => e
      log_error("Failed to parse LLM button analysis: #{e.message}")
      log_debug("Raw response: #{response[0..500]}...")
      []
    end
  end

  def parse_element_analysis(response)
    begin
      json_match = response.match(/\{.*\}/m)
      json_content = json_match ? json_match[0] : response
      
      analysis = JSON.parse(json_content)
      
      {
        is_next_button: analysis['is_next_button'] || false,
        confidence: (analysis['confidence'] || 0.0).to_f,
        reasons: analysis['reasons'] || [],
        button_type: analysis['button_type'] || 'unknown',
        semantic_indicators: analysis['semantic_indicators'] || [],
        interaction_method: analysis['interaction_method'] || 'click'
      }
      
    rescue JSON::ParserError => e
      log_error("Failed to parse LLM element analysis: #{e.message}")
      log_debug("Raw response: #{response[0..300]}...")
      { is_next_button: false, confidence: 0.0, reasons: [], button_type: 'unknown', semantic_indicators: [], interaction_method: 'click' }
    end
  end

  def parse_selector_suggestions(response)
    begin
      json_match = response.match(/\[.*\]/m)
      json_content = json_match ? json_match[0] : response
      
      suggestions = JSON.parse(json_content)
      
      valid_suggestions = suggestions.select do |sug|
        sug.is_a?(Hash) && 
        sug['selector'] && 
        sug['confidence'].is_a?(Numeric) &&
        sug['confidence'] >= 0.4
      end.sort_by { |s| -(s['priority'] || 0) }
      
      log_info("LLM suggested #{valid_suggestions.size} CSS selectors")
      valid_suggestions
      
    rescue JSON::ParserError => e
      log_error("Failed to parse LLM selector suggestions: #{e.message}")
      log_debug("Raw response: #{response[0..500]}...")
      []
    end
  end

  def parse_structure_analysis(response)
    begin
      json_match = response.match(/\{.*\}/m)
      json_content = json_match ? json_match[0] : response
      
      analysis = JSON.parse(json_content)
      
      {
        content_type: analysis['content_type'] || 'unknown',
        pagination_style: analysis['pagination_style'] || 'none',
        main_content_areas: analysis['main_content_areas'] || [],
        navigation_patterns: analysis['navigation_patterns'] || [],
        site_framework: analysis['site_framework'] || 'unknown',
        accessibility_level: analysis['accessibility_level'] || 'medium',
        recommendations: analysis['recommendations'] || []
      }
      
    rescue JSON::ParserError => e
      log_error("Failed to parse LLM structure analysis: #{e.message}")
      log_debug("Raw response: #{response[0..500]}...")
      {}
    end
  end

  def truncate_html_intelligently(html, max_length: 8000)
    return html if html.length <= max_length
    
    # Take first 60% and last 20% to preserve structure
    first_part_size = (max_length * 0.6).to_i
    last_part_size = (max_length * 0.2).to_i
    
    first_part = html[0, first_part_size]
    last_part = html[-last_part_size, last_part_size]
    
    "#{first_part}\n\n<!-- CONTENT TRUNCATED -->\n\n#{last_part}"
  end

end