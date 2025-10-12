#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../.common/script_base'
require 'fileutils'

class ImageOrganizer < ScriptBase
  def script_emoji; '🖼️'; end
  def script_title; 'Image Organizer'; end
  def script_description; 'Moves images into horizontal and vertical folders based on dimensions'; end
  def script_arguments; '[--rename] <folder_path>'; end

  def initialize
    super
    @rename_files = false
    @source_folder = nil
  end

  def run
    parse_arguments
    validate_requirements

    log_banner("Organizing Images")
    log_info "Source folder: #{@source_folder}"
    log_info "Rename files: #{@rename_files ? 'Yes' : 'No'}"

    create_output_folders
    process_images
    show_completion("Image Organization")
  end

  private

  def parse_arguments
    if ARGV.empty? || ARGV.include?('--help') || ARGV.include?('-h')
      show_help
      exit 0
    end

    if ARGV.include?('--rename')
      @rename_files = true
      ARGV.delete('--rename')
    end

    @source_folder = ARGV.first
  end

  def show_help
    puts <<~HELP
      #{script_title}

      Usage: #{script_arguments}

      Moves images from a folder into 'horizontal' and 'vertical' subfolders
      based on their dimensions (width vs height).

      Options:
        --rename    Rename images sequentially as 1.jpg, 2.jpg, etc.
        --help      Show this help message

      Examples:
        organize-images.rb /path/to/images
        organize-images.rb --rename /path/to/images
    HELP
  end

  def validate_requirements
    unless @source_folder
      log_error "Please provide a folder path"
      show_help
      exit 1
    end

    unless File.directory?(@source_folder)
      log_error "Folder not found: #{@source_folder}"
      exit 1
    end

    # Check for required gems
    begin
      require 'chunky_png'
    rescue LoadError
      log_error "Missing required gem: chunky_png"
      log_info "Install with: gem install chunky_png"
      exit 1
    end
  end

  def create_output_folders
    @horizontal_folder = File.join(@source_folder, 'horizontal')
    @vertical_folder = File.join(@source_folder, 'vertical')

    FileUtils.mkdir_p(@horizontal_folder)
    FileUtils.mkdir_p(@vertical_folder)

    log_section "Created output folders"
    log_file_created @horizontal_folder
    log_file_created @vertical_folder
  end

  def process_images
    image_files = find_image_files
    return log_warning "No image files found" if image_files.empty?

    log_section "Processing #{image_files.size} images"

    horizontal_count = 0
    vertical_count = 0
    processed_count = 0

    image_files.each do |file|
      begin
        orientation = get_image_orientation(file)
        target_folder = orientation == :horizontal ? @horizontal_folder : @vertical_folder

        if orientation == :horizontal
          horizontal_count += 1
        else
          vertical_count += 1
        end

        new_filename = if @rename_files
          ext = File.extname(file).downcase
          # Use separate numbering for each orientation
          if orientation == :horizontal
            new_name = "#{horizontal_count}#{ext}"
          else
            new_name = "#{vertical_count}#{ext}"
          end
          log_progress "#{File.basename(file)} → #{new_name} (#{orientation})"
          new_name
        else
          log_progress "#{File.basename(file)} → #{orientation}/"
          File.basename(file)
        end

        target_path = File.join(target_folder, new_filename)
        FileUtils.mv(file, target_path)
        processed_count += 1

      rescue => e
        log_error "Failed to process #{File.basename(file)}: #{e.message}"
      end
    end

    log_section "Organization Complete"
    log_success "Processed #{processed_count} images"
    log_info "Horizontal: #{horizontal_count} images"
    log_info "Vertical: #{vertical_count} images"
  end

  def find_image_files
    image_extensions = %w[.jpg .jpeg .png .gif .bmp .tiff .webp]

    Dir.glob(File.join(@source_folder, "**", "*"))
       .select { |file| File.file?(file) && image_extensions.include?(File.extname(file).downcase) }
       .sort
  end

  def get_image_orientation(file_path)
    ext = File.extname(file_path).downcase

    case ext
    when '.png'
      get_png_orientation(file_path)
    when '.jpg', '.jpeg'
      get_jpeg_orientation(file_path)
    when '.gif'
      get_gif_orientation(file_path)
    when '.bmp'
      get_bmp_orientation(file_path)
    when '.tiff'
      get_tiff_orientation(file_path)
    when '.webp'
      get_webp_orientation(file_path)
    else
      log_warning "Unknown image format: #{ext}"
      :unknown
    end
  end

  def get_png_orientation(file_path)
    image = ChunkyPNG::Image.from_file(file_path)
    image.width >= image.height ? :horizontal : :vertical
  end

  def get_jpeg_orientation(file_path)
    # Simple JPEG dimension extraction
    File.open(file_path, 'rb') do |file|
      # Skip JPEG header
      file.seek(2)

      while true
        marker = file.read(2)&.unpack('n')&.first
        break unless marker

        if marker == 0xFFC0 || marker == 0xFFC2 # SOF markers
          file.seek(3, IO::SEEK_CUR) # Skip length and precision
          height = file.read(2).unpack('n').first
          width = file.read(2).unpack('n').first
          return width >= height ? :horizontal : :vertical
        end

        # Skip to next marker
        length = file.read(2)&.unpack('n')&.first
        break unless length
        file.seek(length - 2, IO::SEEK_CUR)
      end
    end
    :unknown
  end

  def get_gif_orientation(file_path)
    File.open(file_path, 'rb') do |file|
      file.seek(6) # GIF header position
      width = file.read(2).unpack('v').first
      height = file.read(2).unpack('v').first
      return width >= height ? :horizontal : :vertical
    end
  rescue
    :unknown
  end

  def get_bmp_orientation(file_path)
    File.open(file_path, 'rb') do |file|
      file.seek(18) # BMP header position for dimensions
      width = file.read(4).unpack('l').first.abs
      height = file.read(4).unpack('l').first.abs
      return width >= height ? :horizontal : :vertical
    end
  rescue
    :unknown
  end

  def get_tiff_orientation(file_path)
    File.open(file_path, 'rb') do |file|
      file.seek(4) # Skip TIFF header
      offset = file.read(4).unpack('N').first
      file.seek(offset)

      entries = file.read(2).unpack('n').first
      entries.times do
        tag = file.read(2).unpack('n').first
        file.seek(6, IO::SEEK_CUR)
        break if tag == 256 # ImageWidth tag
      end

      # This is simplified - full TIFF parsing would be more complex
      log_warning "Complex TIFF format, using basic detection"
      return :unknown
    end
  rescue
    :unknown
  end

  def get_webp_orientation(file_path)
    File.open(file_path, 'rb') do |file|
      file.seek(12) # Skip VP8 header
      # WebP dimension extraction is complex, this is simplified
      log_warning "Complex WebP format, using basic detection"
      return :unknown
    end
  rescue
    :unknown
  end
end

ImageOrganizer.execute if __FILE__ == $0