# frozen_string_literal: true

require_relative 'script_base'

# Base class for scripts that commit specific types of git changes
class GitCommitScriptBase < ScriptBase
  def add_custom_options(opts)
    opts.on('-m', '--message MESSAGE', 'Commit message (skip interactive prompt)') do |message|
      @options[:message] = message
    end
  end

  def validate!
    unless system('git rev-parse --git-dir >/dev/null 2>&1')
      log_error('Not in a git repository')
      exit 1
    end
    super
  end

  def run
    log_banner(script_title)

    stage_all_changes
    diff_output = get_staged_changes

    return if diff_output.strip.empty?

    changes_to_commit, other_changes = filter_changes(diff_output)

    summarize_changes(changes_to_commit, other_changes)

    return if changes_to_commit.empty?

    handle_other_changes(other_changes)

    commit_message = get_commit_message

    stage_and_commit(changes_to_commit, commit_message)

    show_completion(script_title)
  end

  private

  # Abstract methods to be implemented by subclasses
  def filter_changes(diff_output)
    raise NotImplementedError, 'Subclasses must implement #filter_changes'
  end

  def stage_filtered_changes(changes)
    raise NotImplementedError, 'Subclasses must implement #stage_filtered_changes'
  end

  def change_type_name
    'change'
  end

  def plural_change_type_name
    "#{change_type_name}s"
  end
  # --- End of abstract methods ---

  def stage_all_changes
    log_info('Staging all changes...')
    unless system('git add .')
      log_error('Failed to stage changes')
      exit 1
    end
  end

  def get_staged_changes
    log_info('Checking staged changes...')
    `git diff --cached --name-status`
  end

  def summarize_changes(changes_to_commit, other_changes)
    log_info('📊 Changes Summary:')
    puts "  Total staged: #{changes_to_commit.length + other_changes.length}"
    puts "  #{change_type_name.capitalize}s to commit: #{changes_to_commit.length}"
    puts "  Other changes: #{other_changes.length}"

    if changes_to_commit.empty?
      log_warning("No #{plural_change_type_name} found in staged changes")
      if other_changes.any?
        log_info('Sample of other changes (up to 5):')
        other_changes.sample([5, other_changes.length].min).each { |change| puts "  #{change}" }
      end
      return
    end

    log_success("Found #{changes_to_commit.length} #{plural_change_type_name} to commit:")
    sample_changes = changes_to_commit.sample([5, changes_to_commit.length].min)
    sample_changes.each { |change| puts "  #{change}" }
    puts "  ... and #{changes_to_commit.length - 5} more" if changes_to_commit.length > 5
  end

  def handle_other_changes(other_changes)
    return unless other_changes.any?

    log_warning("Found #{other_changes.length} other change(s) that will NOT be committed:")
    sample_others = other_changes.sample([5, other_changes.length].min)
    sample_others.each { |change| puts "  #{change}" }
    puts "  ... and #{other_changes.length - 5} more" if other_changes.length > 5

    unless force? || confirm_action("Do you want to continue and commit only the #{plural_change_type_name}?")
      log_error('Operation cancelled by user.')
      exit 1
    end
  end

  def get_commit_message
    commit_message = @options[:message]

    if commit_message.nil? || commit_message.strip.empty?
      print "\n💬 Enter commit message for the #{plural_change_type_name}: "
      commit_message = STDIN.gets.chomp.strip

      if commit_message.empty?
        log_error('Commit message cannot be empty')
        exit 1
      end
    else
      log_info("Using provided commit message: #{commit_message}")
    end
    commit_message
  end

  def stage_and_commit(changes_to_commit, commit_message)
    log_info('Resetting staged changes...')
    system('git reset')

    log_info("Staging only #{plural_change_type_name}...")
    stage_filtered_changes(changes_to_commit)

    log_progress("Committing #{plural_change_type_name}...")
    commit_command = "git commit -m '#{commit_message}'"
    if force?
      commit_command += ' --no-verify'
      log_info('Force flag detected, skipping pre-commit hooks with --no-verify.')
    end

    if system(commit_command)
      log_success("Successfully committed #{changes_to_commit.length} #{plural_change_type_name}")
      log_info('Final repository status:')
      system('git status --short')
    else
      log_error('Failed to commit changes')
      exit 1
    end
  end
end
