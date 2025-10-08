# frozen_string_literal: true

module Format
  def format_file_size(size_bytes)
    return '0 B' if size_bytes.nil? || size_bytes == 0

    units = %w[B KB MB GB TB]
    size = size_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    if unit_index.zero?
      "#{size.to_i} #{units[unit_index]}"
    else
      "#{size.round(1)} #{units[unit_index]}"
    end
  end
end
