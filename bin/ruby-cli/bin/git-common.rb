#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../.common/script_base'

class GitCommon < ScriptBase
  def script_emoji; '🔗'; end
  def script_title; 'Git Common Files'; end
  def script_description; 'Show files that exist in both git commits'; end
  def script_arguments; '[OPTIONS] <commit1> <commit2>'; end

  def initialize
    super
    @commit1 = nil
    @commit2 = nil
    @show_details = false
    @format = 'list' # list, count, paths
  end

  def add_custom_options(opts)
    opts.on('-d', '--details', 'Show detailed file information') do
      @show_details = true
    end
    opts.on('-c', '--count', 'Show only the count of common files') do
      @format = 'count'
    end
    opts.on('-p', '--paths', 'Show only file paths (no formatting)') do
      @format = 'paths'
    end
  end

  def validate!
    super

    log_debug "Original working dir: #{original_working_dir}"
    log_debug "Current working dir: #{Dir.pwd}"

    unless in_git_repository?
      log_error "Not in a git repository"
      show_help
      exit 1
    end

    if args.length < 2
      log_error "Two commit references are required"
      show_help
      exit 1
    end

    @commit1 = args[0]
    @commit2 = args[1]

    log_debug "Checking commit: #{@commit1}"
    log_debug "Git command: git rev-parse --verify #{@commit1}"

    unless commit_exists?(@commit1)
      log_error "Commit '#{@commit1}' does not exist"
      exit 1
    end

    unless commit_exists?(@commit2)
      log_error "Commit '#{@commit2}' does not exist"
      exit 1
    end
  end

  def run
    log_banner("Git Common Files Analysis")

    log_info "Comparing commits:"
    log_info "  Commit 1: #{@commit1} (#{get_commit_info(@commit1)})"
    log_info "  Commit 2: #{@commit2} (#{get_commit_info(@commit2)})"
    log_section "Analysis"

    files1 = get_files_in_commit(@commit1)
    files2 = get_files_in_commit(@commit2)

    common_files = files1 & files2

    log_info "Files in #{@commit1}: #{files1.length}"
    log_info "Files in #{@commit2}: #{files2.length}"
    log_success "Common files: #{common_files.length}"

    case @format
    when 'count'
      puts common_files.length
      show_completion("Git Common Files Analysis")
      return
    when 'paths'
      common_files.each { |file| puts file }
      show_completion("Git Common Files Analysis")
      return
    else
      display_files(common_files, files1, files2)
    end

    show_completion("Git Common Files Analysis")
  end

  private

  def in_git_repository?
    Dir.chdir(original_working_dir) do
      system('git rev-parse --git-dir > /dev/null 2>&1')
    end
  end

  def commit_exists?(commit)
    Dir.chdir(original_working_dir) do
      system("git rev-parse --verify #{commit} > /dev/null 2>&1")
    end
  end

  def get_commit_info(commit)
    Dir.chdir(original_working_dir) do
      `git log -1 --format='%h - %s' #{commit}`.strip
    end
  end

  def get_files_in_commit(commit)
    files = []
    Dir.chdir(original_working_dir) do
      `git ls-tree -r --name-only #{commit}`.each_line do |line|
        file = line.strip
        files << file unless file.empty?
      end
    end
    files.sort
  end

  def display_files(common_files, files1, files2)
    return if common_files.empty?

    log_section "Common Files"

    if @show_details
      common_files.each do |file|
        status1 = get_file_status(commit: @commit1, file: file)
        status2 = get_file_status(commit: @commit2, file: file)

        puts "#{file}"
        puts "  #{@commit1}: #{status1}"
        puts "  #{@commit2}: #{status2}"
        puts
      end
    else
      common_files.each { |file| puts file }
    end

    # Show additional statistics
    log_section "Statistics"

    only_in_commit1 = files1 - common_files
    only_in_commit2 = files2 - common_files

    log_info "Only in #{@commit1}: #{only_in_commit1.length} files"
    log_info "Only in #{@commit2}: #{only_in_commit2.length} files"
    log_success "Common: #{common_files.length} files"

    if only_in_commit1.length > 0 || only_in_commit2.length > 0
      log_info "Total unique files across both commits: #{files1.length + files2.length - common_files.length}"
    end
  end

  def get_file_status(commit:, file:)
    Dir.chdir(original_working_dir) do
      type_output = `git ls-tree #{commit} #{file} 2>/dev/null | head -1`.strip
      return "Not found" if type_output.empty?

      type = type_output.split(/\s+/)[1]
      case type
      when '100644'
        'Regular file'
      when '100755'
        'Executable'
      when '120000'
        'Symlink'
      when '040000'
        'Directory'
      else
        "Unknown (#{type})"
      end
    end
  rescue
    'Error getting status'
  end
end

GitCommon.execute if __FILE__ == $0