#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Script to remove single-line console.log statements from source files
class ConsoleLogRemover < ScriptBase
  def script_emoji; '🧹'; end
  def script_title; 'Console Log Remover'; end
  def script_description; 'Removes single-line console.log statements from source files'; end
  def script_arguments; '[OPTIONS] <extension>'; end

  def add_custom_options(opts)
    opts.on('-d', '--directory DIR', 'Target directory (default: current directory)') do |dir|
      @options[:directory] = dir
    end
    opts.on('-r', '--recursive', 'Search recursively in subdirectories') do
      @options[:recursive] = true
    end
    opts.on('--backup', 'Create backup files before modification') do
      @options[:backup] = true
    end
    opts.on('--dry-run', 'Show what would be removed without making changes') do
      @options[:dry_run] = true
    end
  end

  def validate!
    super

    if args.empty?
      log_error("Missing required argument: file extension")
      log_info("Usage: #{script_name} [OPTIONS] <extension>")
      log_info("Example: #{script_name} js")
      log_info("Example: #{script_name} --directory src --recursive ts")
      exit 1
    end

    @extension = args[0].start_with?('.') ? args[0] : ".#{args[0]}"
    @target_dir = @options[:directory] ? File.expand_path(@options[:directory]) : original_working_dir

    unless File.directory?(@target_dir)
      log_error("Directory not found: #{@target_dir}")
      exit 1
    end
  end

  def run
    log_banner(script_title)
    log_info("Target directory: #{@target_dir}")
    log_info("File extension: #{@extension}")
    log_info("Recursive search: #{@options[:recursive] ? 'Yes' : 'No'}")

    if @options[:backup]
      log_info("Backup files will be created")
    end

    if @options[:dry_run]
      log_warning("DRY RUN MODE - No files will be modified")
    end

    files = find_target_files
    if files.empty?
      log_warning("No files found with extension '#{@extension}'")
      return
    end

    log_info("Found #{files.length} files to process")

    process_files(files)
    show_completion(script_title)
  end

  private

  def find_target_files
    pattern = @options[:recursive] ? "**/*#{@extension}" : "*#{@extension}"

    Dir.chdir(@target_dir) do
      Dir.glob(pattern).select { |f| File.file?(f) }
    end
  end

  def process_files(files)
    stats = { files_processed: 0, logs_removed: 0, files_modified: 0 }

    files.each do |file|
      process_file(file, stats)
    end

    log_section("Summary")
    log_info("Files processed: #{stats[:files_processed]}")
    log_info("Console.log statements removed: #{stats[:logs_removed]}")
    log_info("Files modified: #{stats[:files_modified]}")
  end

  def process_file(file, stats)
    stats[:files_processed] += 1
    file_path = File.join(@target_dir, file)

    begin
      content = File.read(file_path, encoding: 'UTF-8')
      original_lines = content.lines
      modified_lines = []
      logs_removed_this_file = 0

      original_lines.each_with_index do |line, index|
        if console_log_line?(line.strip)
          logs_removed_this_file += 1
          log_debug("Removed console.log from #{file}:#{index + 1}") if debug?
          # Skip this line (don't add to modified_lines)
        else
          modified_lines << line
        end
      end

      if logs_removed_this_file > 0
        stats[:logs_removed] += logs_removed_this_file
        stats[:files_modified] += 1

        log_success("Removed #{logs_removed_this_file} console.log statement(s) from #{file}")

        unless @options[:dry_run]
          # Create backup if requested
          if @options[:backup]
            backup_path = "#{file_path}.backup#{Time.now.strftime('%Y%m%d_%H%M%S')}"
            File.write(backup_path, content)
            log_file_backed_up(backup_path) if verbose?
          end

          # Write modified content
          File.write(file_path, modified_lines.join)
          log_file_updated(file_path) if verbose?
        end
      else
        log_debug("No console.log statements found in #{file}") if debug?
      end

    rescue => e
      log_error("Failed to process #{file}: #{e.message}")
    end
  end

  def console_log_line?(line)
    # Skip empty lines and comments
    return false if line.empty? || line.start_with?('//') || line.start_with?('/*') || line.start_with?('*')

    # Match various console.log patterns
    console_log_patterns = [
      /\A\s*console\.log\s*\(/,                   # console.log(
      /\A\s*console\.debug\s*\(/,                 # console.debug(
      /\A\s*console\.info\s*\(/,                  # console.info(
      /\A\s*console\.warn\s*\(/,                  # console.warn(
      /\A\s*console\.error\s*\(/,                 # console.error(
      /\A\s*console\.log\(`.*`\)\s*\z/,           # console.log(`...`) - template literals
      /\A\s*console\.log\('.*'\)\s*\z/,           # console.log('...') - single quotes
      /\A\s*console\.log\(".*"\)\s*\z/,           # console.log("...") - double quotes
      /\A\s*console\.log\([^)]+\)\s*\z/           # console.log(...) - general pattern
    ]

    # Check if the line contains only console.log statement (possibly with whitespace)
    # and no other code on the same line
    stripped_line = line.strip
    return false unless stripped_line.start_with?('console.')

    # Check if it's a single-line console statement (not multi-line)
    # The line should end with ) or ; after the console call
    return true if console_log_patterns.any? { |pattern| stripped_line.match?(pattern) }

    false
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} js                              # Process .js files in current directory"
    puts "  #{script_name} --directory src --recursive ts  # Process .ts files recursively in src/"
    puts "  #{script_name} --backup --dry-run js           # Show what would be removed with backup"
    puts "  #{script_name} --recursive --verbose jsx       # Process .jsx files recursively with verbose output"
  end
end

ConsoleLogRemover.execute if __FILE__ == $0