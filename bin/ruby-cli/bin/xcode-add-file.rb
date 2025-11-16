#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: Add files to Xcode project with automatic category detection
# @tags: xcode, project-management

require_relative '../../.common/script_base'
require_relative '../lib/archive/xcode_project'

class XcodeAddFileScript < ScriptBase
  def script_emoji
    '📁'
  end

  def script_title
    'Xcode Add File'
  end

  def script_description
    'Add a file to the Xcode project with automatic category detection'
  end

  def script_arguments
    '<file_path> [category]'
  end

  def add_custom_options(opts)
    opts.on('-c', '--category CATEGORY', 'Specify file category') do |category|
      @options[:category] = category
    end

    opts.on('-l', '--list-categories', 'List available categories') do
      @options[:list_categories] = true
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} MyViewController.swift ui"
    puts "  #{script_name} Helper.swift --category utils"
    puts "  #{script_name} ContentView.swift          # Auto-detect category"
    puts "  #{script_name} --list-categories          # Show available categories"
  end

  def validate!
    return if @options[:list_categories]

    if @args.empty?
      log_error("File path is required")
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

    if @options[:list_categories]
      list_categories
      return
    end

    file_path = @args[0]
    category = @args[1] || @options[:category]

    add_file_to_project(file_path, category)
    show_completion(script_title)
  end

  private

  def list_categories
    log_section("Available Categories")
    XcodeProject.list_categories.each do |cat|
      puts "  #{cat[:name].ljust(15)} - #{cat[:description]}"
      log_debug("  Group: #{cat[:group_name]}, Build Phase: #{cat[:build_phase]}")
    end
  end

  def add_file_to_project(file_path, category)
    unless File.exist?(file_path)
      log_error("File '#{file_path}' does not exist")
      return false
    end

    file_name = File.basename(file_path)
    file_type = XcodeProject.get_file_type(file_path)

    # Check if file already exists in project
    if XcodeProject.file_exists_in_project?(file_name)
      log_warning("File '#{file_name}' may already exist in project")
      return true unless confirm_action('Continue anyway?')
    end

    # Determine category
    if category.nil?
      category = XcodeProject.infer_category_from_path(file_path)
      log_info("Auto-detected category: #{category}")
    end

    unless XcodeProject.valid_category?(category)
      log_error("Unknown category '#{category}'")
      list_categories
      return false
    end

    category_info = XcodeProject.get_category_info(category)
    build_phase = XcodeProject.get_build_phase(file_path, category)
    target_dir = XcodeProject.get_target_directory(category)

    log_info("Adding #{file_name} to #{category_info['group_name']} group")
    log_info("Build Phase: #{build_phase}")
    log_info("File Type: #{file_type}")

    # Handle resource files specially
    if XcodeProject.is_resource_file?(file_path)
      handle_resource_file(file_path, category, target_dir)
    else
      handle_source_file(file_path, target_dir)
    end

    true
  end

  def handle_resource_file(file_path, category, target_dir)
    resource_info = XcodeProject.get_resource_handling_info(file_path, category)

    log_section("Resource File Handling")
    log_info("Resource Type: #{resource_info[:type].to_s.tr('_', ' ').capitalize}")
    log_info("Recommended Location: #{resource_info[:target_location]}")

    puts "\n📋 Special Instructions:"
    resource_info[:instructions].each_with_index do |instruction, index|
      puts "  #{index + 1}. #{instruction}"
    end

    # Handle asset catalogs specially
    if XcodeProject.is_asset_catalog?(file_path)
      log_warning("Asset catalogs need to be copied as entire directories!")
      if confirm_action("Copy #{file_path} to #{resource_info[:target_location]}?")
        copy_asset_catalog(file_path, resource_info[:target_location])
      end
    else
      # Create target directory if needed
      target_location = resource_info[:target_location]
      if target_location && !File.exist?(target_location)
        if confirm_action("Create directory '#{target_location}'?")
          XcodeProject.ensure_directory_exists(target_location)
          log_success("Created directory: #{target_location}")
        else
          return false
        end
      end

      log_success("Xcode will automatically manage this resource file")
      log_info("💡 Move the file to: #{target_location}")
    end
  end

  def handle_source_file(file_path, target_dir)
    # Ensure target directory exists
    if target_dir && !File.exist?(target_dir)
      if confirm_action("Create directory '#{target_dir}'?")
        XcodeProject.ensure_directory_exists(target_dir)
        log_success("Created directory: #{target_dir}")
      else
        return false
      end
    end

    log_success("File will be managed automatically by Xcode's file system synchronization")
    log_info("Recommended location: #{target_dir}/")
    log_info("💡 Move the file to this location and Xcode will detect it automatically")
  end

  def copy_asset_catalog(source_path, target_location)
    return unless File.directory?(source_path)

    target_path = File.join(target_location, File.basename(source_path))

    if dry_run?
      log_info("[DRY-RUN] Would copy: #{source_path} → #{target_path}")
      return
    end

    begin
      FileUtils.cp_r(source_path, target_location)
      log_success("Copied asset catalog: #{File.basename(source_path)}")
      log_info("Location: #{target_path}")
    rescue => e
      log_error("Failed to copy asset catalog: #{e.message}")
    end
  end
end

XcodeAddFileScript.execute if __FILE__ == $0
