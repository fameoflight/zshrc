#!/usr/bin/env ruby
# frozen_string_literal: true

require 'set'
require_relative '../lib/archive/script_base'

# Description: Finds and displays orphaned Makefile targets.
class FindOrphanedTargets < ScriptBase
  def banner_text
    <<~BANNER
      🔧 Find Orphaned Makefile Targets

      Usage: #{script_name} [OPTIONS]
    BANNER
  end

  def run
    log_banner("Find Orphaned Makefile Targets")

    log_info("Starting analysis...")

    makefile_path = "Makefile"

    unless File.exist?(makefile_path)
      log_error("Makefile not found in current directory")
      exit 1
    end

    # Parse Makefile to find all targets and their dependencies
    targets = {}
    referenced_targets = Set.new

    File.readlines(makefile_path).each_with_index do |line, index|
      line_num = index + 1
      original_line = line
      line = line.strip

      # Skip comments and empty lines
      next if line.empty? || line.start_with?('#')

      # Find target definitions (lines that start at column 1 and contain :)
      # Must start at beginning of line (no leading whitespace)
      if original_line.match(/^([^\s][^:]*):(.*)$/) && !original_line.start_with?("\t") && !original_line.start_with?(" ")
        target_name = $1.strip
        dependencies = $2.strip

        # Skip if it's a variable assignment (contains =)
        next if target_name.include?('=') || dependencies.start_with?('=')

        # Skip if target name contains spaces (likely not a real target)
        next if target_name.include?(' ')

        # Skip special targets
        next if target_name.start_with?('.')

        # Skip if target name looks like a command or contains shell operators
        next if target_name.include?('$') || target_name.include?('(') || target_name.include?('|') || target_name.include?('&')

        targets[target_name] = {
          line_number: line_num,
          dependencies: dependencies.split.reject { |dep| dep.start_with?('$') || dep.include?('(') }
        }

        # Track referenced targets from dependencies
        dependencies.split.each do |dep|
          clean_dep = dep.strip
          next if clean_dep.empty? || clean_dep.start_with?('$') || clean_dep.include?('(') || clean_dep.include?('|')

          referenced_targets.add(clean_dep)
        end
      end
    end

    # Find orphaned targets (targets that are never referenced as dependencies)
    orphaned_targets = targets.keys - referenced_targets.to_a

    # Remove common entry points that are typically not referenced
    entry_points = %w[all install help clean default setup update mac linux doctor find-orphans]
    orphaned_targets = orphaned_targets.reject { |target| entry_points.include?(target) }

    if orphaned_targets.empty?
      log_success("No orphaned targets found! All targets are properly referenced.")
    else
      log_warning("Found #{orphaned_targets.size} potentially orphaned target(s):")
      puts

      orphaned_targets.sort.each do |target|
        target_info = targets[target]
        puts "  #{target} (line #{target_info[:line_number]})"

        unless target_info[:dependencies].empty?
          puts "    Dependencies: #{target_info[:dependencies].join(', ')}"
        end
      end

      puts
      log_info("Note: Entry points like 'all', 'install', 'help', etc. are excluded from orphan detection")
    end

    show_completion("Analysis complete")
  end
end

# Execute the script
FindOrphanedTargets.execute if __FILE__ == $0
