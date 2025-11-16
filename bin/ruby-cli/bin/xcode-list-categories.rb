#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: List all available file categories for Xcode project organization
# @tags: xcode, project-management

require_relative '../../.common/script_base'
require_relative '../lib/archive/xcode_project'

class XcodeListCategoriesScript < ScriptBase
  def script_emoji
    '📋'
  end

  def script_title
    'Xcode List Categories'
  end

  def script_description
    'List all available file categories for Xcode project organization'
  end

  def script_arguments
    '[category_name]'
  end

  def add_custom_options(opts)
    opts.on('-d', '--detailed', 'Show detailed information for each category') do
      @options[:detailed] = true
    end

    opts.on('-j', '--json', 'Output in JSON format') do
      @options[:json] = true
    end

    opts.on('-p', '--patterns', 'Show path matching patterns') do
      @options[:patterns] = true
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # List all categories"
    puts "  #{script_name} ui                # Show details for 'ui' category"
    puts "  #{script_name} --detailed        # Show full details for all"
    puts "  #{script_name} --json            # JSON output"
    puts "  #{script_name} --patterns        # Show path patterns"
  end

  def validate!
    unless XcodeProject.project_exists?
      log_warning("No Xcode project found in current directory")
      log_info("Categories will be shown for reference")
    end

    super
  end

  def run
    log_banner(script_title)

    specific_category = @args[0]

    if @options[:json]
      output_json(specific_category)
    elsif specific_category
      show_category_details(specific_category)
    else
      list_all_categories
    end

    show_completion(script_title)
  end

  private

  def output_json(specific_category = nil)
    categories = XcodeProject.list_categories

    if specific_category
      category = categories.find { |cat| cat[:name] == specific_category }
      if category
        puts JSON.pretty_generate(category)
      else
        log_error("Category '#{specific_category}' not found")
        exit 1
      end
    else
      puts JSON.pretty_generate(categories)
    end
  end

  def show_category_details(category_name)
    category_info = XcodeProject.get_category_info(category_name)

    unless category_info
      log_error("Category '#{category_name}' not found")
      list_available_category_names
      return
    end

    log_section("Category: #{category_name}")
    puts "  📛 Name: #{category_info['group_name']}"
    puts "  📝 Description: #{category_info['description']}"
    puts "  🔨 Build Phase: #{category_info['build_phase']}"

    if @options[:patterns] || @options[:detailed]
      puts "  🎯 Path Patterns:"
      category_info['path_match'].each do |pattern|
        puts "    • #{pattern}"
      end
    end

    if @options[:detailed] && XcodeProject.project_exists?
      target_dir = XcodeProject.get_target_directory(category_name)
      puts "  📂 Target Directory: #{target_dir}"

      if File.exist?(target_dir)
        file_count = Dir.glob("#{target_dir}/**/*").select { |f| File.file?(f) }.size
        puts "  📄 Current Files: #{file_count}"
      else
        puts "  📄 Current Files: 0 (directory doesn't exist)"
      end
    end
  end

  def list_all_categories
    log_section("Available File Categories")
    puts "=" * 60

    categories = XcodeProject.list_categories

    if @options[:detailed]
      categories.each_with_index do |cat, index|
        puts "\n#{index + 1}. #{cat[:name].upcase}"
        puts "   Group: #{cat[:group_name]}"
        puts "   Phase: #{cat[:build_phase]}"
        puts "   Desc:  #{cat[:description]}"

        if @options[:patterns]
          category_info = XcodeProject.get_category_info(cat[:name])
          puts "   Match: #{category_info['path_match'].join(', ')}"
        end
      end
    else
      categories.each do |cat|
        name_padded = cat[:name].ljust(15)
        puts "  #{name_padded} - #{cat[:description]}"
      end
    end

    puts "\nTotal categories: #{categories.size}"

    if XcodeProject.project_exists?
      project_info = XcodeProject.current_project
      puts "Current project: #{project_info[:name]}"
    else
      log_info("\n💡 Run this command in an Xcode project directory for project-specific details")
    end
  end

  def list_available_category_names
    log_section("Available Categories")
    XcodeProject.list_categories.each do |cat|
      puts "  • #{cat[:name]}"
    end
  end
end

XcodeListCategoriesScript.execute if __FILE__ == $0
