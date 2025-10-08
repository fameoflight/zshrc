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
      parallel_enabled: true,
      timeout: 30,
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    }
  end

  def verbose?
    @options[:verbose]
  end

  # Fetch page content (tries cache first, then fetches)
  def fetch_page(url, javascript: false)
    puts "📄 Fetching: #{url} (JS: #{javascript})" if verbose?

    cache_namespace = javascript ? 'js' : 'no_js'
    cache_key = "#{url}:#{javascript}"

    if verbose?
      puts "📂 Cache namespace: #{cache_namespace}"
      puts "🔑 Cache key: #{cache_key}"
    end

    with_cache(cache_key, namespace: cache_namespace) do
      puts "💾 Cache miss, fetching..." if verbose?
      javascript ? fetch_with_javascript(url) : fetch_without_javascript(url)
    end
  end

  # Batch fetch multiple URLs with progress bar
  def fetch_pages(urls, javascript: false)
    require 'tty-progressbar'

    # Use parallel processing for non-JavaScript mode with multiple domains
    if !javascript && can_use_parallel_processing?(urls)
      fetch_pages_parallel(urls, javascript: javascript)
    else
      fetch_pages_sequential(urls, javascript: javascript)
    end
  end

  # Check if we can use parallel processing
  def can_use_parallel_processing?(urls)
    return false unless @options[:parallel_enabled]
    return false if urls.size < 2

    # Count distinct domains
    domains = urls.map { |url| extract_domain(url) }.compact.uniq
    domains.size > 1
  end

  # Extract domain from URL for parallel processing logic
  def extract_domain(url)
    begin
      uri = URI(url)
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end

  # Sequential fetch (original implementation)
  def fetch_pages_sequential(urls, javascript: false)
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

  # Parallel fetch using threads for different domains
  def fetch_pages_parallel(urls, javascript: false)
    require 'tty-progressbar'
    require 'thread'

    # Group URLs by domain
    domain_groups = urls.group_by { |url| extract_domain(url) || 'unknown' }

    puts "🚀 Processing #{domain_groups.size} domains in parallel..." if @options[:verbose]

    # Create shared results hash and mutex for thread safety
    results = {}
    results_mutex = Mutex.new
    completed_count = 0
    completed_mutex = Mutex.new

    # Create progress bar
    bar = TTY::ProgressBar.new("📄 [:bar] :percent Fetching pages (:current/:total)",
                              total: urls.size,
                              width: 20,
                              incomplete: '·',
                              complete: '█')

    # Create thread pool (one thread per domain)
    threads = []

    domain_groups.each do |domain, domain_urls|
      threads << Thread.new do
        begin
          # Process all URLs from this domain sequentially
          domain_urls.each do |url|
            begin
              page_data = fetch_page(url, javascript: javascript)

              # Store result safely
              results_mutex.synchronize do
                results[url] = page_data
              end

            rescue => e
              puts "\n⚠️  Error fetching #{url}: #{e.message}" if @options[:verbose]
              results_mutex.synchronize do
                results[url] = nil
              end
            end

            # Update progress safely
            completed_mutex.synchronize do
              completed_count += 1
              bar.advance(1)
            end
          end
        rescue => e
          puts "\n❌ Thread error for domain #{domain}: #{e.message}" if @options[:verbose]
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    bar.finish
    puts "\n📊 Successfully fetched: #{results.values.compact.size}/#{urls.size} pages"
    puts "⚡ Parallel processing completed for #{domain_groups.size} domains" if @options[:verbose]

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

      # Wait for page to load - increased wait time for complex sites
      sleep(3)

      # Check if page is fully loaded
      ready_state = @browser.evaluate("document.readyState")
      if ready_state != 'complete'
        puts "⏳ Waiting for page to fully load..." if verbose?
        sleep(2) # Wait a bit more for complex sites
      end

      # Wait for dynamic content to load (JavaScript-heavy sites)
      begin
        # Wait up to 10 seconds for content to appear
        wait_start = Time.now
        while (Time.now - wait_start) < 10
          # Check if there's meaningful content (not just loading messages)
          body_text = @browser.evaluate("document.body.innerText")
          if body_text && body_text.length > 100 && !body_text.include?('JavaScript') && !body_text.include?('loading')
            break
          end
          sleep(0.5)
        end
      rescue => e
        puts "⚠️  Content wait check failed: #{e.message}" if verbose?
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
      timeout: @options[:timeout] || 60,  # Increased timeout for JavaScript-heavy sites
      window_size: [1920, 1080],
      browser_options: {
        'no-sandbox' => nil,
        'disable-gpu' => nil,
        'disable-dev-shm-usage' => nil,
        'disable-web-security' => nil,  # Allow cross-origin requests for complex sites
        'disable-features' => 'VizDisplayCompositor'  # Reduce memory usage
      },
      # Ignore certificate errors for HTTPS sites
      ignore_default_options: false,
      process_timeout: 120  # Increased process timeout
    )

    # Set user agent to appear more like a real browser
    @browser.headers.set({
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    })
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