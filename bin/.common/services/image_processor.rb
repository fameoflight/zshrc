#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'fastimage'
require 'fileutils'
require 'base64'
require 'securerandom'
require 'nokogiri'
require 'digest'
require_relative 'base_service'

# Image processing service for downloading and embedding images in EPUBs
class ImageProcessor < BaseService
  def initialize(options = {})
    super(options)
    @options = {
      download_images: true,
      max_image_size: 5 * 1024 * 1024, # 5MB
      timeout: 30,
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      cache_dir: File.join(Dir.tmpdir, 'epub_images'),
      verbose: false
    }.merge(options)

    @image_cache = {}
    @downloaded_images = {}

    # Create cache directory
    FileUtils.mkdir_p(@options[:cache_dir]) if @options[:download_images]
  end

  # Process HTML content to download and embed images
  def process_html_content(html_content, base_url)
    return html_content unless @options[:download_images]

    doc = Nokogiri::HTML::DocumentFragment.parse(html_content)

    # Process all img tags
    doc.search('img').each do |img|
      next unless img['src']

      original_src = img['src']
      processed_image = process_image(original_src, base_url)

      if processed_image
        img['src'] = processed_image[:src]
        img['width'] = processed_image[:width] if processed_image[:width]
        img['height'] = processed_image[:height] if processed_image[:height]
        img['alt'] = processed_image[:alt] || img['alt'] || 'Article image'
      else
        # If image processing failed, keep original but add error alt text
        img['alt'] = img['alt'] || 'Image could not be loaded'
      end
    end

    # Process picture elements and source tags
    doc.search('picture source').each do |source|
      next unless source['srcset']

      # Process srcset to handle multiple image sources
      if source['srcset']
        processed_srcset = process_srcset(source['srcset'], base_url)
        source['srcset'] = processed_srcset if processed_srcset
      end
    end

    doc.to_html
  end

  private

  # Process a single image
  def process_image(src, base_url)
    return nil unless src && !src.empty?

    # Skip data URLs (already embedded)
    return { src: src } if src.start_with?('data:')

    # Resolve relative URL
    absolute_url = resolve_url(src, base_url)
    return nil unless absolute_url

    # Check cache first
    cache_key = Digest::SHA256.hexdigest(absolute_url)
    if @image_cache[cache_key]
      puts "🖼️  Using cached image: #{absolute_url}" if @options[:verbose]
      return @image_cache[cache_key]
    end

    # Download image
    image_data = download_image(absolute_url)
    return nil unless image_data

    # Get image dimensions
    dimensions = get_image_dimensions(image_data)

    # Convert to data URL
    data_url = create_data_url(image_data, absolute_url)

    result = {
      src: data_url,
      width: dimensions[:width],
      height: dimensions[:height],
      alt: extract_alt_text_from_url(absolute_url)
    }

    # Cache result
    @image_cache[cache_key] = result

    puts "✅ Processed image: #{absolute_url} (#{dimensions[:width]}x#{dimensions[:height]})" if @options[:verbose]

    result
  rescue => e
    puts "⚠️  Failed to process image #{absolute_url}: #{e.message}" if @options[:verbose]
    nil
  end

  # Process srcset attribute (responsive images)
  def process_srcset(srcset, base_url)
    return nil unless srcset

    processed_parts = srcset.split(',').map do |part|
      part.strip!
      url_part, descriptor = part.split(/\s+/, 2)

      # Process the URL part
      processed_image = process_image(url_part, base_url)
      next nil unless processed_image

      # Reconstruct with descriptor if present
      descriptor ? "#{processed_image[:src]} #{descriptor}" : processed_image[:src]
    end.compact

    processed_parts.empty? ? nil : processed_parts.join(', ')
  end

  # Download image from URL
  def download_image(url)
    return nil if @downloaded_images[url]

    puts "📥 Downloading image: #{url}" if @options[:verbose]

    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = @options[:timeout]
      http.open_timeout = @options[:timeout]

      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = @options[:user_agent]
      request['Accept'] = 'image/webp,image/apng,image/*,*/*;q=0.8'
      request['Accept-Encoding'] = 'gzip, deflate'

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        puts "❌ Failed to download image: #{response.code} #{response.message}" if @options[:verbose]
        return nil
      end

      # Check content type
      content_type = response['content-type']
      return nil unless content_type&.start_with?('image/')

      # Check file size
      content_length = response['content-length']&.to_i
      if content_length && content_length > @options[:max_image_size]
        puts "⚠️  Image too large (#{content_length} bytes), skipping: #{url}" if @options[:verbose]
        return nil
      end

      image_data = response.body

      # Double-check actual size
      if image_data.bytesize > @options[:max_image_size]
        puts "⚠️  Image too large (#{image_data.bytesize} bytes), skipping: #{url}" if @options[:verbose]
        return nil
      end

      # Cache downloaded image
      @downloaded_images[url] = image_data

      puts "✅ Downloaded image: #{url} (#{image_data.bytesize} bytes)" if @options[:verbose]

      image_data
    rescue => e
      puts "❌ Error downloading image #{url}: #{e.message}" if @options[:verbose]
      nil
    end
  end

  # Get image dimensions using FastImage
  def get_image_dimensions(image_data)
    begin
      dimensions = FastImage.new(image_data, raise_on_failure: true)
      { width: dimensions.size[0], height: dimensions.size[1] }
    rescue => e
      puts "⚠️  Could not get image dimensions: #{e.message}" if @options[:verbose]
      { width: nil, height: nil }
    end
  end

  # Convert image data to data URL
  def create_data_url(image_data, url)
    content_type = determine_content_type(image_data, url)
    base64_data = Base64.strict_encode64(image_data)
    "data:#{content_type};base64,#{base64_data}"
  end

  # Determine content type from image data or URL
  def determine_content_type(image_data, url)
    # Try to get from FastImage first
    begin
      type = FastImage.type(image_data)
      case type
      when :jpeg then 'image/jpeg'
      when :png then 'image/png'
      when :gif then 'image/gif'
      when :bmp then 'image/bmp'
      when :tiff then 'image/tiff'
      when :webp then 'image/webp'
      when :ico then 'image/x-icon'
      when :svg then 'image/svg+xml'
      else 'image/jpeg' # fallback
      end
    rescue
      # Fallback to URL extension
      extension = File.extname(url).downcase
      case extension
      when '.jpg', '.jpeg' then 'image/jpeg'
      when '.png' then 'image/png'
      when '.gif' then 'image/gif'
      when '.webp' then 'image/webp'
      when '.svg' then 'image/svg+xml'
      when '.bmp' then 'image/bmp'
      when '.ico' then 'image/x-icon'
      else 'image/jpeg' # fallback
      end
    end
  end

  # Extract alt text from URL or generate generic one
  def extract_alt_text_from_url(url)
    filename = File.basename(URI.parse(url).path)
    filename = File.basename(filename, File.extname(filename))

    # Clean up filename
    filename.gsub(/[-_]/, ' ').gsub(/\b\w/, &:capitalize).strip
  rescue
    'Article image'
  end

  # Resolve relative URL to absolute URL
  def resolve_url(url, base_url)
    return url if url.nil? || url.empty?
    return url if url.start_with?('data:') # Data URLs don't need resolution

    begin
      # Already absolute URL
      return url if url.start_with?('http://', 'https://', '//')

      # Resolve relative to base URL
      base_uri = URI(base_url)
      absolute_url = URI.join(base_uri.to_s, url).to_s

      # Clean up any potential double slashes in path
      absolute_url.gsub(/([^:])\/{2,}/, '\1/')
    rescue URI::InvalidURIError
      url # Return original if resolution fails
    end
  end
end