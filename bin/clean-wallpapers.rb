#!/usr/bin/env ruby
require 'json'
require_relative '.common/script_base'
require_relative '.common/image_utils'
require_relative '.common/utils/progress_utils'
require_relative '.common/utils/parallel_utils'
require_relative '.common/utils/device_utils'
require_relative '.common/file_processing_tracker'
require_relative '.common/file_filter'
require_relative '.common/image_workflow'

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
    @workflow = nil

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
    # Initialize workflow with worker count after options are parsed
    @workflow = ImageWorkflow.new(@tracker, options: { worker_count: @worker_count, disable_tracking: @disable_tracking, force_reprocess: @force_reprocess })

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

    if image_files.empty?
      log_warning "No image files found in the directory"
      return
    end

    # Pre-filter small images to avoid processing overhead
    filtered_result = FileFilter.filter_images_by_dimensions(
      image_files,
      min_width: 200,
      min_height: 200
    )

    log_info "Found #{image_files.length} image files"
    log_info "Accepted after filtering: #{filtered_result[:accepted].length}"
    log_info "Rejected after filtering: #{filtered_result[:rejected].length}"
    log_info "Errors during filtering: #{filtered_result[:errors].length}"

    if filtered_result[:rejected].any?
      log_info "Skipped #{filtered_result[:rejected].length} small images (< 200x200)"
    end

    if filtered_result[:errors].any?
      log_warning "Errors during filtering: #{filtered_result[:errors].length}"
      if @options[:debug]
        filtered_result[:errors].first(5).each do |error|
          log_debug "Error: #{error[:path]} - #{error[:error]}"
        end
      end
    end

    # Create custom workflow for this script
    workflow_config = [
      {
        name: "Human Detection Analysis",
        operation_name: "detect_humans",
        enable_cache: true,
        cache_description: "human detection results",
        show_progress: true,
        parallel_processing: true,
        progress_description: "files for human detection",
        filter_proc: ->(path) { true }, # Already filtered by size above
        process_proc: ->(path) { detect_humans_in_image(path) },
        filter_remaining: true
      }
    ]

    # Add resolution analysis pass if upscaling is enabled
    if @upscale_small
      workflow_config << {
        name: "Resolution Analysis & Upscaling",
        operation_name: "analyze_resolution",
        enable_cache: true,
        cache_description: "resolution analysis results",
        show_progress: true,
        parallel_processing: true,
        progress_description: "files for resolution analysis",
        process_proc: ->(path) { analyze_image_resolution(path) }
      }
    end

    # Process workflow
    workflow_result = @workflow.process_workflow(
      filtered_result[:accepted].map { |f| f[:path] },
      workflow_config
    )

    # Extract results from workflow
    extract_results_from_workflow(workflow_result)

    # Show deletion candidates and ask for confirmation
    if @files_to_delete.any?
      show_deletion_candidates
      confirm_deletions unless @options[:dry_run] || @options[:force]
    else
      log_success "No images with high human content found"
    end

    puts

    # Show upscaling candidates and ask for confirmation
    if @files_to_upscale.any?
      show_upscale_candidates
      confirm_upscaling unless @options[:dry_run] || @options[:force]
    else
      log_success "No images need upscaling"
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

  def extract_results_from_workflow(workflow_result)
    # Extract human detection results
    if workflow_result[:pass_results].any?
      human_detection_pass = workflow_result[:pass_results].find { |p| p[:pass_name]&.include?("Human Detection") }
      if human_detection_pass
        human_detection_pass[:results].each do |result|
          data = result[:data]
          if data[:human_percentage] && data[:human_percentage] > @human_threshold
            @files_to_delete << {
              path: result[:path],
              human_percentage: data[:human_percentage],
              width: data[:width],
              height: data[:height]
            }
          end
        end
      end

      # Extract upscaling results
      upscaling_pass = workflow_result[:pass_results].find { |p| p[:pass_name]&.include?("Resolution") }
      if upscaling_pass
        upscaling_pass[:results].each do |result|
          data = result[:data]
          if data[:needs_upscale]
            @files_to_upscale << {
              path: result[:path],
              width: data[:width],
              height: data[:height]
            }
          end
        end
      end
    end
  end

  def detect_humans_in_image(image_path)
    dimensions = ImageUtils::General.get_dimensions(image_path)
    width = dimensions[:width]
    height = dimensions[:height]
    human_percentage = detect_humans(image_path)

    result = {
      width: width,
      height: height,
      human_percentage: human_percentage,
      needs_upscale: width < @min_resolution || height < @min_height
    }

    # Mark for exclusion if human content exceeds threshold
    result[:exclude_from_next_pass] = human_percentage > @human_threshold

    result
  end

  def analyze_image_resolution(image_path)
    dimensions = ImageUtils::General.get_dimensions(image_path)
    width = dimensions[:width]
    height = dimensions[:height]
    needs_upscale = width < @min_resolution || height < @min_height

    # Debug output to see what's being analyzed
    if @options[:debug]
      log_debug "Analyzing: #{File.basename(image_path)} - #{width}x#{@min_resolution} x #{height}x#{@min_height} -> needs_upscale: #{needs_upscale}"
    end

    result = {
      width: width,
      height: height,
      needs_upscale: needs_upscale,
      min_width: @min_resolution,
      min_height: @min_height
    }

    # Note: Actual upscaling is done during confirmation step
    # This just marks images that need upscaling
    result[:upscale_needed] = needs_upscale

    result
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

  def upscale_image(image_path)
    # Generate output path
    base_name = File.basename(image_path, ".*")
    extension = File.extname(image_path)
    output_path = File.join(File.dirname(image_path), "#{base_name}_upscaled#{extension}")

    # Call the upscale-image script using the ScriptBase utility method
    output = execute_zsh_script('upscale-image', image_path, output_path,
                              description: "Upscaling #{File.basename(image_path)}")

    if output && File.exist?(output_path)
      log_success "Upscaled: #{File.basename(image_path)} -> #{File.basename(output_path)}"
      return output_path
    else
      log_error "Failed to upscale #{File.basename(image_path)}"
      return nil
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

      # Determine optimal worker count for upscaling (CPU intensive task)
      worker_count = @worker_count || optimal_worker_count(task_type: :cpu_intensive, memory_per_worker: 500)
      worker_count = [worker_count, @files_to_upscale.length].min

      log_info "Using #{worker_count} parallel workers for upscaling"

      success_count = 0
      failure_count = 0
      results_mutex = Mutex.new

      # Process images in parallel
      results = process_in_parallel(
        @files_to_upscale,
        worker_count: worker_count,
        task_type: :cpu_intensive,
        memory_per_worker: 500,
        progress_message: "Upscaling images",
        verbose: @options[:debug]
      ) do |file|
        begin
          upscaled_path = upscale_image(file[:path])
          if upscaled_path
            # Replace original if requested and upscaling succeeded
            if @replace_originals && upscaled_path && File.exist?(upscaled_path)
              remove_file(file[:path])
              File.rename(upscaled_path, file[:path])
              log_success "Upscaled and replaced: #{File.basename(file[:path])}"
            else
              log_success "Upscaled: #{File.basename(file[:path])}"
            end
            { success: true, file: file, path: upscaled_path }
          else
            log_error "Failed to upscale #{File.basename(file[:path])}"
            { success: false, file: file, error: "Upscaling failed" }
          end
        rescue => e
          log_error "Failed to upscale #{File.basename(file[:path])}: #{e.message}"
          { success: false, file: file, error: e.message }
        end
      end

      # Count successes and failures
      results.each do |result|
        if result && result[:success]
          results_mutex.synchronize { success_count += 1 }
        else
          results_mutex.synchronize { failure_count += 1 }
        end
      end

      log_success "Successfully upscaled #{success_count} images"
      if failure_count > 0
        log_warning "Failed to upscale #{failure_count} images"
      end
    else
      log_info "Upscaling cancelled by user"
      @files_to_upscale.clear
    end
  end
end

# Execute the script
CleanWallpapers.execute if __FILE__ == $0