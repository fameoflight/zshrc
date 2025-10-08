#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/file_merger_base'
require_relative '.common/format'
require 'combine_pdf'

# Merge multiple PDF files into a single PDF document
class MergePdf < FileMergerBase
  include Format

  def script_title
    'PDF Merger'
  end

  def script_description
    'Merges PDF files into a single document.'
  end

  def script_arguments
    '<output_file> <input_files_or_directory>'
  end

  def file_extension
    'pdf'
  end

  def merge_files(pdf_files)
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
