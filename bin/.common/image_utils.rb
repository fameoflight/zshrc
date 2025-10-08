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

  # Icon drawing utilities
  module Icons
    # Draw a modern-style icon with layered design
    # @param canvas [ChunkyPNG::Canvas] Target canvas
    # @param size [Integer] Icon size
    # @param accent_color [Integer] ChunkyPNG color value
    def self.draw_modern_icon(canvas, size, accent_color)
      margin = size / 8
      center = size / 2

      # Outer square
      outer_size = size - margin * 2
      PNG.draw_rect(canvas, margin, margin, outer_size, outer_size, accent_color, 3)

      # Inner square with gradient effect
      inner_size = outer_size * 0.7
      inner_offset = (outer_size - inner_size) / 2
      inner_x = margin + inner_offset
      inner_y = margin + inner_offset

      # Create gradient by drawing multiple rectangles with decreasing opacity
      10.times do |i|
        alpha = 255 * (i / 10.0)
        color = PNG.with_alpha(accent_color, alpha.to_i)
        offset = i * 2
        PNG.draw_rect(canvas, inner_x - offset, inner_y - offset,
                              inner_size + offset * 2, inner_size + offset * 2, color, 2)
      end

      # Central circle
      symbol_size = size / 4
      PNG.draw_circle(canvas, center, center, symbol_size / 2, accent_color, 3)

      # Center dot
      dot_size = size / 16
      PNG.draw_circle(canvas, center, center, dot_size, accent_color, :fill)

      # Corner accents
      accent_size = size / 12
      accents = [
        [margin + accent_size, margin + accent_size],
        [size - margin - accent_size, margin + accent_size],
        [margin + accent_size, size - margin - accent_size],
        [size - margin - accent_size, size - margin - accent_size]
      ]

      accents.each do |x, y|
        PNG.draw_rect(canvas, x - accent_size/4, y - accent_size/4,
                              accent_size/2, accent_size/2, accent_color, :fill)
      end
    end

    # Draw a minimal-style icon with simple circle design
    # @param canvas [ChunkyPNG::Canvas] Target canvas
    # @param size [Integer] Icon size
    # @param accent_color [Integer] ChunkyPNG color value
    def self.draw_minimal_icon(canvas, size, accent_color)
      margin = size / 8
      center = size / 2

      # Main circle
      circle_size = size - margin * 2
      PNG.draw_circle(canvas, center, center, circle_size / 2, accent_color, 4)

      # Center square
      center_size = size / 3
      center_x = center - center_size / 2
      center_y = center - center_size / 2
      PNG.draw_rect(canvas, center_x, center_y, center_size, center_size, accent_color, :fill)
    end

    # Convert SVG to PNG with optional color filtering
    # @param svg_path [String] Path to input SVG file
    # @param output_path [String] Path for output PNG file
    # @param size [Integer] Target size
    # @param variant [Symbol] Color variant (:normal, :dark, :tinted)
    # @return [Boolean] True if conversion succeeded
    def self.convert_svg_to_png(svg_path, output_path, size, variant = :normal)
      require 'securerandom'
      require 'fileutils'
      require 'tmpdir'

      # First convert SVG to PNG
      temp_png = File.join(Dir.tmpdir, "temp_#{SecureRandom.hex(8)}.png")

      unless SVG.convert_to_png(svg_path, temp_png, size, size)
        return false
      end

      # Apply color filters for dark/tinted variants
      if variant != :normal
        apply_color_filter(temp_png, output_path, variant)
      else
        # Just move the file for normal variant
        FileUtils.mv(temp_png, output_path)
      end

      # Clean up temporary file
      File.delete(temp_png) if File.exist?(temp_png)
      true
    end

    # Apply color filter to PNG image
    # @param input_path [String] Input PNG file path
    # @param output_path [String] Output PNG file path
    # @param variant [Symbol] Color variant (:normal, :dark, :tinted)
    def self.apply_color_filter(input_path, output_path, variant)
      require 'fileutils'

      case variant
      when :dark
        # Apply dark mode filter using ImageMagick
        command = ['convert', input_path, '-modulate', '80,50,100', output_path]
      when :tinted
        # Apply tinted filter - add blue tint and reduce saturation
        command = ['convert', input_path, '-modulate', '90,70,100', '-fill', '#4A90E2', '-colorize', '20%', output_path]
      else
        # No filter, just copy
        FileUtils.cp(input_path, output_path)
        return
      end

      unless system(*command)
        raise "Failed to apply color filter for #{variant}"
      end
    end

    # Create modified SVG with color filters
    # @param original_svg [String] Path to original SVG file
    # @param variant [Symbol] Color variant (:normal, :dark, :tinted)
    # @return [String] Path to temporary modified SVG file
    def self.create_modified_svg(original_svg, variant)
      require 'securerandom'
      require 'tmpdir'

      # Read the original SVG content
      svg_content = File.read(original_svg)

      case variant
      when :dark
        # Apply dark mode filter - make colors darker
        if svg_content.include?('<defs>')
          # Insert filter inside existing defs section
          modified_svg = svg_content.sub(
            /(<defs>)/,
            '\1<filter id="dark-mode"><feColorMatrix type="matrix" values="0.3 0 0 0.2 0 0.3 0 0 0.2 0 0 0.3 0 0.2 0 0 0 0.5 0.5"/></filter>'
          )
        else
          # Add defs section with filter
          modified_svg = svg_content.sub(
            /<svg([^>]*)>/,
            '<svg\1><defs><filter id="dark-mode"><feColorMatrix type="matrix" values="0.3 0 0 0.2 0 0.3 0 0 0.2 0 0 0.3 0 0.2 0 0 0 0.5 0.5"/></filter></defs>'
          )
        end
        # Wrap content in a filtered group (after defs section)
        modified_svg = modified_svg.sub(
          /(<\/defs>)(.*)/m,
          '\1<g filter="url(#dark-mode)">\2</g>'
        )
      when :tinted
        # Apply tinted mode filter - add a blue tint
        if svg_content.include?('<defs>')
          # Insert filter inside existing defs section
          modified_svg = svg_content.sub(
            /(<defs>)/,
            '\1<filter id="tint-mode"><feColorMatrix type="matrix" values="0.8 0 0 0.3 0 0.6 0 0 0.4 0 0 0.4 0 0 0.5 0 0 0 0.7 0.6"/></filter>'
          )
        else
          # Add defs section with filter
          modified_svg = svg_content.sub(
            /<svg([^>]*)>/,
            '<svg\1><defs><filter id="tint-mode"><feColorMatrix type="matrix" values="0.8 0 0 0.3 0 0.6 0 0 0.4 0 0 0.4 0 0 0.5 0 0 0 0.7 0.6"/></filter></defs>'
          )
        end
        # Wrap content in a filtered group (after defs section)
        modified_svg = modified_svg.sub(
          /(<\/defs>)(.*)/m,
          '\1<g filter="url(#tint-mode)">\2</g>'
        )
      else
        modified_svg = svg_content
      end

      # Create temporary file
      temp_file = File.join(Dir.tmpdir, "temp_#{variant}_#{SecureRandom.hex(8)}.svg")
      File.write(temp_file, modified_svg)
      temp_file
    end
  end

  # Logo drawing utilities (simplified versions for in-app use)
  module Logos
    # Draw a modern-style logo with simpler design for in-app use
    # @param canvas [ChunkyPNG::Canvas] Target canvas
    # @param size [Integer] Logo size
    # @param accent_color [Integer] ChunkyPNG color value
    def self.draw_modern_logo(canvas, size, accent_color)
      # Similar to modern icon but simpler for in-app use
      margin = size / 10
      center = size / 2

      # Outer square
      outer_size = size - margin * 2
      PNG.draw_rect(canvas, margin, margin, outer_size, outer_size, accent_color, 4)

      # Inner element
      inner_size = outer_size * 0.6
      inner_x = margin + (outer_size - inner_size) / 2
      inner_y = margin + (outer_size - inner_size) / 2
      PNG.draw_rect(canvas, inner_x, inner_y, inner_size, inner_size, accent_color, :fill)
    end

    # Draw a minimal-style logo with simple circle design for in-app use
    # @param canvas [ChunkyPNG::Canvas] Target canvas
    # @param size [Integer] Logo size
    # @param accent_color [Integer] ChunkyPNG color value
    def self.draw_minimal_logo(canvas, size, accent_color)
      # Minimal circular logo
      center = size / 2
      radius = size / 3

      PNG.draw_circle(canvas, center, center, radius, accent_color, 4)
    end
  end
end