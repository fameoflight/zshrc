#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require 'combine_pdf'
require 'pathname'

# Merge multiple PDF files into a single PDF document
# Supports both individual file arguments and directory scanning
class MergePdf < ScriptBase
  # Script metadata for standardized help text
  def script_emoji
    '📄'
  end

  def script_title
    'PDF Merger'
  end

  def script_description
    'Merges PDF files into a single document. Can accept multiple individual
PDF files or a directory containing PDF files (merged alphabetically).'
  end

  def script_arguments
    '<output_file> <input_files_or_directory>'
  end

  def add_custom_options(opts)
    opts.on('-r', '--recursive', 'Search subdirectories recursively') do
      @options[:recursive] = true
    end

    opts.on('-o', '--overwrite', 'Overwrite output file if it exists') do
      @options[:overwrite] = true
    end
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name} output.pdf file1.pdf file2.pdf    # Merge specific files"
    puts "  #{script_name} merged.pdf ~/Documents/pdfs/      # Merge all PDFs in directory"
    puts "  #{script_name} --recursive output.pdf ~/docs/   # Recursive directory merge"
    puts "  #{script_name} --overwrite result.pdf input/    # Overwrite existing output"
  end

  def validate!
    if @args.length < 2
      log_error('Insufficient arguments. Need output file and at least one input.')
      show_help
      exit(1)
    end

    @output_file = @args[0]
    @inputs = @args[1..] || []

    # Ensure output has .pdf extension
    @output_file += '.pdf' unless @output_file.end_with?('.pdf')

    # Check if output file exists
    if File.exist?(@output_file) && !@options[:overwrite]
      log_error("Output file '#{@output_file}' already exists. Use --overwrite to replace.")
      exit(1)
    end

    super
  end

  def run
    log_banner(script_title)

    pdf_files = collect_pdf_files

    if pdf_files.empty?
      log_error('No PDF files found to merge')
      exit(1)
    end

    log_info("Found #{pdf_files.length} PDF files:")
    pdf_files.each { |file| puts "  📄 #{file}" }

    return if @options[:dry_run]

    unless confirm_action("Merge #{pdf_files.length} PDF files into '#{@output_file}'?")
      log_info('Operation cancelled')
      exit(0)
    end

    merge_pdfs(pdf_files)
    show_completion(script_title)
  end

  private

  def collect_pdf_files
    pdf_files = []

    @inputs.each do |input|
      if File.directory?(input)
        pdf_files.concat(find_pdfs_in_directory(input))
      elsif File.file?(input) && input.end_with?('.pdf')
        pdf_files << input
      else
        log_warning("Skipping '#{input}' - not a PDF file or directory")
      end
    end

    pdf_files.sort.uniq
  end

  def find_pdfs_in_directory(directory)
    log_info("🔍 Scanning directory: #{directory}")

    pattern = @options[:recursive] ? "#{directory}/**/*.pdf" : "#{directory}/*.pdf"
    pdf_files = Dir.glob(pattern)

    log_info("Found #{pdf_files.length} PDF files in #{directory}")
    pdf_files
  end

  def merge_pdfs(pdf_files)
    log_progress('📄 Merging PDF files...')

    combined_pdf = CombinePDF.new

    pdf_files.each_with_index do |file, index|
      log_info("Processing #{index + 1}/#{pdf_files.length}: #{File.basename(file)}")

      begin
        pdf = CombinePDF.load(file)
        combined_pdf << pdf
      rescue StandardError => e
        log_error("Failed to process '#{file}': #{e.message}")
        exit(1)
      end
    end

    log_progress("💾 Writing merged PDF to '#{@output_file}'...")
    combined_pdf.save(@output_file)

    file_size = File.size(@output_file)
    log_success("Successfully created '#{@output_file}' (#{format_file_size(file_size)})")
  end

  def format_file_size(bytes)
    if bytes < 1024
      "#{bytes} bytes"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)} KB"
    else
      "#{(bytes / (1024.0 * 1024.0)).round(1)} MB"
    end
  end

  def show_examples
    puts <<~EXAMPLES
      Examples:
        #{script_name} output.pdf file1.pdf file2.pdf file3.pdf
        #{script_name} merged.pdf ~/Documents/
        #{script_name} -r combined.pdf ~/Documents/PDFs/
        #{script_name} --overwrite result.pdf *.pdf
    EXAMPLES
  end
end

# Execute the script
MergePdf.execute if __FILE__ == $0
