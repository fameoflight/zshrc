# frozen_string_literal: true

require 'net/http'
require 'uri'
require_relative '../concerns/cacheable'

# Page fetching service with JavaScript and non-JavaScript modes plus caching
class PageFetcher
  include Cacheable
  
  attr_reader :browser

  def initialize(options = {})
    @options = default_options.merge(options)
    @browser = nil
    
    # Configure caching
    self.class.configure_cache(
      enabled: @options[:cache_enabled],
      ttl: @options[:cache_ttl]
    )
  end

  def default_options
    {
      cache_enabled: true,
      cache_ttl: 24 * 60 * 60, # 24 hours in seconds
      timeout: 30,
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    }
  end

  def verbose?
    @options[:verbose]
  end

  # Fetch page content (tries cache first, then fetches)
  def fetch_page(url, javascript: false)
    puts "📄 Fetching: #{url}" if verbose?
    
    cache_namespace = javascript ? 'js' : 'no_js'
    
    with_cache("#{url}:#{javascript}", namespace: cache_namespace) do
      puts "💾 Cache miss, fetching..." if verbose?
      javascript ? fetch_with_javascript(url) : fetch_without_javascript(url)
    end
  end

  # Batch fetch multiple URLs with progress bar
  def fetch_pages(urls, javascript: false)
    require 'tty-progressbar'
    
    bar = TTY::ProgressBar.new("📄 [:bar] :percent Fetching pages (:current/:total)", 
                              total: urls.size,
                              width: 20,
                              incomplete: '·',
                              complete: '█')

    results = {}
    urls.each do |url|
      bar.advance(1)
      begin
        results[url] = fetch_page(url, javascript: javascript)
      rescue => e
        puts "\n⚠️  Error fetching #{url}: #{e.message}" if @options[:verbose]
        results[url] = nil
      end
    end

    bar.finish
    puts "\n📊 Successfully fetched: #{results.values.compact.size}/#{urls.size} pages"
    results
  end

  def close
    if @browser
      puts "🔒 Closing browser..." if @options[:verbose]
      @browser.quit
      @browser = nil
    end
  end


  private

  def fetch_with_javascript(url)
    setup_browser unless @browser
    
    begin
      @browser.goto(url)
      
      # Wait for page to load
      sleep(2)
      
      # Check if page is fully loaded
      ready_state = @browser.evaluate("document.readyState")
      if ready_state != 'complete'
        sleep(1) # Wait a bit more
      end
      
      content = @browser.body
      
      # Handle encoding issues for JavaScript content
      content = clean_encoding(content)
      title = clean_encoding(@browser.title)
      
      {
        url: url,
        content: content,
        title: title,
        final_url: @browser.current_url,
        method: 'javascript',
        timestamp: Time.now.to_i,
        content_length: content.length
      }
      
    rescue => e
      puts "❌ JavaScript fetch failed for #{url}: #{e.message}" if @options[:verbose]
      nil
    end
  end

  def fetch_without_javascript(url)
    uri = URI(url)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = @options[:timeout]
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = @options[:user_agent]
    
    begin
      response = http.request(request)
      
      case response
      when Net::HTTPRedirection
        # Handle redirects
        redirect_url = response['location']
        redirect_url = URI.join(url, redirect_url).to_s unless redirect_url.start_with?('http')
        return fetch_without_javascript(redirect_url) if redirect_url != url
      when Net::HTTPSuccess
        content = response.body
        
        # Handle encoding issues - clean up invalid UTF-8 bytes
        content = clean_encoding(content)
        
        # Extract title from HTML
        title_match = content.match(/<title[^>]*>(.*?)<\/title>/mi)
        title = title_match ? clean_encoding(title_match[1].strip) : ''
        
        return {
          url: url,
          content: content,
          title: title,
          final_url: url,
          method: 'no_javascript',
          timestamp: Time.now.to_i,
          content_length: content.length,
          status_code: response.code.to_i
        }
      else
        puts "❌ HTTP #{response.code} for #{url}" if @options[:verbose]
        return nil
      end
      
    rescue => e
      puts "❌ No-JS fetch failed for #{url}: #{e.message}" if @options[:verbose]
      nil
    end
  end

  def setup_browser
    return if @browser
    
    require 'ferrum'
    
    @browser = Ferrum::Browser.new(
      headless: true,
      timeout: @options[:timeout],
      window_size: [1920, 1080],
      browser_options: {
        'no-sandbox' => nil,
        'disable-gpu' => nil,
        'disable-dev-shm-usage' => nil
      }
    )
  end

  # Clean and handle encoding issues in content
  def clean_encoding(content)
    return '' unless content
    
    # Convert to string and handle encoding
    content = content.to_s
    
    # If it's already valid UTF-8, return as-is
    return content if content.encoding == Encoding::UTF_8 && content.valid_encoding?
    
    # Try to clean up encoding issues
    begin
      # First try to encode to UTF-8
      if content.encoding != Encoding::UTF_8
        content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      else
        # If already UTF-8 but invalid, scrub it
        content = content.scrub('?')
      end
      
      # Final validation - if still invalid, force clean
      unless content.valid_encoding?
        content = content.force_encoding('UTF-8').scrub('?')
      end
      
    rescue Encoding::CompatibilityError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      # Fallback: force UTF-8 and scrub
      content = content.force_encoding('UTF-8').scrub('?')
    end
    
    content
  end

end