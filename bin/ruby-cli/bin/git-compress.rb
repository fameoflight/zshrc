#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/archive/script_base'

class GitCompress < ScriptBase
  def script_emoji; '🗜️'; end
  def script_title; 'Git Compress'; end
  def script_description; 'Compress git history by creating fresh repository with single commit'; end
  def script_arguments; '[OPTIONS]'; end

  def add_custom_options(opts)
    opts.on('-m', '--message MESSAGE', 'Initial commit message (default: "Initial commit")') do |message|
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
    log_banner('Git History Compression')

    # Change to original working directory if specified
    if ENV['ORIGINAL_WORKING_DIR']
      log_info("Changing to original directory: #{ENV['ORIGINAL_WORKING_DIR']}")
      Dir.chdir(ENV['ORIGINAL_WORKING_DIR'])
    end

    # Check if we have any pending changes
    check_pending_changes

    # Get the remote URL
    remote_url = get_remote_url
    return unless remote_url

    # Show repository information
    show_repository_info

    # Handle submodules if any exist
    handle_submodules if @submodules && !@submodules.empty?

    # Get user confirmation with detailed warning
    return unless confirm_compression

    # Perform the compression
    perform_compression(remote_url)

    show_completion('Git history compression')
  end

  private

  def check_pending_changes
    log_info('Checking for pending changes...')

    # Check for uncommitted changes
    status_output = `git status --porcelain`.strip
    unless status_output.empty?
      log_error('Repository has pending changes:')
      puts status_output
      log_error('Please commit or stash all changes before running git-compress')
      exit 1
    end

    # Check if we're in sync with remote
    branch_name = `git rev-parse --abbrev-ref HEAD`.strip
    if branch_name != 'HEAD'  # Not in detached HEAD
      log_info("Checking if branch '#{branch_name}' is in sync with remote...")

      # Check if remote exists and we're tracking it
      tracking_remote = `git config branch.#{branch_name}.remote 2>/dev/null`.strip
      if !tracking_remote.empty?
        ahead_behind = `git rev-list --count --left-right #{tracking_remote}/#{branch_name}...#{branch_name}`.strip
        if ahead_behind != '0\t0'
          behind_count = ahead_behind.split("\t")[0].to_i
          ahead_count = ahead_behind.split("\t")[1].to_i

          if behind_count > 0
            log_warning("Your branch is #{behind_count} commit(s) behind remote.")
            log_warning('Please pull latest changes before running git-compress')
            exit 1 unless force?
          end

          if ahead_count > 0
            log_warning("Your branch is #{ahead_count} commit(s) ahead of remote.")
            log_warning('These changes will be lost if you continue!')
            exit 1 unless confirm_action('Continue despite having unpushed commits?')
          end
        end
      end
    end

    log_success('Repository is clean and in sync with remote')
  end

  def get_remote_url
    log_info('Getting remote URL...')

    # Try origin first, then any remote
    remote_url = `git config remote.origin.url 2>/dev/null`.strip

    if remote_url.empty?
      log_warning('No origin remote found, looking for any remote...')
      remotes = `git remote`.strip.split("\n")
      if remotes.empty?
        log_error('No remote found in this repository')
        log_error('git-compress requires a remote to restore from')
        return nil
      end

      remote_url = `git config remote.#{remotes.first}.url 2>/dev/null`.strip
      log_info("Using remote '#{remotes.first}': #{remote_url}")
    else
      log_info("Using origin remote: #{remote_url}")
    end

    remote_url
  end

  def show_repository_info
    log_section('Repository Information')

    # Show current commit info
    current_commit = `git rev-parse HEAD`.strip
    commit_message = `git log -1 --pretty=format:"%s"`.strip
    commit_date = `git log -1 --pretty=format:"%ad" --date=short`.strip
    commit_author = `git log -1 --pretty=format:"%an"`.strip

    puts "  Current HEAD: #{current_commit}"
    puts "  Commit: #{commit_message}"
    puts "  Author: #{commit_author}"
    puts "  Date: #{commit_date}"

    # Show total commit count
    total_commits = `git rev-list --count HEAD`.strip.to_i
    puts "  Total commits: #{total_commits}"

    # Show branch info
    branch_name = `git rev-parse --abbrev-ref HEAD`.strip
    puts "  Current branch: #{branch_name}"

    # Show repository size (approximate)
    size_output = `du -sh .git 2>/dev/null`.strip
    puts "  Git directory size: #{size_output}" unless size_output.empty?

    # Show submodule information
    show_submodule_info

    puts ""
  end

  def show_submodule_info
    @submodules = get_submodules

    if @submodules.empty?
      log_info('No submodules found')
      return
    end

    log_section("Submodules (#{@submodules.length} found)")

    @submodules.each_with_index do |submodule, index|
      status = get_submodule_status(submodule)
      puts "  #{index + 1}. #{submodule[:name]} (#{status})"
    end
  end

  def get_submodules
    submodules = []

    # Get submodule status output
    status_output = `git submodule status 2>/dev/null`.strip
    return submodules if status_output.empty?

    status_output.split("\n").each do |line|
      next if line.strip.empty?

      # Parse each line: <commit> <path> <description>
      # The commit hash may have + or - prefix to indicate status
      stripped_line = line.strip
      parts = stripped_line.split(' ', 3)
      next if parts.length < 2

      commit_hash = parts[0].gsub(/^[+-]/, '')
      path = parts[1]
      description = parts[2] || path

      submodules << {
        name: path,
        path: path,
        commit: commit_hash,
        description: description,
        url: get_submodule_url(path)
      }
    end

    submodules
  end

  def get_submodule_url(path)
    `git config submodule.#{path}.url 2>/dev/null`.strip
  end

  def get_submodule_status(submodule)
    path = submodule[:path]

    # Check if submodule directory exists
    unless Dir.exist?(path)
      return "missing"
    end

    # Check for uncommitted changes in submodule
    Dir.chdir(path) do
      status_output = `git status --porcelain 2>/dev/null`.strip
      unless status_output.empty?
        return "dirty - #{status_output.split("\n").length} uncommitted files"
      end
    end

    # Check if submodule is on different commit
    submodule_status = `git submodule status #{path} 2>/dev/null`.strip
    if submodule_status.start_with?('+')
      return "different commit"
    elsif submodule_status.start_with?('-')
      return "not initialized"
    end

    "clean"
  end

  def handle_submodules
    log_section('Submodule Handling')

    puts "This repository contains #{@submodules.length} submodule(s):"
    puts ""

    @submodules.each_with_index do |submodule, index|
      status = get_submodule_status(submodule)
      puts "  #{index + 1}. #{submodule[:name]} (#{status})"
    end

    puts ""
    puts "How would you like to handle these submodules?"
    puts "  1) Preserve all submodules (backup and restore after compression)"
    puts "  2) Convert to regular directories (include as normal folders)"
    puts "  3) Remove all submodules (exclude from compressed repository)"
    puts "  4) Handle each submodule individually"
    puts ""

    choice = prompt_select("Choose option:", [
      { name: '1) Preserve all submodules', value: '1' },
      { name: '2) Convert to regular directories', value: '2' },
      { name: '3) Remove all submodules', value: '3' },
      { name: '4) Handle each submodule individually', value: '4' }
    ])

    case choice
    when '1'
      preserve_all_submodules
    when '2'
      convert_all_submodules
    when '3'
      remove_all_submodules
    when '4'
      handle_submodules_individually
    end

    puts ""
  end

  def preserve_all_submodules
    log_info('Preserving all submodules...')
    @submodule_actions = {}
    @submodules.each { |submodule| @submodule_actions[submodule[:name]] = 'preserve' }
    log_success("All #{@submodules.length} submodules will be preserved")
  end

  def convert_all_submodules
    log_info('Converting all submodules to regular directories...')
    @submodule_actions = {}
    @submodules.each { |submodule| @submodule_actions[submodule[:name]] = 'convert' }
    log_success("All #{@submodules.length} submodules will be converted")
  end

  def remove_all_submodules
    log_warning('Removing all submodules...')
    @submodule_actions = {}
    @submodules.each { |submodule| @submodule_actions[submodule[:name]] = 'remove' }
    log_warning("All #{@submodules.length} submodules will be removed")
  end

  def handle_submodules_individually
    @submodule_actions = {}
    apply_to_all = nil

    @submodules.each_with_index do |submodule, index|
      status = get_submodule_status(submodule)

      puts "\nSubmodule #{index + 1}/#{ @submodules.length}: #{submodule[:name]} (#{status})"

      if apply_to_all
        action = apply_to_all
        puts "  Action: #{action} (applied to all)"
      else
        puts "  Actions:"
        puts "    [p] Preserve (backup and restore)"
        puts "    [c] Convert to regular directory"
        puts "    [r] Remove from repository"
        puts "    [a] Apply an action to all remaining submodules"

        input = prompt_select("  Choose action:", [
            { name: '[p] Preserve (backup and restore)', value: 'p' },
            { name: '[c] Convert to regular directory', value: 'c' },
            { name: '[r] Remove from repository', value: 'r' },
            { name: '[a] Apply an action to all remaining submodules', value: 'a' }
          ])

        case input
        when 'p'
          action = 'preserve'
        when 'c'
          action = 'convert'
        when 'r'
          action = 'remove'
        when 'a'
          puts "\n  Apply action to all remaining submodules:"
          puts "    [p] Preserve"
          puts "    [c] Convert"
          puts "    [r] Remove"

          all_choice = prompt_select("  Choose action:", [
              { name: '[p] Preserve', value: 'p' },
              { name: '[c] Convert', value: 'c' },
              { name: '[r] Remove', value: 'r' }
            ])
          apply_to_all = case all_choice
                        when 'p' then 'preserve'
                        when 'c' then 'convert'
                        when 'r' then 'remove'
                        end
          action = apply_to_all
        end
      end

      @submodule_actions[submodule[:name]] = action

      case action
      when 'preserve'
        log_info("  ✅ #{submodule[:name]} will be preserved")
      when 'convert'
        log_info("  📁 #{submodule[:name]} will be converted")
      when 'remove'
        log_warning("  ❌ #{submodule[:name]} will be removed")
      end
    end

    # Summary
    summary = @submodule_actions.values.group_by(&:itself).transform_values(&:count)
    puts "\n📋 Submodule handling summary:"
    summary.each do |action, count|
      case action
      when 'preserve'
        log_success("  #{count} submodule(s) will be preserved")
      when 'convert'
        log_info("  #{count} submodule(s) will be converted")
      when 'remove'
        log_warning("  #{count} submodule(s) will be removed")
      end
    end
  end

  def confirm_compression
    log_section('⚠️  WARNING - IRREVERSIBLE OPERATION')

    puts "This operation will:"
    puts "  1. DELETE the .git folder (all history will be lost)"
    puts "  2. CREATE a new git repository"
    puts "  3. COMMIT all current files as a single initial commit"
    puts "  4. ADD the remote URL back"

    # Add submodule information to warning
    if @submodule_actions && !@submodule_actions.empty?
      puts ""
      puts "Submodule handling:"
      @submodule_actions.each do |name, action|
        case action
        when 'preserve'
          puts "  • #{name}: Will be preserved (backup and restore)"
        when 'convert'
          puts "  • #{name}: Will be converted to regular directory"
        when 'remove'
          puts "  • #{name}: Will be removed from repository"
        end
      end
    end

    puts ""
    puts "After completion, you will need to:"
    puts "  • Run 'git push --force-with-lease' to overwrite remote history"
    puts ""
    puts "To restore your repository if something goes wrong:"
    puts "  • Clone the repository again from the remote URL"
    puts ""

    if force?
      log_warning('Force flag detected - skipping confirmation')
      return true
    end

    confirm_action("Are you absolutely sure you want to compress the git history? This cannot be undone.")
  end

  def perform_compression(remote_url)
    log_section('Compressing Git History')

    # Store current commit info for potential restoration
    current_commit = `git rev-parse HEAD`.strip
    log_info("Current commit saved for reference: #{current_commit}")

    # Step 1: Handle submodules before compression
    handle_submodules_before_compression

    # Step 2: Remove .git directory
    log_progress('Removing .git directory...')
    unless system('rm -rf .git')
      log_error('Failed to remove .git directory')
      exit 1
    end
    log_success('.git directory removed')

    # Step 2: Initialize new repository
    log_progress('Initializing new git repository...')
    unless system('git init')
      log_error('Failed to initialize new git repository')
      exit 1
    end
    log_success('New git repository initialized')

    # Step 3: Add all files
    log_progress('Adding all files...')
    unless system('git add .')
      log_error('Failed to add files')
      exit 1
    end
    log_success('All files added to staging')

    # Step 4: Create initial commit
    commit_message = @options[:message] || 'Initial commit'
    log_progress("Creating initial commit: '#{commit_message}'")

    commit_command = "git commit -m '#{commit_message}'"
    if force?
      commit_command += ' --no-verify'
      log_info('Force flag detected, skipping pre-commit hooks with --no-verify.')
    end

    unless system(commit_command)
      log_error('Failed to create initial commit')
      exit 1
    end
    log_success('Initial commit created')

    # Step 5: Handle submodules after compression
    handle_submodules_after_compression

    # Step 6: Add remote URL
    log_progress("Adding remote URL: #{remote_url}")
    unless system("git remote add origin '#{remote_url}'")
      log_error('Failed to add remote URL')
      exit 1
    end
    log_success('Remote URL added')

    # Step 7: Show final status
    log_section('Compression Complete')
    puts "✅ Git history has been compressed to a single commit"
    puts ""
    puts "Next steps:"
    puts "  1. Review the repository: git status"
    puts "  2. Push to remote (WARNING: This will overwrite remote history):"
    puts "     git push --force-with-lease origin $(git rev-parse --abbrev-ref HEAD)"
    puts ""
    puts "To restore original repository if needed:"
    puts "  1. Note the remote URL: #{remote_url}"
    puts "  2. Clone again: git clone #{remote_url} temp-repo"
    puts "  3. Move files as needed"
    puts ""

    # Save recovery info
    save_recovery_info(remote_url, current_commit)
  end

  def save_recovery_info(remote_url, original_commit)
    recovery_file = '.git-compress-recovery.txt'

    File.open(recovery_file, 'w') do |f|
      f.puts "# Git Compress Recovery Information"
      f.puts "# Generated on: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      f.puts ""
      f.puts "Remote URL: #{remote_url}"
      f.puts "Original Commit: #{original_commit}"
      f.puts "Compression Date: #{Time.now.iso8601}"
      f.puts ""
      f.puts "# To restore original repository:"
      f.puts "# 1. Clone: git clone #{remote_url} original-repo"
      f.puts "# 2. Your files are safe in the current directory"
      f.puts "# 3. Remove this recovery file when done"
    end

    log_file_created(recovery_file)
    log_info('Recovery information saved to .git-compress-recovery.txt')
  end

  def handle_submodules_before_compression
    return unless @submodule_actions && !@submodule_actions.empty?

    log_section('Handling Submodules Before Compression')

    # Create temporary backup directory
    @backup_dir = Dir.mktmpdir('git-compress-')
    log_info("Created backup directory: #{@backup_dir}")

    # Handle each submodule according to its action
    @submodule_actions.each do |name, action|
      case action
      when 'preserve'
        backup_submodule(name)
      when 'remove'
        remove_submodule_directory(name)
      when 'convert'
        # No action needed - just leave it as regular directory
        log_info("📁 #{name}: Converting to regular directory (no action needed)")
      end
    end

    log_success('Submodule pre-compression handling completed')
  end

  def handle_submodules_after_compression
    return unless @submodule_actions && !@submodule_actions.empty?

    log_section('Handling Submodules After Compression')

    restored_count = 0

    @submodule_actions.each do |name, action|
      case action
      when 'preserve'
        restore_submodule(name)
        restored_count += 1
      end
    end

    # Commit restored submodules if any were restored
    if restored_count > 0
      log_progress("Committing restored submodules...")
      commit_command = "git commit --amend --no-edit --no-verify"
      unless system(commit_command)
        log_warning('Failed to amend commit with restored submodules')
      else
        log_success("Restored #{restored_count} submodule(s) and amended initial commit")
      end
    end

    # Clean up backup directory
    if @backup_dir && Dir.exist?(@backup_dir)
      log_progress('Cleaning up backup directory...')
      system("rm -rf '#{@backup_dir}'")
      log_success('Backup directory cleaned up')
    end

    log_success('Submodule post-compression handling completed')
  end

  def backup_submodule(name)
    unless Dir.exist?(name)
      log_warning("⚠️  #{name}: Submodule directory not found, skipping backup")
      return
    end

    backup_path = File.join(@backup_dir, name)
    log_progress("📦 Backing up #{name}...")

    begin
      # Copy entire submodule directory to backup
      system("cp -r '#{name}' '#{backup_path}'")

      if Dir.exist?(backup_path)
        log_success("✅ #{name}: Backed up successfully")
      else
        log_error("❌ #{name}: Backup failed")
      end
    rescue => e
      log_error("❌ #{name}: Backup failed - #{e.message}")
    end
  end

  def restore_submodule(name)
    backup_path = File.join(@backup_dir, name)

    unless Dir.exist?(backup_path)
      log_warning("⚠️  #{name}: Backup not found, skipping restore")
      return
    end

    log_progress("🔄 Restoring #{name}...")

    begin
      # Remove the empty directory that was committed
      if Dir.exist?(name)
        system("rm -rf '#{name}'")
      end

      # Restore from backup
      system("cp -r '#{backup_path}' '#{name}'")

      if Dir.exist?(name)
        # Add restored submodule to git
        system("git add '#{name}'")
        log_success("✅ #{name}: Restored successfully")
      else
        log_error("❌ #{name}: Restore failed")
      end
    rescue => e
      log_error("❌ #{name}: Restore failed - #{e.message}")
    end
  end

  def remove_submodule_directory(name)
    unless Dir.exist?(name)
      log_warning("⚠️  #{name}: Directory not found, skipping removal")
      return
    end

    log_progress("🗑️  Removing #{name}...")

    begin
      system("rm -rf '#{name}'")
      log_success("✅ #{name}: Removed successfully")
    rescue => e
      log_error("❌ #{name}: Removal failed - #{e.message}")
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # Compress with default commit message"
    puts "  #{script_name} -m 'Fresh start'   # Custom initial commit message"
    puts "  #{script_name} --force           # Skip all confirmations (dangerous)"
  end
end

GitCompress.execute if __FILE__ == $0