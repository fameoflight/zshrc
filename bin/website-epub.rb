#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/services/browser_service'
require_relative '.common/services/page_fetcher'
require_relative '.common/services/epub_generator'
require_relative '.common/concerns/article_detector'

# Website EPUB Creator - Scrape website and extract all URLs
class WebsiteEpub < ScriptBase
  def script_emoji
    '🌐'
  end

  def script_title
    'Website EPUB Creator'
  end

  def script_description
    'Scrapes a website using browser automation and extracts all HTTP/HTTPS URLs'
  end

  def script_arguments
    '<url>'
  end

  def add_custom_options(opts)
    opts.on('--max-clicks COUNT', Integer, 'Maximum read more clicks (default: 5)') do |count|
      @options[:max_clicks] = count
    end

    opts.on('--[no-]headless', 'Run browser in headless mode (default: true)') do |headless|
      @options[:headless] = headless
    end

    opts.on('--timeout SECONDS', Integer, 'Browser timeout in seconds (default: 30)') do |timeout|
      @options[:timeout] = timeout
    end

    opts.on('--wait SECONDS', Integer, 'Wait time for page load (default: 3)') do |wait|
      @options[:wait] = wait
    end

    opts.on('--[no-]javascript', 'Use JavaScript for article fetching (default: false)') do |js|
      @options[:use_javascript] = js
    end

    opts.on('--[no-]cache', 'Enable page caching (default: true)') do |cache|
      @options[:cache_enabled] = cache
    end

    opts.on('--articles-only', 'Only process URLs that are detected as articles') do
      @options[:articles_only] = true
    end

    opts.on('--[no-]create-epub', 'Create EPUB file from detected articles (default: false)') do |create|
      @options[:create_epub] = create
    end

    opts.on('--epub-title TITLE', 'Custom title for the EPUB') do |title|
      @options[:epub_title] = title
    end

    opts.on('--epub-author AUTHOR', 'Custom author for the EPUB') do |author|
      @options[:epub_author] = author
    end

    opts.on('--[no-]save-to-icloud', 'Save EPUB to iCloud Drive (default: true)') do |save|
      @options[:save_to_icloud] = save
    end

    opts.on('--[no-]use-llm', 'Use local LLM for intelligent button detection (default: false)') do |llm|
      @options[:use_llm] = llm
    end
  end

  def default_options
    super.merge({
                  timeout: 30,
                  headless: true,
                  wait: 3,
                  max_clicks: 5,
                  use_javascript: false,
                  cache_enabled: true,
                  articles_only: false,
                  create_epub: false,
                  save_to_icloud: true,
                  use_llm: false
                })
  end

  def validate!
    if @args.empty?
      log_error('Please provide a URL to scrape')
      log_info('Usage: website-epub <url>')
      exit 1
    end

    url = @args.first
    unless url.match?(%r{\Ahttps?://})
      log_error('URL must start with http:// or https://')
      exit 1
    end

    super
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name} https://nav.al                    # Extract all URLs"
    puts "  #{script_name} https://nav.al --articles-only    # Only articles"
    puts "  #{script_name} https://blog.com --javascript     # Use JavaScript for fetching"
    puts "  #{script_name} https://site.com --no-cache       # Disable caching"
    puts "  #{script_name} https://nav.al --max-clicks 10    # More aggressive clicking"
    puts "  #{script_name} https://nav.al --use-llm          # Use AI for smart button detection"
    puts "  #{script_name} https://nav.al --create-epub      # Create EPUB from articles"
    puts "  #{script_name} https://nav.al --create-epub --epub-title 'Naval Essays' # Custom title"
    puts "  #{script_name} https://nav.al --create-epub --no-save-to-icloud # Don't save to iCloud"
    puts "  #{script_name} https://blog.com --use-llm --create-epub # AI detection + EPUB creation"
  end

  def run
    log_banner("#{script_emoji} Website EPUB Creator")

    url = @args.first
    log_info("Target URL: #{url}")
    log_info('Configuration:')
    log_info("  • Max clicks: #{@options[:max_clicks]}")
    log_info("  • JavaScript mode: #{@options[:use_javascript]}")
    log_info("  • Cache enabled: #{@options[:cache_enabled]}")
    log_info("  • Articles only: #{@options[:articles_only]}")
    log_info("  • LLM detection: #{@options[:use_llm]}")

    browser_service = nil
    page_fetcher = nil

    begin
      # Step 1: Collect URLs using browser automation
      browser_service = BrowserService.new(url, @options.merge(logger: self, debug: debug?))
      all_urls = browser_service.collect_urls_with_read_more

      if all_urls.empty?
        log_warning('No URLs found on the webpage')
        return
      end

      # Step 2: Filter to same domain only
      domain = extract_domain(url)
      same_domain_urls = all_urls.select { |url_info| same_domain?(url_info[:url], domain) }

      log_info("Domain filtering: #{all_urls.size} total → #{same_domain_urls.size} same-domain URLs")

      if same_domain_urls.empty?
        log_warning('No same-domain URLs found')
        return
      end

      # Step 3: Article detection (if enabled)
      final_urls = same_domain_urls

      if @options[:articles_only]
        puts "\n🔍 Detecting articles..."

        # Initialize page fetcher for article detection
        page_fetcher = PageFetcher.new(
          cache_enabled: @options[:cache_enabled],
          verbose: verbose?
        )

        # Extract just the URLs for analysis
        url_strings = same_domain_urls.map { |url_info| url_info[:url] }

        # Filter to articles only
        article_urls = ArticleDetector.filter_article_urls(
          url_strings,
          page_fetcher,
          javascript: @options[:use_javascript]
        )

        # Convert back to our URL info format
        final_urls = same_domain_urls.select { |url_info| article_urls.include?(url_info[:url]) }

        log_info("Article detection: #{same_domain_urls.size} URLs → #{final_urls.size} articles")

        if final_urls.empty?
          log_warning('No articles detected in the URLs')
          return
        end

        # Store article URLs for EPUB generation
        @article_urls = article_urls
      end

      # Step 4: Create EPUB if requested
      if @options[:create_epub]
        create_epub_from_urls(final_urls)
      else
        # Step 4: Display results
        display_urls(final_urls)
      end

      if verbose?
        puts "\n"
        show_cache_stats(page_fetcher) if page_fetcher
      end
    rescue StandardError => e
      log_error("Failed to process URLs: #{e.message}")
      log_debug("Backtrace: #{e.backtrace.join("\n")}") if debug?
    ensure
      browser_service&.close
      page_fetcher&.close
      log_info('Cleanup completed')
    end

    show_completion('Website processing')
  end

  private

  def create_epub_from_urls(urls)
    return if urls.empty?

    log_section('📚 Creating EPUB')

    # Initialize EPUB generator
    epub_generator = EPUBGenerator.new({
                                         cache_enabled: @options[:cache_enabled],
                                         javascript: @options[:use_javascript],
                                         save_to_icloud: @options[:save_to_icloud],
                                         verbose: verbose?,
                                         debug: debug?,
                                         logger: self
                                       })

    # Generate EPUB from article URLs
    if @options[:articles_only]
      # Use the already filtered article URLs
      epub_path = epub_generator.generate_epub_from_article_urls(
        @article_urls,
        @options[:epub_title],
        @options[:epub_author]
      )
    else
      # Extract URLs for EPUB generation
      url_strings = urls.map { |url_info| url_info[:url] }
      epub_path = epub_generator.generate_epub_from_urls(
        url_strings,
        @options[:epub_title],
        @options[:epub_author]
      )
    end

    if epub_path
      log_success('EPUB created successfully!')
      log_info("EPUB location: #{epub_path}")

      # Show iCloud location if saved to iCloud
      if @options[:save_to_icloud] && epub_generator.icloud_available?
        domain = extract_domain(@args.first)
        nice_domain = domain.gsub('.', '-') if domain
        log_info("Check your iCloud Drive for the EPUB in: WebsiteEPUB/#{nice_domain}/")
      end
    else
      log_error('Failed to create EPUB')
    end
  end

  def extract_domain(url)
    uri = URI(url)
    uri.host
  rescue URI::InvalidURIError
    nil
  end

  def same_domain?(url, domain)
    return false unless url.start_with?('http')

    begin
      uri = URI(url)
      uri.host == domain || uri.host&.end_with?(".#{domain}")
    rescue URI::InvalidURIError
      false
    end
  end

  def show_cache_stats(page_fetcher)
    return unless page_fetcher

    js_stats = page_fetcher.cache_stats(namespace: 'js')
    no_js_stats = page_fetcher.cache_stats(namespace: 'no_js')

    log_section('💾 Cache Statistics')
    puts "JavaScript pages: #{js_stats[:files]} files (#{js_stats[:total_size_mb]} MB)"
    puts "No-JS pages: #{no_js_stats[:files]} files (#{no_js_stats[:total_size_mb]} MB)"
    puts "Cache directory: #{js_stats[:cache_dir]}"
  end

  def display_urls(urls)
    log_section('📋 Final URLs')

    urls.each_with_index do |entry, index|
      puts "#{index + 1}. #{entry[:url]}"

      next unless verbose?

      puts "   📝 Text: #{entry[:text]}" unless entry[:text] == '[No text]'
      puts "   🏷️  Title: #{entry[:title]}" unless entry[:title].to_s.empty?
      puts
    end

    puts
    log_success("Total: #{urls.size} URLs ready for EPUB")
  end
end

# Execute the script
WebsiteEpub.execute if __FILE__ == $0
