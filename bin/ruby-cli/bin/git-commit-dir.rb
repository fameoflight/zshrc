#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/archive/script_base'

class GitCommitDir < ScriptBase
  def add_custom_options(opts)
    opts.on('-m', '--message MESSAGE', 'Commit message (skip interactive prompt)') do |message|
      @options[:message] = message
    end
  end

  def banner_text
    <<~BANNER
      📁 Git Commit Directory

      Usage: #{script_name} <directory> [OPTIONS]

      Stage and commit changes in a specific directory.

      Arguments:
        directory                Directory to stage and commit changes from

      Options:
        -m, --message MESSAGE  Commit message (skip interactive prompt)
    BANNER
  end

  def validate!
    if args.length < 1
      log_error('Directory argument is required')
      log_info("Usage: #{script_name} <directory> [OPTIONS]")
      exit 1
    end

    directory = args[0]

    unless Dir.exist?(directory)
      log_error("Directory '#{directory}' does not exist")
      exit 1
    end

    unless system('git rev-parse --git-dir >/dev/null 2>&1')
      log_error('Not in a git repository')
      exit 1
    end

    super
  end

  def run
    directory = args[0]
    commit_message = @options[:message] || "Update #{directory}"

    log_banner("Git Commit Directory - #{directory}")

    log_info("Checking for changes in directory: #{directory}")

    # Check if there are any changes in the specified directory
    changes_in_dir = `git status --porcelain "#{directory}" 2>/dev/null`.strip

    if changes_in_dir.empty?
      log_warning("No changes found in directory: #{directory}")
      exit 0
    end

    puts ""
    puts "Changes to be committed in '#{directory}':"
    puts changes_in_dir
    puts ""

    # Get commit message if not provided
    if commit_message.nil? || commit_message.strip.empty?
      print "\n💬 Enter commit message for changes in '#{directory}': "
      commit_message = STDIN.gets.chomp.strip

      if commit_message.empty?
        log_error('Commit message cannot be empty')
        exit 1
      end
    else
      log_info("Using provided commit message: #{commit_message}")
    end

    # Confirm before staging
    if confirm_action("Stage and commit these changes?")
      log_info("Staging changes in directory: #{directory}")
      unless system("git add \"#{directory}\"")
        log_error('Failed to stage changes')
        exit 1
      end

      log_info("Committing changes with message: #{commit_message}")
      commit_command = "git commit -m \"#{commit_message}\""
      if force?
        commit_command += ' --no-verify'
        log_info('Force flag detected, skipping pre-commit hooks with --no-verify.')
      end

      if system(commit_command)
        show_completion("Changes in '#{directory}' committed successfully!")
      else
        log_error('Failed to commit changes')
        exit 1
      end
    else
      log_info("Skipping commit for directory: #{directory}")
    end
  end
end

GitCommitDir.execute if __FILE__ == $0
