#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: Generate app icons for Electron applications from SVG or programmatically
# @tags: electron, icon-generation, image-processing

require_relative '../../.common/script_base'
require_relative '../../.common/image_utils'
require 'json'
require 'fileutils'

# Icon Generator for Electron Applications
# Creates app icons for Electron applications from SVG or generates programmatic icons
class ElectronIconGenerator < ScriptBase
  def initialize
    super
    @icon_sizes = {
      # Windows ICO sizes
      windows: [16, 24, 32, 48, 64, 128, 256],
      # macOS ICNS sizes
      macos: [16, 32, 64, 128, 256, 512, 1024],
      # Linux PNG sizes (common for .desktop files)
      linux: [16, 24, 32, 48, 64, 128, 256, 512]
    }
  end

  def script_title
    'Electron Icon Generator'
  end

  def script_description
    'Creates app icons for Electron applications from SVG or generates programmatic icons.'
  end

  def script_arguments
    '[icon.svg] [options]'
  end

  def script_emoji
    '⚛️'
  end

  def add_custom_options(opts)
    opts.on('-i', '--input FILE', 'Input SVG file to convert to icons') do |file|
      @options[:input_svg] = file
    end

    opts.on('-o', '--output DIR', 'Output directory for icons (default: ./icons)') do |dir|
      @options[:output_dir] = dir
    end

    opts.on('-p', '--platform PLATFORM', %i[windows macos linux all],
            'Target platform (windows, macos, linux, all)') do |platform|
      @options[:platform] = platform
    end

    opts.on('-t', '--theme THEME', %i[modern minimal], 'Icon theme (modern, minimal)') do |theme|
      @options[:theme] = theme
    end

    opts.on('-c', '--color COLOR', 'Background color (hex, e.g., #2D2D2D)') do |color|
      @options[:bg_color] = color
    end

    opts.on('-a', '--accent COLOR', 'Accent color (hex, e.g., #0096FF)') do |color|
      @options[:accent_color] = color
    end

    opts.on('--ico', 'Generate Windows .ico file (requires ImageMagick)') do
      @options[:generate_ico] = true
    end

    opts.on('--icns', 'Generate macOS .icns file (requires iconutil on macOS)') do
      @options[:generate_icns] = true
    end
  end

  def show_examples
    puts <<~EXAMPLES
      Examples:
        #{script_name} icon.svg                 # Convert SVG to all platform icons
        #{script_name} icon.svg --ico --icns    # Convert SVG with .ico and .icns
        #{script_name} --input icon.svg         # Alternative: use --input flag
        #{script_name} --platform macos         # macOS only (programmatic)
        #{script_name} icon.svg --platform windows  # Windows only from SVG
        #{script_name} --theme minimal          # Minimal theme (programmatic)
        #{script_name} --color #FF6B6B --accent #4ECDC4  # Custom colors
        #{script_name} icon.svg --output ./build/icons   # Custom output directory
    EXAMPLES
  end

  def validate!
    # Check if first positional argument is an SVG file
    if ARGV.length > 0 && ARGV[0] && !ARGV[0].start_with?('-')
      first_arg = ARGV[0]
      if first_arg.downcase.end_with?('.svg')
        @options[:input_svg] = first_arg
      end
    end

    # Validate SVG input file if provided
    if @options[:input_svg]
      # Expand path relative to original working directory
      svg_path = File.expand_path(@options[:input_svg], original_working_dir)

      unless File.exist?(svg_path)
        log_error("SVG file not found: #{@options[:input_svg]}")
        log_info("Current directory: #{original_working_dir}")
        log_info("Searched for: #{svg_path}")
        exit 1
      end

      unless svg_path.downcase.end_with?('.svg')
        log_error("Input file must be an SVG file: #{@options[:input_svg]}")
        exit 1
      end

      # Check for SVG conversion tools
      unless ImageUtils::SVG.conversion_tool_available?
        log_error('No SVG conversion tool found')
        log_info('Please install either librsvg (rsvg-convert) or ImageMagick (convert/magick)')
        exit 1
      end

      @svg_absolute_path = svg_path
    else
      # Warn if no SVG provided but not generating programmatic icons
      if @options[:theme].nil?
        log_warning('No SVG input provided. Use --input <file.svg> or provide SVG as first argument')
        log_info('Will generate programmatic icons with default theme')
      end
    end

    # Validate ico generation requirements
    if @options[:generate_ico]
      unless system('which convert > /dev/null 2>&1') || system('which magick > /dev/null 2>&1')
        log_error('ImageMagick is required to generate .ico files')
        log_info('Install with: brew install imagemagick')
        exit 1
      end
    end

    # Validate icns generation requirements
    if @options[:generate_icns]
      if RUBY_PLATFORM !~ /darwin/
        log_error('macOS is required to generate .icns files (iconutil)')
        exit 1
      end

      unless system('which iconutil > /dev/null 2>&1')
        log_error('iconutil command not found (should be available on macOS)')
        exit 1
      end
    end

    # Set defaults
    @options[:output_dir] ||= File.join(original_working_dir, 'icons')
    @options[:platform] ||= :all
    @options[:theme] ||= :modern
  end

  def run
    log_banner('Electron Icon Generator')

    # Create output directory
    FileUtils.mkdir_p(@options[:output_dir])
    log_success("Output directory: #{@options[:output_dir]}")

    # Determine which platforms to generate
    platforms = case @options[:platform]
                when :all
                  [:windows, :macos, :linux]
                when :windows, :macos, :linux
                  [@options[:platform]]
                else
                  [:windows, :macos, :linux]
                end

    # Generate icons for each platform
    platforms.each do |platform|
      generate_platform_icons(platform)
    end

    # Generate .ico file if requested
    generate_ico_file if @options[:generate_ico]

    # Generate .icns file if requested
    generate_icns_file if @options[:generate_icns]

    # Generate package.json build config
    generate_package_json_snippet

    show_completion('Icon Generation')
  end

  private

  def generate_platform_icons(platform)
    log_section("#{platform.to_s.capitalize} Icons")

    sizes = @icon_sizes[platform]
    platform_dir = File.join(@options[:output_dir], platform.to_s)
    FileUtils.mkdir_p(platform_dir)

    sizes.each do |size|
      filename = "icon-#{size}x#{size}.png"
      output_path = File.join(platform_dir, filename)

      generate_icon(output_path, size)
    end

    log_success("Generated #{sizes.length} icons for #{platform}")
  end

  def generate_icon(output_path, size)
    log_progress("Generating #{File.basename(output_path)} (#{size}x#{size})")

    # If SVG input is provided, convert it to PNG
    if @options[:input_svg]
      convert_svg_to_png(size, output_path)
      return
    end

    # Generate programmatically
    bg_color = ImageUtils::PNG.parse_color(@options[:bg_color] || '#2D2D2D')
    accent_color = ImageUtils::PNG.parse_color(@options[:accent_color] || '#0096FF')

    canvas = ImageUtils::PNG.create_canvas(size, size, bg_color)

    case @options[:theme]
    when :minimal
      ImageUtils::Icons.draw_minimal_icon(canvas, size, accent_color)
    else
      ImageUtils::Icons.draw_modern_icon(canvas, size, accent_color)
    end

    canvas.save(output_path)
    log_file_created(output_path)
  end

  def convert_svg_to_png(size, output_path)
    svg_path = @svg_absolute_path

    log_progress("Converting SVG to PNG (#{size}x#{size})...")

    unless ImageUtils::SVG.convert_to_png(svg_path, output_path, size, size, mode: :cover)
      log_error("Failed to convert SVG to PNG")
      log_info("Available tools: #{ImageUtils::SVG.available_tools.join(', ')}")
      exit 1
    end

    log_file_created(output_path)
  end

  def generate_ico_file
    log_section('Windows .ico File')

    # Collect all Windows PNG files
    windows_dir = File.join(@options[:output_dir], 'windows')
    unless Dir.exist?(windows_dir)
      log_warning('Windows icons not generated, skipping .ico generation')
      return
    end

    png_files = Dir.glob(File.join(windows_dir, '*.png')).sort
    if png_files.empty?
      log_warning('No PNG files found for .ico generation')
      return
    end

    output_ico = File.join(@options[:output_dir], 'icon.ico')

    log_progress("Generating icon.ico from #{png_files.length} PNG files...")

    # Use ImageMagick to combine PNGs into ICO
    command = if system('which magick > /dev/null 2>&1')
                ['magick', 'convert', *png_files, output_ico]
              else
                ['convert', *png_files, output_ico]
              end

    if system(*command)
      log_file_created(output_ico)
    else
      log_error('Failed to generate .ico file')
    end
  end

  def generate_icns_file
    log_section('macOS .icns File')

    # Collect all macOS PNG files
    macos_dir = File.join(@options[:output_dir], 'macos')
    unless Dir.exist?(macos_dir)
      log_warning('macOS icons not generated, skipping .icns generation')
      return
    end

    # Create iconset directory structure required by iconutil
    iconset_dir = File.join(@options[:output_dir], 'icon.iconset')
    FileUtils.mkdir_p(iconset_dir)

    log_progress('Creating iconset directory structure...')

    # Copy and rename files according to Apple's iconset naming convention
    icon_mappings = {
      16 => ['icon_16x16.png'],
      32 => ['icon_16x16@2x.png', 'icon_32x32.png'],
      64 => ['icon_32x32@2x.png'],
      128 => ['icon_128x128.png'],
      256 => ['icon_128x128@2x.png', 'icon_256x256.png'],
      512 => ['icon_256x256@2x.png', 'icon_512x512.png'],
      1024 => ['icon_512x512@2x.png']
    }

    icon_mappings.each do |size, target_names|
      source = File.join(macos_dir, "icon-#{size}x#{size}.png")
      next unless File.exist?(source)

      target_names.each do |target_name|
        target = File.join(iconset_dir, target_name)
        FileUtils.cp(source, target)
      end
    end

    # Generate .icns using iconutil
    output_icns = File.join(@options[:output_dir], 'icon.icns')
    log_progress('Generating icon.icns using iconutil...')

    command = ['iconutil', '-c', 'icns', iconset_dir, '-o', output_icns]
    if system(*command)
      log_file_created(output_icns)

      # Clean up iconset directory
      FileUtils.rm_rf(iconset_dir)
    else
      log_error('Failed to generate .icns file')
    end
  end

  def generate_package_json_snippet
    log_section('Package.json Build Configuration')

    config = {
      build: {
        appId: 'com.example.app',
        productName: 'Your App Name',
        mac: {
          icon: 'icons/icon.icns',
          category: 'public.app-category.utilities'
        },
        win: {
          icon: 'icons/icon.ico'
        },
        linux: {
          icon: 'icons/linux',
          category: 'Utility'
        }
      }
    }

    snippet_file = File.join(@options[:output_dir], 'package.json.snippet')
    File.write(snippet_file, JSON.pretty_generate(config))

    log_success('Generated package.json configuration snippet')
    log_info("Add the 'build' section from #{snippet_file} to your package.json")
  end

  def help_text
    <<~HELP
      #{banner_text}
      #{script_description}

      Usage: #{script_name} #{script_arguments}

      Options:
        -i, --input FILE         Input SVG file to convert to icons
        -o, --output DIR         Output directory (default: ./icons)
        -p, --platform PLATFORM  Target platform (windows, macos, linux, all)
        -t, --theme THEME        Icon theme (modern, minimal) [default: modern]
        -c, --color COLOR        Background color (hex, e.g., #2D2D2D)
        -a, --accent COLOR       Accent color (hex, e.g., #0096FF)
        --ico                    Generate Windows .ico file
        --icns                   Generate macOS .icns file (macOS only)
        -f, --force              Force overwrite without confirmation
        -d, --dry-run            Show what would be done
        -v, --verbose            Verbose output
        -h, --help               Show this help

      Platforms:
        windows  - Windows .ico compatible PNG icons (16-256px)
        macos    - macOS .icns compatible PNG icons (16-1024px)
        linux    - Linux desktop PNG icons (16-512px)
        all      - All platforms (default)

      Themes:
        modern   - Layered design with gradients and accents (default)
        minimal  - Clean, simple circular design

      SVG Input:
        Use the -i/--input option to convert an SVG file to app icons.
        Requires either librsvg (rsvg-convert) or ImageMagick (convert/magick).
        The SVG will be converted maintaining aspect ratio using cover mode.

      Icon Formats:
        --ico    Generate Windows .ico file (requires ImageMagick)
        --icns   Generate macOS .icns file (requires iconutil, macOS only)

      Output Structure:
        icons/
        ├── windows/
        │   ├── icon-16x16.png
        │   ├── icon-32x32.png
        │   └── ...
        ├── macos/
        │   ├── icon-16x16.png
        │   ├── icon-32x32.png
        │   └── ...
        ├── linux/
        │   ├── icon-16x16.png
        │   ├── icon-32x32.png
        │   └── ...
        ├── icon.ico (if --ico specified)
        ├── icon.icns (if --icns specified)
        └── package.json.snippet

      Usage with Electron Builder:
        Add the generated build configuration to your package.json:
        1. Open icons/package.json.snippet
        2. Copy the "build" section to your package.json
        3. Adjust appId, productName, and category as needed
    HELP
  end
end

# Execute the script
ElectronIconGenerator.execute if __FILE__ == $0
