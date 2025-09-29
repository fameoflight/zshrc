#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/xcode_project'
require_relative '.common/image_utils'
require 'find'
require 'json'
require 'securerandom'
require 'tmpdir'
require 'fileutils'

# Icon Generator for Xcode Projects
# Creates modern app icons for iOS/macOS applications
class XcodeIconGenerator < ScriptBase
  include XcodeProject

  def initialize
    super
  end

  def script_title
    'Xcode Icon Generator'
  end

  def script_description
    'Creates modern app icons for iOS/macOS Xcode projects with customizable themes.'
  end

  def script_arguments
    '[options]'
  end

  def script_emoji
    '🎨'
  end

  def add_custom_options(opts)
    opts.on('-t', '--theme THEME', %i[modern minimal], 'Icon theme (modern, minimal)') do |theme|
      @options[:theme] = theme
    end

    opts.on('-i', '--input FILE', 'Input SVG file to convert to icons') do |file|
      @options[:input_svg] = file
    end

    opts.on('--include-logo', 'Also generate AppLogo for in-app use') do
      @options[:include_logo] = true
    end

    opts.on('--ios-only', 'Generate iOS icons only') do
      @options[:ios_only] = true
    end

    opts.on('--macos-only', 'Generate macOS icons only') do
      @options[:macos_only] = true
    end

    opts.on('-c', '--color COLOR', 'Background color (hex, e.g., #2D2D2D)') do |color|
      @options[:bg_color] = color
    end

    opts.on('-a', '--accent COLOR', 'Accent color (hex, e.g., #0096FF)') do |color|
      @options[:accent_color] = color
    end
  end

  def show_examples
    puts <<~EXAMPLES
      Examples:
        #{script_name}                          # Generate all icons in current project
        #{script_name} --theme minimal          # Minimal theme
        #{script_name} --input icon.svg         # Convert SVG to icons
        #{script_name} --include-logo           # Also generate AppLogo for in-app use
        #{script_name} --ios-only               # iOS only
        #{script_name} --color #FF6B6B --accent #4ECDC4  # Custom colors
    EXAMPLES
  end

  def validate!
    # Check if we're in an Xcode project directory by using system command
    unless xcode_project_exists?
      log_error('No Xcode project found in current directory')
      log_info('Run this script from within your Xcode project directory')
      exit 1
    end

    if @options[:ios_only] && @options[:macos_only]
      log_error('Cannot specify both --ios-only and --macos-only')
      exit 1
    end

    # Validate SVG input file if provided
    if @options[:input_svg]
      svg_path = File.expand_path(@options[:input_svg])
      unless File.exist?(svg_path)
        log_error("SVG file not found: #{@options[:input_svg]}")
        exit 1
      end

      unless svg_path.downcase.end_with?('.svg')
        log_error("Input file must be an SVG file: #{@options[:input_svg]}")
        exit 1
      end

      # Check for SVG conversion tools
      unless ImageUtils::SVG.conversion_tool_available?
        log_error('No SVG conversion tool found')
        log_info('Please install either librsvg (rsvg-convert) or ImageMagick (convert)')
        exit 1
      end
    end
  end

  def run
    log_banner('Xcode Icon Generator')

    # Change to the original directory for all operations
    Dir.chdir(original_working_dir) do
      project_info = get_xcode_project_info
      log_success("Found project: #{project_info[:name]}")

      icon_set_dir = find_icon_set_directory
      unless icon_set_dir
        log_error('Could not find AppIcon.appiconset in the project')
        log_info('Make sure your Xcode project has an app icon asset catalog')
        log_info('It should be located in: Assets.xcassets/AppIcon.appiconset/')
        exit 1
      end

      log_success("Found icon set at: #{icon_set_dir}")

      # Generate icons based on options
      if @options[:ios_only]
        generate_ios_icons(icon_set_dir)
      elsif @options[:macos_only]
        generate_macos_icons(icon_set_dir)
      else
        generate_ios_icons(icon_set_dir)
        generate_macos_icons(icon_set_dir)
      end

      # Update Contents.json to reference the generated icons
      update_contents_json(icon_set_dir)

      # Generate AppLogo if requested
      if @options[:include_logo]
        generate_app_logo
      end
    end

    show_completion('Icon Generation')
  end

  private

  def xcode_project_exists?
    # Use system command to check for Xcode project in the original directory
    !Dir.glob(File.join(original_working_dir, '*.xcodeproj')).empty?
  end

  def get_xcode_project_info
    project_path = Dir.glob(File.join(original_working_dir, '*.xcodeproj')).first
    {
      name: File.basename(project_path, '.xcodeproj'),
      path: project_path,
      pbxproj: File.join(project_path, 'project.pbxproj')
    }
  end

  def find_icon_set_directory
    log_progress('Searching for AppIcon.appiconset...')

    # Search in the current directory and subdirectories
    search_paths = ['.', 'Assets.xcassets']

    search_paths.each do |base_path|
      icon_path = File.join(original_working_dir, base_path, 'AppIcon.appiconset')
      if File.directory?(icon_path)
        log_success("Found icon set: #{icon_path}")
        return icon_path
      end
    end

    # Do a more thorough search if not found in common locations
    Find.find(original_working_dir) do |path|
      next unless File.directory?(path)
      next unless File.basename(path) == 'AppIcon.appiconset'

      log_success("Found icon set: #{path}")
      return path
    end

    nil
  end

  def find_app_logo_directory
    log_progress('Searching for AppLogo.imageset...')

    # Search in the current directory and subdirectories
    search_paths = ['.', 'Assets.xcassets']

    search_paths.each do |base_path|
      logo_path = File.join(original_working_dir, base_path, 'AppLogo.imageset')
      if File.directory?(logo_path)
        log_success("Found AppLogo: #{logo_path}")
        return logo_path
      end
    end

    # Do a more thorough search if not found in common locations
    Find.find(original_working_dir) do |path|
      next unless File.directory?(path)
      next unless File.basename(path) == 'AppLogo.imageset'

      log_success("Found AppLogo: #{path}")
      return path
    end

    nil
  end

  def generate_ios_icons(base_dir)
    log_section('iOS Icons')

    icons = [
      { size: 1024, filename: 'Icon-1024.png', variant: :normal },
      { size: 1024, filename: 'Icon-1024-Dark.png', variant: :dark },
      { size: 1024, filename: 'Icon-1024-Tinted.png', variant: :tinted }
    ]

    @ios_icons_info = []
    icons.each do |icon|
      generate_icon(base_dir, icon[:size], icon[:filename], icon[:variant])
      @ios_icons_info << { filename: icon[:filename], variant: icon[:variant] }
    end
  end

  def generate_macos_icons(base_dir)
    log_section('macOS Icons')

    icons = [
      { size: 16, filename: 'Icon-16.png', scale: '1x', size_str: '16x16' },
      { size: 32, filename: 'Icon-16@2x.png', scale: '2x', size_str: '16x16' },
      { size: 32, filename: 'Icon-32.png', scale: '1x', size_str: '32x32' },
      { size: 64, filename: 'Icon-32@2x.png', scale: '2x', size_str: '32x32' },
      { size: 128, filename: 'Icon-128.png', scale: '1x', size_str: '128x128' },
      { size: 256, filename: 'Icon-128@2x.png', scale: '2x', size_str: '128x128' },
      { size: 256, filename: 'Icon-256.png', scale: '1x', size_str: '256x256' },
      { size: 512, filename: 'Icon-256@2x.png', scale: '2x', size_str: '256x256' },
      { size: 512, filename: 'Icon-512.png', scale: '1x', size_str: '512x512' },
      { size: 1024, filename: 'Icon-512@2x.png', scale: '2x', size_str: '512x512' }
    ]

    @macos_icons_info = []
    icons.each do |icon|
      generate_icon(base_dir, icon[:size], icon[:filename], :normal)
      @macos_icons_info << {
        filename: icon[:filename],
        scale: icon[:scale],
        size_str: icon[:size_str]
      }
    end
  end

  def generate_icon(base_dir, size, filename, variant)
    log_progress("Generating #{filename} (#{size}x#{size})")

    # If SVG input is provided, convert it to PNG
    if @options[:input_svg]
      convert_svg_to_png(size, filename, base_dir, variant)
      return
    end

    # Determine colors based on variant
    bg_color = case variant
               when :dark then ImageUtils::PNG.parse_color(@options[:bg_color] || '#1E1E1E')
               when :tinted then ImageUtils::PNG.parse_color(@options[:bg_color] || '#3C3C50')
               else ImageUtils::PNG.parse_color(@options[:bg_color] || '#2D2D2D')
               end

    accent_color = ImageUtils::PNG.parse_color(@options[:accent_color] || '#0096FF')

    # Create the icon
    canvas = ImageUtils::PNG.create_canvas(size, size, bg_color)

    case @options[:theme]
    when :minimal
      draw_minimal_icon(canvas, size, accent_color)
    else
      draw_modern_icon(canvas, size, accent_color)
    end

    # Save the icon
    filepath = File.join(base_dir, filename)
    canvas.save(filepath)

    log_file_created(filepath)
  end

  def draw_modern_icon(canvas, size, accent_color)
    margin = size / 8
    center = size / 2

    # Outer square
    outer_size = size - margin * 2
    draw_rect(canvas, margin, margin, outer_size, outer_size, accent_color, 3)

    # Inner square with gradient effect
    inner_size = outer_size * 0.7
    inner_offset = (outer_size - inner_size) / 2
    inner_x = margin + inner_offset
    inner_y = margin + inner_offset

    # Create gradient by drawing multiple rectangles with decreasing opacity
    10.times do |i|
      alpha = 255 * (i / 10.0)
      color = ImageUtils::PNG.with_alpha(accent_color, alpha.to_i)
      offset = i * 2
      ImageUtils::PNG.draw_rect(canvas, inner_x - offset, inner_y - offset,
                                inner_size + offset * 2, inner_size + offset * 2, color, 2)
    end

    # Central circle
    symbol_size = size / 4
    ImageUtils::PNG.draw_circle(canvas, center, center, symbol_size / 2, accent_color, 3)

    # Center dot
    dot_size = size / 16
    ImageUtils::PNG.draw_circle(canvas, center, center, dot_size, accent_color, :fill)

    # Corner accents
    accent_size = size / 12
    accents = [
      [margin + accent_size, margin + accent_size],
      [size - margin - accent_size, margin + accent_size],
      [margin + accent_size, size - margin - accent_size],
      [size - margin - accent_size, size - margin - accent_size]
    ]

    accents.each do |x, y|
      ImageUtils::PNG.draw_rect(canvas, x - accent_size/4, y - accent_size/4,
                                accent_size/2, accent_size/2, accent_color, :fill)
    end
  end

  def draw_minimal_icon(canvas, size, accent_color)
    margin = size / 8
    center = size / 2

    # Main circle
    circle_size = size - margin * 2
    ImageUtils::PNG.draw_circle(canvas, center, center, circle_size / 2, accent_color, 4)

    # Center square
    center_size = size / 3
    center_x = center - center_size / 2
    center_y = center - center_size / 2
    ImageUtils::PNG.draw_rect(canvas, center_x, center_y, center_size, center_size, accent_color, :fill)
  end

  def convert_svg_to_png(size, filename, base_dir, variant = :normal)
    svg_path = File.expand_path(@options[:input_svg])
    output_path = File.join(base_dir, filename)

    log_progress("Converting SVG to PNG...")

    # First convert SVG to PNG
    temp_png = File.join(Dir.tmpdir, "temp_#{SecureRandom.hex(8)}.png")

    unless ImageUtils::SVG.convert_to_png(svg_path, temp_png, size, size)
      log_error("Failed to convert SVG to PNG using available tools")
      log_info("Available tools: #{ImageUtils::SVG.available_tools.join(', ')}")
      exit 1
    end

    # Apply color filters for dark/tinted variants
    if variant != :normal
      apply_color_filter(temp_png, output_path, variant)
    else
      # Just move the file for normal variant
      FileUtils.mv(temp_png, output_path)
    end

    log_file_created(output_path)

    # Clean up temporary file
    File.delete(temp_png) if File.exist?(temp_png)
  end

  def apply_color_filter(input_path, output_path, variant)
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
      log_error("Failed to apply color filter for #{variant}")
      exit 1
    end
  end

  def create_modified_svg(original_svg, variant)
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

  def generate_app_logo
    log_section('AppLogo')

    logo_dir = find_app_logo_directory
    unless logo_dir
      log_warning('AppLogo.imageset not found in the project')
      log_info('AppLogo generation skipped')
      return
    end

    # Generate AppLogo images at different scales
    app_logos = [
      { size: 1024, filename: 'AppLogo-1024.png', scale: '1x' },
      { size: 2048, filename: 'AppLogo-2048.png', scale: '2x' },
      { size: 3072, filename: 'AppLogo-3072.png', scale: '3x' }
    ]

    @app_logos_info = []
    app_logos.each do |logo|
      generate_logo_image(logo_dir, logo[:size], logo[:filename], logo[:scale])
      @app_logos_info << { filename: logo[:filename], scale: logo[:scale] }
    end

    # Update AppLogo Contents.json
    update_app_logo_contents_json(logo_dir)
  end

  def generate_logo_image(base_dir, size, filename, scale)
    log_progress("Generating #{filename} (#{size}x#{size}, #{scale})")

    if @options[:input_svg]
      # If SVG input is provided, convert it to PNG
      svg_path = File.expand_path(@options[:input_svg])
      output_path = File.join(base_dir, filename)

      log_progress("Converting SVG to PNG for #{scale}...")

      if ImageUtils::SVG.convert_to_png(svg_path, output_path, size, size)
        log_file_created(output_path)
      else
        log_error("Failed to convert SVG to PNG for #{scale}")
        exit 1
      end
    else
      # Generate programmatically if no SVG input
      bg_color = ImageUtils::PNG.parse_color(@options[:bg_color] || '#2D2D2D')
      accent_color = ImageUtils::PNG.parse_color(@options[:accent_color] || '#0096FF')

      canvas = ImageUtils::PNG.create_canvas(size, size, bg_color)

      case @options[:theme]
      when :minimal
        draw_minimal_logo(canvas, size, accent_color)
      else
        draw_modern_logo(canvas, size, accent_color)
      end

      # Save the logo
      filepath = File.join(base_dir, filename)
      canvas.save(filepath)
      log_file_created(filepath)
    end
  end

  def draw_modern_logo(canvas, size, accent_color)
    # Similar to modern icon but simpler for in-app use
    margin = size / 10
    center = size / 2

    # Outer square
    outer_size = size - margin * 2
    ImageUtils::PNG.draw_rect(canvas, margin, margin, outer_size, outer_size, accent_color, 4)

    # Inner element
    inner_size = outer_size * 0.6
    inner_x = margin + (outer_size - inner_size) / 2
    inner_y = margin + (outer_size - inner_size) / 2
    ImageUtils::PNG.draw_rect(canvas, inner_x, inner_y, inner_size, inner_size, accent_color, :fill)
  end

  def draw_minimal_logo(canvas, size, accent_color)
    # Minimal circular logo
    center = size / 2
    radius = size / 3

    ImageUtils::PNG.draw_circle(canvas, center, center, radius, accent_color, 4)
  end

  def update_app_logo_contents_json(logo_dir)
    log_progress('Updating AppLogo Contents.json...')

    contents_file = File.join(logo_dir, 'Contents.json')

    unless File.exist?(contents_file)
      log_warning('AppLogo Contents.json not found, creating new one')
      create_new_app_logo_contents_json(contents_file)
      return
    end

    # Read existing Contents.json
    contents = JSON.parse(File.read(contents_file))

    # Update AppLogo entries
    if @app_logos_info
      @app_logos_info.each do |logo_info|
        update_app_logo_entry(contents, logo_info)
      end
    end

    # Write back the updated Contents.json
    File.write(contents_file, JSON.pretty_generate(contents))
    log_success('Updated AppLogo Contents.json with logo references')
  end

  def update_app_logo_entry(contents, logo_info)
    # Find the matching entry by scale
    images = contents['images'] || []

    images.each do |image|
      if image['scale'] == logo_info[:scale] && image['idiom'] == 'universal'
        image['filename'] = logo_info[:filename]
      end
    end
  end

  def create_new_app_logo_contents_json(contents_file)
    contents = {
      'images' => [],
      'info' => {
        'author' => 'xcode',
        'version' => 1
      }
    }

    # Add AppLogo entries
    if @app_logos_info
      @app_logos_info.each do |logo_info|
        entry = {
          'idiom' => 'universal',
          'scale' => logo_info[:scale],
          'filename' => logo_info[:filename]
        }
        contents['images'] << entry
      end
    end

    File.write(contents_file, JSON.pretty_generate(contents))
    log_success('Created new AppLogo Contents.json with logo references')
  end

  def update_contents_json(icon_set_dir)
    log_progress('Updating Contents.json...')

    contents_file = File.join(icon_set_dir, 'Contents.json')

    unless File.exist?(contents_file)
      log_warning('Contents.json not found, creating new one')
      create_new_contents_json(contents_file)
      return
    end

    # Read existing Contents.json
    contents = JSON.parse(File.read(contents_file))

    # Update iOS icons
    if @ios_icons_info
      @ios_icons_info.each do |icon_info|
        update_ios_icon_entry(contents, icon_info)
      end
    end

    # Update macOS icons
    if @macos_icons_info
      @macos_icons_info.each do |icon_info|
        update_macos_icon_entry(contents, icon_info)
      end
    end

    # Write back the updated Contents.json
    File.write(contents_file, JSON.pretty_generate(contents))
    log_success('Updated Contents.json with icon references')
  end

  def update_ios_icon_entry(contents, icon_info)
    ios_images = contents['images'].select { |img| img['platform'] == 'ios' && img['size'] == '1024x1024' }

    ios_images.each do |image|
      case icon_info[:variant]
      when :normal
        image['filename'] = icon_info[:filename] unless image['appearances']
      when :dark
        if image['appearances']&.any? { |app| app['appearance'] == 'luminosity' && app['value'] == 'dark' }
          image['filename'] = icon_info[:filename]
        end
      when :tinted
        if image['appearances']&.any? { |app| app['appearance'] == 'luminosity' && app['value'] == 'tinted' }
          image['filename'] = icon_info[:filename]
        end
      end
    end
  end

  def update_macos_icon_entry(contents, icon_info)
    macos_images = contents['images'].select { |img| img['idiom'] == 'mac' && img['size'] == icon_info[:size_str] && img['scale'] == icon_info[:scale] }

    macos_images.each do |image|
      image['filename'] = icon_info[:filename]
    end
  end

  def create_new_contents_json(contents_file)
    contents = {
      'images' => [],
      'info' => {
        'author' => 'xcode',
        'version' => 1
      }
    }

    # Add iOS entries
    if @ios_icons_info
      @ios_icons_info.each do |icon_info|
        entry = {
          'idiom' => 'universal',
          'platform' => 'ios',
          'size' => '1024x1024',
          'filename' => icon_info[:filename]
        }

        case icon_info[:variant]
        when :dark
          entry['appearances'] = [{ 'appearance' => 'luminosity', 'value' => 'dark' }]
        when :tinted
          entry['appearances'] = [{ 'appearance' => 'luminosity', 'value' => 'tinted' }]
        end

        contents['images'] << entry
      end
    end

    # Add macOS entries
    if @macos_icons_info
      @macos_icons_info.each do |icon_info|
        entry = {
          'idiom' => 'mac',
          'size' => icon_info[:size_str],
          'scale' => icon_info[:scale],
          'filename' => icon_info[:filename]
        }
        contents['images'] << entry
      end
    end

    File.write(contents_file, JSON.pretty_generate(contents))
    log_success('Created new Contents.json with icon references')
  end

  def help_text
    <<~HELP
      #{banner_text}
      #{script_description}

      Usage: #{script_name} #{script_arguments}

      Options:
        -t, --theme THEME        Icon theme (modern, minimal) [default: modern]
        -i, --input FILE         Input SVG file to convert to icons
        --include-logo           Also generate AppLogo for in-app use
        --ios-only               Generate iOS icons only
        --macos-only             Generate macOS icons only
        -c, --color COLOR        Background color (hex, e.g., #2D2D2D)
        -a, --accent COLOR       Accent color (hex, e.g., #0096FF)
        -f, --force              Force overwrite without confirmation
        -d, --dry-run            Show what would be done
        -v, --verbose            Verbose output
        -h, --help               Show this help

      Themes:
        modern   - Layered design with gradients and accents (default)
        minimal  - Clean, simple circular design

      SVG Input:
        Use the -i/--input option to convert an SVG file to app icons.
        Requires either librsvg (rsvg-convert) or ImageMagick (convert).

      AppLogo:
        Use --include-logo to also generate AppLogo images for in-app use.
        Generates 1x, 2x, and 3x scale versions for universal devices.
        Updates AppLogo.imageset/Contents.json automatically.

      Color format: Use hex colors with or without # (e.g., #FF6B6B or FF6B6B)

      Note: Run this script from within your Xcode project directory
    HELP
  end
end

# Execute the script
XcodeIconGenerator.execute if __FILE__ == $0