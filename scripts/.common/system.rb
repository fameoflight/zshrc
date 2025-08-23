# frozen_string_literal: true

require 'open3'
require 'tty-which'
require 'tty-prompt'
require_relative 'logger'

# System utilities for ZSH configuration scripts
module System
  # Execute shell commands with proper error handling
  def self.execute(command, description: nil, dry_run: false, verbose: false)
    log_progress(description) if description
    log_debug("Executing: #{command}") if verbose

    return log_info("[DRY-RUN] Would execute: #{command}") if dry_run

    stdout, stderr, status = Open3.capture3(command)

    if status.success?
      log_debug("Command succeeded: #{command}") if verbose && !stdout.empty?
      stdout.strip
    else
      log_warning("Command failed: #{command}")
      log_debug("Error: #{stderr}") if verbose && !stderr.empty?
      nil
    end
  end

  # Execute command and return true/false for success
  def self.execute?(command, description: nil, dry_run: false, verbose: false)
    !execute(command, description: description, dry_run: dry_run, verbose: verbose).nil?
  end

  # Check if command exists in PATH
  def self.command?(command)
    TTY::Which.exist?(command)
  end

  # Kill processes by name
  def self.kill_processes(name, signal: 'TERM', verbose: false)
    pids = `pgrep -i "#{name}"`.split.map(&:to_i)
    return log_info("No running processes found for '#{name}'") if pids.empty?

    log_warning("Found #{pids.length} running process(es) for '#{name}'")
    pids.each { |pid| log_debug("PID: #{pid}") } if verbose

    return unless confirm_action("Kill running processes for '#{name}'?")

    pids.each do |pid|
      log_progress("Terminating process #{pid}")
      system("kill -#{signal} #{pid}")
      sleep 1

      # Force kill if still running
      if system("kill -0 #{pid} 2>/dev/null")
        log_progress("Force killing process #{pid}")
        system("kill -KILL #{pid}")
      end
    end

    log_success("Stopped running processes")
  end

  # Find files matching pattern
  def self.find_files(directories, pattern, type: nil)
    found_files = []
    
    Array(directories).each do |dir|
      next unless Dir.exist?(dir)
      
      Dir.chdir(dir) do
        cmd = "find . -maxdepth 2 -iname '*#{pattern}*'"
        cmd += " -type #{type}" if type
        cmd += " 2>/dev/null"
        
        files = `#{cmd}`.split("\n").map { |f| File.join(dir, f.sub('./', '')) }
        found_files.concat(files)
      end
    end
    
    found_files.sort
  end

  # Check if running as administrator
  def self.admin?
    Process.uid == 0
  end

  # Get current user
  def self.current_user
    ENV['USER'] || ENV['USERNAME'] || `whoami`.strip
  end

  # Get home directory
  def self.home_dir
    ENV['HOME'] || Dir.home
  end

  # Platform detection
  def self.macos?
    RUBY_PLATFORM.include?('darwin')
  end

  def self.linux?
    RUBY_PLATFORM.include?('linux')
  end

  # Homebrew utilities
  module Homebrew
    def self.installed?
      System.command?('brew')
    end

    def self.list_formulae
      return [] unless installed?
      `brew list --formula 2>/dev/null`.split
    end

    def self.list_casks
      return [] unless installed?
      `brew list --cask 2>/dev/null`.split
    end

    def self.running_services
      return [] unless installed?
      services = `brew services list 2>/dev/null`.split("\n")[1..-1] # Skip header
      services&.map { |line| line.split.first } || []
    end

    def self.stop_service(service)
      return false unless installed?
      System.execute("brew services stop '#{service}'", description: "Stopping service: #{service}")
    end

    def self.uninstall_formula(formula)
      return false unless installed?
      System.execute("brew uninstall '#{formula}'", description: "Removing Homebrew formula: #{formula}")
    end

    def self.uninstall_cask(cask)
      return false unless installed?
      System.execute("brew uninstall --cask '#{cask}'", description: "Removing Homebrew cask: #{cask}")
    end
  end

  # Mac App Store utilities
  module MacAppStore
    def self.installed?
      System.command?('mas')
    end

    def self.list_installed
      return [] unless installed?
      apps = `mas list 2>/dev/null`.split("\n")
      apps.map do |line|
        parts = line.split(' ', 2)
        { id: parts[0], name: parts[1] }
      end
    end

    def self.uninstall(app_id)
      return false unless installed?
      System.execute("mas uninstall '#{app_id}'", description: "Removing Mac App Store app: #{app_id}")
    end
  end
end

# Interactive prompts
def confirm_action(message, force: false)
  return true if force
  return true if ENV['FORCE'] == '1'

  require 'tty-prompt'
  prompt = TTY::Prompt.new
  prompt.yes?(message)
end

def prompt_select(message, choices)
  require 'tty-prompt'
  prompt = TTY::Prompt.new
  prompt.select(message, choices)
end

def prompt_multiselect(message, choices)
  require 'tty-prompt'
  prompt = TTY::Prompt.new
  prompt.multi_select(message, choices)
end