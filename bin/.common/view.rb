# frozen_string_literal: true

require 'pastel'
require 'tty-table'
require 'tty-box'
require 'tty-font'

# View helper methods for creating beautiful terminal UIs
# Contains all common view components like tables, boxes, headers, etc.
module View
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Initialize view components once for the class
    def setup_view
      @pastel ||= Pastel.new
      @view_initialized = true
    end

    def pastel
      setup_view unless @view_initialized
      @pastel
    end
  end

  # Instance methods available in classes that include this module
  def pastel
    @pastel ||= Pastel.new
  end

  # Safe pastel decorator with fallback and debug logging
  def safe_decorate(text, *styles)
    begin
      log_debug("Decorating text: '#{text.to_s[0..50]}...' with styles: #{styles}") if respond_to?(:log_debug)
      result = pastel.decorate(text.to_s, *styles)
      log_debug("Decoration successful") if respond_to?(:log_debug)
      result
    rescue StandardError => e
      log_debug("Pastel decoration failed: #{e.message}, using plain text") if respond_to?(:log_debug)
      text.to_s
    end
  end

  # Create a beautiful header with large font and fallback
  def create_header(title, color: :cyan)
    log_debug("Creating header: '#{title}' with color: #{color}") if respond_to?(:log_debug)
    begin
      font = TTY::Font.new(:doom)
      font_text = font.write(title.upcase)
      log_debug("Font created successfully, applying color") if respond_to?(:log_debug)
      safe_decorate(font_text, color)
    rescue StandardError => e
      log_debug("Font creation failed: #{e.message}, using fallback") if respond_to?(:log_debug)
      # Fallback to simple decorated text
      safe_decorate("🎯 #{title.upcase}", color, :bold)
    end
  end

  # Create a framed box with content
  def create_box(content, title: nil, color: :green, padding: 1, border: :thick)
    log_debug("Creating box with title: '#{title}', color: #{color}") if respond_to?(:log_debug)
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
      log_debug("Box creation failed: #{e.message}, using simple output") if respond_to?(:log_debug)
      fallback_box(content, title, color, border)
    end
  end

  # Create a table with safe rendering and auto-decoration
  def create_table(headers, data, style: :unicode, padding: [0, 1], auto_color: true, width: nil)
    log_debug("Creating table with #{headers.length} headers and #{data.length} rows") if respond_to?(:log_debug)
    begin
      # Process headers - decorate if auto_color is enabled and not already decorated
      safe_headers = headers.map.with_index do |header, idx|
        log_debug("Processing header #{idx}: '#{header}'") if respond_to?(:log_debug)
        if auto_color && !(header.is_a?(String) && header.match?(/\e\[/))
          safe_decorate(header.to_s, :cyan, :bold)
        else
          header.to_s
        end
      end
      
      # Process data rows - keep existing decoration or apply none
      safe_data = data.map.with_index do |row, row_idx|
        log_debug("Processing row #{row_idx} with #{row.length} columns") if respond_to?(:log_debug)
        row.map.with_index do |cell, col_idx|
          log_debug("Processing cell [#{row_idx}][#{col_idx}]: '#{cell.to_s[0..20]}...'") if respond_to?(:log_debug)
          cell.to_s
        end
      end
      
      log_debug("Creating TTY::Table instance") if respond_to?(:log_debug)
      table = TTY::Table.new(safe_headers, safe_data)
      
      # Set up render options with width handling
      render_options = { padding: padding }
      
      # Set width if provided, otherwise use terminal width with some margin
      if width
        render_options[:width] = width
      else
        # Get terminal width, cap at reasonable maximum
        terminal_width = [IO.console.winsize[1] - 10, 120].min
        render_options[:width] = terminal_width
        render_options[:resize] = true # Enable auto-resize
      end
      
      log_debug("Rendering table with style: #{style}, width: #{render_options[:width]}") if respond_to?(:log_debug)
      table.render(style, render_options)
    rescue StandardError => e
      log_debug("Table creation failed: #{e.message}, using fallback") if respond_to?(:log_debug)
      fallback_table(headers, data)
    end
  end

  # Create a status box based on condition
  def create_status_box(content, status: :info, title: nil)
    color = case status
           when :success then :green
           when :error then :red
           when :warning then :yellow
           else :blue
           end
    
    create_box(content, title: title, color: color)
  end

  # Create an empty state message
  def create_empty_state(message, icon: "📭", color: :yellow)
    create_box(
      "#{icon} #{message}",
      color: color
    )
  end

  # Create a summary box with statistics
  def create_summary_box(stats, title: nil, color: :green)
    content = stats.map { |key, value| "#{key}: #{value}" }.join("\n")
    create_box(content, title: title, color: color)
  end

  # Create a progress-style message
  def create_progress_message(message, icon: "🔄", color: :cyan)
    safe_decorate("#{icon} #{message}", color)
  end

  # Create an error message with formatting
  def create_error_message(message, icon: "❌", color: :red)
    safe_decorate("#{icon} #{message}", color)
  end

  # Create a success message with formatting  
  def create_success_message(message, icon: "✅", color: :green)
    safe_decorate("#{icon} #{message}", color)
  end

  # Create a warning message with formatting
  def create_warning_message(message, icon: "⚠️", color: :yellow)
    safe_decorate("#{icon} #{message}", color)
  end

  # Create a separator line
  def create_separator(char: "─", length: 50, color: :dim)
    safe_decorate(char * length, color)
  end

  # Create a section header
  def create_section_header(title, icon: "🔧", color: :magenta)
    safe_decorate("#{icon} #{title.upcase}", color, :bold)
  end

  # Display a list of items with formatting
  def display_list(title, items, numbered: true, icon: "•")
    puts create_section_header(title)
    puts
    
    items.each_with_index do |item, index|
      prefix = numbered ? "#{index + 1}." : icon
      puts "  #{prefix} #{item}"
    end
    puts
  end

  # Display key-value pairs in a formatted way
  def display_key_value_pairs(pairs, title: nil, indent: 2)
    puts create_section_header(title) if title
    puts if title
    
    pairs.each do |key, value|
      key_formatted = safe_decorate("#{key}:", :cyan)
      puts "#{' ' * indent}#{key_formatted} #{value}"
    end
    puts
  end

  # Create a loading message
  def create_loading_message(message, dots: true)
    suffix = dots ? "..." : ""
    create_progress_message("#{message}#{suffix}")
  end

  private

  # Fallback box rendering when TTY::Box fails
  def fallback_box(content, title, color, border)
    border_char = case border
                 when :thick then '━'
                 when :double then '═' 
                 else '─'
                 end
    
    width = [content.length + 4, title&.length&.+(4) || 0, 50].max
    lines = []
    
    # Top border
    lines << border_char * width
    
    # Title if provided
    if title
      title_line = "#{border_char} #{title} #{border_char}"
      padding = width - title_line.length
      lines << title_line + (border_char * padding) if padding > 0
      lines << border_char * width
    end
    
    # Content
    lines << "#{border_char} #{content} #{border_char}"
    
    # Bottom border
    lines << border_char * width
    
    lines.join("\n")
  end

  # Fallback table rendering when TTY::Table fails
  def fallback_table(headers, data)
    log_debug("Using fallback table rendering") if respond_to?(:log_debug)
    lines = []
    
    # Get terminal width for fallback
    terminal_width = begin
      IO.console.winsize[1] - 10
    rescue StandardError
      80 # Fallback width
    end
    
    # Calculate column widths with terminal constraint
    col_widths = []
    headers.each_with_index do |header, idx|
      max_width = [header.to_s.length, 10].min # Minimum width
      data.each do |row|
        cell_width = row[idx]&.to_s&.length || 0
        max_width = [max_width, cell_width].max
      end
      col_widths << [max_width, 30].min # Cap at 30 chars per column
    end
    
    # Adjust column widths to fit terminal
    total_width = col_widths.sum + (col_widths.length - 1) * 3 # +3 for " | " separators
    if total_width > terminal_width
      # Scale down columns proportionally
      scale_factor = terminal_width.to_f / total_width
      col_widths = col_widths.map { |w| [w * scale_factor, 8].max.to_i }
    end
    
    # Header row
    header_line = headers.map.with_index do |h, idx|
      content = h.to_s
      max_len = col_widths[idx]
      content.length > max_len ? "#{content[0..max_len-3]}..." : content.ljust(max_len)
    end.join(' | ')
    lines << header_line
    lines << '-' * [header_line.length, terminal_width].min
    
    # Data rows
    data.each do |row|
      data_line = row.map.with_index do |cell, idx|
        content = cell.to_s
        max_len = col_widths[idx]
        content.length > max_len ? "#{content[0..max_len-3]}..." : content.ljust(max_len)
      end.join(' | ')
      lines << data_line
    end
    
    lines.join("\n")
  end
end