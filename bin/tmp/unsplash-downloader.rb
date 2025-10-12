#!/usr/bin/env ruby

# frozen_string_literal: true

require_relative '../.common/script_base'
require_relative '../.common/services/url_collector'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'digest'

# Optimized Unsplash Image Downloader
# Downloads high-quality images from any Unsplash page with bulk optimization
class UnsplashDownloader < ScriptBase
  # ==============================================================================
  # CONFIGURATION (Adjust these settings as needed)
  # ==============================================================================

  def default_download_dir
    @default_download_dir ||= File.expand_path('~/Downloads/Unsplash Images')
  end

  def default_url
    @default_url ||= 'https://unsplash.com/s/photos/vertical-wallpaper'
  end

  def max_images
    @max_images ||= 100
  end

  def min_width
    @min_width ||= 1080
  end

  def min_height
    @min_height ||= 1920
  end

  def delay_between_downloads
    @delay_between_downloads ||= 1
  end

  def max_retries
    @max_retries ||= 3
  end

  def retry_delay
    @retry_delay ||= 5
  end

  def headless
    @headless ||= true
  end

  def scroll_pause
    @scroll_pause ||= 2
  end

  def max_scroll_attempts
    @max_scroll_attempts ||= 20
  end

  def parallel_downloads
    @parallel_downloads ||= 3
  end

  def image_quality
    @image_quality ||= 'high'  # 'high', 'medium', 'low'
  end

  def min_file_size
    @min_file_size ||= 100 * 1024  # 100KB in bytes
  end

  # ==============================================================================
  # SCRIPT METADATA
  # ==============================================================================

  def script_emoji
    '📸'
  end

  def script_title
    'Unsplash Downloader'
  end

  def script_description
    'Optimized bulk downloader for high-quality images from any Unsplash page'
  end

  def script_arguments
    '[URL] [OPTIONS]'
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                                          # Download from default vertical wallpapers"
    puts "  #{script_name} https://unsplash.com/s/photos/nature     # Download nature photos"
    puts "  #{script_name} https://unsplash.com/collections/12345   # Download from collection"
    puts "  #{script_name} --max-images 50 --quality high           # Download 50 high quality images"
    puts "  #{script_name} --parallel 5 --delay 0.5                 # Faster parallel downloads"
    puts "  #{script_name} --download-dir ~/Pictures/Wallpapers     # Custom download directory"
    puts "  #{script_name} --min-file-size 500KB                    # Skip images smaller than 500KB"
    puts "  #{script_name} --min-file-size 0                        # No file size limit"
  end

  # ==============================================================================
  # CUSTOM OPTIONS
  # ==============================================================================

  def add_custom_options(opts)
    opts.on('-u', '--url URL', "Unsplash URL to download from (default: #{default_url})") do |url|
      @target_url = url
    end

    opts.on('--max-images NUM', Integer, "Maximum number of images to download (default: #{max_images})") do |num|
      @max_images = num
    end

    opts.on('--download-dir PATH', "Download directory (default: #{default_download_dir})") do |path|
      @download_dir = File.expand_path(path)
    end

    opts.on('--min-width NUM', Integer, "Minimum image width (default: #{min_width})") do |num|
      @min_width = num
    end

    opts.on('--min-height NUM', Integer, "Minimum image height (default: #{min_height})") do |num|
      @min_height = num
    end

    opts.on('--delay SECONDS', Float, "Delay between downloads (default: #{delay_between_downloads})") do |num|
      @delay_between_downloads = num
    end

    opts.on('--parallel NUM', Integer, "Parallel download threads (default: #{parallel_downloads})") do |num|
      @parallel_downloads = num
    end

    opts.on('--quality LEVEL', ['high', 'medium', 'low'], "Image quality: high, medium, low (default: #{image_quality})") do |level|
      @image_quality = level
    end

    opts.on('--max-retries NUM', Integer, "Maximum retry attempts (default: #{max_retries})") do |num|
      @max_retries = num
    end

    opts.on('--retry-delay SECONDS', Integer, "Delay between retries (default: #{retry_delay})") do |num|
      @retry_delay = num
    end

    opts.on('--no-headless', 'Run browser in non-headless mode') do
      @headless = false
    end

    opts.on('--vertical-only', 'Download only vertical images') do
      @vertical_only = true
    end

    opts.on('--no-filter', 'Download all images regardless of dimensions') do
      @no_filter = true
    end

    opts.on('--min-file-size SIZE', String, "Minimum file size (e.g., 100KB, 1MB, 0 for no limit) (default: 100KB)") do |size|
      @min_file_size = parse_file_size(size)
    end
  end

  # ==============================================================================
  # VALIDATION
  # ==============================================================================

  def validate!
    super

    # Extract URL from args or use default
    @target_url = args.empty? ? default_url : args.first

    # Validate URL
    unless valid_unsplash_url?(@target_url)
      log_error "Invalid Unsplash URL: #{@target_url}"
      log_error "URL must be from unsplash.com"
      exit 1
    end

    # Validate numeric parameters
    if max_images <= 0
      log_error 'max-images must be a positive number'
      exit 1
    end

    if min_width <= 0 || min_height <= 0
      log_error 'min-width and min-height must be positive numbers'
      exit 1
    end

    if delay_between_downloads < 0
      log_error 'delay must be a non-negative number'
      exit 1
    end

    if parallel_downloads < 1 || parallel_downloads > 10
      log_error 'parallel must be between 1 and 10'
      exit 1
    end

    log_debug "URL validated: #{@target_url}"
  end

  # ==============================================================================
  # MAIN EXECUTION
  # ==============================================================================

  def run
    log_banner(script_title)

    check_dependencies
    setup_download_directory
    show_configuration

    log_section 'Scraping Process'
    log_info "Extracting image URLs from #{@target_url}..."

    image_urls = scrape_image_urls

    if image_urls.empty?
      log_warning 'No images found on the page'
      return
    end

    log_success "Found #{image_urls.length} images"

    log_section 'Download Process'
    downloaded_count = download_images(image_urls)

    show_completion(script_title)
    log_info "Successfully downloaded #{downloaded_count} images to: #{download_dir}"
  end

  private

  # ==============================================================================
  # URL VALIDATION
  # ==============================================================================

  def valid_unsplash_url?(url)
    return false unless url
    uri = URI.parse(url)
    (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)) && uri.host.include?('unsplash.com')
  rescue URI::InvalidURIError
    false
  end

  def target_url
    @target_url || default_url
  end

  def download_dir
    @download_dir || default_download_dir
  end

  # ==============================================================================
  # DEPENDENCY CHECKING
  # ==============================================================================

  def check_dependencies
    log_info 'Checking dependencies...'

    # Check for required gems (Ferrum should be available via Gemfile)
    begin
      require 'ferrum'
      log_success 'Ferrum browser automation found'
    rescue LoadError => e
      log_error "Ferrum not available: #{e.message}"
      log_error 'Please ensure Ferrum is installed in the Gemfile'
      exit 1
    end

    log_success 'All dependencies found'
  end

  # ==============================================================================
  # DIRECTORY SETUP
  # ==============================================================================

  def setup_download_directory
    log_info "Creating download directory: #{download_dir}"

    unless Dir.exist?(download_dir)
      FileUtils.mkdir_p(download_dir)
      log_success 'Download directory created'
    else
      log_info 'Download directory already exists'
    end
  end

  # ==============================================================================
  # CONFIGURATION DISPLAY
  # ==============================================================================

  def show_configuration
    log_section 'Configuration'
    log_info "Source URL: #{target_url}"
    log_info "Download Directory: #{download_dir}"
    log_info "Maximum Images: #{max_images}"
    log_info "Image Quality: #{image_quality}"
    log_info "Minimum Dimensions: #{min_width}x#{min_height}" unless @no_filter
    log_info "Minimum File Size: #{format_bytes(min_file_size)}" if min_file_size > 0
    log_info "Delay Between Downloads: #{delay_between_downloads}s"
    log_info "Parallel Downloads: #{parallel_downloads}"
    log_info "Max Retries: #{max_retries}"
    log_info "Headless Mode: #{headless ? 'Yes' : 'No'}"
  end

  # ==============================================================================
  # IMAGE SCRAPING
  # ==============================================================================

  def scrape_image_urls
    log_info 'Starting optimized browser scraper using Ferrum...'

    # Use the existing URLCollector which handles Ferrum setup
    @url_collector = URLCollector.new(target_url, {
      headless: headless,
      timeout: 30,
      wait: 3,
      window_size: [1920, 1080]
    })

    begin
      image_urls = []
      scroll_attempts = 0
      no_new_urls_count = 0

      log_info "Loading #{target_url}..."
      @url_collector.load_page

      while image_urls.length < max_images && scroll_attempts < max_scroll_attempts
        log_progress "Found #{image_urls.length} images so far... (scroll #{scroll_attempts + 1})"

        # Wait a bit for content to load (reduced for faster response)
        sleep 0.5

        # Find all image elements with different selectors
        new_urls = []

        # Try multiple selectors to find images
        selectors = [
          'img[src*="unsplash"]',
          'img[data-src*="unsplash"]',
          'img[srcset*="unsplash"]',
          'figure img',
          'a[href*="/photos/"] img',
          'div[data-test="photo-grid-item"] img',
          'div[itemprop="contentUrl"] img'
        ]

        if debug?
          log_debug "Trying #{selectors.length} selectors to find images"
        end

        selectors.each do |selector|
          begin
            elements = @url_collector.browser.css(selector)
            elements.each do |img|
              url = extract_optimized_image_url(img)
              if url && !image_urls.include?(url)
                new_urls << url
                if debug?
                  log_debug "Found image: #{url[0..80]}..."
                end
              end
            end
          rescue StandardError => e
            log_debug "Error with selector #{selector}: #{e.message}"
          end
        end

        # Add new URLs to our collection
        image_urls.concat(new_urls)
        image_urls.uniq!

        # Check if we found new URLs
        if new_urls.empty?
          no_new_urls_count += 1
          log_debug "No new URLs found (attempt #{no_new_urls_count})"

          # Try Load More button FIRST (after just 2 attempts)
          if no_new_urls_count == 2
            log_debug "Trying to click load more button if exists"

            # Try multiple selectors for load more buttons
            button_selectors = [
              'button[class*="loadMore"]',
              'button:contains("Load more")',
              'button:contains("load more")',
              'button:contains("More")',
              'button:contains("Show more")',
              'button:contains("show more")',
              'a[class*="loadMore"]',
              'a:contains("Load more")',
              'a:contains("Show more")',
              'div[class*="load"] button',
              'div[data-test*="load"] button',
              'button[type="button"]',  # Generic buttons
              'button',                 # Any button
              'a'                       # Any link
            ]

            button_found = false
            button_selectors.each do |selector|
              begin
                elements = @url_collector.browser.css(selector)
                elements.each do |element|
                  text = element.text.strip rescue ''
                  class_name = element.attribute('class') || ''
                  onclick = element.attribute('onclick') || ''

                  # Check for load more indicators
                  if text.downcase.include?('load') || text.downcase.include?('more') || text.downcase.include?('show') ||
                     class_name.include?('loadMore') || class_name.include?('load-more') ||
                     class_name.include?('showMore') || class_name.include?('show-more') ||
                     onclick.include?('load') || onclick.include?('more')

                    log_debug "Found load more button: #{text} (#{class_name})"
                    element.click
                    sleep 2 # Wait for content to load after clicking
                    button_found = true
                    break
                  end
                end
                break if button_found
              rescue StandardError => e
                log_debug "Error with selector #{selector}: #{e.message}"
              end
            end

            if button_found
              log_debug "Load more button clicked, waiting for content..."
              no_new_urls_count = 0 # Reset counter after clicking
            else
              log_debug "No load more button found"
            end
          elsif no_new_urls_count == 4
            log_debug "Trying scroll to bottom"
            @url_collector.browser.evaluate('window.scrollTo(0, document.body.scrollHeight);')
          elsif no_new_urls_count == 6
            log_debug "Trying incremental scroll"
            @url_collector.browser.evaluate('window.scrollBy(0, 1500);')
          elsif no_new_urls_count == 8
            log_debug "Trying fast scroll to top then bottom"
            @url_collector.browser.evaluate('window.scrollTo(0, 0);')
            sleep 1
            @url_collector.browser.evaluate('window.scrollTo(0, document.body.scrollHeight);')
          elsif no_new_urls_count == 10
            log_debug "Trying multiple rapid scrolls"
            3.times do
              @url_collector.browser.evaluate('window.scrollBy(0, 800);')
              sleep 0.5
            end
          end
        else
          no_new_urls_count = 0
        end

        # Stop if we have enough images
        break if image_urls.length >= max_images

        # Scroll down to load more images
        @url_collector.browser.evaluate('window.scrollTo(0, document.body.scrollHeight);')
        sleep scroll_pause
        scroll_attempts += 1

        # Break if we haven't found new images in many attempts (increased threshold)
        break if no_new_urls_count >= 15
      end

      log_success "Scraping completed! Found #{image_urls.length} unique image URLs"
      image_urls.first(max_images)

    ensure
      @url_collector.close
    end
  end

  def extract_optimized_image_url(img_element)
    # Try different attributes that might contain the image URL
    ['src', 'data-src', 'srcset'].each do |attr|
      url = img_element.attribute(attr) rescue nil
      next unless url

      # Handle srcset (multiple URLs with sizes)
      if attr == 'srcset'
        # Extract the highest quality URL from srcset
        urls = url.split(',').map { |u| u.strip.split(' ').first }
        url = urls.last # Usually the highest quality
      end

      # Skip placeholder, thumbnail, and profile images
      next if url.include?('placeholder') || url.include?('blur') || url.include?('thumb') || url.include?('profile')

      # Convert to high resolution based on quality setting
      case image_quality
      when 'high'
        if url.include?('w=') && url.include?('q=')
          url = url.gsub(/w=\d+/, 'w=3840')
          url = url.gsub(/q=\d+/, 'q=100')
        end
        url = url.gsub('/fit=crop', '/w=3840')
      when 'medium'
        if url.include?('w=') && url.include?('q=')
          url = url.gsub(/w=\d+/, 'w=1920')
          url = url.gsub(/q=\d+/, 'q=85')
        end
        url = url.gsub('/fit=crop', '/w=1920')
      when 'low'
        if url.include?('w=') && url.include?('q=')
          url = url.gsub(/w=\d+/, 'w=1080')
          url = url.gsub(/q=\d+/, 'q=70')
        end
        url = url.gsub('/fit=crop', '/w=1080')
      end

      return url
    end
    nil
  end

  # ==============================================================================
  # IMAGE DOWNLOADING
  # ==============================================================================

  def download_images(image_urls)
    downloaded_count = 0
    failed_count = 0

    if parallel_downloads > 1
      log_info "Starting parallel downloads with #{parallel_downloads} threads..."
      downloaded_count = download_images_parallel(image_urls)
    else
      log_info "Starting sequential downloads..."
      image_urls.each_with_index do |url, index|
        if download_single_image(url, index + 1, image_urls.length)
          downloaded_count += 1
        else
          failed_count += 1
        end

        # Add delay between downloads
        sleep delay_between_downloads if delay_between_downloads > 0 && index < image_urls.length - 1
      end
    end

    log_success "Download completed: #{downloaded_count} successful, #{failed_count} failed"
    downloaded_count
  end

  def download_images_parallel(image_urls)
    require 'thread'

    downloaded_count = 0
    mutex = Mutex.new
    work_queue = Queue.new

    # Add all URLs to the queue
    image_urls.each_with_index { |url, index| work_queue << [url, index + 1] }

    # Create worker threads
    threads = Array.new(parallel_downloads) do |thread_id|
      Thread.new do
        while !work_queue.empty?
          begin
            url, index = work_queue.pop(true)
            if download_single_image(url, index, image_urls.length)
              mutex.synchronize { downloaded_count += 1 }
            end
          rescue ThreadError
            # Queue is empty
            break
          rescue StandardError => e
            log_debug "Thread #{thread_id} error: #{e.message}"
          end
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    downloaded_count
  end

  def download_single_image(url, index, total)
    # Generate filename based on URL and index
    filename = generate_filename(url, index)
    filepath = File.join(download_dir, filename)

    # Skip if file already exists
    if File.exist?(filepath)
      log_debug "[#{index}/#{total}] Skipping existing file: #{filename}"
      return true
    end

    # Download with retry logic
    (1..max_retries).each do |attempt|
      if attempt_image_download(url, filepath, index, total, attempt)
        return true
      elsif attempt < max_retries
        log_warning "[#{index}/#{total}] Retry #{attempt}/#{max_retries} for #{filename} (URL: #{truncate_url(url)})"
        sleep retry_delay
      end
    end

    log_error "[#{index}/#{total}] Failed to download #{filename} after #{max_retries} attempts"
    log_error "[#{index}/#{total}] URL: #{truncate_url(url)}"
    false
  end

  def attempt_image_download(url, filepath, index, total, attempt)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    request['Referer'] = target_url

    response = http.request(request)

    if response.code == '200'
      image_data = response.body

      # Basic image validation - check if it's actually an image
      unless valid_image?(image_data)
        log_debug "[#{index}/#{total}] Invalid image data, skipping"
        return false
      end

      # Check file size if minimum is set
      if min_file_size > 0 && image_data.bytesize < min_file_size
        log_debug "[#{index}/#{total}] Skipping small file: #{format_bytes(image_data.bytesize)} < #{format_bytes(min_file_size)}"
        return false
      end

      # Validate image dimensions if filtering is enabled
      unless @no_filter
        # Check dimensions using FastImage if available
        begin
          require 'fastimage'
          width, height = FastImage.size(StringIO.new(image_data))

          if width && height
            # Skip if dimensions don't meet requirements
            if @vertical_only && height <= width
              log_debug "[#{index}/#{total}] Skipping non-vertical image: #{width}x#{height}"
              return false
            end

            if width < min_width || height < min_height
              log_debug "[#{index}/#{total}] Skipping small image: #{width}x#{height}"
              return false
            end
          end
        rescue LoadError
          log_debug "FastImage not available, skipping dimension check"
        rescue StandardError => e
          log_debug "Error checking image dimensions: #{e.message}"
        end
      end

      # Write the file
      File.open(filepath, 'wb') { |file| file.write(image_data) }

      file_size = File.size(filepath)
      if file_size > 0
        log_success "[#{index}/#{total}] Downloaded #{File.basename(filepath)} (#{format_bytes(file_size)})"
        return true
      else
        log_debug "[#{index}/#{total}] Empty file, deleting"
        File.delete(filepath) if File.exist?(filepath)
        return false
      end
    else
      log_debug "[#{index}/#{total}] HTTP #{response.code} error for #{truncate_url(url)}"
      return false
    end
  rescue StandardError => e
    log_debug "[#{index}/#{total}] Download error (attempt #{attempt}): #{e.message}"
    log_debug "[#{index}/#{total}] URL: #{truncate_url(url)}" if debug?
    false
  end

  def valid_image?(data)
    # Check common image signatures
    jpeg_sig = [0xFF, 0xD8, 0xFF].pack('C*')
    png_sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack('C*')
    gif87a_sig = 'GIF87a'.b
    gif89a_sig = 'GIF89a'.b
    webp_sig = 'RIFF'.b
    jxl_sig = [0x00, 0x00, 0x00, 0x0C, 0x4A, 0x58, 0x4C, 0x20].pack('C*')

    signatures = [jpeg_sig, png_sig, gif87a_sig, gif89a_sig, webp_sig, jxl_sig]

    signatures.any? { |sig| data.start_with?(sig) }
  end

  def parse_file_size(size_str)
    return 0 if size_str.to_i == 0  # 0 means no limit

    # Parse file size strings like "100KB", "1MB", "2GB"
    if match = size_str.match(/^(\d+(?:\.\d+)?)\s*(KB|MB|GB)?$/i)
      size = match[1].to_f
      unit = match[2]&.upcase || 'B'

      case unit
      when 'KB'
        (size * 1024).to_i
      when 'MB'
        (size * 1024 * 1024).to_i
      when 'GB'
        (size * 1024 * 1024 * 1024).to_i
      else
        size.to_i
      end
    else
      log_error "Invalid file size format: #{size_str}. Use format like '100KB', '1MB', etc."
      exit 1
    end
  end

  def truncate_url(url, max_length = 100)
    if url.length <= max_length
      url
    else
      "#{url[0..max_length-3]}..."
    end
  end

  def generate_filename(url, index)
    # Extract photo ID from URL if possible
    if match = url.match(/unsplash\.com\/photos\/([a-zA-Z0-9]+)/)
      photo_id = match[1]
    else
      # Generate ID from URL hash
      photo_id = Digest::MD5.hexdigest(url)[0..8]
    end

    # Determine file extension from URL
    extension = if url.include?('.jpg') || url.include?('.jpeg')
                  'jpg'
                elsif url.include?('.png')
                  'png'
                elsif url.include?('.webp')
                  'webp'
                else
                  'jpg'  # Default to jpg
                end

    "unsplash_#{index.to_s.rjust(4, '0')}_#{photo_id}.#{extension}"
  end

  def format_bytes(bytes)
    units = ['B', 'KB', 'MB', 'GB']
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end
end

# Execute the script
UnsplashDownloader.execute if __FILE__ == $0