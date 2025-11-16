#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Split large commits into smaller logical commits interactively
# @tags: automation, interactive, refactor

require_relative '../../.common/interactive_script_base'

# Interactive script to split a git commit by selecting files for separate commits
class GitCommitSplitter < InteractiveScriptBase
  def script_emoji; '✂️'; end
  def script_title; 'Git Commit Splitter'; end
  def script_description; 'Interactive tool to split an existing git commit into multiple commits'; end
  def script_arguments; '[OPTIONS] [commit-hash]'; end

  def add_custom_options(opts)
    opts.on('-c', '--commit HASH', 'Commit hash to split (defaults to HEAD)') do |hash|
      @options[:commit] = hash
    end
    opts.on('--since COUNT', 'Split commits since N commits back (default: 1)') do |count|
      @options[:since] = count.to_i
    end
  end

  def validate!
    # Change to original working directory
    Dir.chdir(original_working_dir)

    unless system('git rev-parse --git-dir >/dev/null 2>&1')
      log_error('Not in a git repository')
      exit 1
    end

    # Check for uncommitted changes
    unless system('git diff-index --quiet HEAD')
      log_error('You have uncommitted changes. Please commit or stash them first.')
      exit 1
    end

    # Handle positional argument for commit hash
    @commit_hash = @options[:commit] || @args[0] || 'HEAD'

    # Validate commit exists
    unless system("git rev-parse --verify #{@commit_hash} >/dev/null 2>&1")
      log_error("Invalid commit hash: #{@commit_hash}")
      exit 1
    end

    super
  end

  def run
    log_banner(script_title)

    # Get commit info
    @commit_info = get_commit_info(@commit_hash)
    log_info("Working with commit: #{@commit_info[:short_hash]}")
    log_info("Original message: #{@commit_info[:message]}")
    log_info("Files changed: #{@commit_info[:files].length}")

    # Interactive file selection
    selected_files, remaining_files = select_files_interactive(@commit_info[:files])

    if selected_files.empty?
      log_warning('No files selected for splitting')
      return
    end

    # Show what will be split
    show_split_preview(selected_files, remaining_files)

    log_info("Splitting commit #{@commit_info[:short_hash]} into two commits...")
    log_info("First commit: [FIRST] #{@commit_info[:message]}")
    log_info("Second commit: [SECOND] #{@commit_info[:message]}")

    # Perform the split
    perform_commit_split(selected_files, remaining_files)

    show_completion(script_title)
  end

  private

  def get_commit_info(commit_hash)
    log_info("Analyzing commit #{commit_hash}...")

    # Get commit message
    message = `git log -1 --pretty=format:%B #{commit_hash}`.strip

    # Get changed files with status
    diff_output = `git show --name-status --format= #{commit_hash}`
    files = diff_output.strip.split("\n").map do |line|
      next if line.empty?
      status, path = line.strip.split("\t", 2)
      { status: status, path: path, type: get_file_type(status) }
    end.compact

    {
      short_hash: `git rev-parse --short #{commit_hash}`.strip,
      full_hash: `git rev-parse #{commit_hash}`.strip,
      message: message,
      files: files
    }
  end

  def get_file_type(status_code)
    case status_code
    when 'A', 'M', 'T'
      :modified
    when 'D'
      :deleted
    when 'R'
      :renamed
    else
      :unknown
    end
  end

  def select_files_interactive(files)
    log_section('File Selection')
    log_info('Select files for the FIRST commit (remaining files will go to the SECOND commit)')

    # Create choices with proper display text
    choices = files.map do |file|
      status_icon = get_status_icon(file[:status])
      display_path = file[:path].length > 60 ? file[:path][0..57] + '...' : file[:path]
      display_text = "#{status_icon} #{display_path} (#{file[:type].capitalize})"
      {
        name: display_text,
        value: file
      }
    end

    # Simple multi-select using tty-prompt
    selected_files = @prompt.multi_select(
      "📁 Select files for the FIRST commit (#{files.length} files available):",
      choices,
      per_page: 15,
      cycle: true,
      show_help: :always,
      filter: true,
      symbols: { marker: '→' }
    )

    if selected_files.empty?
      log_warning('Please select at least one file')
      return select_files_interactive(files) # Retry
    end

    remaining_files = files.reject { |file| selected_files.include?(file) }

    log_success("Selected #{selected_files.length} files for first commit")
    log_info("Remaining #{remaining_files.length} files will go to second commit")

    [selected_files, remaining_files]
  end

  def get_status_icon(status_code)
    case status_code
    when 'A' then '➕'
    when 'M' then '📝'
    when 'D' then '🗑️'
    when 'R' then '🔄'
    when 'T' then '🔧'
    else    '❓'
    end
  end

  def view_file_diff(file)
    view_file_diff_with_context(file, 3)
  end

  def view_file_diff_with_context(file, context_lines = 3)
    log_section("File Diff: #{file[:path]}")

    begin
      require 'pastel'
      pastel = Pastel.new

      case file[:status]
      when 'A'
        # Show new file content with green highlighting
        content = `git show #{@commit_hash}:#{file[:path]}`
        puts "#{pastel.green('📄 New file:')} #{pastel.bold(file[:path])}"
        puts "─" * 80
        content.each_line do |line|
          puts "#{pastel.green('+')} #{pastel.green(line)}"
        end
        puts "─" * 80

      when 'M', 'T'
        # Show diff with color highlighting
        diff_output = `git show --unified=#{context_lines} #{@commit_hash} -- #{file[:path]}`
        puts "#{pastel.yellow('📝 Modified file:')} #{pastel.bold(file[:path])}"
        puts "─" * 80

        diff_output.each_line do |line|
          if line.start_with?('+') && !line.start_with?('+++')
            puts "#{pastel.green(line)}"
          elsif line.start_with?('-') && !line.start_with?('---')
            puts "#{pastel.red(line)}"
          elsif line.start_with?('@@')
            puts "#{pastel.cyan(line)}"
          elsif line.start_with?('---') || line.start_with?('+++')
            puts "#{pastel.magenta(line)}"
          else
            puts line
          end
        end
        puts "─" * 80

      when 'D'
        # Show what was deleted with red highlighting
        content = `git show #{@commit_hash}^:#{file[:path]}`
        puts "#{pastel.red('🗑️ Deleted file:')} #{pastel.bold(file[:path])}"
        puts "─" * 80
        content.each_line do |line|
          puts "#{pastel.red('-')} #{pastel.red(line)}"
        end
        puts "─" * 80

      when 'R'
        # For renamed files, show rename info and diff
        diff_output = `git show --unified=#{context_lines} #{@commit_hash} -- #{file[:path]}`
        puts "#{pastel.blue('🔄 Renamed file:')} #{pastel.bold(file[:path])}"
        puts "─" * 80

        diff_output.each_line do |line|
          if line.start_with?('+') && !line.start_with?('+++')
            puts "#{pastel.green(line)}"
          elsif line.start_with?('-') && !line.start_with?('---')
            puts "#{pastel.red(line)}"
          elsif line.start_with?(/@@.*rename/)
            puts "#{pastel.blue(line)}"
          elsif line.start_with?('@@')
            puts "#{pastel.cyan(line)}"
          elsif line.start_with?('---') || line.start_with?('+++')
            puts "#{pastel.magenta(line)}"
          else
            puts line
          end
        end
        puts "─" * 80

      else
        log_warning("Unknown file status: #{file[:status]}")
        puts "#{pastel.yellow('Raw diff:')}"
        puts `git show #{@commit_hash} -- #{file[:path]}`
      end

    rescue => e
      log_error("Failed to view diff: #{e.message}")
    end

    puts "\n#{pastel.cyan('Press Enter to continue...')}"
    begin
      gets
    rescue
      # Fallback if gets fails
      sleep 2
    end
  end

  def show_split_preview(selected_files, remaining_files)
    log_section('Split Preview')

    if selected_files.any?
      log_info('📦 First commit will contain:')
      selected_files.each do |file|
        puts "  #{get_status_icon(file[:status])} #{file[:path]}"
      end
      puts
    end

    if remaining_files.any?
      log_info('📦 Second commit will contain:')
      remaining_files.each do |file|
        puts "  #{get_status_icon(file[:status])} #{file[:path]}"
      end
      puts
    end

    puts "Original commit: #{@commit_info[:short_hash]} - #{@commit_info[:message]}"
  end

  def perform_commit_split(selected_files, remaining_files)
    log_progress('Starting commit split operation...')

    # Get commits that come after the target commit
    commits_after = `git rev-list #{@commit_hash}..HEAD`.strip.split("\n").reverse
    log_info("Found #{commits_after.length} commits after target commit")

    # Create a backup branch
    backup_branch = "backup-split-#{Time.now.to_i}"
    log_info("Creating backup branch: #{backup_branch}")
    system("git branch #{backup_branch}")

    begin
      # Reset to the parent of the target commit
      parent_commit = "#{@commit_hash}^"
      log_info("Resetting to parent commit: #{parent_commit}")
      unless system("git reset --hard #{parent_commit}")
        log_error('Failed to reset to parent commit')
        restore_backup(backup_branch)
        return
      end

      # Recreate the target commit's changes in staging
      log_info('Reapplying changes from target commit...')
      system("git cherry-pick --no-commit #{@commit_hash}")

      # Create first commit with selected files
      if selected_files.any?
        log_info('Creating first commit with selected files...')
        stage_files(selected_files)
        message = get_commit_message_for_split('first')
        unless system("git commit -m '#{message}'")
          log_error('Failed to create first commit')
          restore_backup(backup_branch)
          return
        end
        log_success('✅ Created first commit')
      end

      # Create second commit with remaining files
      if remaining_files.any?
        log_info('Creating second commit with remaining files...')
        stage_files(remaining_files)
        message = get_commit_message_for_split('second')
        unless system("git commit -m '#{message}'")
          log_error('Failed to create second commit')
          restore_backup(backup_branch)
          return
        end
        log_success('✅ Created second commit')
      end

      # Reapply commits that came after the target commit
      if commits_after.any?
        log_info("Reapplying #{commits_after.length} commits that came after...")
        commits_after.each do |commit_hash|
          log_info("Reapplying commit: #{commit_hash[0..7]}")
          unless system("git cherry-pick #{commit_hash}")
            log_error("Failed to reapply commit #{commit_hash[0..7]}")
            log_error('You may need to resolve conflicts manually')
            log_info("Run 'git cherry-pick --continue' after resolving conflicts")
            return
          end
        end
        log_success('✅ All subsequent commits reapplied')
      end

      # Show results
      log_success('🎉 Commit split completed successfully!')
      log_info('New commits (replacing original):')
      system('git log --oneline -10')

      # Clean up backup branch automatically
      system("git branch -D #{backup_branch}")
      log_info('✅ Backup branch removed')

    rescue => e
      log_error("Error during commit split: #{e.message}")
      log_info('You can restore from backup:')
      puts "  git checkout #{backup_branch}"
    end
  end

  def stage_files(files)
    # Reset everything first
    system('git reset HEAD .')

    # Stage selected files
    files.each do |file|
      case file[:status]
      when 'A', 'M', 'T'
        system("git add '#{file[:path]}'")
      when 'D'
        system("git add '#{file[:path]}'")
      when 'R'
        # For renamed files, stage both old and new paths
        system("git add '#{file[:path]}'")
      end
    end
  end

  def get_commit_message_for_split(which)
    original_message = @commit_info[:message]

    case which
    when 'first'
      "[FIRST] #{original_message}"
    when 'second'
      "[SECOND] #{original_message}"
    end
  end

  def restore_backup(backup_branch)
    log_warning("Restoring from backup branch: #{backup_branch}")
    system('git rebase --abort 2>/dev/null')
    system("git checkout #{backup_branch}")
    system("git reset --hard #{@commit_hash}")
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # Split HEAD commit"
    puts "  #{script_name} abc123            # Split specific commit"
    puts "  #{script_name} --since 3         # Split commits from 3 back"
    puts "  #{script_name} --force           # Skip confirmation prompts"
  end
end

GitCommitSplitter.execute if __FILE__ == $0