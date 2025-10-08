#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/git_commit_script_base'

# Commits only deletions (D status) after user confirmation
class GitCommitDeletes < GitCommitScriptBase
  def banner_text
    <<~BANNER
      🗑️  Git Commit Deletes

      Usage: #{script_name} [OPTIONS]

      This script commits only file deletions (D status).

      Options:
        -m, --message MESSAGE  Commit message (skip interactive prompt)
    BANNER
  end

  private

  def change_type_name
    'deletion'
  end

  def filter_changes(diff_output)
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

    [deletions, other_changes]
  end

  def stage_filtered_changes(deletions)
    deletions.each do |deletion|
      # Parse the deletion line: D	filename
      deleted_file = deletion.split("\t")[1]
      system("git add '#{deleted_file}'")
    end
  end
end

# Execute the script
GitCommitDeletes.execute if __FILE__ == $0
