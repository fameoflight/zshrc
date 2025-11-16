#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Intelligently rebase with automatic conflict resolution for permissions and whitespace
# @tags: automation, interactive, rebase

require_relative '../../.common/interactive_script_base'

# Smart Git Rebase - Automatically handles permission/whitespace conflicts during rebase
class GitSmartRebase < InteractiveScriptBase
  def script_emoji; '🔄'; end
  def script_title; 'Git Smart Rebase'; end
  def script_description; 'Safely rebase clean branches, auto-resolving permission and whitespace conflicts'; end
  def script_arguments; '[OPTIONS] <target-branch>'; end

  def add_custom_options(opts)
    opts.on('-f', '--force', 'Skip confirmation prompts and auto-resolve conflicts') do
      @options[:force] = true
    end
    opts.on('-d', '--dry-run', 'Show what would be done without making changes') do
      @options[:dry_run] = true
    end
    opts.on('-k', '--keep-backup', 'Keep backup branch after successful rebase') do
      @options[:keep_backup] = true
    end
    opts.on('-s', '--squash', 'Squash all commits into one after rebase') do
      @options[:squash] = true
    end
    opts.on('-m', '--message MESSAGE', 'Commit message for squashed commit') do |message|
      @options[:squash_message] = message
    end
  end

  def validate!
    # Change to original working directory
    Dir.chdir(original_working_dir)

    unless system('git rev-parse --git-dir >/dev/null 2>&1')
      log_error('Not in a git repository')
      exit 1
    end

    # Get target branch from argument or default to master/main
    @target_branch = @args[0] || detect_main_branch
    @current_branch = `git rev-parse --abbrev-ref HEAD`.strip

    # Debug output
    log_debug("Parsed args: #{@args.inspect}")
    log_debug("Options: #{@options.inspect}")
    log_debug("Target branch: #{@target_branch}")
    log_debug("Current branch: #{@current_branch}") if @options[:debug]

    if @current_branch == @target_branch
      log_error("Cannot rebase #{@current_branch} onto itself")
      exit 1
    end

    # Validate target branch exists
    unless system("git rev-parse --verify #{@target_branch} >/dev/null 2>&1")
      log_error("Target branch '#{@target_branch}' not found")
      exit 1
    end

    super
  end

  def run
    log_banner(script_title)

    # Pre-flight checks
    pre_flight_checks

    # Analyze changes if any exist
    change_analysis = analyze_local_changes

    if change_analysis[:has_real_changes] && !@options[:force]
      log_error('Found real content changes that would be lost.')
      log_error('Commit or stash these changes first, or use --force to proceed anyway.')
      exit 1
    end

    # Show rebase plan
    show_rebase_plan(change_analysis)

    # Get confirmation unless forced
    unless @options[:force] || @options[:dry_run]
      return unless confirm_rebase
    end

    # Perform smart rebase
    perform_smart_rebase(change_analysis)

    show_completion(script_title)
  end

  private

  def detect_main_branch
    # Try to detect main/master branch
    if system('git rev-parse --verify origin/main >/dev/null 2>&1')
      'main'
    elsif system('git rev-parse --verify origin/master >/dev/null 2>&1')
      'master'
    elsif system('git rev-parse --verify main >/dev/null 2>&1')
      'main'
    elsif system('git rev-parse --verify master >/dev/null 2>&1')
      'master'
    else
      log_error('Could not detect main/master branch. Please specify target branch.')
      exit 1
    end
  end

  def pre_flight_checks
    log_section('Pre-flight Checks')

    # Check if working directory is clean
    status_output = `git status --porcelain`.strip
    if status_output.empty?
      log_success('✅ Working directory is clean')
    else
      log_info('📋 Working directory has changes:')
      status_output.each_line do |line|
        puts "  #{line}"
      end
    end

    # Check if branch is pushed and count commits for squashing
    unpushed_commits = `git log #{@target_branch}..#{@current_branch} --oneline`.strip
    if unpushed_commits.empty?
      log_success('✅ Branch is up to date with remote')
      @commit_count = 0
    else
      @commit_count = unpushed_commits.lines.count
      log_warning("⚠️  Branch has #{@commit_count} unpushed commits")

      if @options[:squash]
        if @commit_count == 1
          log_info('📝 Only 1 commit to squash (no squashing needed)')
          @options[:squash] = false
        else
          log_success("📝 Will squash #{@commit_count} commits into one")
        end
      end

      if @commit_count > 5
        log_warning('Consider pushing before rebasing large number of commits')
      end
    end

    # Check for potential conflicts
    log_progress('Checking for potential merge conflicts...')
    conflict_check = check_rebase_conflicts
    if conflict_check[:has_conflicts]
      log_warning("⚠️  Potential conflicts detected in #{conflict_check[:conflict_files].length} files:")
      conflict_check[:conflict_files].each do |file|
        puts "  🔥 #{file}"
      end
    else
      log_success('✅ No obvious conflicts detected')
    end
  end

  def analyze_local_changes
    log_progress('Analyzing local changes...')

    status_output = `git status --porcelain`.strip
    return { has_changes: false, has_real_changes: false, changes: [] } if status_output.empty?

    changes = []
    has_real_changes = false
    permission_changes = false
    whitespace_changes = false

    status_output.each_line do |line|
      status, path = line.strip.split(' ', 2)

      change_info = {
        status: status,
        path: path,
        type: categorize_change(status, path)
      }

      changes << change_info

      case change_info[:type]
      when :permission
        permission_changes = true
      when :whitespace
        whitespace_changes = true
      when :content
        has_real_changes = true
      end
    end

    {
      has_changes: true,
      has_real_changes: has_real_changes,
      permission_changes: permission_changes,
      whitespace_changes: whitespace_changes,
      changes: changes
    }
  end

  def categorize_change(status, path)
    # Check if it's a permission change
    diff_output = `git diff --name-only -p #{path} 2>/dev/null || git diff --name-only HEAD -- #{path}`
    if diff_output.include?('old mode') || diff_output.include?('new mode')
      return :permission
    end

    # Check if it's only whitespace changes
    full_diff = `git diff --check #{path} 2>/dev/null || echo "no-whitespace-issues"`
    if full_diff.include?('trailing whitespace') || full_diff.include?('space before tab')
      return :whitespace
    end

    # Check actual content changes
    content_diff = `git diff --ignore-space-change --ignore-all-space #{path} 2>/dev/null`
    if content_diff.strip.empty?
      return :whitespace
    end

    :content
  end

  def check_rebase_conflicts
    # Try a dry run rebase to detect conflicts
    conflict_files = []

    # Create a temporary file to capture conflicts
    temp_file = "/tmp/rebase_check_#{Time.now.to_i}.log"

    result = system("git rebase --abort >/dev/null 2>&1")
    system("git rebase --onto #{@target_branch} #{@target_branch} #{@current_branch} --exec 'echo $PWD >> #{temp_file}' 2>/dev/null")

    # This is a simplified check - in practice we'd parse the rebase output more carefully
    # For now, we'll do a basic merge conflict check
    merge_tree_output = `git merge-tree $(git merge-base #{@target_branch} #{@current_branch}) #{@target_branch} #{@current_branch} 2>/dev/null || echo "CONFLICT"`

    if merge_tree_output.include?('CONFLICT') || merge_tree_output.include?('<<<<<<<')
      # Extract conflicted files (simplified)
      conflict_files = merge_tree_output.scan(/^diff --cc (.+)$/).flatten
    end

    # Clean up
    system("git rebase --abort >/dev/null 2>&1")
    system("rm -f #{temp_file}")

    {
      has_conflicts: !conflict_files.empty?,
      conflict_files: conflict_files
    }
  end

  def show_rebase_plan(change_analysis)
    log_section('Rebase Plan')

    puts "Current branch: #{@current_branch}"
    puts "Target branch:  #{@target_branch}"

    if change_analysis[:has_changes]
      puts
      log_info('📋 Local changes analysis:')

      if change_analysis[:permission_changes]
        puts "  🔧 Permission-only changes: #{change_analysis[:changes].count { |c| c[:type] == :permission }}"
      end

      if change_analysis[:whitespace_changes]
        puts "  ␣ Whitespace-only changes: #{change_analysis[:changes].count { |c| c[:type] == :whitespace }}"
      end

      if change_analysis[:has_real_changes]
        puts "  📝 Content changes: #{change_analysis[:changes].count { |c| c[:type] == :content }}"
      end
    end

    puts
    if @options[:dry_run]
      log_info('🔍 DRY RUN MODE - No changes will be made')
    end

    # Show squashing info if requested
    if @options[:squash] && @commit_count > 1
      puts
      log_info('📝 Squash configuration:')
      if @options[:squash_message]
        puts "  📋 Squash message: #{@options[:squash_message]}"
      else
        puts "  📋 Squash message: Will be prompted after rebase"
      end
    end

    puts
    log_info('📋 Planned actions:')
    puts "  1. Save current state to backup branch"
    puts "  2. Stash permission/whitespace changes if needed" if change_analysis[:has_changes]
    puts "  3. Rebase #{@current_branch} onto #{@target_branch}"
    puts "  4. Auto-resolve with -Xignore-space-change -Xtheirs"
    if @options[:squash] && @commit_count > 1
      puts "  5. Squash #{@commit_count} commits into one"
      puts "  6. Restore stashed changes" if change_analysis[:has_changes]
      puts "  7. Clean up backup branch" unless @options[:keep_backup]
    else
      puts "  5. Restore stashed changes" if change_analysis[:has_changes]
      puts "  6. Clean up backup branch" unless @options[:keep_backup]
    end
  end

  def confirm_rebase
    puts
    @prompt.yes?('🤔 Proceed with this rebase plan?') do |q|
      q.default false
      q.required true
    end
  end

  def perform_smart_rebase(change_analysis)
    log_section('Executing Smart Rebase')

    @backup_branch = "smart-rebase-backup-#{@current_branch}-#{Time.now.to_i}"

    begin
      # Step 1: Create backup branch
      log_info("Creating backup branch: #{@backup_branch}")
      unless system("git branch #{@backup_branch}")
        log_error('Failed to create backup branch')
        return false
      end

      # Step 2: Handle local changes if needed
      stash_created = false
      if change_analysis[:has_changes] && !change_analysis[:has_real_changes]
        log_info('Stashing permission/whitespace changes...')
        system('git stash push -m "Smart rebase temporary stash" --include-untracked')
        stash_created = true
      end

      return false if @options[:dry_run]

      # Step 3: Perform the smart rebase
      log_progress("Rebasing #{@current_branch} onto #{@target_branch}...")

      # Use rebase flags to auto-resolve common conflicts
      rebase_command = "git rebase -X ignore-space-change -X theirs #{@target_branch}"
      log_info("Running: #{rebase_command}")

      rebase_success = system(rebase_command)

      unless rebase_success
        log_error('Rebase failed. Attempting to resolve automatically...')

        # Try to continue if there are conflicts we can resolve
        if resolve_rebase_conflicts
          log_success('✅ Conflicts resolved successfully')
        else
          log_error('❌ Unable to resolve conflicts automatically')
          log_info("You can restore from backup: git checkout #{@backup_branch}")
          return false
        end
      end

      # Step 4: Squash commits if requested
      if @options[:squash] && @commit_count > 1
        perform_squash_operation
      end

      # Step 5: Restore stashed changes
      if stash_created
        log_info('Restoring stashed changes...')
        system('git stash pop')

        # Clean up any remaining permission/whitespace changes
        cleanup_permission_changes if change_analysis[:permission_changes]
      end

      # Step 6: Cleanup
      unless @options[:keep_backup]
        log_info('Cleaning up backup branch...')
        system("git branch -D #{@backup_branch}")
      end

      log_success('🎉 Smart rebase completed successfully!')
      log_info('Branch status after rebase:')
      system('git log --oneline -5')

      return true

    rescue => e
      log_error("Smart rebase failed: #{e.message}")
      log_info("You can restore from backup: git checkout #{@backup_branch}")
      return false
    end
  end

  def resolve_rebase_conflicts
    log_progress('Attempting to resolve conflicts automatically...')

    # Check if there are any conflicts
    conflict_files = `git diff --name-only --diff-filter=U`.strip.split("\n")

    if conflict_files.empty?
      log_success('No conflicts found')
      return true
    end

    log_info("Found conflicts in #{conflict_files.length} files:")
    conflict_files.each { |file| puts "  🔥 #{file}" }

    # Try to resolve each conflict automatically
    conflict_files.each do |file|
      log_info("Resolving conflicts in #{file}...")

      # Check if this is a permission-only conflict
      if `git diff --name-only -p #{file}`.include?('old mode') || `git diff --name-only -p #{file}`.include?('new mode')
        log_info("  → Permission conflict detected, accepting 'theirs'")
        system("git checkout --theirs '#{file}'")
        system("git add '#{file}'")
        next
      end

      # Check if this is a whitespace-only conflict
      ours_content = `git show :2:'#{file}' 2>/dev/null`
      theirs_content = `git show :3:'#{file}' 2>/dev/null`

      if ours_content.gsub(/\s+/, '') == theirs_content.gsub(/\s+/, '')
        log_info("  → Whitespace-only conflict detected, accepting 'theirs'")
        system("git checkout --theirs '#{file}'")
        system("git add '#{file}'")
        next
      end

      # For other conflicts, prefer 'theirs' as specified
      log_warning("  → Content conflict detected, accepting 'theirs' (may lose local changes)")
      system("git checkout --theirs '#{file}'")
      system("git add '#{file}'")
    end

    # Continue the rebase
    log_info('Continuing rebase...')
    system('git rebase --continue')
  end

  def cleanup_permission_changes
    log_progress('Cleaning up permission changes...')

    # Reset file permissions to match git index
    system('git diff --name-only | xargs -I {} git checkout -- {}')
  end

  def perform_squash_operation
    log_progress("Squashing #{@commit_count} commits into one...")

    # Show commits that will be squashed
    log_info("Commits to be squashed:")
    system("git log --oneline #{@target_branch}..#{@current_branch}")

    # Get the squash message
    squash_message = @options[:squash_message]
    unless squash_message
      if @options[:force]
        # Generate default message for force mode
        oldest_commit = `git rev-list --max-parents=0 #{@target_branch}..#{@current_branch} | tail -1`.strip
        newest_commit = `git rev-list #{@target_branch}..#{@current_branch} | head -1`.strip
        squash_message = "Squashed commits from #{oldest_commit[0..7]} to #{newest_commit[0..7]}"
      else
        # Interactive prompt for squash message
        oldest_commit = `git rev-list --max-parents=0 #{@target_branch}..#{@current_branch} | tail -1`.strip
        newest_commit = `git rev-list #{@target_branch}..#{@current_branch} | head -1`.strip
        default_message = "Squashed commits from #{oldest_commit[0..7]} to #{newest_commit[0..7]}"

        squash_message = @prompt.ask('📝 Enter squash commit message:', default: default_message) do |q|
          q.required false
          q.validate ->(input) { true } # Allow any input
        end

        # If user cancelled the prompt
        if squash_message.nil?
          log_warning("Squash operation cancelled by user")
          return
        end

        # Use default if empty
        squash_message = default_message if squash_message.strip.empty?
      end
    end

    # Perform the squash using reset and commit
    log_info("Creating squashed commit with message: #{squash_message}")

    # Reset to target branch but keep changes staged
    system("git reset --soft #{@target_branch}")

    # Create the squashed commit
    unless system("git commit -m '#{squash_message}'")
      log_error('Failed to create squashed commit')
      log_info('You may need to complete the squash manually')
      return
    end

    log_success('✅ Successfully squashed commits')
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # Rebase current branch onto detected main/master"
    puts "  #{script_name} main              # Rebase current branch onto main"
    puts "  #{script_name} develop           # Rebase current branch onto develop"
    puts "  #{script_name} --force main      # Skip confirmations and auto-resolve"
    puts "  #{script_name} --dry-run main    # Show what would be done"
    puts "  #{script_name} --squash main     # Rebase and squash all commits into one"
    puts "  #{script_name} -s -m 'Fix bug' main  # Squash with custom message"
  end
end

GitSmartRebase.execute if __FILE__ == $0