# frozen_string_literal: true

# Common file filtering utilities
module FileFilter
  module_function

  # Filter files by file extensions
  def filter_by_extensions(file_paths, extensions)
    extensions_set = extensions.map { |ext| ext.downcase }.to_set
    file_paths.select do |file_path|
      ext = File.extname(file_path).downcase
      extensions_set.include?(ext)
    end
  end

  # Filter image files by dimensions
  def filter_images_by_dimensions(image_paths, min_width: 200, min_height: 200,
                                 max_width: nil, max_height: nil)
    filtered = {
      accepted: [],
      rejected: [],
      errors: []
    }

    image_paths.each do |image_path|
      begin
        width, height = get_image_dimensions(image_path)

        if width < min_width || height < min_height
          filtered[:rejected] << {
            path: image_path,
            width: width,
            height: height,
            reason: 'too_small'
          }
        elsif max_width && width > max_width
          filtered[:rejected] << {
            path: image_path,
            width: width,
            height: height,
            reason: 'too_wide'
          }
        elsif max_height && height > max_height
          filtered[:rejected] << {
            path: image_path,
            width: width,
            height: height,
            reason: 'too_tall'
          }
        else
          filtered[:accepted] << {
            path: image_path,
            width: width,
            height: height
          }
        end
      rescue => e
        filtered[:errors] << {
          path: image_path,
          error: e.message
        }
      end
    end

    filtered
  end

  # Filter files using custom criteria
  def filter_by_criteria(file_paths, criteria_proc)
    filtered = {
      accepted: [],
      rejected: [],
      errors: []
    }

    file_paths.each do |file_path|
      begin
        if criteria_proc.call(file_path)
          filtered[:accepted] << file_path
        else
          filtered[:rejected] << file_path
        end
      rescue => e
        filtered[:errors] << {
          path: file_path,
          error: e.message
        }
      end
    end

    filtered
  end

  # Create a filter chain for complex filtering
  def filter_chain(file_paths, *filters)
    result = {
      accepted: file_paths.dup,
      rejected: [],
      errors: [],
      filter_results: []
    }

    filters.each_with_index do |filter, index|
      case filter[:type]
      when :dimensions
        filter_result = filter_images_by_dimensions(
          result[:accepted],
          min_width: filter[:min_width] || 200,
          min_height: filter[:min_height] || 200,
          max_width: filter[:max_width],
          max_height: filter[:max_height]
        )
      when :extensions
        filter_result = {
          accepted: filter_by_extensions(result[:accepted], filter[:extensions]),
          rejected: result[:accepted] - filter_by_extensions(result[:accepted], filter[:extensions]),
          errors: []
        }
      when :custom
        filter_result = filter_by_criteria(result[:accepted], filter[:criteria])
      else
        raise "Unknown filter type: #{filter[:type]}"
      end

      result[:filter_results] << {
        filter: filter,
        result: filter_result
      }

      # Move rejected files to overall rejected list
      result[:rejected].concat(filter_result[:rejected])
      result[:errors].concat(filter_result[:errors])

      # Update accepted files for next filter
      result[:accepted] = filter_result[:accepted]
    end

    result
  end

  # Make get_image_dimensions available as module function
  module_function

  def get_image_dimensions(image_path)
    require_relative 'image_utils'
    dims = ImageUtils::General.get_dimensions(image_path)
    if dims[:width] > 0 && dims[:height] > 0
      [dims[:width], dims[:height]]
    else
      raise "Failed to get image dimensions"
    end
  end
end