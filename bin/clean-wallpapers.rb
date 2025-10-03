#!/usr/bin/env ruby
require 'json'
require_relative '.common/script_base'
require_relative '.common/image_utils'
require_relative '.common/utils/progress_utils'
require_relative '.common/utils/parallel_utils'
require_relative '.common/utils/device_utils'
require_relative '.common/file_processing_tracker'

class CleanWallpapers < ScriptBase
  include ProgressUtils
  include ParallelUtils
  include DeviceUtils
  def script_title
    "Wallpaper Cleanup Tool"
  end

  def banner_text
    "Usage: #{script_name} [OPTIONS] <wallpapers_directory>"
  end

  def initialize
    # Initialize custom instance variables
    @human_threshold = 60.0
    @min_resolution = 3840
    @min_height = 2160
    @max_files = nil
    @upscale_small = true
    @replace_originals = true
    @files_to_delete = []
    @files_to_upscale = []
    @tracker = FileProcessingTracker.new
    @worker_count = nil

    super
  end

  def add_custom_options(opts)
    opts.on("--threshold PERCENT", Float, "Human detection threshold (default: 60.0)") do |t|
      @human_threshold = t
    end

    opts.on("--resolution WIDTH", Integer, "Minimum width in pixels (default: 3840)") do |w|
      @min_resolution = w
    end

    opts.on("--min-height HEIGHT", Integer, "Minimum height in pixels (default: 2160)") do |h|
      @min_height = h
    end

    opts.on("-m", "--max COUNT", Integer, "Process only first N files (for debugging)") do |count|
      @max_files = count
    end

    opts.on("--no-upscale", "Skip upscaling small images") do
      @upscale_small = false
    end

    opts.on("--no-replace", "Keep original images (default: replaces originals)") do
      @replace_originals = false
    end

    opts.on("--force-reprocess", "Force reprocessing of all files") do
      @force_reprocess = true
    end

    opts.on("--no-tracking", "Disable processing tracking (use with caution)") do
      @disable_tracking = true
    end

    opts.on("-j", "--workers COUNT", Integer, "Number of parallel workers (default: auto-detect)") do |count|
      @worker_count = count
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} /path/to/wallpapers"
    puts "  #{script_name} /path/to/wallpapers --threshold 70 --max 10"
    puts "  #{script_name} /path/to/wallpapers --no-replace --dry-run"
    puts "  #{script_name} /path/to/wallpapers --resolution 2560 --min-height 1440"
    puts "  #{script_name} /path/to/wallpapers --force-reprocess  # Re-process all files"
    puts "  #{script_name} /path/to/wallpapers --no-tracking     # Disable caching"
    puts "  #{script_name} /path/to/wallpapers --workers 8       # Use 8 parallel workers"
  end

  def run
    validate_directory
    execute_cleanup
  end

  def validate_directory
    @wallpapers_dir = validate_directory_arg("Wallpapers directory")
  end

  def execute_cleanup
    log_banner script_title
    log_info "Scanning directory: #{@wallpapers_dir}"
    log_info "Human detection threshold: #{@human_threshold}%"
    log_info "Minimum resolution: #{@min_resolution}x#{@min_height}"
    log_info "Dry run: #{@options[:dry_run] ? 'YES' : 'NO'}"
    log_info "Upscale small images: #{@upscale_small ? 'YES' : 'NO'}"
    log_info "Replace originals: #{@replace_originals ? 'YES' : 'NO'}"
    log_info "Processing tracking: #{@disable_tracking ? 'DISABLED' : 'ENABLED'}"
    log_info "Force reprocess: #{@force_reprocess ? 'YES' : 'NO'}"
    log_info "Parallel workers: #{@worker_count || 'auto-detect'}"

    # Show system information when auto-detecting workers
    if @worker_count.nil?
      sys_info = system_info
      memory_mb = sys_info[:memory][:available] ? (sys_info[:memory][:available] / 1024 / 1024).round : 0
      log_info "System: #{sys_info[:cpu][:cores]} cores, #{memory_mb}MB available RAM"
      if sys_info[:cpu][:model] && !sys_info[:cpu][:model].include?("Unknown")
        log_info "CPU: #{sys_info[:cpu][:model]}"
      end
      if apple_silicon?
        log_info "🍎 Apple Silicon detected - optimizing for ARM architecture"
      end
    end

    if !@disable_tracking
      stats = @tracker.get_statistics
      log_info "Previously processed files: #{stats[:total_files]}"
    end
    puts

    # Get all image files
    image_files = find_image_files

    # Limit files for debugging if max is specified
    if @max_files && @max_files > 0
      original_count = image_files.length
      image_files = image_files.first(@max_files)
      log_info "Limited to first #{@max_files} files (was #{original_count} total)"
    end

    log_info "Processing #{image_files.length} image files"
    puts

    if image_files.empty?
      log_warning "No image files found in the directory"
      return
    end

    # PASS 1: Human Detection
    log_section "PASS 1: Human Detection Analysis"
    detect_humans_in_files(image_files)

    # Show deletion candidates and ask for confirmation
    if @files_to_delete.any?
      show_deletion_candidates
      confirm_deletions unless @options[:dry_run] || @options[:force]
    else
      log_success "No images with high human content found"
    end

    puts

    # PASS 2: Resolution Analysis & Upscaling
    if @upscale_small
      log_section "PASS 2: Resolution Analysis & Upscaling"
      analyze_resolution(image_files)

      if @files_to_upscale.any?
        show_upscale_candidates
        confirm_upscaling unless @options[:dry_run] || @options[:force]
      else
        log_success "No images need upscaling"
      end
    end

    # Final summary
    puts
    log_section "Summary"
    log_success "Images marked for deletion: #{@files_to_delete.length}"
    log_success "Images marked for upscaling: #{@files_to_upscale.length}"

    if @options[:dry_run]
      log_warning "This was a dry run - no changes were made"
      log_info "Run without --dry-run to apply changes"
    else
      show_completion(script_title)
    end
  end

  private

  def find_image_files
    find_files_by_extensions(@wallpapers_dir, %w[.jpg .jpeg .png .webp .bmp .tiff .tif])
  end

  def detect_humans_in_files(image_files)
    found_count = 0
    error_count = 0
    skipped_count = 0
    cached_count = 0

    # Pre-filter small images to avoid parallel processing overhead
    large_images = []
    small_images = []

    image_files.each do |image_path|
      begin
        width, height = get_image_dimensions(image_path)
        if width < 200 || height < 200
          small_images << { path: image_path, width: width, height: height }
        else
          large_images << { path: image_path, width: width, height: height }
        end
      rescue => e
        error_count += 1
        log_debug "Error getting dimensions for #{File.basename(image_path)}: #{e.message}" if @options[:debug]
      end
    end

    skipped_count = small_images.size

    if large_images.any?
      # Process large images in parallel
      operation_params = { threshold: @human_threshold }

      results = process_in_parallel(
        large_images,
        worker_count: @worker_count,
        task_type: :io_intensive, # External process calls
        memory_per_worker: 50, # Estimated memory per worker for human detection
        progress_message: "Detecting humans (parallel)",
        verbose: @options[:debug]
      ) do |image_info|
        process_single_image_human_detection(image_info, operation_params)
      end

      # Process results
      results.each do |result|
        next if result.nil?

        if result[:cached]
          cached_count += 1
        end

        if result[:human_percentage] > 0
          found_count += 1
        end

        if result[:human_percentage] > @human_threshold
          @files_to_delete << {
            path: result[:path],
            human_percentage: result[:human_percentage],
            width: result[:width],
            height: result[:height]
          }
        end

        if result[:error]
          error_count += 1
        end
      end
    end

    log_info "Found #{found_count} images with human content"
    log_info "Skipped #{skipped_count} small images"
    log_info "Used cached results: #{cached_count}" if cached_count > 0
    log_info "Errors encountered: #{error_count}" if error_count > 0

    if large_images.any?
      log_info "Processed #{large_images.size} images with parallel workers"
    end
  end

  def process_single_image_human_detection(image_info, operation_params)
    image_path = image_info[:path]
    width = image_info[:width]
    height = image_info[:height]

    begin
      human_percentage = nil

      # Check if we already have cached results
      if !@disable_tracking && !@force_reprocess
        if !@tracker.needs_processing?(image_path, 'detect_humans', params: operation_params)
          # Get cached result
          record = @tracker.get_processing_record(image_path, 'detect_humans')
          if record && record['result']
            human_percentage = JSON.parse(record['result'])['human_percentage']
            return {
              path: image_path,
              width: width,
              height: height,
              human_percentage: human_percentage,
              cached: true,
              error: false
            }
          end
        end
      end

      # Only run detection if needed
      if human_percentage.nil?
        human_percentage = detect_humans(image_path)

        # Cache the result
        if !@disable_tracking
          result_data = { human_percentage: human_percentage }
          @tracker.record_processed(image_path, 'detect_humans',
                                    result_data.to_json,
                                    params: operation_params)
        end
      end

      {
        path: image_path,
        width: width,
        height: height,
        human_percentage: human_percentage,
        cached: false,
        error: false
      }

    rescue => e
      log_debug "Error processing #{File.basename(image_path)}: #{e.message}" if @options[:debug]
      {
        path: image_path,
        width: width,
        height: height,
        human_percentage: 0.0,
        cached: false,
        error: true
      }
    end
  end

  def analyze_resolution(image_files)
    # Filter out files that are already marked for deletion
    remaining_files = image_files - @files_to_delete.map { |f| f[:path] }

    with_step_progress("Checking resolution", remaining_files.length) do |progress|
      remaining_files.each do |image_path|
        begin
          width, height = get_image_dimensions(image_path)

          if width < @min_resolution || height < @min_height
            @files_to_upscale << {
              path: image_path,
              width: width,
              height: height
            }
          end
        rescue => e
          # Silently skip errors
        end

        progress.call(remaining_files.index(image_path) + 1)
      end
    end
  end

  def get_image_dimensions(image_path)
    dims = ImageUtils::General.get_dimensions(image_path)
    if dims[:width] > 0 && dims[:height] > 0
      [dims[:width], dims[:height]]
    else
      raise "Failed to get image dimensions"
    end
  end

  def detect_humans(image_path)
    # Call the detect-human script using the ScriptBase utility method
    output = execute_zsh_script('detect-human', image_path,
                              description: "Detecting humans in #{File.basename(image_path)}")

    if output
      if match = output.match(/Average confidence: ([\d.]+)%/)
        return match[1].to_f
      elsif match = output.match(/avg confidence: ([\d.]+)%/)
        return match[1].to_f
      elsif match = output.match(/confidence ([\d.]+)%/)
        return match[1].to_f
      elsif output.include?("person(s)")
        if match = output.match(/Person \d+: confidence ([\d.]+)%/)
          return match[1].to_f
        else
          return 80.0
        end
      else
        return 0.0
      end
    else
      log_debug "detect-human command failed" if @options[:debug]
      return 0.0
    end
  end

  def show_deletion_candidates
    log_section "Images with High Human Content (Threshold: #{@human_threshold}%)"
    puts

    @files_to_delete.each_with_index do |file, index|
      puts "#{index + 1}. #{File.basename(file[:path])}"
      puts "   📏 Resolution: #{file[:width]}x#{file[:height]}"
      puts "   👤 Human content: #{file[:human_percentage]}%"
      puts "   📂 Path: #{file[:path]}"
      puts
    end
  end

  def show_upscale_candidates
    log_section "Low Resolution Images (Minimum: #{@min_resolution}x#{@min_height})"
    puts

    @files_to_upscale.each_with_index do |file, index|
      puts "#{index + 1}. #{File.basename(file[:path])}"
      puts "   📏 Current resolution: #{file[:width]}x#{file[:height]}"
      puts "   📂 Path: #{file[:path]}"
      puts
    end
  end

  def confirm_deletions
    return if @files_to_delete.empty?

    log_warning "Found #{@files_to_delete.length} images with human content above threshold"

    if confirm_action("Do you want to delete these images?")
      log_section "Deleting Images"

      @files_to_delete.each_with_index do |file, index|
        print "\r🗑️  Deleting: #{index + 1}/#{@files_to_delete.length}"
        $stdout.flush

        begin
          File.delete(file[:path])
          log_success "Deleted: #{File.basename(file[:path])}"
        rescue => e
          log_error "Failed to delete #{File.basename(file[:path])}: #{e.message}"
        end
      end

      puts "\n"
      log_success "Successfully deleted #{@files_to_delete.length} images"
    else
      log_info "Deletion cancelled by user"
      @files_to_delete.clear
    end
  end

  def confirm_upscaling
    return if @files_to_upscale.empty?

    log_warning "Found #{@files_to_upscale.length} images that need upscaling"

    if confirm_action("Do you want to upscale these images?")
      log_section "Upscaling Images"

      @files_to_upscale.each_with_index do |file, index|
        print "\r🖼️  Upscaling: #{index + 1}/#{@files_to_upscale.length}"
        $stdout.flush

        begin
          upscale_image(file)
          log_success "Upscaled: #{File.basename(file[:path])}"
        rescue => e
          log_error "Failed to upscale #{File.basename(file[:path])}: #{e.message}"
        end
      end

      puts "\n"
      log_success "Successfully upscaled #{@files_to_upscale.length} images"
    else
      log_info "Upscaling cancelled by user"
      @files_to_upscale.clear
    end
  end

  def upscale_image(file)
    image_path = file[:path]
    operation_params = {
      min_resolution: @min_resolution,
      min_height: @min_height,
      replace_originals: @replace_originals
    }

    base_name = File.basename(image_path, File.extname(image_path))
    extension = File.extname(image_path)

    if @replace_originals
      # When replacing originals, upscale to a temporary file first
      temp_path = File.join(File.dirname(image_path), "#{base_name}_temp_upscale#{extension}")

      # Call the upscale-image script using the ScriptBase utility method
      result = execute_zsh_script?('upscale-image', image_path, temp_path,
                                  description: "Upscaling #{File.basename(image_path)}")

      if result
        if !@options[:dry_run]
          # Create backup of original
          backup_path = File.join(File.dirname(image_path), "#{base_name}_original#{extension}")
          require 'fileutils'
          FileUtils.mv(image_path, backup_path)

          # Move upscaled version to original location
          FileUtils.mv(temp_path, image_path)

          # Track successful upscaling
          if !@disable_tracking
            result_data = {
              upscaled: true,
              backup_path: backup_path,
              original_resolution: "#{file[:width]}x#{file[:height]}",
              method: 'replace_original'
            }
            @tracker.record_processed(image_path, 'upscale_image',
                                      result_data.to_json,
                                      params: operation_params)
          end

          log_success "Upscaled and replaced: #{File.basename(image_path)} (backup: #{File.basename(backup_path)})"
        else
          log_warning "[DRY RUN] Would replace: #{File.basename(image_path)}"
        end
      else
        raise "Upscaling process failed"
      end
    else
      # Original behavior: keep both files
      upscaled_path = File.join(File.dirname(image_path), "#{base_name}_upscaled#{extension}")

      # Call the local upscale-image script using the ScriptBase utility method
      result = execute_zsh_script?('upscale-image', image_path, upscaled_path,
                                  description: "Upscaling #{File.basename(image_path)}")

      if result
        # Track successful upscaling
        if !@options[:dry_run] && !@disable_tracking
          result_data = {
            upscaled: true,
            upscaled_path: upscaled_path,
            original_resolution: "#{file[:width]}x#{file[:height]}",
            method: 'keep_both'
          }
          @tracker.record_processed(image_path, 'upscale_image',
                                    result_data.to_json,
                                    params: operation_params)
        end

        log_success "Upscaled: #{File.basename(image_path)} -> #{File.basename(upscaled_path)}"
      else
        raise "Upscaling process failed"
      end
    end
  end
end

# Execute the script
CleanWallpapers.execute if __FILE__ == $0