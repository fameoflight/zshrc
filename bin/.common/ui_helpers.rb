# frozen_string_literal: true

require 'pastel'
require 'tty-table'
require 'tty-box'
require 'tty-font'

# UI Helper methods for common TTY components
# Provides wrapper functions for pastel, tty-table, and other common UI elements
module UIHelpers
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Initialize UI components once for the class
    def setup_ui_helpers
      @pastel ||= Pastel.new
      @ui_initialized = true
    end

    def pastel
      setup_ui_helpers unless @ui_initialized
      @pastel
    end
  end

  # Instance methods available in classes that include this module
  def pastel
    @pastel ||= Pastel.new
  end

  # Safe pastel decorator with fallback
  def safe_decorate(text, *styles)
    begin
      log_debug("Decorating text: '#{text[0..50]}...' with styles: #{styles}")
      result = pastel.decorate(text.to_s, *styles)
      log_debug("Decoration successful")
      result
    rescue StandardError => e
      log_debug("Pastel decoration failed: #{e.message}, using plain text")
      text.to_s
    end
  end

  # Create a beautiful header with large font and fallback
  def create_header(title, color: :cyan)
    log_debug("Creating header: '#{title}' with color: #{color}")
    begin
      font = TTY::Font.new(:doom)
      font_text = font.write(title.upcase)
      log_debug("Font created successfully, applying color")
      safe_decorate(font_text, color)
    rescue StandardError => e
      log_debug("Font creation failed: #{e.message}, using fallback")
      # Fallback to simple decorated text
      safe_decorate("🎯 #{title.upcase}", color, :bold)
    end
  end

  # Create a framed box with content
  def create_box(content, title: nil, color: :green, padding: 1, border: :thick)
    log_debug("Creating box with title: '#{title}', color: #{color}")
    begin
      box_options = {
        padding: padding,
        border: border,
        style: { border: { fg: color } }
      }
      
      box_options[:title] = { top_center: title } if title
      
      TTY::Box.frame(**box_options) do
        safe_decorate(content, color)
      end
    rescue StandardError => e
      log_debug("Box creation failed: #{e.message}, using simple output")
      # Fallback to simple bordered text
      border_char = case border
                   when :thick then '━'
                   when :double then '═' 
                   else '─'
                   end
      
      width = [content.length + 4, 50].max
      lines = []
      lines << border_char * width
      lines << "#{border_char} #{title} #{border_char}" if title
      lines << border_char * width if title
      lines << "#{border_char} #{content} #{border_char}"
      lines << border_char * width
      lines.join("\n")
    end
  end

  # Create a table with safe rendering
  def create_table(headers, data, style: :unicode, padding: [0, 1])
    log_debug("Creating table with #{headers.length} headers and #{data.length} rows")
    begin
      # Safely decorate headers
      safe_headers = headers.map.with_index do |header, idx|
        log_debug("Processing header #{idx}: '#{header}'")
        if header.is_a?(String) && header.match?(/\e\[/)
          # Already decorated, use as-is
          header
        else
          safe_decorate(header.to_s, :cyan, :bold)
        end
      end
      
      # Process data rows
      safe_data = data.map.with_index do |row, row_idx|
        log_debug("Processing row #{row_idx} with #{row.length} columns")
        row.map.with_index do |cell, col_idx|
          log_debug("Processing cell [#{row_idx}][#{col_idx}]: '#{cell.to_s[0..20]}...'")
          if cell.is_a?(String) && cell.match?(/\e\[/)
            # Already decorated, use as-is
            cell
          else
            cell.to_s
          end
        end
      end
      
      log_debug("Creating TTY::Table instance")
      table = TTY::Table.new(safe_headers, safe_data)
      log_debug("Rendering table with style: #{style}")
      table.render(style, padding: padding)
    rescue StandardError => e
      log_debug("Table creation failed: #{e.message}, using fallback")
      # Fallback to simple text table
      fallback_table(headers, data)
    end
  end

  private

  def fallback_table(headers, data)
    log_debug("Using fallback table rendering")
    lines = []
    
    # Header row
    header_line = headers.map { |h| h.to_s.ljust(20) }.join(' | ')
    lines << header_line
    lines << '-' * header_line.length
    
    # Data rows
    data.each do |row|
      data_line = row.map { |cell| cell.to_s.ljust(20) }.join(' | ')
      lines << data_line
    end
    
    lines.join("\n")
  end
end