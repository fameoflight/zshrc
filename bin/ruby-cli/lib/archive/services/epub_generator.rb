#!/usr/bin/env ruby
# frozen_string_literal: true

require 'gepub'
require 'fileutils'
require 'uri'
require 'cgi'
require 'json'
require 'securerandom'
require 'readability'
require 'nokogiri'
require_relative '../script_base'
require_relative '../logger'
require_relative './base_service'
require_relative './page_fetcher'
require_relative './browser_service'
require_relative '../concerns/article_detector'
require_relative '../concerns/icloud_storage'
require_relative './image_processor'

# EPUB Generator Service - Creates EPUB files from website articles
class EPUBGenerator < BaseService
  include ICloudStorage

  def initialize(options = {})
    super(options)
    @options = {
      cache_enabled: true,
      javascript: false,
      parallel_enabled: true,
      save_to_icloud: true,
      app_name: 'WebsiteEPUB',
      icloud_identifier: nil,
      verbose: false,
      debug: false,
      download_images: true,
      max_image_size: 5 * 1024 * 1024 # 5MB
    }.merge(options)

    @page_fetcher = PageFetcher.new(
      cache_enabled: @options[:cache_enabled],
      parallel_enabled: @options[:parallel_enabled],
      verbose: @options[:verbose]
    )

    @image_processor = ImageProcessor.new({
      download_images: @options[:download_images],
      max_image_size: @options[:max_image_size],
      verbose: @options[:verbose],
      debug: @options[:debug]
    })

    # Clear cache if force mode is enabled
    clear_all_cache if @options[:force]
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
      page_data = @page_fetcher.fetch_page(url, javascript: @options[:javascript])
      
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
        remove_empty_nodes: true,
        min_text_length: 100,
        retry_length: 250,
        debug: @options[:debug],
        keep_images: true,      # Preserve images in content
        ignore_image_format: false  # Don't ignore image elements
      })
      
      content = readability_doc.content
      title = readability_doc.title
      
      # Clean up the content
      if content && !content.empty?
        doc = Nokogiri::HTML(content)
        # Process images to ensure proper URLs and preservation
        process_images(doc, url)

        # Remove any remaining unwanted elements (but preserve tables and images)
        doc.search('script', 'style', 'nav', 'header', 'footer', 'aside', '.sidebar', '.navigation', '.ads', '.comments').remove

        # Specifically preserve tables with meaningful content
        preserve_meaningful_tables(doc)

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

    # Add table of contents page first
    add_table_of_contents(book, articles, book_title)

    # Add articles as chapters
    book.ordered do
      articles.each_with_index do |article, index|
        add_article_chapter(book, article, index + 2) # Start from chapter 2 since TOC is chapter 1
      end
    end

    # Generate EPUB file
    book.generate_epub(temp_path)

    log_success("EPUB created: #{temp_path}")
    log_info("EPUB contains #{articles.size} articles with clickable TOC")

    temp_path
  end

  def add_table_of_contents(book, articles, book_title)
    log_info("Creating table of contents page")

    # Generate TOC HTML content
    toc_html = generate_toc_html(articles, book_title)

    # Add TOC as the first chapter
    toc_filename = "table_of_contents.xhtml"
    book.add_item(toc_filename).add_content(StringIO.new(toc_html)).toc_text("Table of Contents")

    log_debug("Added table of contents page")
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

  def generate_toc_html(articles, book_title)
    # Generate TOC HTML with clickable links to chapters
    toc_content = articles.each_with_index.map do |article, index|
      chapter_num = index + 2  # Chapter 1 is TOC, articles start from chapter 2
      article_num = index + 1  # Article number for display
      title = article[:extracted_title] || "Article #{article_num}"
      author = article[:extracted_author] || "Unknown Author"
      date = article[:extracted_date] || Date.today
      url = article[:url]

      <<~TOC_ENTRY
        <div class="toc-entry">
          <div class="toc-title">
            <span class="toc-number">#{article_num}</span>
            <a href="chapter_#{chapter_num}.xhtml">#{CGI.escapeHTML(title)}</a>
          </div>
          <div class="toc-meta">
            #{CGI.escapeHTML(author)} • #{date.strftime('%B %d, %Y')}
          </div>
          <div class="toc-source">
            <a href="#{CGI.escapeHTML(url)}" class="source-link">#{CGI.escapeHTML(url)}</a>
          </div>
        </div>
      TOC_ENTRY
    end.join("\n")

    <<~TOC_HTML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html>
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>Table of Contents - #{CGI.escapeHTML(book_title)}</title>
          <style>
            /* Light theme (default) */
            body {
              font-family: serif;
              line-height: 1.6;
              margin: 2em;
              max-width: 800px;
              margin: 0 auto;
              background-color: #fafafa;
              color: #333;
            }
            .header {
              text-align: center;
              margin-bottom: 3em;
              padding: 2em;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white;
              border-radius: 8px;
              box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            .header h1 {
              margin: 0;
              font-size: 2.5em;
              font-weight: 300;
              text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .header p {
              margin: 0.5em 0 0 0;
              font-size: 1.2em;
              opacity: 0.9;
            }
            .toc-entry {
              margin-bottom: 2em;
              padding: 1.5em;
              background-color: white;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              transition: transform 0.2s ease, box-shadow 0.2s ease;
            }
            .toc-entry:hover {
              transform: translateY(-2px);
              box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            }
            .toc-title {
              margin-bottom: 0.5em;
            }
            .toc-title a {
              color: #0066cc;
              text-decoration: none;
              font-size: 1.3em;
              font-weight: 600;
              display: block;
              padding: 0.5em 0;
              border-bottom: 2px solid transparent;
              transition: border-color 0.3s ease;
            }
            .toc-title a:hover {
              color: #004499;
              border-bottom-color: #0066cc;
              text-decoration: none;
            }
            .toc-meta {
              color: #666;
              font-size: 0.9em;
              margin-bottom: 0.5em;
              font-style: italic;
            }
            .toc-source {
              font-size: 0.85em;
            }
            .source-link {
              color: #888;
              text-decoration: none;
              font-family: monospace;
              background-color: #f5f5f5;
              padding: 0.2em 0.4em;
              border-radius: 3px;
              word-break: break-all;
            }
            .source-link:hover {
              color: #666;
              background-color: #e8e8e8;
              text-decoration: none;
            }
            .stats {
              text-align: center;
              margin-top: 3em;
              padding: 1em;
              background-color: #e8f4fd;
              border-radius: 6px;
              color: #2c5282;
            }
            .toc-number {
              display: inline-block;
              width: 2em;
              height: 2em;
              background-color: #667eea;
              color: white;
              border-radius: 50%;
              text-align: center;
              line-height: 2em;
              margin-right: 0.5em;
              font-weight: bold;
              font-size: 0.9em;
            }

            /* Dark theme for Apple Books and other dark readers */
            @media (prefers-color-scheme: dark) {
              body {
                background-color: #1a1a1a;
                color: #e0e0e0;
              }

              .header {
                background: linear-gradient(135deg, #4a5568 0%, #2d3748 100%);
                box-shadow: 0 4px 6px rgba(0,0,0,0.3);
              }

              .toc-entry {
                background-color: #2d3748;
                box-shadow: 0 2px 4px rgba(0,0,0,0.3);
              }

              .toc-entry:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.4);
                background-color: #374151;
              }

              .toc-title a {
                color: #63b3ed;
                border-bottom-color: transparent;
              }

              .toc-title a:hover {
                color: #90cdf4;
                border-bottom-color: #63b3ed;
              }

              .toc-meta {
                color: #a0aec0;
              }

              .source-link {
                color: #cbd5e0;
                background-color: #4a5568;
              }

              .source-link:hover {
                color: #e2e8f0;
                background-color: #2d3748;
              }

              .stats {
                background-color: #2c5282;
                color: #e2e8f0;
              }

              .toc-number {
                background-color: #4a5568;
                color: white;
              }
            }

            /* Fallback for EPUB readers that don't support media queries */
            /* Use Apple Books-specific dark mode */
            html.apple-books-dark-mode {
              background-color: #1a1a1a;
              color: #e0e0e0;
            }

            html.apple-books-dark-mode .header {
              background: linear-gradient(135deg, #4a5568 0%, #2d3748 100%);
              box-shadow: 0 4px 6px rgba(0,0,0,0.3);
            }

            html.apple-books-dark-mode .toc-entry {
              background-color: #2d3748;
              box-shadow: 0 2px 4px rgba(0,0,0,0.3);
            }

            html.apple-books-dark-mode .toc-entry:hover {
              background-color: #374151;
              box-shadow: 0 4px 12px rgba(0,0,0,0.4);
            }

            html.apple-books-dark-mode .toc-title a {
              color: #63b3ed;
            }

            html.apple-books-dark-mode .toc-title a:hover {
              color: #90cdf4;
              border-bottom-color: #63b3ed;
            }

            html.apple-books-dark-mode .toc-meta {
              color: #a0aec0;
            }

            html.apple-books-dark-mode .source-link {
              color: #cbd5e0;
              background-color: #4a5568;
            }

            html.apple-books-dark-mode .source-link:hover {
              color: #e2e8f0;
              background-color: #2d3748;
            }

            html.apple-books-dark-mode .stats {
              background-color: #2c5282;
              color: #e2e8f0;
            }

            html.apple-books-dark-mode .toc-number {
              background-color: #4a5568;
            }

            @media (max-width: 600px) {
              body { margin: 1em; }
              .header { padding: 1em; }
              .header h1 { font-size: 2em; }
              .toc-entry { padding: 1em; margin-bottom: 1em; }
              .toc-title a { font-size: 1.1em; }
            }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>#{CGI.escapeHTML(book_title)}</h1>
            <p>Table of Contents</p>
          </div>

          <div class="toc-entries">
            #{toc_content}
          </div>

          <div class="stats">
            <p><strong>#{articles.size}</strong> articles compiled on #{Date.today.strftime('%B %d, %Y')}</p>
            <p>Generated by <strong>Website EPUB Generator</strong></p>
          </div>
        </body>
      </html>
    TOC_HTML
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
            /* Light theme (default) */
            body {
              font-family: serif;
              line-height: 1.6;
              margin: 2em;
              max-width: 600px;
              margin: 0 auto;
              color: #333;
              background-color: #ffffff;
            }
            h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 0.5em; }
            .meta {
              color: #666;
              font-style: italic;
              margin-bottom: 2em;
              padding: 1em;
              background-color: #f5f5f5;
              border-radius: 4px;
            }
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
            /* Table styling for better readability */
            .content table {
              border-collapse: collapse;
              width: 100%;
              margin-bottom: 1.5em;
              font-size: 0.9em;
            }
            .content table,
            .content th,
            .content td {
              border: 1px solid #ddd;
            }
            .content th,
            .content td {
              padding: 0.75em;
              text-align: left;
              vertical-align: top;
            }
            .content th {
              background-color: #f5f5f5;
              font-weight: bold;
            }
            .content tr:nth-child(even) {
              background-color: #f9f9f9;
            }
            /* Image styling */
            .content img {
              max-width: 100%;
              height: auto;
              display: block;
              margin: 1em auto;
              border-radius: 4px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .content figure {
              margin: 1.5em 0;
              text-align: center;
            }
            .content figcaption {
              font-style: italic;
              color: #666;
              margin-top: 0.5em;
              font-size: 0.9em;
            }
            a { color: #0066cc; text-decoration: none; }
            a:hover { text-decoration: underline; }
            /* Navigation link back to TOC */
            .nav-toc {
              position: fixed;
              top: 1em;
              right: 1em;
              background-color: #667eea;
              color: white;
              padding: 0.5em 1em;
              border-radius: 4px;
              text-decoration: none;
              font-size: 0.9em;
              box-shadow: 0 2px 4px rgba(0,0,0,0.2);
              transition: background-color 0.3s ease;
            }
            .nav-toc:hover {
              background-color: #5a6fd8;
              text-decoration: none;
              color: white;
            }

            /* Dark theme for Apple Books and other dark readers */
            @media (prefers-color-scheme: dark) {
              body {
                color: #e0e0e0;
                background-color: #1a1a1a;
              }

              h1 { color: #e0e0e0; border-bottom-color: #666; }

              .meta {
                color: #a0aec0;
                background-color: #2d3748;
              }

              .content h2, .content h3 { color: #cbd5e0; }

              .content blockquote {
                border-left-color: #666;
                color: #a0aec0;
              }

              .content code {
                background-color: #374151;
                color: #e0e0e0;
              }

              .content pre {
                background-color: #374151;
                color: #e0e0e0;
              }

              .content table,
              .content th,
              .content td {
                border-color: #4a5568;
              }

              .content th {
                background-color: #374151;
                color: #e0e0e0;
              }

              .content tr:nth-child(even) {
                background-color: #2d3748;
              }

              .content figcaption {
                color: #a0aec0;
              }

              a { color: #63b3ed; }
              a:hover { color: #90cdf4; }

              .nav-toc {
                background-color: #4a5568;
                box-shadow: 0 2px 4px rgba(0,0,0,0.4);
              }

              .nav-toc:hover {
                background-color: #374151;
              }
            }

            /* Fallback for EPUB readers that don't support media queries */
            html.apple-books-dark-mode {
              color: #e0e0e0;
              background-color: #1a1a1a;
            }

            html.apple-books-dark-mode h1 {
              color: #e0e0e0;
              border-bottom-color: #666;
            }

            html.apple-books-dark-mode .meta {
              color: #a0aec0;
              background-color: #2d3748;
            }

            html.apple-books-dark-mode .content h2,
            html.apple-books-dark-mode .content h3 {
              color: #cbd5e0;
            }

            html.apple-books-dark-mode .content blockquote {
              border-left-color: #666;
              color: #a0aec0;
            }

            html.apple-books-dark-mode .content code {
              background-color: #374151;
              color: #e0e0e0;
            }

            html.apple-books-dark-mode .content pre {
              background-color: #374151;
              color: #e0e0e0;
            }

            html.apple-books-dark-mode .content table,
            html.apple-books-dark-mode .content th,
            html.apple-books-dark-mode .content td {
              border-color: #4a5568;
            }

            html.apple-books-dark-mode .content th {
              background-color: #374151;
              color: #e0e0e0;
            }

            html.apple-books-dark-mode .content tr:nth-child(even) {
              background-color: #2d3748;
            }

            html.apple-books-dark-mode .content figcaption {
              color: #a0aec0;
            }

            html.apple-books-dark-mode a {
              color: #63b3ed;
            }

            html.apple-books-dark-mode a:hover {
              color: #90cdf4;
            }

            html.apple-books-dark-mode .nav-toc {
              background-color: #4a5568;
              box-shadow: 0 2px 4px rgba(0,0,0,0.4);
            }

            html.apple-books-dark-mode .nav-toc:hover {
              background-color: #374151;
            }

            @media (max-width: 600px) {
              .nav-toc {
                position: relative;
                top: auto;
                right: auto;
                display: block;
                margin-bottom: 1em;
                text-align: center;
              }
            }
          </style>
        </head>
        <body>
          <a href="table_of_contents.xhtml" class="nav-toc">← Table of Contents</a>

          <h1>#{CGI.escapeHTML(title)}</h1>
          <div class="meta">
            <p><strong>Published:</strong> #{date.strftime('%B %d, %Y')}</p>
            <p><strong>Source:</strong> <a href="#{CGI.escapeHTML(url)}">#{CGI.escapeHTML(url)}</a></p>
          </div>
          <div class="content">
            #{format_content_for_epub(content, url)}
          </div>
        </body>
      </html>
    HTML
  end

  def format_content_for_epub(content, base_url = nil)
    return "<p>Content not available</p>" if content.nil? || content.empty?

    # Check if content is already HTML (from Readability)
    if content.include?('<p>') || content.include?('<div>') || content.include?('<h')
      # Content is already HTML, process images and clean it up
      doc = Nokogiri::HTML::DocumentFragment.parse(content)

      # Process images if image downloading is enabled
      if @options[:download_images] && base_url
        puts "🖼️  Processing images in content from: #{base_url}" if @options[:verbose]
        processed_html = @image_processor.process_html_content(doc.to_html, base_url)
        doc = Nokogiri::HTML::DocumentFragment.parse(processed_html)
      end

      # Remove any unwanted attributes but keep structure
      doc.search('*').each do |element|
        # Keep only essential attributes
        allowed_attrs = %w[href src alt title width height]
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

    # Use custom identifier if provided, otherwise fallback to domain
    if @options[:icloud_identifier]
      item_identifier = @options[:icloud_identifier]
    else
      # Create directory in iCloud with nicer naming (no timestamp for reusability)
      nice_domain = domain.gsub('.', '-') if domain
      item_identifier = nice_domain
    end

    icloud_dir = ensure_icloud_item_directory!(@options[:app_name], item_identifier)

    # Generate iCloud filename
    icloud_filename = File.basename(epub_path)
    icloud_path = File.join(icloud_dir, icloud_filename)

    # Check if file already exists
    if File.exist?(icloud_path)
      if @options[:force]
        log_warning("Overwriting existing EPUB in iCloud: #{icloud_path}")
      else
        log_error("EPUB already exists in iCloud: #{icloud_path}")
        log_error("Use --force to overwrite or delete the existing file first")
        return nil
      end
    end

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

  # Process images to ensure proper URLs and preservation
  def process_images(doc, base_url)
    begin
      base_uri = URI(base_url)

      doc.search('img').each do |img|
        # Process src attribute
        if img['src']
          img['src'] = resolve_url(img['src'], base_uri)
        end

        # Process srcset attribute if present
        if img['srcset']
          srcset_parts = img['srcset'].split(',').map do |part|
            url_part, descriptor = part.strip.split(/\s+/, 2)
            resolved_url = resolve_url(url_part, base_uri)
            descriptor ? "#{resolved_url} #{descriptor}" : resolved_url
          end
          img['srcset'] = srcset_parts.join(', ')
        end

        # Ensure alt text exists
        unless img['alt'] && !img['alt'].empty?
          img['alt'] = 'Article image'
        end

        # Remove potentially problematic attributes
        img.remove_attribute('loading')
        img.remove_attribute('decoding')
        img.remove_attribute('onload')
        img.remove_attribute('onerror')
      end

      # Also process picture elements
      doc.search('picture source').each do |source|
        if source['srcset']
          srcset_parts = source['srcset'].split(',').map do |part|
            url_part, descriptor = part.strip.split(/\s+/, 2)
            resolved_url = resolve_url(url_part, base_uri)
            descriptor ? "#{resolved_url} #{descriptor}" : resolved_url
          end
          source['srcset'] = srcset_parts.join(', ')
        end
      end

    rescue => e
      log_debug("Image processing failed for #{base_url}: #{e.message}") if @options[:debug]
    end
  end

  # Resolve relative URLs to absolute URLs
  def resolve_url(url, base_uri)
    return url if url.nil? || url.empty?
    return url if url.start_with?('data:') # Data URLs don't need resolution

    begin
      # Already absolute URL
      return url if url.start_with?('http://', 'https://', '//')

      # Resolve relative to base URL
      absolute_url = URI.join(base_uri.to_s, url).to_s

      # Clean up any potential double slashes in path
      absolute_url.gsub(/([^:])\/{2,}/, '\1/')
    rescue URI::InvalidURIError
      url # Return original if resolution fails
    end
  end

  # Preserve tables that contain meaningful content
  def preserve_meaningful_tables(doc)
    doc.search('table').each do |table|
      # Check if table has meaningful data
      rows = table.search('tr')
      next if rows.size < 2 # Skip tables with less than 2 rows

      # Check if table has data cells (not just navigation/layout)
      data_cells = table.search('td').size
      header_cells = table.search('th').size

      # Preserve if table has reasonable amount of data
      if (data_cells + header_cells) >= 4
        # Add table class for styling
        table['class'] = 'data-table'

        # Ensure proper table structure
        ensure_table_structure(table)
      end
    end
  end

  # Ensure proper table structure for EPUB compatibility
  def ensure_table_structure(table)
    # Add thead if missing and there are header cells
    header_rows = table.search('tr:has(th)')
    if header_rows.any? && !table.at_css('thead')
      thead = doc.create_element('thead')
      header_rows.each { |row| thead.add_child(row.dup) }
      table.add_child(thead)
    end

    # Add tbody if missing and there are data rows
    data_rows = table.search('tr:has(td)')
    if data_rows.any? && !table.at_css('tbody')
      tbody = doc.create_element('tbody')
      data_rows.each { |row| tbody.add_child(row.dup) }
      table.add_child(tbody)
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


  def clear_all_cache
    log_section("🧹 Clearing All Cache (Force Mode)")

    # Clear page fetcher caches
    js_cleared = @page_fetcher.cache_clear(namespace: 'js')
    no_js_cleared = @page_fetcher.cache_clear(namespace: 'no_js')

    # Clear image processor cache
    if @options[:download_images]
      image_cache_dir = File.join(Dir.tmpdir, 'epub_images')
      if Dir.exist?(image_cache_dir)
        image_count = Dir.glob(File.join(image_cache_dir, '*')).size
        FileUtils.rm_rf(image_cache_dir)
        FileUtils.mkdir_p(image_cache_dir)
        log_info("Cleared #{image_count} cached images")
      end
    end

    log_success("Cache cleared - JS: #{js_cleared} files, No-JS: #{no_js_cleared} files")
  end

end