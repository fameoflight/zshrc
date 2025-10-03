# frozen_string_literal: true

require_relative 'workflow_processor'
require_relative 'file_filter'
require_relative 'image_utils'

# Specialized workflow processor for image processing operations
class ImageWorkflow < WorkflowProcessor
  include FileFilter

  def initialize(tracker = nil, logger: nil, options: {})
    super(tracker, logger: logger, options: options)
  end

  # Common image processing workflow
  def process_images(image_paths, options = {})
    workflow_config = build_image_workflow_config(options)
    process_workflow(image_paths, workflow_config)
  end

  # Build a standard image processing workflow configuration
  def build_image_workflow_config(options = {})
    passes = []

    # Pass 1: Filter by dimensions and optionally detect humans
    if options[:human_detection] || options[:min_width] || options[:min_height]
      passes << {
        name: "Image Analysis & Filtering",
        operation_name: "analyze_images",
        enable_cache: true,
        cache_description: "image analysis results",
        show_progress: true,
        filter_proc: lambda do |file_path|
          width, height = ImageUtils::General.get_dimensions(file_path)
          (width >= (options[:min_width] || 200)) && (height >= (options[:min_height] || 200))
        end,
        process_proc: lambda do |file_path|
          width, height = ImageUtils::General.get_dimensions(file_path)
          result = {
            width: width,
            height: height,
            file_size: File.size(file_path),
            needs_upscaling: width < (options[:min_resolution] || 3840) || height < (options[:min_height] || 2160)
          }

          # Add human detection if enabled
          if options[:human_detection]
            human_percentage = detect_humans(file_path, options[:human_threshold] || 60.0)
            result[:human_percentage] = human_percentage
            result[:exclude_from_next_pass] = human_percentage > (options[:human_threshold] || 60.0)
          end

          result
        end,
        filter_remaining: true
      }
    end

    # Pass 2: Resolution analysis and upscaling
    if options[:upscaling]
      passes << {
        name: "Resolution Analysis & Upscaling",
        operation_name: "analyze_resolution",
        enable_cache: true,
        cache_description: "resolution analysis results",
        show_progress: true,
        process_proc: lambda do |file_path|
          width, height = ImageUtils::General.get_dimensions(file_path)
          min_width = options[:min_resolution] || 3840
          min_height = options[:min_height] || 2160

          needs_upscaling = width < min_width || height < min_height
          result = {
            width: width,
            height: height,
            needs_upscaling: needs_upscaling,
            min_width: min_width,
            min_height: min_height
          }

          # Perform upscaling if needed and not dry run
          if needs_upscaling && !options[:dry_run]
            upscaled_path = upscale_image(file_path, options)
            result[:upscaled_path] = upscaled_path
          end

          result
        end
      }
    end

    # Pass 3: Custom processing pass
    if options[:custom_pass]
      passes << options[:custom_pass]
    end

    passes
  end

  # Detect humans in an image using external script
  def detect_humans(image_path, threshold = 60.0)
    # This would need to be implemented based on the specific human detection method
    # For now, return a placeholder
    0.0
  end

  # Upscale an image using external script
  def upscale_image(image_path, options = {})
    # This would need to be implemented based on the specific upscaling method
    # For now, return a placeholder
    nil
  end

  # Pre-filter images by multiple criteria
  def prefilter_images(image_paths, options = {})
    filters = []

    # Add dimension filter
    if options[:min_width] || options[:min_height] || options[:max_width] || options[:max_height]
      filters << {
        type: :dimensions,
        min_width: options[:min_width] || 200,
        min_height: options[:min_height] || 200,
        max_width: options[:max_width],
        max_height: options[:max_height]
      }
    end

    # Add extension filter
    if options[:allowed_extensions]
      filters << {
        type: :extensions,
        extensions: options[:allowed_extensions]
      }
    end

    # Add custom filter
    if options[:custom_filter]
      filters << {
        type: :custom,
        criteria: options[:custom_filter]
      }
    end

    if filters.any?
      filter_chain(image_paths, *filters)
    else
      {
        accepted: image_paths,
        rejected: [],
        errors: [],
        filter_results: []
      }
    end
  end

  # Generate summary statistics for image processing results
  def generate_image_summary(workflow_result)
    summary = workflow_result[:summary]

    # Add image-specific statistics
    if workflow_result[:pass_results].any?
      first_pass = workflow_result[:pass_results].first
      if first_pass[:results].any?
        dimensions = first_pass[:results].map { |r| r[:data][:width] && r[:data][:height] ?
                                                 [r[:data][:width], r[:data][:height]] : nil }.compact

        if dimensions.any?
          widths = dimensions.map(&:first)
          heights = dimensions.map(&:last)

          summary[:image_stats] = {
            min_width: widths.min,
            max_width: widths.max,
            avg_width: (widths.sum.to_f / widths.length).round(0),
            min_height: heights.min,
            max_height: heights.max,
            avg_height: (heights.sum.to_f / heights.length).round(0),
            total_pixels: dimensions.sum { |w, h| w * h }
          }
        end

        # Count images needing upscaling
        upscaling_needed = first_pass[:results].count { |r| r[:data][:needs_upscaling] }
        summary[:upscaling_needed] = upscaling_needed if upscaling_needed > 0

        # Count images with human content
        human_content = first_pass[:results].count { |r| r[:data][:human_percentage] && r[:data][:human_percentage] > 0 }
        summary[:human_content_detected] = human_content if human_content > 0
      end
    end

    summary
  end

  # Override process_workflow to add image-specific summary
  def process_workflow(image_paths, passes, options = {})
    result = super(image_paths, passes, options)

    # Add image-specific summary
    result[:image_summary] = generate_image_summary(result)

    result
  end
end