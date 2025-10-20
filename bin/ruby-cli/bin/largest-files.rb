#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../.common/script_base'

# Script to find largest files while respecting .gitignore patterns
class LargestFilesScript < ScriptBase
  def script_emoji; '📊'; end
  def script_title; 'Largest Files Finder'; end
  def script_description; 'Find the largest files by lines (default) or size while respecting .gitignore patterns'; end
  def script_arguments; '[OPTIONS] [directory]'; end

  def add_custom_options(opts)
    opts.on('-n', '--count COUNT', Integer, 'Number of files to show (default: 20)') do |count|
      @options[:count] = count
    end
    opts.on('-s', '--size', 'Sort by file size instead of number of lines') do
      @options[:sort_by_size] = true
    end
    opts.on('-m', '--min-size SIZE', 'Minimum file size to consider (e.g., 1M, 100K)') do |size|
      @options[:min_size] = parse_size(size)
    end
    opts.on('--min-lines COUNT', Integer, 'Minimum number of lines to consider') do |count|
      @options[:min_lines] = count
    end
    opts.on('--hidden', 'Include hidden files and directories') do
      @options[:hidden] = true
    end
    opts.on('--no-gitignore', 'Ignore .gitignore patterns') do
      @options[:no_gitignore] = true
    end
  end

  def validate!
    super
    @directory = args.empty? ? original_working_dir : File.expand_path(args[0])

    unless File.directory?(@directory)
      log_error "Directory not found: #{@directory}"
      exit 1
    end

    @count = @options[:count] || 20
    @min_size = @options[:min_size] || 0
    @min_lines = @options[:min_lines] || 0
    @sort_by_size = @options[:sort_by_size] || false
    @include_hidden = @options[:hidden] || false
    @respect_gitignore = !@options[:no_gitignore]
  end

  def run
    log_banner("Finding Largest Files")

    log_info "Scanning directory: #{@directory}"
    log_info "Showing top #{@count} files" if @count > 0

    if @sort_by_size
      log_info "Sorting by: File size"
      log_info "Minimum size: #{format_size(@min_size)}" if @min_size > 0
    else
      log_info "Sorting by: Number of lines"
      log_info "Minimum lines: #{@min_lines}" if @min_lines > 0
    end

    log_info "Respecting .gitignore: #{@respect_gitignore ? 'Yes' : 'No'}"
    log_info "Including hidden files: #{@include_hidden ? 'Yes' : 'No'}"

    gitignore_patterns = load_gitignore_patterns if @respect_gitignore

    log_progress "Scanning for files..."
    files = find_files(@directory, gitignore_patterns)

    if files.empty?
      log_warning "No files found matching criteria"
      return
    end

    if @sort_by_size
      log_progress "Calculating file sizes..."
      files_with_metrics = get_file_sizes(files)
    else
      log_progress "Counting lines..."
      files_with_metrics = get_file_line_counts(files)
    end

    log_progress "Filtering and sorting..."
    filtered_files = filter_and_sort_files(files_with_metrics)

    display_results(filtered_files)
    show_completion("Largest files analysis")
  end

  private

  def parse_size(size_str)
    case size_str.downcase
    when /^(\d+)b?$/i
      $1.to_i
    when /^(\d+)k$/i
      $1.to_i * 1024
    when /^(\d+)m$/i
      $1.to_i * 1024 * 1024
    when /^(\d+)g$/i
      $1.to_i * 1024 * 1024 * 1024
    else
      log_error "Invalid size format: #{size_str}. Use formats like 100K, 1M, 1G"
      exit 1
    end
  end

  def format_size(bytes)
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    if unit_index == 0
      "#{size.to_i}#{units[unit_index]}"
    else
      "#{size.round(1)}#{units[unit_index]}"
    end
  end

  def load_gitignore_patterns
    gitignore_path = File.join(@directory, '.gitignore')
    return [] unless File.exist?(gitignore_path)

    patterns = []
    File.readlines(gitignore_path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')

      # Convert gitignore pattern to regex
      pattern = gitignore_pattern_to_regex(line)
      patterns << pattern if pattern
    end

    log_info "Loaded #{patterns.length} patterns from .gitignore"
    patterns
  end

  def gitignore_pattern_to_regex(pattern)
    # Handle negation patterns starting with !
    negated = pattern.start_with?('!')
    pattern = pattern[1..-1] if negated

    # Escape regex special characters except * and ?
    escaped = Regexp.escape(pattern)
    escaped = escaped.gsub('\\*', '.*').gsub('\\?', '.')

    # Handle directory patterns ending with /
    if escaped.end_with?('\/')
      escaped = escaped[0..-2] + '(/.*)?$'
    else
      escaped += '(/.*)?'
    end

    # Handle leading slash (absolute path)
    if escaped.start_with?('\/')
      escaped = '^' + escaped[1..-1]
    else
      escaped = '(^|/)' + escaped
    end

    begin
      regex = Regexp.new(escaped, Regexp::IGNORECASE)
      negated ? { regex: regex, negated: true } : { regex: regex, negated: false }
    rescue RegexpError => e
      log_warning "Invalid gitignore pattern: #{pattern} (#{e.message})"
      nil
    end
  end

  def file_ignored?(file_path, gitignore_patterns)
    return false if gitignore_patterns.empty?

    relative_path = file_path.sub(@directory + '/', '')

    gitignore_patterns.each do |pattern|
      if relative_path.match?(pattern[:regex])
        return !pattern[:negated]
      end
    end

    false
  end

  def find_files(directory, gitignore_patterns)
    files = []

    Dir.glob("#{directory}/**/*", File::FNM_DOTMATCH).each do |path|
      next unless File.file?(path)

      # Skip hidden files unless requested
      unless @include_hidden
        basename = File.basename(path)
        next if basename.start_with?('.')
      end

      # Skip if file is ignored by gitignore
      next if @respect_gitignore && file_ignored?(path, gitignore_patterns)

      files << path
    end

    log_info "Found #{files.length} files"
    files
  end

  def get_file_sizes(files)
    files.map do |path|
      begin
        size = File.size(path)
        { path: path, size: size, lines: 0 }
      rescue Errno::ENOENT
        # File might have been deleted during scanning
        nil
      end
    end.compact
  end

  def get_file_line_counts(files)
    files.map do |path|
      begin
        # Only count lines for text files to avoid binary files
        if text_file?(path)
          lines = File.readlines(path).count
        else
          lines = 0
        end
        { path: path, size: File.size(path), lines: lines }
      rescue Errno::ENOENT
        # File might have been deleted during scanning
        nil
      rescue => e
        # Handle encoding errors or other file reading issues
        log_debug "Could not read #{path}: #{e.message}" if debug?
        { path: path, size: File.size(path), lines: 0 }
      end
    end.compact
  end

  def text_file?(path)
    # Simple heuristic to detect text files by extension and content
    text_extensions = %w[.txt .rb .py .js .html .css .json .xml .yaml .yml .md .sh .zsh .sql .go .rs .java .c .cpp .h .hpp .php .pl .swift .kt .scala .clj .hs .ml .r .R .m .mm .swift .dart .ts .jsx .tsx .vue .svelte .elm .ex .exs .erl .hrl .nim .zig .v .vsh .jl .lua .tcl .tk .vim .vimrc .gitignore .gitattributes .editorconfig .dockerfile .makefile .cmake .rake .gemfile .package.json .requirements.txt .toml .ini .cfg .conf .config .env .env.example .env.local .env.development .env.test .env.production .log .out .err .stderr .stdout]

    extension = File.extname(path).downcase
    return true if text_extensions.include?(extension)

    # Check file content if extension is not recognized
    begin
      File.open(path, 'rb') do |file|
        # Read first 1024 bytes and check for null bytes (indicator of binary)
        chunk = file.read(1024)
        return !chunk.include?("\x00")
      end
    rescue
      false
    end
  end

  def filter_and_sort_files(files_with_metrics)
    # Filter by minimum criteria
    if @sort_by_size
      filtered = files_with_metrics.select { |file| file[:size] >= @min_size }
      # Sort by size (largest first)
      sorted = filtered.sort_by { |file| -file[:size] }
    else
      filtered = files_with_metrics.select { |file| file[:lines] >= @min_lines }
      # Sort by lines (largest first)
      sorted = filtered.sort_by { |file| -file[:lines] }
    end

    # Take top N files
    @count > 0 ? sorted.first(@count) : sorted
  end

  def display_results(files)
    if @sort_by_size
      log_section "Largest Files by Size"
    else
      log_section "Largest Files by Lines"
    end

    if files.empty?
      log_warning "No files found matching criteria"
      return
    end

    # Calculate totals
    total_size = files.sum { |file| file[:size] }
    total_lines = files.sum { |file| file[:lines] }

    if @sort_by_size
      puts "Total size of shown files: #{format_size(total_size)}"
    else
      puts "Total lines of shown files: #{total_lines.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end
    puts ""

    # Find the longest path for alignment
    max_path_length = [40, files.map { |f| f[:path].length }.max].min

    # Display header based on sorting method
    if @sort_by_size
      printf "%-#{max_path_length}s %10s %s\n", "File", "Size", "Path"
      puts "-" * (max_path_length + 10 + 50)

      files.each_with_index do |file, index|
        size_str = format_size(file[:size])
        relative_path = file[:path].sub(@directory + '/', '')

        # Truncate path if too long
        if relative_path.length > 50
          relative_path = "..." + relative_path[-47..-1]
        end

        printf "%-#{max_path_length}s %10s %s\n",
               File.basename(file[:path]),
               size_str,
               relative_path
      end
    else
      printf "%-#{max_path_length}s %8s %10s %s\n", "File", "Lines", "Size", "Path"
      puts "-" * (max_path_length + 8 + 10 + 50)

      files.each_with_index do |file, index|
        lines_str = file[:lines].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        size_str = format_size(file[:size])
        relative_path = file[:path].sub(@directory + '/', '')

        # Truncate path if too long
        if relative_path.length > 50
          relative_path = "..." + relative_path[-47..-1]
        end

        printf "%-#{max_path_length}s %8s %10s %s\n",
               File.basename(file[:path]),
               lines_str,
               size_str,
               relative_path
      end
    end

    puts ""
    if @sort_by_size
      log_info "Found #{files.length} files matching criteria"
    else
      log_info "Found #{files.length} files matching criteria"
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # Show 20 files with most lines in current directory"
    puts "  #{script_name} -s                 # Show 20 largest files by size in current directory"
    puts "  #{script_name} /path/to/dir       # Show files with most lines in specific directory"
    puts "  #{script_name} -n 50              # Show 50 files with most lines"
    puts "  #{script_name} -s -n 50           # Show 50 largest files by size"
    puts "  #{script_name} -m 10M             # Show files larger than 10MB (requires -s)"
    puts "  #{script_name} --min-lines 100    # Show files with at least 100 lines"
    puts "  #{script_name} --hidden           # Include hidden files"
    puts "  #{script_name} --no-gitignore     # Ignore .gitignore patterns"
    puts "  #{script_name} -n 10 -s -m 5M /path # Custom options with directory"
  end
end

LargestFilesScript.execute if __FILE__ == $0