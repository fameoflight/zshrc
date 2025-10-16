# frozen_string_literal: true

require 'uri'
require 'time'
require 'ferrum'

# URL collection and analysis utility with page loading capabilities
class URLCollector
  attr_reader :urls, :external_urls, :internal_urls, :other_urls, :domain, :browser, :base_url

  def initialize(url, options = {})
    @base_url = url
    @domain = extract_domain(url)
    @options = default_options.merge(options)
    @urls = []
    @external_urls = []
    @internal_urls = []
    @other_urls = []
    @browser = nil
  end

  def default_options
    {
      headless: true,
      timeout: 30,
      wait: 3,
      window_size: [1920, 1080]
    }
  end

  def load_page
    setup_browser unless @browser
    
    puts "🌐 Loading #{@base_url}..."
    @browser.goto(@base_url)
    
    wait_for_page_load
    self
  end

  def collect_urls
    link_elements = @browser.css('a[href]')
    clear_collections

    link_elements.each_with_index do |link, index|
      process_link_element(link, index)
    end

    self
  end

  def collect_and_dedupe_urls
    collect_urls
    
    # Deduplicate by URL
    unique_urls = @urls.uniq { |url_info| url_info[:url] }
    
    # Update collections with all unique URLs
    clear_collections
    unique_urls.each { |url_info| categorize_url(url_info) }
    @urls = unique_urls
    
    puts "📊 Initial URLs found: #{@urls.size}"
    self
  end

  def get_same_domain_urls
    @urls.select { |url_info| same_domain?(url_info[:url]) }
  end

  def reload_and_collect
    collect_and_dedupe_urls
  end

  def merge_urls(other_urls)
    # Merge with existing URLs and deduplicate
    all_urls = (@urls + other_urls).uniq { |url_info| url_info[:url] }
    
    clear_collections
    all_urls.each_with_index { |url_info, index| 
      url_info[:index] = index + 1
      categorize_url(url_info) 
    }
    @urls = all_urls
    
    self
  end

  def get_url
    @browser&.current_url || @base_url
  end

  def close
    if @browser
      puts "   🔒 Closing browser..."
      @browser.quit
      @browser = nil
      puts "   ✅ Browser closed successfully"
    end
  end


  def display_summary
    puts "   📊 URL Summary:"
    puts "      🌐 External URLs: #{@external_urls.size}"
    puts "      🏠 Internal URLs: #{@internal_urls.size}"
    puts "      📎 Other URLs: #{@other_urls.size}"
  end

  def display_all_urls
    display_url_category("🌐 External URLs", @external_urls)
    display_url_category("🏠 Internal/#{@domain.capitalize} URLs", @internal_urls)
    display_url_category("📎 Other URLs", @other_urls) if @other_urls.any?
  end

  def compare_with(other_collector, label = "NEW")
    original_urls = other_collector.urls.map { |u| u[:url] }
    new_urls = @urls.reject { |u| original_urls.include?(u[:url]) }
    
    puts "   📊 #{label} URLs discovered: #{new_urls.size}"
    
    if new_urls.any?
      new_collector = URLCollector.new(@domain)
      new_collector.instance_variable_set(:@urls, new_urls)
      new_urls.each { |url_info| new_collector.send(:categorize_url, url_info) }
      
      new_collector.display_new_urls
    else
      puts "   ⚠️  No completely new URLs found"
      puts "   💡 Total links: #{other_collector.urls.size} → #{@urls.size}"
    end
    
    new_urls
  end

  def display_new_urls
    display_url_category("🌐 NEW External URLs", @external_urls, "➤")
    display_url_category("🏠 NEW Internal/#{@domain.capitalize} URLs", @internal_urls, "➤")
    display_url_category("📎 NEW Other URLs", @other_urls, "➤") if @other_urls.any?
  end

  def find_urls_with_text(pattern)
    @urls.select do |url_info|
      url_info[:full_text].downcase.include?(pattern.downcase) ||
      url_info[:url].downcase.include?(pattern.downcase)
    end
  end

  def same_domain_urls
    @urls.select { |url_info| same_domain?(url_info[:url]) }
  end

  def to_simple_list
    @urls.map { |url_info| { url: url_info[:url], text: url_info[:full_text], title: url_info[:title] } }
  end

  private

  def setup_browser
    puts "📱 Setting up browser..."
    browser_options = {
      headless: @options[:headless],
      timeout: @options[:timeout],
      window_size: @options[:window_size],
      browser_options: {
        'no-sandbox' => nil,
        'disable-gpu' => nil,
        'disable-dev-shm-usage' => nil
      }
    }
    
    @browser = Ferrum::Browser.new(browser_options)
    puts "   ✅ Browser created successfully"
  end

  def wait_for_page_load
    require 'tty-progressbar'
    
    sleep_duration = @options[:wait]
    bar = TTY::ProgressBar.new("⏳ [:bar] :percent Page loading", 
                              total: sleep_duration, 
                              width: 20,
                              incomplete: '·',
                              complete: '█')
    
    sleep_duration.times do |i|
      sleep(1)
      bar.advance(1)
    end
    bar.finish
  end

  def extract_domain(url)
    begin
      uri = URI(url)
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end

  def process_link_element(link, index)
    begin
      href = link.attribute('href')
      text = link.text.strip
      title = link.attribute('title') || ''
      
      if href && !href.empty?
        # Convert relative URLs to absolute
        absolute_url = make_absolute_url(href, @base_url)
        
        url_info = {
          url: absolute_url,
          text: text.length > 50 ? "#{text[0..47]}..." : text,
          title: title,
          index: index + 1,
          full_text: text
        }
        
        @urls << url_info
        categorize_url(url_info)
      end
    rescue => e
      puts "   ⚠️  Error processing link #{index + 1}: #{e.message}"
    end
  end

  def clear_collections
    @urls.clear
    @external_urls.clear
    @internal_urls.clear
    @other_urls.clear
  end

  def make_absolute_url(href, base_url)
    return href if href.start_with?('http')
    
    begin
      URI.join(base_url, href).to_s
    rescue URI::InvalidURIError
      href
    end
  end

  def same_domain?(url)
    return false unless url.start_with?('http')
    
    begin
      uri = URI(url)
      uri.host == @domain || uri.host&.end_with?(".#{@domain}")
    rescue URI::InvalidURIError
      false
    end
  end

  def categorize_url(url_info)
    url = url_info[:url]
    
    if url.start_with?('http') && !same_domain?(url)
      @external_urls << url_info
    elsif same_domain?(url) || url.start_with?('/')
      @internal_urls << url_info
    else
      @other_urls << url_info
    end
  end

  def display_url_category(title, urls, prefix = "")
    return if urls.empty?
    
    puts "   \n   #{title} (#{urls.size}):"
    urls.each do |url_info|
      puts "      #{prefix} #{url_info[:index]}. #{url_info[:url]}"
      puts "         Text: \"#{url_info[:text]}\"" unless url_info[:text].empty?
    end
  end
end