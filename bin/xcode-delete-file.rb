#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/xcode_project'

class XcodeDeleteFileScript < ScriptBase
  def script_emoji
    '🗑️'
  end

  def script_title
    'Xcode Delete File'
  end

  def script_description
    'Remove a file from the Xcode project and filesystem'
  end

  def script_arguments
    '<file_name>'
  end

  def add_custom_options(opts)
    opts.on('-f', '--find-only', 'Only find files, do not delete') do
      @options[:find_only] = true
    end

    opts.on('--file-system-only', 'Only delete from filesystem (Xcode will auto-remove)') do
      @options[:file_system_only] = true
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} OldFile.swift           # Find and delete file"
    puts "  #{script_name} Helper.swift --find-only # Just locate file"
    puts "  #{script_name} Test.swift --force      # Skip confirmation"
  end

  def validate!
    if @args.empty?
      log_error("File name is required")
      puts banner_text
      show_examples
      exit 1
    end

    unless XcodeProject.project_exists?
      log_error("No Xcode project found in current directory")
      exit 1
    end

    super
  end

  def run
    log_banner(script_title)

    file_name = @args[0]

    if @options[:find_only]
      find_and_display_files(file_name)
    else
      delete_file_from_project(file_name)
    end

    show_completion(script_title)
  end

  private

  def find_and_display_files(file_name)
    log_section("Searching for '#{file_name}'")

    found_files = XcodeProject.find_files_in_project(file_name)

    if found_files.empty?
      log_warning("File '#{file_name}' not found in project directories")
      return
    end

    log_success("Found #{found_files.size} matching file(s):")
    found_files.each_with_index do |file, index|
      status = file[:exists] ? "✅" : "❌ (missing)"
      size_info = file[:size] ? " (#{format_file_size(file[:size])})" : ""
      puts "  #{index + 1}. #{file[:path]} #{status}#{size_info}"
    end
  end

  def delete_file_from_project(file_name)
    log_section("Removing '#{file_name}' from project")

    found_files = XcodeProject.find_files_in_project(file_name)

    if found_files.empty?
      log_warning("File '#{file_name}' not found in project directories")
      log_info("💡 Xcode will automatically remove missing file references")
      return
    end

    log_info("Found #{found_files.size} matching file(s):")
    existing_files = []

    found_files.each_with_index do |file, index|
      if file[:exists]
        size_info = file[:size] ? " (#{format_file_size(file[:size])})" : ""
        puts "  #{index + 1}. #{file[:path]}#{size_info}"
        existing_files << file
      else
        puts "  #{index + 1}. #{file[:path]} (already missing)"
      end
    end

    if existing_files.empty?
      log_info("All matching files are already missing from filesystem")
      log_info("💡 Xcode will automatically clean up the project references")
      return
    end

    return unless confirm_deletion(existing_files)

    delete_files(existing_files)
  end

  def confirm_deletion(files)
    if force?
      log_info("Force mode enabled - skipping confirmation")
      return true
    end

    log_warning("This will permanently delete #{files.size} file(s) from the filesystem")
    log_info("Xcode will automatically remove them from the project")

    confirm_action("Delete these files?")
  end

  def delete_files(files)
    success_count = 0
    error_count = 0

    files.each do |file|
      begin
        if dry_run?
          log_info("[DRY-RUN] Would delete: #{file[:path]}")
        else
          # Handle different types of files appropriately
          if handle_file_deletion(file[:path])
            log_success("Deleted: #{File.basename(file[:path])}")
            log_debug("Path: #{file[:path]}") if verbose?
          else
            log_warning("Skipped: #{File.basename(file[:path])}")
          end
        end
        success_count += 1
      rescue => e
        log_error("Failed to delete #{file[:path]}: #{e.message}")
        error_count += 1
      end
    end

    if dry_run?
      log_info("Dry-run completed - no files were actually deleted")
    else
      log_success("Processed #{success_count} file(s)")
      log_error("Failed to delete #{error_count} file(s)") if error_count > 0
      log_info("💡 Xcode will automatically update the project on next build/refresh")
    end
  end

  def handle_file_deletion(file_path)
    if XcodeProject.is_resource_file?(file_path)
      return handle_resource_deletion(file_path)
    else
      return handle_source_deletion(file_path)
    end
  end

  def handle_resource_deletion(file_path)
    resource_info = XcodeProject.get_resource_handling_info(file_path, nil)

    case resource_info[:type]
    when :info_plist
      log_warning("Info.plist is critical - consider editing instead of deleting")
      return false unless confirm_action("Really delete Info.plist? This may break your app!")
    when :asset_catalog
      log_info("Deleting asset catalog directory: #{file_path}")
      if File.directory?(file_path)
        FileUtils.rm_rf(file_path)
        return true
      else
        log_warning("Asset catalog path is not a directory")
        return false
      end
    when :interface_builder
      log_info("Deleting Interface Builder file (may affect UI)")
    when :core_ml_model
      log_info("Deleting Core ML model (may affect app functionality)")
    end

    # Standard file deletion for resources
    File.delete(file_path)
    true
  end

  def handle_source_deletion(file_path)
    # Standard file deletion for source files
    if File.directory?(file_path)
      FileUtils.rm_rf(file_path)
    else
      File.delete(file_path)
    end
    true
  end

  def format_file_size(bytes)
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)} KB"
    else
      "#{(bytes / (1024.0 * 1024)).round(1)} MB"
    end
  end
end

XcodeDeleteFileScript.execute if __FILE__ == $0
