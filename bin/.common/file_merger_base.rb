# frozen_string_literal: true

require_relative 'script_base'

# Base class for scripts that merge files
class FileMergerBase < ScriptBase
  def add_custom_options(opts)
    opts.on('-r', '--recursive', 'Search subdirectories recursively') do
      @options[:recursive] = true
    end

    opts.on('-o', '--overwrite', 'Overwrite output file if it exists') do
      @options[:overwrite] = true
    end
  end

  def validate!
    if @args.length < 2
      log_error('Insufficient arguments. Need output file and at least one input.')
      show_help
      exit(1)
    end

    @output_file = @args[0]
    @inputs = @args[1..] || []

    # Ensure output has the correct extension
    @output_file += ".#{file_extension}" unless @output_file.end_with?(".#{file_extension}")

    # Check if output file exists
    if File.exist?(@output_file) && !@options[:overwrite]
      log_error("Output file '#{@output_file}' already exists. Use --overwrite to replace.")
      exit(1)
    end

    super
  end

  def run
    log_banner(script_title)

    files_to_merge = collect_files

    if files_to_merge.empty?
      log_error("No #{file_extension.upcase} files found to merge")
      exit(1)
    end

    log_info("Found #{files_to_merge.length} #{file_extension.upcase} files:")
    files_to_merge.each { |file| puts "  📄 #{file}" }

    return if @options[:dry_run]

    unless confirm_action("Merge #{files_to_merge.length} #{file_extension.upcase} files into '#{@output_file}'?")
      log_info('Operation cancelled')
      exit(0)
    end

    merge_files(files_to_merge)
    show_completion(script_title)
  end

  private

  def collect_files
    files = []

    @inputs.each do |input|
      if File.directory?(input)
        files.concat(find_files_in_directory(input))
      elsif File.file?(input) && input.end_with?(".#{file_extension}")
        files << input
      else
        log_warning("Skipping '#{input}' - not a #{file_extension.upcase} file or directory")
      end
    end

    files.sort.uniq
  end

  def find_files_in_directory(directory)
    log_info("🔍 Scanning directory: #{directory}")

    pattern = @options[:recursive] ? "#{directory}/**/*.#{file_extension}" : "#{directory}/*.#{file_extension}"
    files = Dir.glob(pattern)

    log_info("Found #{files.length} #{file_extension.upcase} files in #{directory}")
    files
  end

  # Methods to be implemented by subclasses
  def file_extension
    raise NotImplementedError, "Subclasses must implement #file_extension"
  end

  def merge_files(files)
    raise NotImplementedError, "Subclasses must implement #merge_files"
  end
end
