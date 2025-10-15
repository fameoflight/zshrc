#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require 'json'

# Easy-to-use wrapper for duti with fuzzy application matching
#
# Examples:
#   change-extension .log vscode        # Set .log files to open with VSCode
#   change-extension .md text           # Set .md files to open with default text editor
#   change-extension .pdf preview       # Set .pdf files to open with Preview
#   change-extension .jpg "photo"       # Fuzzy match for Photo editor
class ChangeExtension < ScriptBase
  def script_emoji; '📄'; end
  def script_title; 'Change Extension'; end
  def script_description; 'Easy-to-use wrapper for duti with fuzzy application matching'; end
  def script_arguments; '<extension> <app_name>'; end

  def add_custom_options(opts)
    opts.on('-l', '--list', 'List current file extension associations') do
      @options[:list] = true
    end

    opts.on('-s', '--show', 'Show current association for extension') do
      @options[:show] = true
    end
  end

  def run
    log_banner(script_title)

    if @options[:list]
      list_associations
      show_completion(script_title)
      return
    end

    if @options[:show]
      show_association
      show_completion(script_title)
      return
    end

    if args.length < 2
      log_error 'Extension and app name are required'
      puts
      show_examples
      exit 1
    end

    extension = args[0]
    app_pattern = args[1]

    # Normalize extension (ensure it starts with dot)
    extension = ".#{extension}" unless extension.start_with?('.')

    log_info "Setting #{extension} files to open with: #{app_pattern}"

    # Find best matching application
    app_bundle_id = find_application(app_pattern)

    if app_bundle_id.nil?
      log_error "No application found matching: #{app_pattern}"
      log_info "Try a more specific name or check installed applications"
      exit 1
    end

    # Apply the change using duti
    apply_association(extension, app_bundle_id)

    show_completion(script_title)
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} .log vscode          # Set .log files to open with VSCode"
    puts "  #{script_name} .md text            # Set .md files to open with TextEdit"
    puts "  #{script_name} .pdf preview        # Set .pdf files to open with Preview"
    puts "  #{script_name} .jpg \"photo\"        # Fuzzy match for Photo editor"
    puts "  #{script_name} .rb code             # Set .rb files to open with code editor"
    puts "  #{script_name} --list              # List current associations"
    puts "  #{script_name} --show .pdf         # Show current association for .pdf"
  end

  private

  def list_associations
    log_info "Current file extension associations:"
    puts

    # Get all UTIs and their handlers
    result = `duti -x 2>&1`
    if $?.success?
      puts result
    else
      log_warning "Could not retrieve associations"
      puts "This requires duti to be installed: brew install duti"
    end
  end

  def show_association
    if args.empty?
      log_error "Extension is required for --show option"
      exit 1
    end

    extension = args[0]
    extension = ".#{extension}" unless extension.start_with?('.')

    log_info "Current association for #{extension}:"

    # Use duti to look up the extension
    result = `duti -x #{extension} 2>&1`
    if $?.success?
      puts result
    else
      log_warning "No association found for #{extension}"
    end
  end

  def find_application(pattern)
    log_info "Searching for applications matching: #{pattern}"

    # Get list of installed applications
    apps = get_installed_applications

    # Fuzzy match against the pattern
    matches = fuzzy_match_applications(apps, pattern)

    if matches.empty?
      log_warning "No applications found matching: #{pattern}"
      return nil
    end

    if matches.length == 1
      app = matches.first
      log_success "Found application: #{app[:name]} (#{app[:bundle_id]})"
      return app[:bundle_id]
    end

    # Multiple matches - let user choose
    log_info "Multiple applications found. Please choose:"

    choices = matches.map { |app|
      {
        name: "#{app[:name]} (#{app[:bundle_id]})",
        value: app[:bundle_id]
      }
    }

    selected = interactive_select(
      "Choose application for '#{pattern}':",
      choices
    )

    selected
  end

  def get_installed_applications
    apps = []

    # Common application directories
    app_dirs = [
      '/Applications',
      '/System/Applications',
      "#{ENV['HOME']}/Applications"
    ]

    app_dirs.each do |dir|
      next unless Dir.exist?(dir)

      Dir.glob("#{dir}/*.app").each do |app_path|
        app_info = get_app_info(app_path)
        apps << app_info if app_info
      end
    end

    apps.sort_by { |app| app[:name].downcase }
  end

  def get_app_info(app_path)
    app_name = File.basename(app_path, '.app')
    info_plist = File.join(app_path, 'Contents', 'Info.plist')

    unless File.exist?(info_plist)
      return { name: app_name, bundle_id: nil, path: app_path }
    end

    # Try to get bundle ID from Info.plist
    bundle_id = nil
    begin
      # Use defaults command to read plist
      result = `defaults read "#{info_plist}" CFBundleIdentifier 2>/dev/null`.strip
      bundle_id = result unless result.empty?
    rescue StandardError
      # Fallback to nil if reading fails
    end

    {
      name: app_name,
      bundle_id: bundle_id,
      path: app_path
    }
  end

  def fuzzy_match_applications(apps, pattern)
    pattern_lower = pattern.downcase

    # Calculate similarity scores for each app
    scored_apps = apps.map do |app|
      score = calculate_similarity(app[:name], pattern_lower)
      [score, app]
    end.select { |score, _| score > 0 } # Only keep matches with some similarity

    # Sort by score (descending) and return just the apps
    scored_apps.sort_by { |score, _| -score }.map { |_, app| app }
  end

  def calculate_similarity(text, pattern)
    text_lower = text.downcase

    # Exact match gets highest score
    return 100 if text_lower == pattern

    # Starts with pattern gets high score
    return 80 if text_lower.start_with?(pattern)

    # Contains pattern gets medium score
    return 60 if text_lower.include?(pattern)

    # Contains any word from pattern gets lower score
    pattern_words = pattern.split(/\s+/)
    text_words = text_lower.split(/\s+/)

    matches = pattern_words.sum do |p_word|
      text_words.count { |t_word| t_word.include?(p_word) || p_word.include?(t_word) }
    end

    return 40 if matches > 0

    # Partial character matching
    shared_chars = (text_lower.chars & pattern.chars).length
    return 20 if shared_chars >= pattern.length / 2

    0
  end

  def apply_association(extension, bundle_id)
    log_info "Setting #{extension} → #{bundle_id}"

    # Build duti command
    cmd = "duti -s #{bundle_id} #{extension} all"

    if dry_run?
      log_info "[DRY-RUN] Would execute: #{cmd}"
    else
      success = execute_cmd?(cmd, description: "Setting file association")

      if success
        log_success "File association updated successfully!"
        log_info "You may need to restart affected applications for changes to take effect."
      else
        log_error "Failed to set file association"
        log_info "Make sure duti is installed: brew install duti"
        exit 1
      end
    end
  end
end

ChangeExtension.execute if __FILE__ == $0