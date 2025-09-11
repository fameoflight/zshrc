#!/usr/bin/env ruby
# frozen_string_literal: true

require 'gepub'
require 'fileutils'
require 'uri'
require 'cgi'
require 'json'
require 'securerandom'
require 'readability'
require_relative '../script_base'
require_relative '../logger'
require_relative './page_fetcher'
require_relative './browser_service'
require_relative '../concerns/article_detector'
require_relative '../concerns/icloud_storage'

# EPUB Generator Service - Creates EPUB files from website articles
class EPUBGenerator
  include ICloudStorage

  def initialize(options = {})
    @options = {
      cache_enabled: true,
      javascript: false,
      save_to_icloud: true,
      app_name: 'WebsiteEPUB',
      verbose: false,
      debug: false
    }.merge(options)

    @page_fetcher = PageFetcher.new(
      cache_enabled: @options[:cache_enabled],
      verbose: @options[:verbose]
    )

    @logger = @options[:logger]
  end

  def generate_epub_from_urls(urls, title = nil, author = nil)
    log_info("Starting EPUB generation for #{urls.size} URLs")
    
    # Fetch pages first
    pages_data = @page_fetcher.fetch_pages(urls, javascript: @options[:javascript])
    
    # Only analyze pages that were successfully fetched
    valid_pages = pages_data.select { |url, data| data }.values
    
    # Analyze for articles
    analysis = ArticleDetector.batch_analyze(valid_pages, progress: @options[:verbose])
    
    if analysis[:articles].empty?
      log_warning("No articles detected in the fetched pages")
      return nil
    end

    log_success("Found #{analysis[:articles].size} articles")
    
    # Extract just the URLs and use the working method
    article_urls = analysis[:articles].map { |article| article[:url] }
    
    # Use the working generate_epub_from_article_urls method
    generate_epub_from_article_urls(article_urls, title, author)
  end

  def generate_epub_from_article_urls(article_urls, title = nil, author = nil)
    log_info("Starting EPUB generation for #{article_urls.size} article URLs")
    
    # Fetch each article page and create enhanced article data
    enhanced_articles = []
    
    article_urls.each_with_index do |url, index|
      log_info("Processing article #{index + 1}/#{article_urls.size}: #{url}")
      
      # Fetch the page
      page_data = @page_fetcher.fetch_page(url, javascript: @options[:use_javascript])
      
      unless page_data && page_data[:content]
        log_warning("Failed to fetch content for #{url}")
        next
      end
      
      # Create enhanced article data
      enhanced_article = {
        url: url,
        final_url: page_data[:final_url] || url,
        content: page_data[:content],
        title: page_data[:title],
        clean_content: extract_clean_content(url, page_data[:content]),
        extracted_title: extract_article_title(url, page_data[:content]),
        extracted_author: extract_article_author(url, page_data[:content]),
        extracted_date: extract_article_date(url, page_data[:content]),
        safe_filename: generate_safe_filename("article_#{index + 1}")
      }
      
      enhanced_articles << enhanced_article
      log_debug("Added article: #{enhanced_article[:extracted_title]} (#{enhanced_article[:clean_content].length} chars)")
    end
    
    if enhanced_articles.empty?
      log_error("No valid articles found to create EPUB")
      return nil
    end

    # Generate EPUB
    epub_path = create_epub(enhanced_articles, title, author)
    
    # Save to iCloud if enabled
    if epub_path && @options[:save_to_icloud]
      domain = extract_domain(enhanced_articles.first[:url])
      save_to_icloud_storage(epub_path, domain)
    end

    epub_path
  end

  def generate_epub_from_website(base_url, options = {})
    log_info("Generating EPUB from website: #{base_url}")
    
    # Fetch all URLs from the website
    browser_service = BrowserService.new(base_url, @options)
    all_urls = browser_service.collect_urls_with_read_more
    
    if all_urls.empty?
      log_error("No URLs found on the website")
      return nil
    end

    # Filter to same domain only
    domain = extract_domain(base_url)
    same_domain_urls = all_urls.select { |url_info| same_domain?(url_info[:url], domain) }
    
    log_info("Found #{same_domain_urls.size} same-domain URLs")
    
    if same_domain_urls.empty?
      log_error("No same-domain URLs found")
      return nil
    end

    # Extract just the URLs for article detection
    url_strings = same_domain_urls.map { |url_info| url_info[:url] }
    
    # Generate EPUB from detected articles
    generate_epub_from_urls(url_strings, options[:title], options[:author])
  end

  private

  def fetch_and_analyze_articles(urls)
    log_info("Fetching and analyzing #{urls.size} URLs for articles")
    
    # Fetch pages
    pages_data = @page_fetcher.fetch_pages(urls, javascript: @options[:javascript])
    
    # Only analyze pages that were successfully fetched
    valid_pages = pages_data.select { |url, data| data }.values
    
    # Analyze for articles
    analysis = ArticleDetector.batch_analyze(valid_pages, progress: @options[:verbose])
    
    if analysis[:articles].empty?
      log_warning("No articles detected in the fetched pages")
      return []
    end

    log_success("Found #{analysis[:articles].size} articles")
    
    # Enhance article data with extracted content
    enhance_article_data(analysis[:articles])
  end

  def enhance_article_data(articles)
    articles.map do |article|
      enhanced = article.dup
      
      log_debug("Processing article: #{enhanced[:url]}")
      log_debug("Original content length: #{enhanced[:content] ? enhanced[:content].length : 'nil'}")
      
      # Extract clean content
      enhanced[:clean_content] = extract_clean_content(enhanced[:url], enhanced[:content])
      log_debug("Clean content length: #{enhanced[:clean_content] ? enhanced[:clean_content].length : 'nil'}")
      
      # Extract article metadata
      enhanced[:extracted_title] = extract_article_title(enhanced[:url], enhanced[:content])
      enhanced[:extracted_author] = extract_article_author(enhanced[:url], enhanced[:content])
      enhanced[:extracted_date] = extract_article_date(enhanced[:url], enhanced[:content])
      
      log_debug("Extracted title: #{enhanced[:extracted_title]}")
      log_debug("Extracted author: #{enhanced[:extracted_author]}")
      
      # Generate safe filename
      enhanced[:safe_filename] = generate_safe_filename(enhanced[:extracted_title] || "article_#{SecureRandom.hex(4)}")
      
      enhanced
    end
  end

  def extract_clean_content(url, html_content)
    return extract_fallback_content(html_content) if html_content.nil? || html_content.empty?
    
    begin
      # Use Readability to extract main content
      readability_doc = Readability::Document.new(html_content, {
        url: url,
        min_text_length: 200,
        retry_length: 250,
        debug: @options[:debug]
      })
      
      content = readability_doc.content
      title = readability_doc.title
      
      # Clean up the content
      if content && !content.empty?
        doc = Nokogiri::HTML(content)
        # Remove any remaining unwanted elements
        doc.search('script', 'style', 'nav', 'header', 'footer', 'aside', '.sidebar', '.navigation', '.ads', '.comments').remove
        
        # Remove related articles sections
        doc.search('.related', '.jp-relatedposts', '[class*="related"]', '[id*="related"]').remove
        
        # Remove elements with "Related" text
        doc.xpath('//*[contains(text(), "Related")]').each do |element|
          # Remove the element and its following siblings until next section
          next_element = element.next_sibling
          element.remove
          # Remove following elements until we hit a major section break
          while next_element && !next_element.name.match?(/^h[1-6]$/) && !next_element.name.match?(/^(article|section|div)$/)
            to_remove = next_element
            next_element = next_element.next_sibling
            to_remove.remove
          end
        end
        
        # Return the cleaned HTML instead of just text to preserve paragraph structure
        cleaned_html = doc.to_html.strip
        cleaned_html.empty? ? extract_fallback_content(html_content) : cleaned_html
      else
        log_warning("Readability could not extract content from #{url}")
        extract_fallback_content(html_content)
      end
    rescue => e
      log_warning("Readability failed for #{url}: #{e.message}")
      extract_fallback_content(html_content)
    end
  end

  def extract_fallback_content(html_content)
    # Fallback extraction method
    doc = Nokogiri::HTML(html_content)
    
    # Remove unwanted elements
    doc.search('script', 'style', 'nav', 'header', 'footer', 'aside', '.sidebar', '.navigation', '.ads', '.comments').remove
    
    # Try to find main content
    main_content = doc.at_css('article, main, .content, .post, .entry, #content, #main, .article-content')
    
    if main_content
      # Return HTML content to preserve paragraph structure
      main_content.inner_html.strip
    else
      # Fallback to body content
      body_content = doc.at_css('body')
      if body_content
        # Try to preserve some structure in body content
        body_content.inner_html.strip
      else
        "<p>Content not available</p>"
      end
    end
  end

  def extract_article_title(url, html_content)
    return "Unknown Title" if html_content.nil? || html_content.empty?
    
    begin
      # First try Readability for better title extraction
      readability_doc = Readability::Document.new(html_content, {
        url: url,
        min_text_length: 200,
        retry_length: 250
      })
      
      title = readability_doc.title
      
      if title && !title.empty?
        return title.gsub(/\s+/, ' ').strip
      end
    rescue => e
      log_debug("Readability title extraction failed: #{e.message}")
    end
    
    # Fallback to traditional extraction
    doc = Nokogiri::HTML(html_content)
    
    # Try multiple title sources
    title = doc.at_css('h1, .post-title, .entry-title, article h1, .article-title')&.text&.strip
    
    # Fallback to <title> tag
    title ||= doc.at_css('title')&.text&.strip
    
    # Clean up title
    cleaned_title = title&.gsub(/\s+/, ' ')&.strip
    cleaned_title.empty? ? "Unknown Title" : cleaned_title
  end

  def extract_article_author(url, html_content)
    doc = Nokogiri::HTML(html_content)
    
    # Try common author selectors
    author = doc.at_css('.author, .byline, [rel="author"], .post-author, .entry-author')&.text&.strip
    
    # Look for author patterns in content
    if !author
      content = doc.text
      author_match = content.match(/by\s+([A-Z][a-z]+\s+[A-Z][a-z]+)/i)
      author = author_match[1] if author_match
    end
    
    author&.gsub(/^by\s+/i, '')&.strip
  end

  def extract_article_date(url, html_content)
    doc = Nokogiri::HTML(html_content)
    
    # Try time element
    time_element = doc.at_css('time[datetime]')
    if time_element && time_element['datetime']
      return Date.parse(time_element['datetime'])
    end
    
    # Look for date patterns in content
    content = doc.text
    date_match = content.match(/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+\d{4}/i)
    
    if date_match
      Date.parse(date_match[0])
    else
      Date.today
    end
  rescue
    Date.today
  end

  def create_epub(articles, title = nil, author = nil)
    return nil if articles.empty?

    # Determine EPUB metadata
    first_article = articles.first
    domain = extract_domain(first_article[:url])
    book_title = title || "Articles from #{domain}"
    book_author = author || "Various Authors"
    
    # Generate filename with nice formatting (no timestamp for reusability)
    nice_title = nice_filename(book_title)
    filename = "#{nice_title}.epub"
    temp_path = File.join(Dir.tmpdir, filename)
    
    log_info("Creating EPUB: #{filename}")
    
    # Create EPUB with proper metadata
    book = GEPUB::Book.new
    book.primary_identifier("website-epub-#{domain}", 'BookID', 'URL')
    book.language = 'en'
    
    # Add title with metadata
    book.add_title(book_title, title_type: GEPUB::TITLE_TYPE::MAIN) do |title|
      title.lang = 'en'
      title.display_seq = 1
    end
    
    # Add creator/author
    book.add_creator(book_author) do |creator|
      creator.display_seq = 1
    end
    
    # Add publisher
    book.add_contributor("Website EPUB Generator") do |contributor|
      contributor.display_seq = 1
    end
    
    # Add publication date
    book.date = Date.today.to_s
    
    # Store articles count for metadata
    @articles_count = articles.size
    
    # Add articles as chapters
    book.ordered do
      articles.each_with_index do |article, index|
        add_article_chapter(book, article, index + 1)
      end
    end
    
    # Generate EPUB file
    book.generate_epub(temp_path)
    
    log_success("EPUB created: #{temp_path}")
    log_info("EPUB contains #{articles.size} articles")
    
    temp_path
  end

  def add_article_chapter(book, article, chapter_number)
    # Create HTML content for the article
    html_content = generate_article_html(article, chapter_number)
    
    # Create unique filename for this chapter
    chapter_filename = "chapter_#{chapter_number}.xhtml"
    
    # Add chapter to book with table of contents entry
    chapter_title = article[:extracted_title] || "Chapter #{chapter_number}"
    book.add_item(chapter_filename).add_content(StringIO.new(html_content)).toc_text(chapter_title)
    
    log_debug("Added chapter #{chapter_number}: #{chapter_title}")
  end

  def generate_article_html(article, chapter_number)
    title = article[:extracted_title] || "Article #{chapter_number}"
    author = article[:extracted_author] || "Unknown Author"
    date = article[:extracted_date] || Date.today
    url = article[:url]
    content = article[:clean_content] || "Content not available"
    
    # Generate HTML with proper content formatting
    <<~HTML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html>
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>#{CGI.escapeHTML(title)}</title>
          <style>
            body { font-family: serif; line-height: 1.6; margin: 2em; max-width: 600px; margin: 0 auto; }
            h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 0.5em; }
            .meta { color: #666; font-style: italic; margin-bottom: 2em; padding: 1em; background-color: #f5f5f5; border-radius: 4px; }
            .meta p { margin: 0.5em 0; }
            .content { margin-top: 2em; }
            .content p { margin-bottom: 1.5em; margin-top: 0; text-align: justify; }
            .content h2, .content h3 { color: #444; margin-top: 1.5em; margin-bottom: 0.5em; }
            .content ul, .content ol { margin-bottom: 1em; }
            .content blockquote { 
              border-left: 4px solid #ccc; 
              margin-left: 1em; 
              padding-left: 1em; 
              font-style: italic; 
              color: #555; 
            }
            .content code { 
              background-color: #f0f0f0; 
              padding: 0.2em 0.4em; 
              border-radius: 3px; 
              font-family: monospace; 
            }
            .content pre { 
              background-color: #f0f0f0; 
              padding: 1em; 
              border-radius: 4px; 
              overflow-x: auto; 
              margin-bottom: 1em; 
            }
            .content pre code { 
              background: none; 
              padding: 0; 
            }
            a { color: #0066cc; text-decoration: none; }
            a:hover { text-decoration: underline; }
          </style>
        </head>
        <body>
          <h1>#{CGI.escapeHTML(title)}</h1>
          <div class="meta">
            <p><strong>Published:</strong> #{date.strftime('%B %d, %Y')}</p>
            <p><strong>Source:</strong> <a href="#{CGI.escapeHTML(url)}">#{CGI.escapeHTML(url)}</a></p>
          </div>
          <div class="content">
            #{format_content_for_epub(content)}
          </div>
        </body>
      </html>
    HTML
  end

  def format_content_for_epub(content)
    return "<p>Content not available</p>" if content.nil? || content.empty?
    
    # Check if content is already HTML (from Readability)
    if content.include?('<p>') || content.include?('<div>') || content.include?('<h')
      # Content is already HTML, just clean it up
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
      
      # Remove any unwanted attributes but keep structure
      doc.search('*').each do |element|
        # Keep only essential attributes
        allowed_attrs = %w[href src alt title]
        element.attributes.each do |name, attr|
          attr.remove unless allowed_attrs.include?(name)
        end
      end
      
      # Return the cleaned HTML
      doc.to_html
    else
      # Content is plain text, format as paragraphs
      # Split by double newlines to separate paragraphs
      paragraphs = content.split(/\n\s*\n/)
      
      html_content = paragraphs.map do |paragraph|
        next if paragraph.strip.empty?
        
        # Clean up the paragraph
        clean_para = paragraph.strip.gsub(/\s+/, ' ')
        
        # Escape HTML entities
        escaped_para = CGI.escapeHTML(clean_para)
        
        # Wrap in paragraph tags
        "<p>#{escaped_para}</p>"
      end.compact.join("\n")
      
      html_content
    end
  end

  def save_to_icloud_storage(epub_path, domain)
    return unless icloud_available?
    
    # Create directory in iCloud with nicer naming (no timestamp for reusability)
    nice_domain = domain.gsub('.', '-') if domain
    item_identifier = nice_domain
    icloud_dir = ensure_icloud_item_directory!(@options[:app_name], item_identifier)
    
    # Generate iCloud filename
    icloud_filename = File.basename(epub_path)
    icloud_path = File.join(icloud_dir, icloud_filename)
    
    # Copy EPUB to iCloud
    log_info("Saving EPUB to iCloud: #{icloud_path}")
    FileUtils.cp(epub_path, icloud_path)
    
    # Save metadata
    metadata = {
      created_at: Time.now.iso8601,
      domain: domain,
      source: epub_path,
      articles_count: @articles_count,
      file_size: File.size(epub_path),
      generator: 'WebsiteEPUB'
    }
    
    save_icloud_metadata(@options[:app_name], item_identifier, metadata)
    
    log_success("EPUB saved to iCloud: #{icloud_path}")
    
    # Wait for iCloud sync
    wait_for_icloud_sync(icloud_path) if @options[:wait_for_sync]
    
    icloud_path
  end

  def extract_domain(url)
    begin
      uri = URI(url)
      uri.host
    rescue URI::InvalidURIError
      nil
    end
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

  def generate_safe_filename(title)
    # Sanitize title for filesystem
    sanitized = title.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-').gsub(/-+/, '-')
    sanitized = "untitled" if sanitized.empty?
    "#{sanitized[0..50]}_#{SecureRandom.hex(4)}"
  end

  def sanitize_filename(name)
    name.gsub(/[^\w\-_.]/, '_').gsub(/_+/, '_').gsub(/^_|_$/, '')
  end

  def nice_filename(name)
    # Convert to lowercase and replace problematic characters
    nice_name = name.to_s.downcase
                    .gsub(/[^\w\s\-]/, '')  # Remove non-word chars except spaces and dashes
                    .gsub(/\s+/, '-')       # Replace spaces with dashes  
                    .gsub(/\./, '-')        # Replace dots with dashes
                    .gsub(/-+/, '-')        # Collapse multiple dashes
                    .gsub(/^-|-$/, '')      # Remove leading/trailing dashes
    
    # Handle edge cases
    nice_name = 'untitled' if nice_name.empty?
    
    # Limit length to avoid overly long filenames
    nice_name[0..50]
  end

  def log_info(message)
    if @logger
      @logger.send(:log_info, message)
    elsif @options[:verbose]
      puts "ℹ️  #{message}"
    end
  end

  def log_success(message)
    if @logger
      @logger.send(:log_success, message)
    else
      puts "✅ #{message}"
    end
  end

  def log_warning(message)
    if @logger
      @logger.send(:log_warning, message)
    else
      puts "⚠️  #{message}"
    end
  end

  def log_error(message)
    if @logger
      @logger.send(:log_error, message)
    else
      puts "❌ #{message}"
    end
  end

  def log_debug(message)
    if @logger
      @logger.send(:log_debug, message)
    elsif @options[:debug]
      puts "🐛 #{message}"
    end
  end
end