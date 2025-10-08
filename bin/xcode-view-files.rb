#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/xcode_project'

class XcodeViewFilesScript < ScriptBase
  def script_emoji
    '👀'
  end

  def script_title
    'Xcode View Files'
  end

  def script_description
    'View files in the Xcode project, optionally filtered by category'
  end

  def script_arguments
    '[category]'
  end

  def add_custom_options(opts)
    opts.on('-c', '--category CATEGORY', 'Filter by specific category') do |category|
      @options[:category] = category
    end

    opts.on('-s', '--summary', 'Show project summary only') do
      @options[:summary] = true
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # View all files"
    puts "  #{script_name} ui                # View UI files only"
    puts "  #{script_name} --category models # View model files"
    puts "  #{script_name} --summary         # Show project summary"
  end

  def validate!
    unless XcodeProject.project_exists?
      log_error("No Xcode project found in current directory")
      exit 1
    end

    super
  end

  def run
    log_banner(script_title)

    if @options[:summary]
      show_project_summary
      return
    end

    category = @args[0] || @options[:category]

    if category && !XcodeProject.valid_category?(category)
      log_error("Unknown category '#{category}'")
      list_available_categories
      return
    end

    view_project_files(category)
    show_completion(script_title)
  end

  private

  def show_project_summary
    summary = XcodeProject.project_summary
    return unless summary

    log_section("Project Summary")
    puts "  📱 Project: #{summary[:project_name]}"
    puts "  📄 Project File: #{summary[:project_file]}"
    puts "  📁 Project Path: #{summary[:project_path]}"
    puts "  🗂️  Root Groups: #{summary[:root_groups_count]}"
    puts "  🏷️  Categories Available: #{summary[:categories_available]}"
  end

  def list_available_categories
    log_section("Available Categories")
    XcodeProject.list_categories.each do |cat|
      puts "  #{cat[:name]}"
    end
  end

  def view_project_files(category = nil)
    project_info = XcodeProject.current_project

    log_section("Project Files - #{project_info[:name]}")
    puts "=" * 60

    root_groups = XcodeProject.get_root_groups

    if root_groups.empty?
      log_warning("No root groups found in project file")
      return
    end

    root_groups.each do |group|
      next if category && !group_matches_category?(group, category)

      puts "\n📁 #{group[:name]} -> #{group[:path]}"

      full_path = File.join(".", group[:path])
      if File.exist?(full_path)
        files = XcodeProject.list_directory_files(full_path)

        if files.empty?
          puts "    (empty directory)"
        else
          files.each do |file|
            if file[:type] == :directory
              puts "    📁 #{file[:name]}/"
            else
              size_info = file[:size] ? " (#{format_file_size(file[:size])})" : ""
              puts "    📄 #{file[:name]}#{size_info}"
            end
          end
        end
      else
        log_warning("    Directory not found: #{full_path}")
      end
    end

    if category
      log_info("\nFiltered by category: #{category}")
    else
      log_info("\nShowing all files. Use --category to filter.")
    end
  end

  def group_matches_category?(group, category)
    return true unless category

    category_info = XcodeProject.get_category_info(category)
    return false unless category_info

    group_name_lower = group[:name].downcase
    path_lower = group[:path].downcase

    category_info['path_match'].any? do |pattern|
      pattern_lower = pattern.downcase
      group_name_lower.include?(pattern_lower) || path_lower.include?(pattern_lower)
    end
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

XcodeViewFilesScript.execute if __FILE__ == $0
