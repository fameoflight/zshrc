#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Commits only pure renames (R100) after user confirmation
class GitCommitRenames < ScriptBase
  def banner_text
    <<~BANNER
      🔄 Git Commit Pure Renames

      Usage: #{script_name} [OPTIONS]

      This script will:
      1. Stage all changes with 'git add .'
      2. Show the diff status
      3. Filter for pure renames (R100) only
      4. Prompt for commit message (or use -m flag)
      5. Commit only the pure renames

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
    log_banner("Git Commit Pure Renames")

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

    # Filter for pure renames (R100)
    pure_renames = []
    other_changes = []
    
    diff_output.each_line do |line|
      line = line.strip
      next if line.empty?
      
      if line.start_with?('R100')
        pure_renames << line
      else
        other_changes << line
      end
    end

    # Show summary
    log_info("📊 Changes Summary:")
    puts "  Total staged: #{pure_renames.length + other_changes.length}"
    puts "  Pure renames (R100): #{pure_renames.length}"
    puts "  Other changes: #{other_changes.length}"

    if pure_renames.empty?
      log_warning("No pure renames (R100) found in staged changes")
      if other_changes.any?
        log_info("Sample of other changes (up to 5):")
        other_changes.sample([5, other_changes.length].min).each { |change| puts "  #{change}" }
      end
      return
    end

    log_success("Found #{pure_renames.length} pure rename(s):")
    sample_renames = pure_renames.sample([5, pure_renames.length].min)
    sample_renames.each { |rename| puts "  #{rename}" }
    if pure_renames.length > 5
      puts "  ... and #{pure_renames.length - 5} more"
    end

    if other_changes.any?
      log_warning("Found #{other_changes.length} non-rename change(s) that will NOT be committed:")
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
      print "\n💬 Enter commit message for the pure renames: "
      commit_message = STDIN.gets.chomp.strip

      if commit_message.empty?
        log_error("Commit message cannot be empty")
        exit 1
      end
    else
      log_info("Using provided commit message: #{commit_message}")
    end

    # Reset and stage only the pure renames
    log_info("Resetting staged changes...")
    system('git reset')

    log_info("Staging only pure renames...")
    pure_renames.each do |rename|
      # Parse the rename line: R100 old_file new_file
      parts = rename.split("\t")
      old_file = parts[1]
      new_file = parts[2]
      
      # Stage the rename
      system("git add '#{old_file}' '#{new_file}'")
    end

    # Commit the pure renames
    log_progress("Committing pure renames...")
    if system("git commit -m '#{commit_message}'")
      log_success("Successfully committed #{pure_renames.length} pure rename(s)")
      
      # Show final status
      log_info("Final repository status:")
      system('git status --short')
    else
      log_error("Failed to commit changes")
      exit 1
    end

    show_completion("Git Commit Pure Renames")
  end
end

# Execute the script
GitCommitRenames.execute if __FILE__ == $0