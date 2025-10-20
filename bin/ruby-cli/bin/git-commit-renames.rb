#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../.common/git_commit_script_base'

# Commits only pure renames (R100) after user confirmation
class GitCommitRenames < GitCommitScriptBase
  def banner_text
    <<~BANNER
      🔄 Git Commit Pure Renames

      Usage: #{script_name} [OPTIONS]

      This script commits only pure file renames (R100 status).

      Options:
        -m, --message MESSAGE  Commit message (skip interactive prompt)
    BANNER
  end

  private

  def change_type_name
    'pure rename'
  end

  def plural_change_type_name
    'pure renames'
  end

  def filter_changes(diff_output)
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

    [pure_renames, other_changes]
  end

  def stage_filtered_changes(renames)
    renames.each do |rename|
      # Parse the rename line: R100\told_file\tnew_file
      parts = rename.split("\t")
      old_file = parts[1]
      new_file = parts[2]
      system("git add '#{old_file}' '#{new_file}'")
    end
  end
end

# Execute the script
GitCommitRenames.execute if __FILE__ == $0
