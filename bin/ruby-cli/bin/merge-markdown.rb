#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/archive/file_merger_base'
require 'pathname'

# Merge markdown files with their references into a single file
class MergeMarkdown < FileMergerBase
  def script_title
    'Merge Markdown Files'
  end

  def script_description
    'Merges markdown files into a single document.'
  end

  def script_arguments
    '<input_file> [output_file]'
  end

  def file_extension
    'md'
  end

  def add_custom_options(opts)
    super
    opts.on('-p', '--preserve-structure', 'Preserve directory structure in headers') do
      @options[:preserve_structure] = true
    end
  end

  def validate!
    super

    @input_file = File.expand_path(@args[0])
    unless File.exist?(@input_file)
      log_error("Input file not found: #{@input_file}")
      exit 1
    end

    unless File.extname(@input_file).downcase == '.md'
      log_error('Input file must be a markdown (.md) file')
      exit 1
    end

    # Set default options
    @options[:preserve_structure] ||= false

    @base_dir = File.dirname(@input_file)
    @processed_files = Set.new
    @file_order = [] # Preserve discovery order
    @file_contents = {}
  end

  def merge_files(files)
    log_progress('Creating merged file...')

    File.open(@output_file, 'w') do |output|
      # Write header
      output.puts '# Merged Documentation'
      output.puts
      output.puts "Generated on: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      output.puts "Source file: #{relative_path(@input_file)}"
      output.puts "Files merged: #{files.size}"
      output.puts
      output.puts '---'
      output.puts

      # Write files in discovery order
      files.each do |file_path|
        write_file_section(output, file_path)
      end
    end

    log_file_created(@output_file)
    log_success("Merged #{files.size} files into #{relative_path(@output_file)}")
  end

  def collect_files
    log_progress('Scanning for referenced files...')
    scan_file(@args[0])
    @file_order
  end

  private

  def scan_file(file_path)
    return if @processed_files.include?(file_path)

    log_debug("Scanning: #{file_path}")
    @processed_files.add(file_path)
    @file_order << file_path # Preserve discovery order

    unless File.exist?(file_path)
      log_warning("Referenced file not found: #{file_path}")
      return
    end

    content = File.read(file_path)
    @file_contents[file_path] = content

    return unless @options[:recursive]

    # Find markdown file references
    references = find_markdown_references(content, File.dirname(file_path))
    references.each { |ref| scan_file(ref) }
  end

  def find_markdown_references(content, base_dir)
    references = []

    # Match markdown links: [text](path.md) or [text](./path.md) or [text](../path.md)
    content.scan(/\[([^\]]*)\]\(([^)]+\.md)\)/i) do |_text, path|
      # Resolve relative paths
      full_path = if path.start_with?('/')
                    path
                  else
                    File.expand_path(File.join(base_dir, path))
                  end

      references << full_path if File.exist?(full_path)
    end

    # Match file includes: <!-- include: path.md --> or similar
    content.scan(/<!--\s*include:\s*([^>]+\.md)\s*-->/i) do |path|
      full_path = if path.start_with?('/')
                    path
                  else
                    File.expand_path(File.join(base_dir, path))
                  end

      references << full_path if File.exist?(full_path)
    end

    references.uniq
  end

  def write_file_section(output, file_path)
    relative = relative_path(file_path)

    # Create section header
    header = if @options[:preserve_structure]
               "# #{relative}"
             else
               "# #{File.basename(file_path, '.md').gsub(/[-_]/, ' ').split.map(&:capitalize).join(' ')}"
             end

    output.puts header
    output.puts
    output.puts "**Source:** `#{relative}`"
    output.puts

    # Write content, but skip the first H1 header if it exists to avoid duplication
    content = @file_contents[file_path]
    lines = content.lines

    # Skip first line if it's an H1 header
    lines = lines[1..-1] if lines.first&.start_with?('# ')

    output.puts lines.join
    output.puts
    output.puts '---'
    output.puts
  end

  def relative_path(file_path)
    Pathname.new(file_path).relative_path_from(Pathname.new(@base_dir)).to_s
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name} README.md"
    puts "  #{script_name} docs/main.md merged_docs.md"
    puts "  #{script_name} --dry-run --preserve-structure project.md"
    puts "  #{script_name} --no-recursive simple.md"
  end
end

# Execute the script
MergeMarkdown.execute if __FILE__ == $0
