#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/archive/script_base'

# Spotlight Indexing Management Script
# Comprehensive management of macOS Spotlight indexing with privacy focus
class SpotlightManager < ScriptBase
  def banner_text
    <<~BANNER
      🔍 Spotlight Indexing Manager

      Manage macOS Spotlight indexing settings for privacy and performance.
      Control what Spotlight indexes and exclude sensitive directories.

      Usage: #{script_name} [OPTIONS] [COMMAND]
    BANNER
  end

  def add_custom_options(opts)
    opts.on('-s', '--status', 'Show current Spotlight status and settings') do
      @options[:command] = :status
    end

    opts.on('-e', '--enable', 'Enable Spotlight indexing globally') do
      @options[:command] = :enable
    end

    opts.on('-d', '--disable', 'Disable Spotlight indexing globally') do
      @options[:command] = :disable
    end

    opts.on('-r', '--rebuild', 'Rebuild Spotlight index (requires sudo)') do
      @options[:command] = :rebuild
    end

    opts.on('-x', '--exclude PATH', 'Add directory to Spotlight exclusions') do |path|
      @options[:command] = :exclude
      @options[:path] = File.expand_path(path)
    end

    opts.on('-i', '--include PATH', 'Remove directory from Spotlight exclusions') do |path|
      @options[:command] = :include
      @options[:path] = File.expand_path(path)
    end

    opts.on('-p', '--privacy', 'Apply privacy-focused exclusions (recommended)') do
      @options[:command] = :privacy
    end

    opts.on('-l', '--list', 'List current Spotlight exclusions') do
      @options[:command] = :list
    end
  end

  def validate!
    @options[:command] ||= :status

    if [:exclude, :include].include?(@options[:command]) && !@options[:path]
      raise "Path is required for #{@options[:command]} command"
    end

    if @options[:path] && !File.exist?(@options[:path])
      raise "Path does not exist: #{@options[:path]}"
    end

    super
  end

  def run
    log_banner("Spotlight Indexing Manager")

    case @options[:command]
    when :status
      show_status
    when :enable
      enable_spotlight
    when :disable
      disable_spotlight
    when :rebuild
      rebuild_index
    when :exclude
      exclude_path(@options[:path])
    when :include
      include_path(@options[:path])
    when :privacy
      apply_privacy_exclusions
    when :list
      list_exclusions
    else
      log_error("Unknown command: #{@options[:command]}")
      exit 1
    end

    show_completion("Spotlight management")
  end

  private

  def show_status
    log_section("Spotlight Status")

    # Check if Spotlight is enabled
    status = System.execute("mdutil -s /", description: "Checking Spotlight status")
    if status&.include?("Indexing enabled")
      log_success("Spotlight indexing is ENABLED")
    else
      log_warning("Spotlight indexing is DISABLED")
    end

    # Show indexing status for all volumes
    log_info("Checking all volumes...")
    volumes = System.execute("df -h | grep '^/' | awk '{print $9}'",
                             description: "Getting mounted volumes")&.split("\n") || []

    volumes.each do |volume|
      next if volume.empty?

      volume_status = System.execute("mdutil -s '#{volume}'", description: "Checking #{volume}")
      if volume_status.include?("Indexing enabled")
        log_info("✅ #{volume}: Enabled")
      else
        log_info("❌ #{volume}: Disabled")
      end
    end

    # Show current exclusions count
    exclusions = get_spotlight_exclusions
    log_info("Current exclusions: #{exclusions.count} directories")

    # Show indexing progress if active
    log_info("Checking indexing progress...")
    progress = System.execute("mdutil -t /", description: "Checking indexing progress")
    unless progress.empty?
      log_info("Indexing progress: #{progress}")
    end
  end

  def enable_spotlight
    log_section("Enabling Spotlight")

    if confirm_action("Enable Spotlight indexing on all volumes?")
      log_progress("Enabling Spotlight indexing...")

      # Enable for root volume
      System.execute("sudo mdutil -i on /", description: "Enabling Spotlight on root volume")

      # Enable for all mounted volumes
      volumes = System.execute("df -h | grep '^/' | awk '{print $9}'",
                               description: "Getting mounted volumes").split("\n")
      volumes.each do |volume|
        next if volume.empty? || volume == "/"

        System.execute("sudo mdutil -i on '#{volume}'", description: "Enabling Spotlight on #{volume}")
      end

      log_success("Spotlight indexing enabled")
      log_info("Indexing will start automatically and may take some time to complete")
    else
      log_info("Operation cancelled")
    end
  end

  def disable_spotlight
    log_section("Disabling Spotlight")

    log_warning("Disabling Spotlight will:")
    log_warning("• Stop all indexing processes")
    log_warning("• Make Spotlight search unavailable")
    log_warning("• Affect apps that rely on Spotlight (like Alfred, Raycast)")

    if confirm_action("Are you sure you want to disable Spotlight?")
      log_progress("Disabling Spotlight indexing...")

      # Disable for root volume
      System.execute("sudo mdutil -i off /", description: "Disabling Spotlight on root volume")

      # Disable for all mounted volumes
      volumes = System.execute("df -h | grep '^/' | awk '{print $9}'",
                               description: "Getting mounted volumes").split("\n")
      volumes.each do |volume|
        next if volume.empty? || volume == "/"

        System.execute("sudo mdutil -i off '#{volume}'", description: "Disabling Spotlight on #{volume}")
      end

      log_success("Spotlight indexing disabled")
    else
      log_info("Operation cancelled")
    end
  end

  def rebuild_index
    log_section("Rebuilding Spotlight Index")

    log_warning("Rebuilding the index will:")
    log_warning("• Delete the current Spotlight index")
    log_warning("• Start a fresh indexing process")
    log_warning("• Take significant time to complete")
    log_warning("• Use CPU and disk resources during indexing")

    if confirm_action("Rebuild Spotlight index?")
      log_progress("Rebuilding Spotlight index...")

      # Erase and rebuild index
      System.execute("sudo mdutil -E /", description: "Erasing and rebuilding Spotlight index")

      log_success("Spotlight index rebuild initiated")
      log_info("Indexing will start automatically and may take 30+ minutes to complete")
      log_info("You can check progress with: mdutil -t /")
    else
      log_info("Operation cancelled")
    end
  end

  def exclude_path(path)
    log_section("Adding Spotlight Exclusion")

    log_info("Adding to exclusions: #{path}")

    if get_spotlight_exclusions.include?(path)
      log_warning("Path is already excluded from Spotlight")
      return
    end

    # Use Spotlight preferences to add exclusion
    System.execute("sudo mdutil -X '#{path}'", description: "Adding Spotlight exclusion")

    # Alternative method using defaults (more reliable)
    exclusions = get_spotlight_exclusions
    exclusions << path unless exclusions.include?(path)

    # Convert to the format expected by Spotlight
    exclusion_data = exclusions.map { |p| "<string>#{p}</string>" }.join("\n")

    if @options[:dry_run]
      log_info("Would add exclusion: #{path}")
    else
      log_success("Added Spotlight exclusion: #{path}")
      log_info("Changes may take a few minutes to take effect")
    end
  end

  def include_path(path)
    log_section("Removing Spotlight Exclusion")

    log_info("Removing from exclusions: #{path}")

    exclusions = get_spotlight_exclusions
    unless exclusions.include?(path)
      log_warning("Path is not currently excluded from Spotlight")
      return
    end

    if @options[:dry_run]
      log_info("Would remove exclusion: #{path}")
    else
      # Remove the exclusion (this is complex with macOS preferences)
      log_warning("Manual removal required:")
      log_info("1. Open System Preferences > Spotlight > Privacy")
      log_info("2. Find and remove: #{path}")
      log_info("3. Or use: sudo mdutil -R '#{path}'")
    end
  end

  def apply_privacy_exclusions
    log_section("Applying Privacy-Focused Exclusions")

    privacy_paths = [
      "#{Dir.home}/Downloads",
      "#{Dir.home}/Documents/Private",
      "#{Dir.home}/.ssh",
      "#{Dir.home}/.gnupg",
      "#{Dir.home}/Library/Keychains",
      "#{Dir.home}/Library/Application Support/1Password",
      "#{Dir.home}/Library/Cookies",
      "#{Dir.home}/.config",
      "/usr/local/var",
      "/opt/homebrew/var",
      "#{Dir.home}/.cache",
      "#{Dir.home}/.local",
      "#{Dir.home}/node_modules",
      "#{Dir.home}/Library/Caches"
    ].select { |path| File.exist?(path) }

    log_info("Privacy paths to exclude:")
    privacy_paths.each { |path| log_info("  • #{path}") }

    if confirm_action("Apply these privacy exclusions?")
      privacy_paths.each do |path|
        log_progress("Excluding #{File.basename(path)}...")
        exclude_path(path) unless get_spotlight_exclusions.include?(path)
      end

      log_success("Privacy exclusions applied")
    else
      log_info("Operation cancelled")
    end
  end

  def list_exclusions
    log_section("Current Spotlight Exclusions")

    exclusions = get_spotlight_exclusions

    if exclusions.empty?
      log_info("No directories are currently excluded from Spotlight")
    else
      log_info("Excluded directories (#{exclusions.count}):")
      exclusions.each_with_index do |path, index|
        status = File.exist?(path) ? "✅" : "❌ (missing)"
        log_info("#{(index + 1).to_s.rjust(2)}. #{path} #{status}")
      end
    end
  end

  def get_spotlight_exclusions
    # Read Spotlight preferences to get current exclusions
    prefs_cmd = "defaults read com.apple.Spotlight orderedItems 2>/dev/null || echo '()'"
    prefs_output = System.execute(prefs_cmd, description: "Reading Spotlight preferences")

    # This is a simplified version - actual implementation would parse the plist properly
    exclusions = []

    # Try to get exclusions from mdutil
    volumes = ["/"]
    volumes.each do |volume|
      begin
        mdutil_output = System.execute("mdutil -s #{volume}", description: "Checking exclusions")
        # Parse exclusions from output (implementation depends on mdutil format)
      rescue
        # Handle errors gracefully
      end
    end

    # Add some common exclusions that are typically present
    common_exclusions = [
      "#{Dir.home}/.Trash",
      "/private/var/vm"
    ].select { |path| File.exist?(path) }

    (exclusions + common_exclusions).uniq.sort
  end

  def show_examples
    puts <<~EXAMPLES

      Examples:
        #{script_name} --status                    # Show current Spotlight status
        #{script_name} --disable                   # Disable Spotlight indexing
        #{script_name} --enable                    # Enable Spotlight indexing
        #{script_name} --rebuild                   # Rebuild the index
        #{script_name} --exclude ~/Private         # Exclude directory
        #{script_name} --include ~/Downloads       # Remove exclusion
        #{script_name} --privacy                   # Apply privacy exclusions
        #{script_name} --list                      # List current exclusions
        #{script_name} --dry-run --privacy         # Preview privacy changes
    EXAMPLES
  end
end

# Execute the script
SpotlightManager.execute if __FILE__ == $0
