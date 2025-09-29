# frozen_string_literal: true

# Image utilities for various image processing tasks
module ImageUtils
  # SVG to PNG conversion utilities
  module SVG
    # Check if SVG conversion tools are available
    def self.conversion_tool_available?
      system('which rsvg-convert > /dev/null 2>&1') || system('which convert > /dev/null 2>&1')
    end

    # Convert SVG to PNG with specified dimensions
    # @param svg_path [String] Path to input SVG file
    # @param output_path [String] Path for output PNG file
    # @param width [Integer] Target width in pixels
    # @param height [Integer] Target height in pixels (optional, defaults to width)
    # @return [Boolean] True if conversion succeeded
    def self.convert_to_png(svg_path, output_path, width, height = width)
      # Try rsvg-convert first (librsvg)
      if system('which rsvg-convert > /dev/null 2>&1')
        command = ['rsvg-convert', '-w', width.to_s, '-h', height.to_s, '-o', output_path, svg_path]
        result = system(*command)
        return true if result
      end

      # Fall back to ImageMagick convert
      if system('which convert > /dev/null 2>&1')
        command = ['convert', svg_path, '-resize', "#{width}x#{height}", output_path]
        result = system(*command)
        return true if result
      end

      false
    end

    # Validate SVG file
    # @param svg_path [String] Path to SVG file
    # @return [Boolean] True if file exists and is valid SVG
    def self.valid_svg?(svg_path)
      return false unless File.exist?(svg_path)
      return false unless svg_path.downcase.end_with?('.svg')

      # Basic validation - check if it contains SVG-related content
      content = File.read(svg_path, encoding: 'UTF-8', &:read)
      content.include?('<svg') && content.include?('xmlns=')
    rescue StandardError
      false
    end

    # Get available conversion tools
    # @return [Array<String>] List of available tools
    def self.available_tools
      tools = []
      tools << 'rsvg-convert' if system('which rsvg-convert > /dev/null 2>&1')
      tools << 'ImageMagick' if system('which convert > /dev/null 2>&1')
      tools
    end
  end

  # Image manipulation utilities using ChunkyPNG
  module PNG
    require 'chunky_png'

    # Parse hex color to ChunkyPNG color
    # @param hex_color [String] Hex color (with or without #)
    # @return [Integer] ChunkyPNG color value
    def self.parse_color(hex_color)
      # Remove # if present
      hex = hex_color.sub(/^#/, '')

      # Parse hex color
      r = hex[0..1].to_i(16)
      g = hex[2..3].to_i(16)
      b = hex[4..5].to_i(16)

      ChunkyPNG::Color.rgba(r, g, b, 255)
    end

    # Add alpha channel to color
    # @param color [Integer] ChunkyPNG color
    # @param alpha [Integer] Alpha value (0-255)
    # @return [Integer] ChunkyPNG color with alpha
    def self.with_alpha(color, alpha)
      r = ChunkyPNG::Color.r(color)
      g = ChunkyPNG::Color.g(color)
      b = ChunkyPNG::Color.b(color)
      ChunkyPNG::Color.rgba(r, g, b, alpha)
    end

    # Create a new canvas with specified dimensions and background color
    # @param width [Integer] Canvas width
    # @param height [Integer] Canvas height
    # @param color [String, Integer] Background color (hex string or ChunkyPNG color)
    # @return [ChunkyPNG::Canvas] New canvas
    def self.create_canvas(width, height, color = '#FFFFFF')
      bg_color = color.is_a?(String) ? parse_color(color) : color
      ChunkyPNG::Canvas.new(width, height, bg_color)
    end

    # Draw a rectangle on canvas
    # @param canvas [ChunkyPNG::Canvas] Target canvas
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param width [Integer] Rectangle width
    # @param height [Integer] Rectangle height
    # @param color [String, Integer] Color (hex string or ChunkyPNG color)
    # @param thickness [Integer, Symbol] Border thickness or :fill for filled rectangle
    def self.draw_rect(canvas, x, y, width, height, color, thickness = 1)
      fill_color = color.is_a?(String) ? parse_color(color) : color

      # Convert to integers to avoid Float iteration issues
      x_int = x.to_i
      y_int = y.to_i
      width_int = width.to_i
      height_int = height.to_i

      if thickness == :fill
        (x_int...(x_int + width_int)).each do |px|
          (y_int...(y_int + height_int)).each do |py|
            canvas[px, py] = fill_color if canvas.include?(px, py)
          end
        end
      else
        # Top border
        (x_int...(x_int + width_int)).each { |px| canvas[px, y_int] = fill_color if canvas.include?(px, y_int) }
        # Bottom border
        (x_int...(x_int + width_int)).each { |px| canvas[px, y_int + height_int - 1] = fill_color if canvas.include?(px, y_int + height_int - 1) }
        # Left border
        (y_int...(y_int + height_int)).each { |py| canvas[x_int, py] = fill_color if canvas.include?(x_int, py) }
        # Right border
        (y_int...(y_int + height_int)).each { |py| canvas[x_int + width_int - 1, py] = fill_color if canvas.include?(x_int + width_int - 1, py) }
      end
    end

    # Draw a circle on canvas
    # @param canvas [ChunkyPNG::Canvas] Target canvas
    # @param center_x [Integer] Center X coordinate
    # @param center_y [Integer] Center Y coordinate
    # @param radius [Integer] Circle radius
    # @param color [String, Integer] Color (hex string or ChunkyPNG color)
    # @param thickness [Integer, Symbol] Border thickness or :fill for filled circle
    def self.draw_circle(canvas, center_x, center_y, radius, color, thickness = 1)
      fill_color = color.is_a?(String) ? parse_color(color) : color

      # Convert to integers to avoid Float iteration issues
      center_x_int = center_x.to_i
      center_y_int = center_y.to_i
      radius_int = radius.to_i

      if thickness == :fill
        (center_x_int - radius_int...center_x_int + radius_int).each do |x|
          (center_y_int - radius_int...center_y_int + radius_int).each do |y|
            if Math.sqrt((x - center_x)**2 + (y - center_y)**2) <= radius
              canvas[x, y] = fill_color if canvas.include?(x, y)
            end
          end
        end
      else
        # Draw circle outline
        (0...360).each do |angle|
          rad = angle * Math::PI / 180
          x = center_x + radius * Math.cos(rad)
          y = center_y + radius * Math.sin(rad)
          canvas[x.to_i, y.to_i] = fill_color if canvas.include?(x.to_i, y.to_i)
        end
      end
    end
  end

  # General image utilities
  module General
    # Get image dimensions
    # @param image_path [String] Path to image file
    # @return [Hash] Hash with :width and :height keys
    def self.get_dimensions(image_path)
      if image_path.downcase.end_with?('.png')
        # Use ChunkyPNG for PNG files
        image = ChunkyPNG::Image.from_file(image_path)
        { width: image.width, height: image.height }
      else
        # Use ImageMagick identify for other formats
        result = `identify -format "%wx%h" "#{image_path}" 2>/dev/null`.chomp
        if result.match?(/^\d+x\d+$/)
          width, height = result.split('x').map(&:to_i)
          { width: width, height: height }
        else
          { width: 0, height: 0 }
        end
      end
    rescue StandardError
      { width: 0, height: 0 }
    end

    # Resize image
    # @param input_path [String] Input image path
    # @param output_path [String] Output image path
    # @param width [Integer] Target width
    # @param height [Integer] Target height (optional, maintains aspect ratio if nil)
    # @return [Boolean] True if resize succeeded
    def self.resize(input_path, output_path, width, height = nil)
      if height.nil?
        command = "convert \"#{input_path}\" -resize #{width} \"#{output_path}\""
      else
        command = "convert \"#{input_path}\" -resize #{width}x#{height} \"#{output_path}\""
      end
      system(command)
    end

    # Check if image file is valid
    # @param image_path [String] Path to image file
    # @return [Boolean] True if file exists and is a valid image
    def self.valid_image?(image_path)
      return false unless File.exist?(image_path)

      # Try to get dimensions as a basic validation
      dims = get_dimensions(image_path)
      dims[:width] > 0 && dims[:height] > 0
    end
  end
end