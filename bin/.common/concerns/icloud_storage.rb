#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'pathname'
require_relative '../logger'

# iCloud Storage concern following Rails pattern
# Provides iCloud Drive storage capabilities to any class that includes it
module ICloudStorage
  extend self

  # Default iCloud Drive path on macOS
  ICLOUD_ROOT = File.expand_path('~/Library/Mobile Documents/com~apple~CloudDocs').freeze

  # Check if iCloud Drive is available and accessible
  def icloud_available?
    Dir.exist?(ICLOUD_ROOT) && File.writable?(ICLOUD_ROOT)
  end

  # Get the full path to an application storage directory
  def icloud_app_path(app_name)
    File.join(ICLOUD_ROOT, app_name)
  end

  # Ensure an application storage directory exists
  def ensure_icloud_app_storage!(app_name)
    storage_path = icloud_app_path(app_name)
    return storage_path if Dir.exist?(storage_path)

    log_info("Creating #{app_name} storage directory in iCloud")
    FileUtils.mkdir_p(storage_path)
    log_success("Created #{storage_path}")
    storage_path
  end

  # Get path for a specific item directory within an app
  def icloud_item_directory(app_name, item_identifier)
    sanitized_name = sanitize_filename(item_identifier)
    File.join(ensure_icloud_app_storage!(app_name), sanitized_name)
  end

  # Ensure an item directory exists
  def ensure_icloud_item_directory!(app_name, item_identifier)
    item_dir = icloud_item_directory(app_name, item_identifier)
    return item_dir if Dir.exist?(item_dir)

    log_info("Creating directory for #{app_name} item: #{item_identifier}")
    FileUtils.mkdir_p(item_dir)
    log_success("Created #{item_dir}")
    item_dir
  end

  # Get metadata file path for an item
  def icloud_metadata_path(app_name, item_identifier, metadata_filename = '.metadata.json')
    File.join(ensure_icloud_item_directory!(app_name, item_identifier), metadata_filename)
  end

  # Load metadata for an item
  def load_icloud_metadata(app_name, item_identifier, metadata_filename = '.metadata.json')
    metadata_file = icloud_metadata_path(app_name, item_identifier, metadata_filename)
    return {} unless File.exist?(metadata_file)

    begin
      JSON.parse(File.read(metadata_file))
    rescue JSON::ParserError => e
      log_warning("Invalid JSON in metadata file: #{e.message}")
      {}
    end
  end

  # Save metadata for an item
  def save_icloud_metadata(app_name, item_identifier, metadata, metadata_filename = '.metadata.json')
    metadata_file = icloud_metadata_path(app_name, item_identifier, metadata_filename)
    log_debug("Saving metadata to #{metadata_file}")

    File.write(metadata_file, JSON.pretty_generate(metadata))
    log_success("Metadata saved")
  end

  # Get path for a specific file within an item directory
  def icloud_item_file_path(app_name, item_identifier, filename)
    File.join(ensure_icloud_item_directory!(app_name, item_identifier), filename)
  end

  # Check if a file exists for an item
  def icloud_item_file_exists?(app_name, item_identifier, filename)
    File.exist?(icloud_item_file_path(app_name, item_identifier, filename))
  end

  # Get backup path for a file
  def icloud_backup_path(app_name, item_identifier, filename)
    original_file = icloud_item_file_path(app_name, item_identifier, filename)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    "#{original_file}.backup_#{timestamp}"
  end

  # Create backup of existing file
  def backup_icloud_file(app_name, item_identifier, filename)
    return false unless icloud_item_file_exists?(app_name, item_identifier, filename)

    source = icloud_item_file_path(app_name, item_identifier, filename)
    backup = icloud_backup_path(app_name, item_identifier, filename)

    log_info("Backing up existing file: #{filename}")
    FileUtils.cp(source, backup)
    log_success("Backup created: #{File.basename(backup)}")
    backup
  end

  # List all items for an application
  def list_icloud_app_items(app_name)
    storage_path = icloud_app_path(app_name)
    return [] unless Dir.exist?(storage_path)

    Dir.children(storage_path)
       .select { |item| Dir.exist?(File.join(storage_path, item)) }
       .map { |dir| unsanitize_filename(dir) }
  end

  # Clean up old backups (keep last N)
  def cleanup_icloud_backups(app_name, item_identifier, filename_pattern = '*.backup_*', keep_count = 5)
    item_dir = icloud_item_directory(app_name, item_identifier)
    return unless Dir.exist?(item_dir)

    backup_pattern = File.join(item_dir, filename_pattern)
    backups = Dir.glob(backup_pattern).sort

    return if backups.size <= keep_count

    to_remove = backups[0...-keep_count]
    to_remove.each do |backup|
      log_info("Removing old backup: #{File.basename(backup)}")
      File.delete(backup)
    end

    log_success("Cleaned up #{to_remove.size} old backups")
  end

  # Get iCloud sync status for a file
  def icloud_sync_status(file_path)
    return :not_in_icloud unless file_path.start_with?(ICLOUD_ROOT)

    # Check for iCloud status indicators in extended attributes
    # Note: This is a simplified check - actual iCloud status is more complex
    if File.exist?(file_path)
      :synced
    elsif File.exist?("#{file_path}.icloud")
      :not_downloaded
    else
      :unknown
    end
  end

  # Wait for iCloud sync to complete (basic implementation)
  def wait_for_icloud_sync(file_path, timeout: 30)
    return true unless file_path.start_with?(ICLOUD_ROOT)

    start_time = Time.now
    while Time.now - start_time < timeout
      status = icloud_sync_status(file_path)
      return true if status == :synced

      sleep(1)
    end

    log_warning("iCloud sync timeout for #{File.basename(file_path)}")
    false
  end

  private

  # Sanitize filename for filesystem safety
  def sanitize_filename(name)
    name.gsub(/[^\w\-_.]/, '_')
        .gsub(/_+/, '_')
        .gsub(/^_|_$/, '')
  end

  # Reverse filename sanitization (best effort)
  def unsanitize_filename(name)
    name.gsub('_', ' ')
  end
end