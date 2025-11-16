#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Find files by extension in git history with interactive viewing
# @tags: search, interactive, history

require_relative '../lib/script_helpers'
require 'tempfile'

# Git History - Find files by extension in git history with view commands
#
# Examples:
#   git-history txt         # Find .txt files in git history
#   git-history .rb        # Find .rb files in git history
#   git-history '*.md'     # Find .md files in git history
#   git-history --interactive rb  # Interactive mode to open files
#   git-history --open md         # Open all markdown files in EDITOR
class GitHistory
  include ScriptHelpers

  def script_emoji = '🐙'
  def script_title = 'Git History'
  def script_description = 'Find files by extension in git history with view commands'
  def script_arguments = '<extension>'

  def add_custom_options(opts)
    opts.on('-i', '--interactive', 'Interactive mode - select files to open in EDITOR') do
      @options[:interactive] = true
    end

    opts.on('-n', '--limit COUNT', Integer, 'Limit number of commits per file') do |count|
      @options[:limit] = count
    end

    opts.on('-d', '--debug', 'Enable debug output') do
      @options[:debug] = true
    end

    opts.on('-o', '--open', 'Open all files in temporary directory with EDITOR') do
      @options[:open_all] = true
    end

    opts.on('--since DATE', 'Show commits since DATE (YYYY-MM-DD)') do |date|
      @options[:since] = date
    end

    opts.on('--until DATE', 'Show commits until DATE (YYYY-MM-DD)') do |date|
      @options[:until] = date
    end
  end

  def run
    log_banner(script_title)

    if args.empty?
      log_error 'Extension is required'
      puts
      show_examples
      exit 1
    end

    # Check if interactive mode is available
    if @options[:interactive] && !interactive_available?
      log_warning 'Interactive mode requires a terminal. Disabling interactive mode.'
      @options[:interactive] = false
    end

    extension = normalize_extension(args[0])
    repo_path = ENV['ORIGINAL_WORKING_DIR'] || '.'

    unless git_repository?(repo_path)
      log_error "Not a git repository: #{repo_path}"
      exit 1
    end

    log_info "Searching for #{extension} files in git history..."
    files_history = get_files_history(extension, repo_path)

    if files_history.empty?
      log_warning "No files with extension '#{extension}' found in git history"
      exit 0
    end

    if @options[:open_all]
      open_all_files(files_history)
    elsif @options[:interactive]
      interactive_mode(files_history)
    else
      display_files_history(files_history)
    end

    show_completion(script_title)
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name} txt                    # Find .txt files in git history"
    puts "  #{script_name} .rb                   # Find .rb files in git history"
    puts "  #{script_name} '*.md'                # Find .md files in git history"
    puts "  #{script_name} --limit 5 js          # Show only 5 most recent commits per file"
    puts "  #{script_name} --since 2024-01-01 py # Show Python files changed since 2024-01-01"
    puts "  #{script_name} --interactive rb      # Interactive mode to select Ruby files to open"
    puts "  #{script_name} --open md             # Create temp files for all markdown versions and open directory"
  end

  private

  def normalize_extension(ext)
    clean_ext = ext.gsub(/[*"']/, '')
    clean_ext = ".#{clean_ext}" unless clean_ext.start_with?('.')
    clean_ext
  end

  def git_repository?(path)
    Dir.chdir(path) do
      system('git rev-parse --git-dir > /dev/null 2>&1')
    end
  rescue StandardError
    false
  end

  def get_files_history(extension, repo_path)
    files_history = {}

    Dir.chdir(repo_path) do
      cmd = build_git_log_command
      output = `#{cmd} 2>/dev/null`

      unless $?.success?
        log_error 'Failed to execute git command'
        exit 1
      end

      current_commit = nil
      current_files = []

      output.each_line do |line|
        line.chomp!

        if line.match(/^([a-f0-9]{7,})\|(.+)\|(\d{4}-\d{2}-\d{2})$/)
          process_commit_files(current_files, current_commit, extension, files_history) if current_commit

          current_commit = {
            hash: ::Regexp.last_match(1),
            message: ::Regexp.last_match(2),
            date: ::Regexp.last_match(3)
          }
          current_files = []
        elsif !line.empty? && current_commit
          current_files << line
        end
      end

      process_commit_files(current_files, current_commit, extension, files_history) if current_commit
    end

    apply_limit(files_history) if @options[:limit]
    files_history
  end

  def build_git_log_command
    cmd = 'git log --all --pretty=format:"%H|%s|%ad" --date=short --name-only'
    cmd += " --since=#{@options[:since]}" if @options[:since]
    cmd += " --until=#{@options[:until]}" if @options[:until]
    cmd
  end

  def process_commit_files(files, commit, extension, files_history)
    files.each do |file|
      next unless file.end_with?(extension)

      files_history[file] ||= []
      files_history[file] << commit
    end
  end

  def file_exists_in_commit?(file, commit_hash)
    # Try git cat-file first, but also try git show as backup
    system("git cat-file -e #{commit_hash}:#{file} 2>/dev/null") ||
      system("git show #{commit_hash}:#{file} > /dev/null 2>&1")
  end

  def apply_limit(files_history)
    files_history.each do |file, commits|
      files_history[file] = commits.first(@options[:limit])
    end
  end

  def display_files_history(files_history)
    total_files = files_history.length
    total_commits = files_history.values.map(&:length).sum

    log_info "Found #{total_files} files with #{total_commits} total commits:"
    puts

    files_history.sort.each do |file, commits|
      display_file_history(file, commits)
      puts
    end
  end

  def display_file_history(file, commits)
    repo_path = ENV['ORIGINAL_WORKING_DIR'] || '.'
    full_path = File.join(repo_path, file)
    file_exists = File.exist?(full_path)
    status_indicator = file_exists ? '✓' : '✗'
    status_text = file_exists ? '' : ' (deleted)'

    puts "#{status_indicator} #{file}#{status_text}"

    commits.each do |commit|
      puts "  ↳ #{commit[:hash]} (#{commit[:date]}) #{commit[:message]}"
      puts "     → git show #{commit[:hash]}:#{file}"
    end
  end

  def interactive_mode(files_history)
    log_info 'Interactive mode - select files to open in EDITOR'
    puts

    file_options = files_history.sort.map do |file, commits|
      status = File.exist?(File.join(ENV['ORIGINAL_WORKING_DIR'] || '.', file)) ? '✓' : '✗'
      {
        name: "#{status} #{file} (#{commits.length} commits)",
        value: file
      }
    end

    file_options << { name: 'Exit', value: :exit }

    loop do
      puts 'Select a file to open:'
      choice = interactive_select('Choose file:', file_options)

      case choice
      when :exit
        log_info 'Exiting interactive mode'
        break
      else
        open_file_interactive(choice, files_history[choice])
      end
    end
  end

  def interactive_available?
    # Check if we have a proper terminal for input
    return false unless $stdin.tty?

    # Try to test if we can read from stdin
    begin
      # This is a simple test - try to check if stdin is readable
      $stdin.stat
      true
    rescue Errno::ENOENT, IOError
      false
    end
  end

  def interactive_select(prompt, choices)
    # Try to use a better TTY prompt if available
    if tty_prompt_available?
      use_tty_prompt(prompt, choices)
    else
      use_simple_prompt(prompt, choices)
    end
  rescue Errno::ENOENT
    log_warning 'Interactive mode requires a terminal. Please run without --interactive.'
    :exit
  rescue IOError
    log_warning 'Cannot read input in current context. Please run without --interactive.'
    :exit
  rescue StandardError => e
    log_error "Input error: #{e.message}"
    :exit
  end

  def tty_prompt_available?
    # Check if we have access to common terminal UI tools
    return true if system('which fzf > /dev/null 2>&1')
    return true if system('which selecta > /dev/null 2>&1')
    return true if system('which peco > /dev/null 2>&1')

    false
  end

  def use_tty_prompt(prompt, choices)
    # Try fzf first (most common and feature-rich)
    return use_fzf_prompt(choices) if system('which fzf > /dev/null 2>&1')

    # Try peco
    return use_peco_prompt(choices) if system('which peco > /dev/null 2>&1')

    # Try selecta
    return use_selecta_prompt(choices) if system('which selecta > /dev/null 2>&1')

    # Fallback to simple prompt
    use_simple_prompt(prompt, choices)
  end

  def use_fzf_prompt(choices)
    # Create fzf input
    input = choices.map.with_index do |choice, index|
      "#{index + 1}. #{choice[:name]}"
    end.join("\n")

    # Run fzf and get selection
    selected = `echo "#{input}" | fzf --prompt="Select file: " --height=10 --border`.strip

    return :exit if selected.empty?

    # Parse the selection to get the index
    match = selected.match(/^(\d+)\./)
    if match
      index = match[1].to_i - 1
      return choices[index][:value] if index.between?(0, choices.length - 1)
    end

    :exit
  end

  def use_peco_prompt(choices)
    input = choices.map.with_index do |choice, index|
      "#{index + 1}. #{choice[:name]}"
    end.join("\n")

    selected = `echo "#{input}" | peco`.strip
    return :exit if selected.empty?

    match = selected.match(/^(\d+)\./)
    if match
      index = match[1].to_i - 1
      return choices[index][:value] if index.between?(0, choices.length - 1)
    end

    :exit
  end

  def use_selecta_prompt(choices)
    input = choices.map.with_index do |choice, index|
      "#{index + 1}. #{choice[:name]}"
    end.join("\n")

    selected = `echo "#{input}" | selecta`.strip
    return :exit if selected.empty?

    match = selected.match(/^(\d+)\./)
    if match
      index = match[1].to_i - 1
      return choices[index][:value] if index.between?(0, choices.length - 1)
    end

    :exit
  end

  def use_simple_prompt(prompt, choices)
    puts "\n#{prompt}"
    puts

    choices.each_with_index do |choice, index|
      puts "  #{index + 1}. #{choice[:name]}"
    end

    print "\nEnter choice (1-#{choices.length}): "
    input = $stdin.gets.chomp.to_i

    if input.between?(1, choices.length)
      choices[input - 1][:value]
    else
      log_warning 'Invalid choice'
      :exit
    end
  end

  def open_all_files(files_history)
    log_info "Creating temporary files for all versions..."

    temp_dir = create_temp_directory
    files_created = 0

    files_history.each do |file, commits|
      commits.each do |commit|
        if create_temp_file_for_commit(file, commit, temp_dir)
          files_created += 1
        end
      end
    end

    if files_created > 0
      log_success "Created #{files_created} temporary files in #{temp_dir}"
      open_temp_directory(temp_dir)
    else
      log_warning "No temporary files were created"
    end

    show_completion(script_title)
  end

  def create_temp_directory
    require 'fileutils'
    require 'time'

    timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
    temp_dir = "/tmp/git-history-#{timestamp}"

    FileUtils.mkdir_p(temp_dir)
    log_info "Created temporary directory: #{temp_dir}"

    temp_dir
  end

  def create_temp_file_for_commit(file, commit, temp_dir)
    # First try direct file access
    content = run_git_command("git show #{commit[:hash]}:#{file}")

    # If direct access fails, try searching in commit tree
    unless content
      content = find_file_content_in_commit(file, commit)
    end

    return false unless content

    # Create filename with specified pattern: name-commit-hash.extension
    file_basename = File.basename(file, '.*')
    file_extension = File.extname(file)
    temp_filename = "#{file_basename}-#{commit[:hash]}#{file_extension}"
    temp_filepath = File.join(temp_dir, temp_filename)

    begin
      File.write(temp_filepath, content)
      log_debug "Created: #{temp_filename}"
      true
    rescue StandardError => e
      log_error "Failed to create #{temp_filename}: #{e.message}"
      false
    end
  end

  def find_file_content_in_commit(file, commit)
    tree_output = run_git_command("git ls-tree -r #{commit[:hash]}")
    return nil unless tree_output

    file_basename = File.basename(file)

    # Look for files with similar names
    tree_output.each_line do |line|
      next unless line =~ /^\d+\s+\w+\s+([a-f0-9]+)\s+(.+)$/

      file_path = ::Regexp.last_match(2)
      if file_path.include?(file_basename) || file_path.end_with?(file)
        content = run_git_command("git show #{commit[:hash]}:#{file_path}")
        return content if content
      end
    end

    nil
  end

  def open_temp_directory(temp_dir)
    editor = ENV['EDITOR'] || 'vim'

    if dry_run?
      log_info "[DRY-RUN] Would open directory: #{temp_dir} with #{editor}"
      return
    end

    log_info "Opening directory #{temp_dir} with #{editor}..."

    # Try different ways to open the directory
    success = false

    # Try opening with editor (some editors can open directories)
    success = system("#{editor} #{temp_dir}") if system("which #{editor} > /dev/null 2>&1")

    # If editor fails, try system file manager
    unless success
      if macos?
        success = system("open #{temp_dir}")
      elsif linux?
        success = system("xdg-open #{temp_dir}")
      end
    end

    if success
      log_success "Opened #{temp_dir}"
    else
      log_warning "Could not open #{temp_dir}. Directory created at: #{temp_dir}"
    end
  end

  def open_file_interactive(file, commits)
    log_info "Opening #{file} from git history..."

    # Try each commit until we find one that works
    commits.each do |commit|
      return true if open_file_at_commit_interactive(file, commit)
    end

    # If direct file access failed, try to find the file in the commit tree
    log_info "Attempting to find #{file} in commit history..."
    commits.each do |commit|
      return true if find_and_open_file_in_commit(file, commit)
    end

    log_warning "Could not open #{file} - no working commits found"
    false
  end

  def open_file_at_commit_interactive(file, commit)
    log_debug "Attempting to open #{file} at commit #{commit[:hash]}"
    temp_content = run_git_command("git show #{commit[:hash]}:#{file}")
    return false unless temp_content

    create_and_open_temp_file(file, temp_content, commit)
  end

  def find_and_open_file_in_commit(file, commit)
    log_debug "Searching for #{file} in commit #{commit[:hash]} tree"

    # Get the tree listing for the commit
    tree_output = run_git_command("git ls-tree -r #{commit[:hash]}")
    return false unless tree_output

    # Look for files with similar names
    file_basename = File.basename(file)
    found_files = []

    tree_output.each_line do |line|
      next unless line =~ /^\d+\s+\w+\s+([a-f0-9]+)\s+(.+)$/

      file_path = ::Regexp.last_match(2)
      found_files << file_path if file_path.include?(file_basename) || file_path.end_with?(file)
    end

    # Try exact match first, then similar files
    [file, *found_files].uniq.each do |file_path|
      temp_content = run_git_command("git show #{commit[:hash]}:#{file_path}")
      if temp_content
        log_info "Found file as: #{file_path}"
        return create_and_open_temp_file(file_path, temp_content, commit)
      end
    end

    false
  end

  def create_and_open_temp_file(file_path, content, commit)
    require 'tempfile'

    Tempfile.create(['git-history-', File.extname(file_path)]) do |temp_file|
      temp_file.write(content)
      temp_file.flush

      editor = ENV['EDITOR'] || 'vim'
      log_info "Opening #{file_path} (#{commit[:hash]}) in #{editor}..."

      if dry_run?
        log_info "[DRY-RUN] Would open: #{temp_file.path}"
        return true
      end

      success = system("#{editor} #{temp_file.path}")
      if success
        log_success "Closed #{file_path} (#{commit[:hash]})"
        return true
      else
        log_error "Failed to open editor: #{editor}"
        return false
      end
    end
  rescue StandardError => e
    log_error "Error creating temp file: #{e.message}"
    false
  end

  def log_debug(message)
    return unless @options[:debug]

    puts "🔍 DEBUG: #{message}"
  end

  def run_git_command(command)
    repo_path = ENV['ORIGINAL_WORKING_DIR'] || '.'
    original_dir = Dir.pwd

    begin
      Dir.chdir(repo_path)
      log_debug "Running git command in #{repo_path}: #{command}"
      output = `#{command} 2>&1`

      unless $?.success?
        log_debug "Git command failed: #{command} - Exit code: #{$?.exitstatus}"
        log_debug "Error output: #{output}" unless output.empty?
        return nil
      end

      output
    rescue StandardError => e
      log_error "Failed to run git command: #{e.message}"
      nil
    ensure
      Dir.chdir(original_dir)
    end
  end

  # Platform detection helpers
  def macos?
    RUBY_PLATFORM =~ /darwin/
  end

  def linux?
    RUBY_PLATFORM =~ /linux/
  end

  class << self
    def macos?
      RUBY_PLATFORM =~ /darwin/
    end

    def linux?
      RUBY_PLATFORM =~ /linux/
    end
  end
end

# Simple execution for scripts that don't need the full framework
GitHistory.new.run if __FILE__ == $0
