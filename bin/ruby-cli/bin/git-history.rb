#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/script_helpers'

# Git History - Find files by extension in git history with view commands
#
# Examples:
#   git-history txt         # Find .txt files in git history
#   git-history .rb        # Find .rb files in git history
#   git-history '*.md'     # Find .md files in git history
class GitHistory
  include ScriptHelpers
  def script_emoji; '🐙'; end
  def script_title; 'Git History'; end
  def script_description; 'Find files by extension in git history with view commands'; end
  def script_arguments; '<extension>'; end

  def add_custom_options(opts)
    opts.on('-r', '--repository PATH', 'Path to git repository (default: current directory)') do |path|
      @options[:repo_path] = path
    end

    opts.on('-n', '--limit COUNT', Integer, 'Limit number of commits per file') do |count|
      @options[:limit] = count
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

    extension = normalize_extension(args[0])
    repo_path = @options[:repo_path] || (ENV['ORIGINAL_WORKING_DIR'] || '.')

    # Verify we're in a git repository
    unless git_repository?(repo_path)
      log_error "Not a git repository: #{repo_path}"
      exit 1
    end

    log_info "Searching for #{extension} files in git history..."
    puts

    # Get git history for files with the extension
    files_history = get_files_history(extension, repo_path)

    if files_history.empty?
      log_warning "No files with extension '#{extension}' found in git history"
      exit 0
    end

    # Display results
    display_files_history(files_history)

    show_completion(script_title)
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} txt                    # Find .txt files in git history"
    puts "  #{script_name} .rb                   # Find .rb files in git history"
    puts "  #{script_name} '*.md'                # Find .md files in git history"
    puts "  #{script_name} --limit 5 js          # Show only 5 most recent commits per file"
    puts "  #{script_name} --since 2024-01-01 py # Show Python files changed since 2024-01-01"
    puts "  #{script_name} --repository ~/src txt # Search in specific repository"
  end

  private

  def normalize_extension(ext)
    # Remove any wildcards and quotes
    clean_ext = ext.gsub(/[*"']/, '')

    # Ensure it starts with a dot
    clean_ext = ".#{clean_ext}" unless clean_ext.start_with?('.')

    clean_ext
  end

  def git_repository?(path)
    Dir.chdir(path) do
      system('git rev-parse --git-dir > /dev/null 2>&1')
    end
  rescue SystemCallError
    false
  end

  def get_files_history(extension, repo_path)
    files_history = {}

    # Build git log command
    git_cmd = build_git_log_command(extension)

    log_debug "Running: #{git_cmd}" if verbose?

    Dir.chdir(repo_path) do
      # Get git log output
      output = `#{git_cmd} 2>/dev/null`

      unless $?.success?
        log_error "Failed to execute git command"
        exit 1
      end

      # Parse the output
      current_commit = nil
      current_files = []

      output.each_line do |line|
        line.chomp!

        if line.match(/^([a-f0-9]{7,})\|(.+)\|(\d{4}-\d{2}-\d{2})$/)
          # Previous commit is complete, add it to files_history
          if current_commit
            current_files.each do |file|
              # Only include files that match the extension
              if file.end_with?(extension)
                files_history[file] ||= []
                files_history[file] << current_commit
              end
            end
          end

          # Start new commit
          hash = $1
          message = $2
          date = $3

          current_commit = {
            hash: hash,
            message: message,
            date: date
          }
          current_files = []

        elsif !line.empty? && current_commit
          # This is a filename for the current commit
          current_files << line
        end
      end

      # Don't forget the last commit
      if current_commit
        current_files.each do |file|
          # Only include files that match the extension
          if file.end_with?(extension)
            files_history[file] ||= []
            files_history[file] << current_commit
          end
        end
      end
    end

    # Apply limit if specified
    if @options[:limit]
      files_history.each do |file, commits|
        files_history[file] = commits.first(@options[:limit])
      end
    end

    files_history
  end

  def build_git_log_command(extension)
    cmd = 'git log --pretty=format:"%H|%s|%ad" --date=short --name-only'

    # Add date filters if specified
    if @options[:since]
      cmd += " --since=#{@options[:since]}"
    end

    if @options[:until]
      cmd += " --until=#{@options[:until]}"
    end

    # Don't add extension filter here - we'll filter in the code
    # This ensures we get all files and can filter properly
    cmd
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
    # Check if file still exists
    file_exists = File.exist?(file)
    status_indicator = file_exists ? "✓" : "✗"
    status_text = file_exists ? "" : " (deleted)"

    puts "#{status_indicator} #{file}#{status_text}"

    commits.each do |commit|
      puts "  ↳ #{commit[:hash]} (#{commit[:date]}) #{commit[:message]}"
      puts "     → git show #{commit[:hash]}:#{file}"
    end
  end
end

# Simple execution for scripts that don't need the full framework
if __FILE__ == $0
  script = GitHistory.new
  script.run
end