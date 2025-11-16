#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: files
# @description: Identify files with only comment changes for safe low-risk commits
# @tags: analysis, git, code-review

require_relative '../../.common/script_base'

# Identifies files with only comment changes for safe low-risk commits
class CommentOnlyChanges < ScriptBase
  # Script metadata for standardized help text
  def script_emoji
    '🔍'
  end

  def script_title
    'Comment-Only Changes Detector'
  end

  def script_description
    'Analyzes git dirty files to identify those with only comment changes.
Perfect for identifying low-risk changes that can be committed first.'
  end

  def script_arguments
    '[repository_path]'
  end

  def add_custom_options(opts)
    opts.on('-l', '--list-only', 'Only list comment-only files (default behavior)') do
      @options[:list_only] = true
    end

    opts.on('-s', '--stage', 'Stage the comment-only files for commit') do
      @options[:stage] = true
    end

    opts.on('-c', '--commit [MESSAGE]', 'Commit comment-only files with optional message') do |msg|
      @options[:commit] = msg || 'Update comments and documentation'
    end

    opts.on('--skip-hooks', 'Skip git hooks when committing (useful for comment-only changes)') do
      @options[:skip_hooks] = true
    end

    opts.on('--languages LANGS', 'Comma-separated list of languages to check (default: ruby,python)') do |langs|
      @options[:languages] = langs.split(',').map(&:strip)
    end
  end

  def validate!
    super
    @options[:languages] ||= %w[ruby python]
    @repository_path = @args[0] || Dir.pwd

    unless Dir.exist?(@repository_path)
      log_error("Repository path does not exist: #{@repository_path}")
      exit 1
    end

    return if Dir.exist?(File.join(@repository_path, '.git'))

    log_error("Not a git repository: #{@repository_path}")
    exit 1
  end

  def run
    log_banner(script_title)

    Dir.chdir(@repository_path) do
      dirty_files = get_dirty_files

      if dirty_files.empty?
        log_info('No dirty files found in repository')
        return
      end

      log_info("Found #{dirty_files.length} dirty files, analyzing...")

      comment_only_files = analyze_files(dirty_files)

      display_results(comment_only_files, dirty_files.length)

      stage_files(comment_only_files) if @options[:stage] && !comment_only_files.empty?

      commit_files(comment_only_files) if @options[:commit] && !comment_only_files.empty?
    end

    show_completion(script_title)
  end

  private

  def get_dirty_files
    result = `git status --porcelain`.lines
    result.map do |line|
      # Extract filename from git status output (handle spaces in filenames)
      line.strip.split(' ', 2)[1]&.strip
    end.compact.select do |file|
      # Only process files that exist and match our supported languages
      File.exist?(file) && supported_language?(file)
    end
  end

  def supported_language?(file)
    extension = File.extname(file).downcase
    language_extensions = {
      'ruby' => %w[.rb .rake .gemspec],
      'python' => %w[.py .pyx .pxd .pxi],
      'javascript' => %w[.js .jsx .mjs],
      'typescript' => %w[.ts .tsx],
      'java' => %w[.java],
      'php' => %w[.php],
      'go' => %w[.go],
      'rust' => %w[.rs],
      'shell' => %w[.sh .bash .zsh]
    }

    @options[:languages].any? do |lang|
      language_extensions[lang]&.include?(extension)
    end
  end

  def analyze_files(files)
    comment_only_files = []

    files.each do |file|
      log_progress("Analyzing #{file}")

      if comment_only_changes?(file)
        comment_only_files << file
        log_success("✅ #{file} - comment changes only")
      else
        log_info("⚠️  #{file} - has code changes")
      end
    end

    comment_only_files
  end

  def comment_only_changes?(file)
    # Check both staged and unstaged changes
    unstaged_diff = `git diff "#{file}"`
    staged_diff = `git diff --staged "#{file}"`

    # Combine both diffs
    combined_diff = unstaged_diff + staged_diff
    return false if combined_diff.empty?

    language = detect_language(file)
    comment_patterns = get_comment_patterns(language)

    # Parse diff and check if all changes are comments
    diff_lines = combined_diff.lines
    change_lines = diff_lines.select { |line| line.start_with?('+', '-') && !line.start_with?('+++', '---') }

    return false if change_lines.empty?

    # Remove the +/- prefix and check if remaining content is comment or whitespace
    change_lines.all? do |line|
      content = line[1..-1] # Remove +/- prefix
      is_comment_or_whitespace?(content, comment_patterns)
    end
  end

  def detect_language(file)
    extension = File.extname(file).downcase

    case extension
    when '.rb', '.rake', '.gemspec'
      'ruby'
    when '.py', '.pyx', '.pxd', '.pxi'
      'python'
    when '.js', '.jsx', '.mjs'
      'javascript'
    when '.ts', '.tsx'
      'typescript'
    when '.java'
      'java'
    when '.php'
      'php'
    when '.go'
      'go'
    when '.rs'
      'rust'
    when '.sh', '.bash', '.zsh'
      'shell'
    else
      'unknown'
    end
  end

  def get_comment_patterns(language)
    patterns = {
      'ruby' => [
        /^\s*#.*$/,           # Single line comments
        /^\s*=begin.*$/,      # Multi-line comment start
        /^\s*=end.*$/         # Multi-line comment end
      ],
      'python' => [
        /^\s*#.*$/,           # Single line comments
        /^\s*""".*$/,         # Triple quote docstrings (start)
        /^\s*'''.*$/,         # Triple quote docstrings (start)
        /^.*""".*$/,          # Triple quote docstrings (end)
        /^.*'''.*$/           # Triple quote docstrings (end)
      ],
      'javascript' => [
        %r{^\s*//.*$},        # Single line comments
        %r{^\s*/\*.*$},        # Multi-line comment start
        %r{^.*\*/.*$}          # Multi-line comment end
      ],
      'typescript' => [
        %r{^\s*//.*$}, # Single line comments
        %r{^\s*/\*.*$},        # Multi-line comment start
        %r{^.*\*/.*$}          # Multi-line comment end
      ],
      'java' => [
        %r{^\s*//.*$}, # Single line comments
        %r{^\s*/\*.*$},        # Multi-line comment start
        %r{^.*\*/.*$}          # Multi-line comment end
      ],
      'php' => [
        %r{^\s*//.*$},        # Single line comments
        /^\s*#.*$/,           # Shell-style comments
        %r{^\s*/\*.*$},        # Multi-line comment start
        %r{^.*\*/.*$}          # Multi-line comment end
      ],
      'go' => [
        %r{^\s*//.*$}, # Single line comments
        %r{^\s*/\*.*$},        # Multi-line comment start
        %r{^.*\*/.*$}          # Multi-line comment end
      ],
      'rust' => [
        %r{^\s*//.*$}, # Single line comments
        %r{^\s*/\*.*$},        # Multi-line comment start
        %r{^.*\*/.*$}          # Multi-line comment end
      ],
      'shell' => [
        /^\s*#.*$/ # Single line comments
      ]
    }

    patterns[language] || []
  end

  def is_comment_or_whitespace?(content, comment_patterns)
    # Check if line is whitespace only
    return true if content.strip.empty?

    # Check if line matches any comment pattern
    comment_patterns.any? { |pattern| content.match?(pattern) }
  end

  def display_results(comment_only_files, total_files)
    log_separator

    if comment_only_files.empty?
      log_warning('No files found with comment-only changes')
      log_info("All #{total_files} dirty files contain code changes")
    else
      log_success("Found #{comment_only_files.length} files with comment-only changes:")
      comment_only_files.each do |file|
        puts "  📄 #{file}"
      end

      remaining = total_files - comment_only_files.length
      log_info("#{remaining} files contain code changes and should be reviewed separately") if remaining > 0
    end

    log_separator
  end

  def stage_files(files)
    log_info("Staging #{files.length} comment-only files...")

    files.each do |file|
      system('git', 'add', file)
      log_file_updated(file)
    end

    log_success('Files staged successfully!')
  end

  def commit_files(files)
    if @options[:stage]
      # Files already staged above
      message = @options[:commit]
    else
      # Stage files first
      stage_files(files)
      message = @options[:commit]
    end

    log_info('Committing comment-only changes...')

    commit_message = "#{message}\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"

    # Build commit command with optional --no-verify flag
    commit_cmd = ['git', 'commit', '-m', commit_message]
    commit_cmd << '--no-verify' if @options[:skip_hooks]

    if system(*commit_cmd)
      log_success("Successfully committed #{files.length} files with comment-only changes!")
    else
      log_error('Failed to commit changes')
      exit 1
    end
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name}                                    # Analyze current directory"
    puts "  #{script_name} /path/to/repo                      # Analyze specific repository"
    puts "  #{script_name} --stage                            # Stage comment-only files"
    puts "  #{script_name} --commit                           # Stage and commit comment-only files"
    puts "  #{script_name} --commit 'Update documentation'    # Custom commit message"
    puts "  #{script_name} --commit --skip-hooks              # Skip git hooks (e.g., RuboCop)"
    puts "  #{script_name} --languages ruby,python,javascript # Check specific languages"
  end
end

# Execute the script
CommentOnlyChanges.execute if __FILE__ == $0
