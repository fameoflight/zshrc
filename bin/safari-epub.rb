#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/services/epub_generator'
require 'rexml/document'
require 'fileutils'
require 'tmpdir'

# Safari Reading List to EPUB Converter
# Extracts URLs from Safari's reading list and converts them to EPUB format
class SafariEpub < ScriptBase
  BOOKMARKS_PLIST = '~/Library/Safari/Bookmarks.plist'

  def script_emoji
    '🧭'
  end

  def script_title
    'Safari Reading List to EPUB'
  end

  def script_description
    'Converts Safari reading list items to EPUB format for offline reading'
  end

  def script_arguments
    '[OPTIONS]'
  end

  def add_custom_options(opts)
    opts.on('--epub-title TITLE', 'Custom title for the EPUB (default: "Safari Reading List")') do |title|
      @options[:epub_title] = title
    end

    opts.on('--epub-author AUTHOR', 'Custom author for the EPUB (default: "Safari Reader")') do |author|
      @options[:epub_author] = author
    end

    opts.on('--[no-]save-to-icloud', 'Save EPUB to iCloud Drive (default: true)') do |save|
      @options[:save_to_icloud] = save
    end

    opts.on('--[no-]javascript', 'Use JavaScript for article fetching (default: false)') do |js|
      @options[:use_javascript] = js
    end

    opts.on('--[no-]download-images', 'Download and embed images in EPUB (default: true)') do |download|
      @options[:download_images] = download
    end

    opts.on('--max-image-size SIZE', Integer, 'Maximum image size in bytes (default: 5MB)') do |size|
      @options[:max_image_size] = size
    end

    opts.on('--[no-]cache', 'Enable page caching (default: true)') do |cache|
      @options[:cache_enabled] = cache
    end

    opts.on('--max-articles COUNT', Integer, 'Maximum articles to process (default: 33)') do |count|
      @options[:max_articles] = count
    end

    opts.on('--[no-]parallel', 'Enable parallel downloads for different domains (default: true)') do |parallel|
      @options[:parallel_enabled] = parallel
    end

    opts.on('--[no-]delete-after', 'Delete articles from reading list after EPUB creation (default: false)') do |delete|
      @options[:delete_after] = delete
    end

    opts.on('--cache-stats', 'Show cache statistics and exit') do
      @options[:cache_stats] = true
    end

    opts.on('--clear-cache', 'Clear all cache and exit') do
      @options[:clear_cache] = true
    end

    opts.on('--list-only', 'Only list reading list URLs without creating EPUB') do
      @options[:list_only] = true
    end
  end

  def default_options
    super.merge({
                  epub_title: generate_default_title,
                  epub_author: 'Safari Reader',
                  save_to_icloud: true,
                  use_javascript: false,
                  download_images: true,
                  max_image_size: 5 * 1024 * 1024, # 5MB
                  cache_enabled: true,
                  max_articles: 33,
                  parallel_enabled: true,
                  delete_after: false,
                  list_only: false
                })
  end

  def validate!
    bookmarks_file = File.expand_path(BOOKMARKS_PLIST)
    unless File.exist?(bookmarks_file)
      log_error("Safari bookmarks file not found at: #{bookmarks_file}")
      log_info('Make sure Safari is installed and has been used to add reading list items')
      exit 1
    end

    super
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name}                              # Convert all reading list items to EPUB"
    puts "  #{script_name} --list-only                  # Just show reading list URLs"
    puts "  #{script_name} --epub-title 'My Articles'   # Custom EPUB title"
    puts "  #{script_name} --max-articles 50            # Limit to 50 articles (default: 33)"
    puts "  #{script_name} --force                      # Force fresh download (clears all cache)"
    puts "  #{script_name} --delete-after               # Delete articles after EPUB creation"
    puts "  #{script_name} --javascript                 # Use JavaScript for better content extraction"
    puts "  #{script_name} --no-download-images         # Skip downloading images (smaller EPUB size)"
    puts "  #{script_name} --max-image-size 1048576     # Limit images to 1MB each"
    puts "  #{script_name} --no-parallel                # Disable parallel downloads (slower but safer)"
    puts "  #{script_name} --no-save-to-icloud          # Save locally instead of iCloud"
    puts "  #{script_name} --no-cache                   # Disable caching"
    puts "  #{script_name} --cache-stats                # Show cache statistics for both modes"
    puts "  #{script_name} --clear-cache                # Clear all cached pages"
    puts ""
    puts "Note: Default EPUB title is 'Readings {Current Date}' (e.g., 'Readings May 12, 2025')"
    puts "Note: JavaScript and non-JavaScript modes use separate caches"
    puts "Note: Images are downloaded and embedded by default (max 5MB each)"
    puts "Note: Use --force to clear all cache and ensure fresh content downloads"
  end

  def run
    log_banner("#{script_emoji} Safari Reading List to EPUB")

    # Handle cache operations first
    if @options[:cache_stats]
      show_cache_stats
      return
    end

    if @options[:clear_cache]
      clear_cache
      return
    end

    # Extract reading list URLs
    reading_list_urls = extract_reading_list_urls

    if reading_list_urls.empty?
      log_warning('No items found in Safari reading list')
      log_info('Add some articles to your Safari reading list and try again')
      return
    end

    log_info("Found #{reading_list_urls.length} items in reading list")

    # Apply max articles limit if specified
    if @options[:max_articles] && reading_list_urls.length > @options[:max_articles]
      reading_list_urls = reading_list_urls.first(@options[:max_articles])
      log_info("Limited to first #{@options[:max_articles]} articles")
    end

    if @options[:list_only]
      display_reading_list(reading_list_urls)
    else
      create_epub_from_reading_list(reading_list_urls)
    end

    show_completion('Safari reading list processing')
  end

  private

  def show_cache_stats
    require_relative '.common/services/page_fetcher'

    log_section('📊 Cache Statistics')

    # Create a temporary PageFetcher to access cache stats
    fetcher = PageFetcher.new(verbose: true)

    # Show stats for both namespaces
    js_stats = fetcher.cache_stats(namespace: 'js')
    no_js_stats = fetcher.cache_stats(namespace: 'no_js')

    puts "JavaScript Mode Cache:"
    if js_stats[:enabled]
      puts "  Files: #{js_stats[:files]}"
      puts "  Size: #{js_stats[:total_size_mb]} MB"
      puts "  Directory: #{js_stats[:cache_dir]}"
    else
      puts "  Disabled"
    end

    puts ""
    puts "Non-JavaScript Mode Cache:"
    if no_js_stats[:enabled]
      puts "  Files: #{no_js_stats[:files]}"
      puts "  Size: #{no_js_stats[:total_size_mb]} MB"
      puts "  Directory: #{no_js_stats[:cache_dir]}"
    else
      puts "  Disabled"
    end

    puts ""
    log_success("Cache statistics displayed")
  end

  def clear_cache
    require_relative '.common/services/page_fetcher'

    log_section('🧹 Clearing Cache')

    # Create a temporary PageFetcher to access cache clearing
    fetcher = PageFetcher.new(verbose: true)

    # Clear both namespaces
    puts "Clearing JavaScript cache..."
    fetcher.cache_clear(namespace: 'js')

    puts "Clearing Non-JavaScript cache..."
    fetcher.cache_clear(namespace: 'no_js')

    log_success("All cache cleared")
  end

  def generate_default_title
    "Readings #{Date.today.strftime('%b %d, %Y')}"
  end

  def extract_reading_list_urls
    bookmarks_file = File.expand_path(BOOKMARKS_PLIST)

    log_info("Reading Safari bookmarks from: #{bookmarks_file}")

    # Create a temporary copy and convert to XML format
    temp_file = nil

    begin
      temp_file = create_temp_plist_copy(bookmarks_file)

      # Convert binary plist to XML
      convert_result = system('plutil', '-convert', 'xml1', temp_file)
      unless convert_result
        log_error("Failed to convert bookmarks plist to XML format")
        return []
      end

      # Parse the XML plist
      parse_reading_list_from_xml(temp_file)
    rescue StandardError => e
      log_error("Failed to extract reading list: #{e.message}")
      log_debug("Backtrace: #{e.backtrace.join("\n")}") if debug?
      []
    ensure
      File.unlink(temp_file) if temp_file && File.exist?(temp_file)
    end
  end

  def create_temp_plist_copy(source_file)
    temp_dir = Dir.mktmpdir('safari_epub_')
    temp_file = File.join(temp_dir, 'Bookmarks.plist')

    FileUtils.cp(source_file, temp_file)

    # Register cleanup
    at_exit { FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir) }

    temp_file
  end

  def parse_reading_list_from_xml(xml_file)
    log_progress("Parsing reading list from Safari bookmarks")

    doc = REXML::Document.new(File.read(xml_file))

    # Navigate through the plist structure to find reading list
    dict = doc.elements['plist/dict']
    return [] unless dict

    children_array = find_children_array(dict)
    return [] unless children_array

    # Find the reading list entry
    reading_list_dict = find_reading_list_dict(children_array)
    return [] unless reading_list_dict

    # Extract URLs from reading list children
    extract_urls_from_reading_list(reading_list_dict)
  end

  def find_children_array(dict)
    # Look for the "Children" key in the top-level dictionary
    dict.elements.each do |element|
      if element.name == 'key' && element.text == 'Children'
        # The next sibling should be the array
        next_element = element.next_element
        return next_element if next_element&.name == 'array'
      end
    end
    nil
  end

  def find_reading_list_dict(children_array)
    # Look through the children array for the reading list
    children_array.elements.each('dict') do |dict|
      title_found = false

      dict.elements.each do |element|
        if element.name == 'key' && element.text == 'Title'
          next_element = element.next_element
          if next_element&.name == 'string' && next_element.text == 'com.apple.ReadingList'
            title_found = true
            break
          end
        end
      end

      return dict if title_found
    end
    nil
  end

  def extract_urls_from_reading_list(reading_list_dict)
    urls = []

    # Find the Children array within the reading list
    reading_list_dict.elements.each do |element|
      if element.name == 'key' && element.text == 'Children'
        children_array = element.next_element
        next unless children_array&.name == 'array'

        # Extract URLs from each child
        children_array.elements.each('dict') do |item_dict|
          url = extract_url_from_item(item_dict)
          urls << url if url
        end
        break
      end
    end

    log_success("Extracted #{urls.length} URLs from reading list")
    urls
  end

  def extract_url_from_item(item_dict)
    # Look for URLString key
    item_dict.elements.each do |element|
      if element.name == 'key' && element.text == 'URLString'
        next_element = element.next_element
        return next_element.text if next_element&.name == 'string'
      end
    end
    nil
  end

  def delete_processed_articles(urls_to_delete)
    return if urls_to_delete.empty?

    log_section('🗑️  Deleting Articles from Reading List')

    # Convert to set for faster lookup
    urls_set = urls_to_delete.to_set

    if dry_run?
      log_info("[DRY-RUN] Would delete #{urls_to_delete.size} articles from reading list")
      urls_to_delete.each { |url| log_info("  Would delete: #{url}") }
      return
    end

    # Ask for confirmation unless force mode
    unless force?
      log_warning("You are about to delete #{urls_to_delete.size} articles from Safari's reading list")
      log_warning("This action cannot be undone!")
      return unless confirm_action("Continue with deletion?")
    end

    bookmarks_file = File.expand_path(BOOKMARKS_PLIST)

    begin
      # Create backup
      backup_file = create_backup(bookmarks_file)
      log_info("Created backup: #{backup_file}")

      # Process the plist file
      deleted_count = process_bookmarks_for_deletion(bookmarks_file, urls_set)

      if deleted_count > 0
        log_success("Deleted #{deleted_count} articles from Safari reading list")
        log_info("Backup saved at: #{backup_file}")
        log_info("You may need to restart Safari for changes to take effect")
      else
        log_warning("No articles were deleted from the reading list")
      end
    rescue => e
      log_error("Failed to delete articles: #{e.message}")
      log_debug("Backtrace: #{e.backtrace.join('\n')}") if debug?
    end
  end

  def create_backup(original_file)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_dir = File.join(File.dirname(original_file), 'backups')
    FileUtils.mkdir_p(backup_dir) unless Dir.exist?(backup_dir)

    backup_file = File.join(backup_dir, "Bookmarks_#{timestamp}.plist")
    FileUtils.cp(original_file, backup_file)
    backup_file
  end

  def process_bookmarks_for_deletion(bookmarks_file, urls_to_delete)
    # Create temp copy for processing
    temp_file = create_temp_plist_copy(bookmarks_file)

    # Convert to XML for processing
    convert_result = system('plutil', '-convert', 'xml1', temp_file)
    unless convert_result
      log_error("Failed to convert bookmarks plist to XML format")
      return 0
    end

    # Parse and modify XML
    deleted_count = modify_bookmarks_xml(temp_file, urls_to_delete)

    if deleted_count > 0
      # Convert back to binary format
      system('plutil', '-convert', 'binary1', temp_file)

      # Replace original file
      FileUtils.cp(temp_file, bookmarks_file)
    end

    deleted_count
  end

  def modify_bookmarks_xml(xml_file, urls_to_delete)
    doc = REXML::Document.new(File.read(xml_file))

    # Navigate to reading list
    dict = doc.elements['plist/dict']
    return 0 unless dict

    children_array = find_children_array(dict)
    return 0 unless children_array

    reading_list_dict = find_reading_list_dict(children_array)
    return 0 unless reading_list_dict

    # Find and remove matching articles
    deleted_count = remove_articles_from_reading_list(reading_list_dict, urls_to_delete)

    # Save modified XML back to file
    File.write(xml_file, doc.to_s)

    deleted_count
  end

  def remove_articles_from_reading_list(reading_list_dict, urls_to_delete)
    deleted_count = 0

    # Find the Children array within the reading list
    reading_list_dict.elements.each do |element|
      if element.name == 'key' && element.text == 'Children'
        children_array = element.next_element
        next unless children_array&.name == 'array'

        # Remove items that match URLs to delete
        items_to_remove = []

        children_array.elements.each('dict') do |item_dict|
          url = extract_url_from_item(item_dict)
          if url && urls_to_delete.include?(url)
            items_to_remove << item_dict
            log_info("Marked for deletion: #{url}")
          end
        end

        # Remove the items
        items_to_remove.each { |item| children_array.delete_element(item) }
        deleted_count = items_to_remove.size

        break
      end
    end

    deleted_count
  end

  def display_reading_list(urls)
    log_section('🔖 Safari Reading List URLs')

    urls.each_with_index do |url, index|
      puts "#{index + 1}. #{url}"
    end

    puts
    log_success("Total: #{urls.length} reading list items")
  end

  def create_epub_from_reading_list(urls)
    return if urls.empty?

    if force?
      log_section('🧹 Force Mode Enabled - Clearing All Cache')
      log_info('This will ensure fresh content is downloaded')
    end

    log_section('📚 Creating EPUB from Reading List')

    # Initialize EPUB generator using existing service (DRY principle)
    epub_generator = EPUBGenerator.new({
                                         cache_enabled: @options[:cache_enabled],
                                         javascript: @options[:use_javascript],
                                         parallel_enabled: @options[:parallel_enabled],
                                         save_to_icloud: @options[:save_to_icloud],
                                         download_images: @options[:download_images],
                                         max_image_size: @options[:max_image_size],
                                         app_name: 'SafariEPUB',
                                         icloud_identifier: 'reading-list',
                                         force: force?,
                                         verbose: verbose?,
                                         debug: debug?,
                                         logger: self
                                       })

    # Use the existing generate_epub_from_article_urls method for direct URL processing
    # This method handles article detection, content extraction, and EPUB creation
    epub_path = epub_generator.generate_epub_from_article_urls(
      urls,
      @options[:epub_title],
      @options[:epub_author]
    )

    if epub_path
      log_success('EPUB created successfully!')
      log_info("EPUB location: #{epub_path}")

      # Show iCloud location if saved to iCloud
      if @options[:save_to_icloud] && epub_generator.icloud_available?
        log_info("Check your iCloud Drive for the EPUB in: SafariEPUB/safari-reading-list/")
      end

      # Delete articles from reading list if requested
      if @options[:delete_after]
        delete_processed_articles(urls)
      end
    else
      log_error('Failed to create EPUB')
    end
  end
end

# Execute the script
SafariEpub.execute if __FILE__ == $0
