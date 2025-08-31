#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Commits only deletions (D status) after user confirmation
class GitCommitDeletes < ScriptBase
  def banner_text
    <<~BANNER
      🗑️  Git Commit Deletes

      Usage: #{script_name} [OPTIONS]

      This script will:
      1. Stage all changes with 'git add .'
      2. Show the diff status
      3. Filter for deletions (D) only
      4. Prompt for commit message (or use -m flag)
      5. Commit only the deletions

      Options:
        -m, --message MESSAGE  Commit message (skip interactive prompt)
    BANNER
  end

  def add_custom_options(opts)
    opts.on('-m', '--message MESSAGE', 'Commit message (skip interactive prompt)') do |message|
      @options[:message] = message
    end
  end

  def validate!
    unless system('git rev-parse --git-dir >/dev/null 2>&1')
      log_error("Not in a git repository")
      exit 1
    end
    super
  end

  def run
    log_banner("Git Commit Deletes")

    # Stage all changes
    log_info("Staging all changes...")
    unless system('git add .')
      log_error("Failed to stage changes")
      exit 1
    end

    # Get diff status
    log_info("Checking staged changes...")
    diff_output = `git diff --cached --name-status`
    
    if diff_output.strip.empty?
      log_warning("No staged changes found")
      return
    end

    # Filter for deletions (D)
    deletions = []
    other_changes = []
    
    diff_output.each_line do |line|
      line = line.strip
      next if line.empty?
      
      if line.start_with?('D')
        deletions << line
      else
        other_changes << line
      end
    end

    # Show summary
    log_info("📊 Changes Summary:")
    puts "  Total staged: #{deletions.length + other_changes.length}"
    puts "  Deletions (D): #{deletions.length}"
    puts "  Other changes: #{other_changes.length}"

    if deletions.empty?
      log_warning("No deletions (D) found in staged changes")
      if other_changes.any?
        log_info("Sample of other changes (up to 5):")
        other_changes.sample([5, other_changes.length].min).each { |change| puts "  #{change}" }
      end
      return
    end

    log_success("Found #{deletions.length} deletion(s):")
    sample_deletions = deletions.sample([5, deletions.length].min)
    sample_deletions.each { |deletion| puts "  #{deletion}" }
    if deletions.length > 5
      puts "  ... and #{deletions.length - 5} more"
    end

    if other_changes.any?
      log_warning("Found #{other_changes.length} non-deletion change(s) that will NOT be committed:")
      sample_others = other_changes.sample([5, other_changes.length].min)
      sample_others.each { |change| puts "  #{change}" }
      if other_changes.length > 5
        puts "  ... and #{other_changes.length - 5} more"
      end
    end

    # Get commit message
    commit_message = @options[:message]
    
    if commit_message.nil? || commit_message.strip.empty?
      # Prompt for commit message
      print "\n💬 Enter commit message for the deletions: "
      commit_message = STDIN.gets.chomp.strip

      if commit_message.empty?
        log_error("Commit message cannot be empty")
        exit 1
      end
    else
      log_info("Using provided commit message: #{commit_message}")
    end

    # Reset and stage only the deletions
    log_info("Resetting staged changes...")
    system('git reset')

    log_info("Staging only deletions...")
    deletions.each do |deletion|
      # Parse the deletion line: D filename
      parts = deletion.split("\t")
      deleted_file = parts[1]
      
      # Stage the deletion
      system("git add '#{deleted_file}'")
    end

    # Commit the deletions
    log_progress("Committing deletions...")
    if system("git commit -m '#{commit_message}'")
      log_success("Successfully committed #{deletions.length} deletion(s)")
      
      # Show final status
      log_info("Final repository status:")
      system('git status --short')
    else
      log_error("Failed to commit changes")
      exit 1
    end

    show_completion("Git Commit Deletes")
  end
end

# Execute the script
GitCommitDeletes.execute if __FILE__ == $0