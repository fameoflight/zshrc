# frozen_string_literal: true

require 'uri'

# Concern for detecting if a page is likely an article
module ArticleDetector
  # Article detection patterns and scoring
  ARTICLE_INDICATORS = {
    # URL patterns (higher scores for more specific patterns)
    url_patterns: {
      /\/post\/|\/posts\/|\/article\/|\/articles\//i => 15,
      /^https?:\/\/blog\./i => 15,  # blog.domain.com style URLs
      /\/blog\/|\/blogs\//i => 12,
      /\/\d{4}\/\d{2}\/|\/\d{4}-\d{2}-\d{2}/i => 10,  # Date patterns
      /\/read\/|\/story\/|\/stories\//i => 10,
      /\/news\/|\/opinion\/|\/essay\//i => 8,
      /\/p\//i => 5,  # Medium-style short paths
      /^https?:\/\/[^\/]+\/[^\/]+$/ => 8  # domain.com/article-title pattern
    },

    # HTML structure indicators
    html_patterns: {
      /<article[^>]*>/i => 15,
      /<div[^>]*class="[^"]*post[^"]*"[^>]*>/i => 12,
      /<div[^>]*class="[^"]*article[^"]*"[^>]*>/i => 12,
      /<div[^>]*class="[^"]*entry[^"]*"[^>]*>/i => 10,
      /<div[^>]*class="[^"]*content[^"]*"[^>]*>/i => 8,
      /<time[^>]*>/i => 8,
      /<div[^>]*class="[^"]*author[^"]*"[^>]*>/i => 6,
      /<meta[^>]*property="article:|<meta[^>]*name="article:/i => 10
    },

    # Content indicators
    content_patterns: {
      /\b(by\s+[A-Z][a-z]+\s+[A-Z][a-z]+|author:|written\s+by)\b/i => 8,
      /\b(published|posted|updated)[\s:]+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/i => 10,
      /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+\d{4}/i => 8,
      /\d{1,2}\s+(minute|min|hour|hr)s?\s+(read|ago)/i => 6,
      /\b(share|tweet|facebook|linkedin|reddit)\b/i => 4
    },

    # Title/heading patterns
    title_patterns: {
      /^(how\s+to|why|what|when|where|the\s+\d+|top\s+\d+)/i => 5,
      /[\?\!]$/ => 3,
      /:\s*[A-Z]/ => 3  # Subtitle pattern
    }
  }

  # Negative indicators (subtract points)
  NON_ARTICLE_INDICATORS = {
    url_patterns: {
      /\/(home|index|about|contact|privacy|terms|search|tag|tags|category|categories|archive)[\/$]/i => -10,
      /\/(api|admin|login|signup|register|dashboard|logout)[\/$]/i => -15,
      /\.(css|js|json|xml|rss|atom|pdf|jpg|png|gif|svg)$/i => -20,
      /\/page\/\d+/i => -8,  # Pagination
      # Strong negative for root URLs and archive pages
      /^https?:\/\/[^\/]+\/?$/i => -25,  # Root URL with no path
      /\/(archive|all-posts|blog|posts)[\/$]?$/i => -20,  # Archive pages
      /\/archive\?/i => -30,  # Archive pages with query parameters (stronger negative)
      /[?&]date=/i => -25,  # URLs with date parameters (likely archives/filters)
      /posthaven/i => -25,  # Posthaven internal URLs
      /logout|login|signin|signup/i => -25  # Authentication URLs
    },

    html_patterns: {
      /<nav[^>]*>/i => -3,
      /<footer[^>]*>/i => -2,
      /<form[^>]*>/i => -5,
      /<input[^>]*type="search"/i => -8,
      # Archive/index page indicators
      /<div[^>]*class="[^"]*(archive|blogroll|post-list|article-list)[^"]*"[^>]*>/i => -15,
      /<h[1-6][^>]*>.*?\b(all posts|archive|blog|recent posts)\b.*?<\/h[1-6]>/i => -12,
      /<div[^>]*class="[^"]*(pagination|page-nav)[^"]*"[^>]*>/i => -10
    },

    content_patterns: {
      # Only match obvious error page indicators
      /<title[^>]*>.*?\b(404|not\s+found|error)\b.*?<\/title>/i => -20,
      /<h[1-6][^>]*>.*?\b(404|not\s+found|page\s+not\s+found)\b.*?<\/h[1-6]>/i => -15,
      /<title[^>]*>.*?\b(search\s+results|no\s+results)\b.*?<\/title>/i => -15,
      # Archive/index page content indicators
      /\b(all posts|view all posts|post archive|blog archive)\b/i => -12,
      /\b(recent posts|latest posts|previous posts)\b/i => -8,
      /\b(continue reading|read more)\s+→\s*$/m => -5  # Multiple "read more" links
    }
  }

  # Minimum content length for articles (in characters)
  MIN_ARTICLE_LENGTH = 500
  
  # Minimum score to consider something an article
  MIN_ARTICLE_SCORE = 15

  def self.analyze_page(page_data)
    return nil unless page_data && page_data[:content]

    score = 0
    details = {
      url_score: 0,
      html_score: 0,
      content_score: 0,
      title_score: 0,
      length_score: 0,
      negative_score: 0,
      indicators_found: [],
      negative_indicators: []
    }

    url = page_data[:url] || page_data[:final_url] || ''
    content = page_data[:content] || ''
    title = page_data[:title] || ''

    # Analyze URL patterns
    details[:url_score] = analyze_patterns(url, ARTICLE_INDICATORS[:url_patterns], details[:indicators_found], 'URL')
    
    # Analyze HTML structure
    details[:html_score] = analyze_patterns(content, ARTICLE_INDICATORS[:html_patterns], details[:indicators_found], 'HTML')
    
    # Analyze content patterns
    details[:content_score] = analyze_patterns(content, ARTICLE_INDICATORS[:content_patterns], details[:indicators_found], 'Content')
    
    # Analyze title patterns
    details[:title_score] = analyze_patterns(title, ARTICLE_INDICATORS[:title_patterns], details[:indicators_found], 'Title')

    # Content length scoring
    content_length = extract_text_content(content).length
    if content_length >= MIN_ARTICLE_LENGTH
      length_bonus = [content_length / 200, 10].min  # Max 10 points for length
      details[:length_score] = length_bonus
      details[:indicators_found] << "Content length: #{content_length} chars (+#{length_bonus})"
    else
      details[:length_score] = -5
      details[:negative_indicators] << "Content too short: #{content_length} chars (-5)"
    end

    # Check negative indicators
    details[:negative_score] += analyze_negative_patterns(url, NON_ARTICLE_INDICATORS[:url_patterns], details[:negative_indicators], 'URL')
    details[:negative_score] += analyze_negative_patterns(content, NON_ARTICLE_INDICATORS[:html_patterns], details[:negative_indicators], 'HTML')
    details[:negative_score] += analyze_negative_patterns(content, NON_ARTICLE_INDICATORS[:content_patterns], details[:negative_indicators], 'Content')

    # Calculate total score
    total_score = details.values_at(:url_score, :html_score, :content_score, :title_score, :length_score, :negative_score).sum

    {
      url: url,
      title: title,
      score: total_score,
      is_article: total_score >= MIN_ARTICLE_SCORE,
      confidence: calculate_confidence(total_score),
      content_length: content_length,
      details: details
    }
  end

  def self.batch_analyze(pages_data, progress: true)
    require 'tty-progressbar' if progress

    results = []
    
    if progress
      bar = TTY::ProgressBar.new("🔍 [:bar] :percent Analyzing articles (:current/:total)", 
                                total: pages_data.size,
                                width: 20,
                                incomplete: '·',
                                complete: '█')
    end

    pages_data.each do |page_data|
      bar&.advance(1)
      result = analyze_page(page_data)
      results << result if result
    end

    bar&.finish
    
    articles = results.select { |r| r[:is_article] }
    non_articles = results.reject { |r| r[:is_article] }
    
    if progress
      puts "\n📊 Analysis complete:"
      puts "   ✅ Articles found: #{articles.size}"
      puts "   ❌ Non-articles: #{non_articles.size}"
      puts "   📈 Article ratio: #{(articles.size.to_f / results.size * 100).round(1)}%"
    end

    {
      articles: articles,
      non_articles: non_articles,
      total_analyzed: results.size,
      article_ratio: articles.size.to_f / results.size
    }
  end

  def self.filter_article_urls(urls, page_fetcher, javascript: false)
    # Pre-filter URLs based on URL patterns alone (before fetching)
    potentially_good_urls = urls.select { |url| url_looks_like_article?(url) }
    
    puts "🔍 URL pre-filtering: #{urls.size} total → #{potentially_good_urls.size} potentially good URLs"
    
    if potentially_good_urls.empty?
      puts "⚠️  No potentially good URLs found after pre-filtering"
      return []
    end
    
    # Fetch pages in batches (only the pre-filtered ones)
    pages_data = page_fetcher.fetch_pages(potentially_good_urls, javascript: javascript)
    
    # Only analyze pages that were successfully fetched
    valid_pages = pages_data.select { |url, data| data }.values
    
    # Analyze for articles
    analysis = batch_analyze(valid_pages)
    
    # Return just the article URLs
    analysis[:articles].map { |article| article[:url] }
  end
  
  # Quick URL-only check to filter out obviously bad URLs before fetching
  def self.url_looks_like_article?(url)
    return false unless url && !url.empty?
    
    # Calculate score based only on URL patterns
    url_score = 0
    negative_score = 0
    
    # Check positive URL patterns
    ARTICLE_INDICATORS[:url_patterns].each do |pattern, points|
      url_score += points if url.match?(pattern)
    end
    
    # Check negative URL patterns  
    NON_ARTICLE_INDICATORS[:url_patterns].each do |pattern, points|
      negative_score += points if url.match?(pattern)  # points are already negative
    end
    
    total_score = url_score + negative_score
    
    # More strict threshold for URL-only filtering 
    total_score > -10
  end

  
  private

  def self.analyze_patterns(text, patterns, indicators_list, category)
    score = 0
    return score unless text && !text.empty?
    
    # Ensure text is properly encoded and valid
    text = clean_text_encoding(text)
    return score if text.empty?
    
    patterns.each do |pattern, points|
      begin
        if text.match?(pattern)
          score += points
          indicators_list << "#{category}: #{pattern.source} (+#{points})"
        end
      rescue Encoding::CompatibilityError, ArgumentError => e
        # Skip this pattern if there's an encoding issue
        next
      end
    end
    score
  end

  def self.analyze_negative_patterns(text, patterns, indicators_list, category)
    score = 0
    return score unless text && !text.empty?
    
    # Ensure text is properly encoded and valid
    text = clean_text_encoding(text)
    return score if text.empty?
    
    patterns.each do |pattern, points|
      begin
        if text.match?(pattern)
          score += points  # points are already negative
          indicators_list << "#{category}: #{pattern.source} (#{points})"
        end
      rescue Encoding::CompatibilityError, ArgumentError => e
        # Skip this pattern if there's an encoding issue
        next
      end
    end
    score
  end

  def self.extract_text_content(html)
    # Clean encoding first
    html = clean_text_encoding(html)
    return '' if html.empty?
    
    begin
      # Simple text extraction (removes HTML tags)
      text = html.gsub(/<script[^>]*>.*?<\/script>/mi, '')
                 .gsub(/<style[^>]*>.*?<\/style>/mi, '')
                 .gsub(/<[^>]+>/, ' ')
                 .gsub(/\s+/, ' ')
                 .strip
      text
    rescue ArgumentError, Encoding::CompatibilityError => e
      # If regex fails due to encoding, return empty string
      ''
    end
  end

  def self.calculate_confidence(score)
    case score
    when 30.. then 'very_high'
    when 20..29 then 'high'  
    when 15..19 then 'medium'
    when 10..14 then 'low'
    when 5..9 then 'very_low'
    else 'none'
    end
  end

  # Clean text encoding for pattern matching
  def self.clean_text_encoding(text)
    return '' unless text
    
    # Convert to string
    text = text.to_s
    
    # If it's already valid UTF-8, return as-is
    return text if text.encoding == Encoding::UTF_8 && text.valid_encoding?
    
    begin
      # Try to clean up encoding issues
      if text.encoding != Encoding::UTF_8
        text = text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      else
        text = text.scrub('?')
      end
      
      # Final check and cleanup if still invalid
      unless text.valid_encoding?
        text = text.force_encoding('UTF-8').scrub('?')
      end
      
    rescue Encoding::CompatibilityError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      # Fallback: force UTF-8 and scrub
      text = text.force_encoding('UTF-8').scrub('?')
    end
    
    text
  end
end