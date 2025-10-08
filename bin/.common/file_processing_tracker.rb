# frozen_string_literal: true

require_relative 'database'
require 'digest'

# Try to require tty-progressbar, but don't fail if it's not available
begin
  require 'tty-progressbar'
rescue LoadError
  # Gem not available, will handle gracefully
end

# Track file processing operations to avoid redundant work
class FileProcessingTracker
  attr_reader :database

  def initialize(db_path = nil)
    # Default database path in ZSH config directory
    zsh_config = ENV['ZSH_CONFIG'] || File.expand_path('~/.config/zsh')
    db_path ||= File.join(zsh_config, 'file_processing.sqlite.db')

    @database = Database.new(db_path)
    setup_database
  end

  # Check if file needs processing for a specific operation
  def needs_processing?(file_path, operation, options = {})
    record = get_processing_record(file_path, operation)

    # No record exists, needs processing
    return true if record.nil?

    # Check if file has been modified since last processing
    current_mtime = File.mtime(file_path).to_i
    current_size = File.size(file_path)
    current_hash = options[:content_sensitive] ? calculate_file_hash(file_path) : nil

    needs_processing = false

    # File was modified
    if current_mtime != record['mtime']
      needs_processing = true
    end

    # File size changed
    if current_size != record['size']
      needs_processing = true
    end

    # Content hash changed (if enabled)
    if current_hash && current_hash != record['content_hash']
      needs_processing = true
    end

    # Operation parameters changed (e.g., threshold value)
    if options[:params] && record['params'] != options[:params].to_json
      needs_processing = true
    end

    # Force reprocessing if requested
    if options[:force]
      needs_processing = true
    end

    needs_processing
  end

  # Analyze files and categorize them as cached, new, or needing reprocessing
  def analyze_files(file_paths, operation, options = {})
    analysis = {
      cached: [],
      needs_processing: [],
      total: file_paths.length
    }

    # Show progress for large batches if enabled
    if file_paths.length > 50 && options[:show_progress] != false
      # Calculate progress update interval (update every 10% or every 50 files, whichever is smaller)
      update_interval = [50, (file_paths.length / 10.0).ceil].min

      file_paths.each_with_index do |file_path, index|
        begin
          if needs_processing?(file_path, operation, options)
            analysis[:needs_processing] << file_path
          else
            analysis[:cached] << file_path
          end
        rescue => e
          # If there's an error checking the file, mark it as needing processing
          analysis[:needs_processing] << file_path
        end

        # Show progress at intervals
        if (index + 1) % update_interval == 0 || index == file_paths.length - 1
          percent = ((index + 1).to_f / file_paths.length * 100).round(1)
          print "\r🔍 Analyzing files: #{percent}% (#{index + 1}/#{file_paths.length})"
          $stdout.flush
        end
      end

      puts # New line after progress
    else
      # Process silently for small batches
      file_paths.each do |file_path|
        begin
          if needs_processing?(file_path, operation, options)
            analysis[:needs_processing] << file_path
          else
            analysis[:cached] << file_path
          end
        rescue => e
          # If there's an error checking the file, mark it as needing processing
          analysis[:needs_processing] << file_path
        end
      end
    end

    analysis
  end

  # Analyze files and return summary statistics (for initial reporting)
  def get_processing_summary(file_paths, operation, options = {})
    analysis = analyze_files(file_paths, operation, options.merge(show_progress: false))

    {
      total_files: file_paths.length,
      cached_files: analysis[:cached].length,
      new_files: analysis[:needs_processing].length,
      operation: operation,
      cache_enabled: !options[:force] && analysis[:cached].length > 0
    }
  end

  # Print a standardized processing summary
  def print_processing_summary(summary, operation_description = "processing")
    if summary[:cache_enabled] && summary[:cached_files] > 0
      puts "📋 Using cached #{operation_description} for #{summary[:cached_files]} files"
      puts "🔍 Will analyze #{summary[:new_files]} new files"
    else
      puts "🔍 Will analyze #{summary[:total_files]} files"
    end
  end

  # Record that a file has been processed
  def record_processed(file_path, operation, result = nil, options = {})
    data = {
      file_path: file_path,
      operation: operation,
      mtime: File.mtime(file_path).to_i,
      size: File.size(file_path),
      processed_at: Time.now.to_i,
      result: result,
      params: options[:params] ? options[:params].to_json : nil,
      content_hash: options[:content_sensitive] ? calculate_file_hash(file_path) : nil
    }

    @database.upsert('file_processing', data)
  end

  # Get processing history for a file
  def get_file_history(file_path)
    @database.execute(
      'SELECT * FROM file_processing WHERE file_path = ? ORDER BY processed_at DESC',
      [file_path]
    )
  end

  # Get files processed with a specific operation
  def get_processed_files(operation, since: nil)
    sql = 'SELECT DISTINCT file_path FROM file_processing WHERE operation = ?'
    params = [operation]

    if since
      sql += ' AND processed_at >= ?'
      params << since.to_i
    end

    @database.execute(sql, params).map { |row| row['file_path'] }
  end

  # Get statistics about processing operations
  def get_statistics
    stats = @database.execute(<<-SQL)
      SELECT
        operation,
        COUNT(*) as total_processed,
        MAX(processed_at) as last_processed,
        MIN(processed_at) as first_processed
      FROM file_processing
      GROUP BY operation
      ORDER BY total_processed DESC
    SQL

    total_files = @database.execute_scalar('SELECT COUNT(DISTINCT file_path) FROM file_processing')

    {
      total_files: total_files,
      operations: stats
    }
  end

  # Clear old processing records (cleanup)
  def cleanup(days_to_keep = 30)
    cutoff_time = Time.now.to_i - (days_to_keep * 24 * 60 * 60)

    deleted = @database.execute_scalar(
      'SELECT COUNT(*) FROM file_processing WHERE processed_at < ?',
      [cutoff_time]
    )

    @database.execute('DELETE FROM file_processing WHERE processed_at < ?', [cutoff_time])

    deleted
  end

  # Force reprocessing for a file (remove its records)
  def force_reprocessing(file_path, operation = nil)
    if operation
      @database.execute(
        'DELETE FROM file_processing WHERE file_path = ? AND operation = ?',
        [file_path, operation]
      )
    else
      @database.execute(
        'DELETE FROM file_processing WHERE file_path = ?',
        [file_path]
      )
    end
  end

  # Clear all records for testing/debugging
  def clear_all_records
    @database.execute('DELETE FROM file_processing')
  end

  # Get a specific processing record
  def get_processing_record(file_path, operation)
    @database.execute_single(
      'SELECT * FROM file_processing WHERE file_path = ? AND operation = ?',
      [file_path, operation]
    )
  end

  private

  def setup_database
    schema = <<~SQL
      file_path TEXT NOT NULL,
      operation TEXT NOT NULL,
      mtime INTEGER NOT NULL,
      size INTEGER NOT NULL,
      processed_at INTEGER NOT NULL,
      result TEXT,
      params TEXT,
      content_hash TEXT,
      PRIMARY KEY (file_path, operation)
    SQL

    indexes = [
      { name: 'mtime', columns: 'mtime' },
      { name: 'processed_at', columns: 'processed_at' },
      { name: 'operation', columns: 'operation' }
    ]

    @database.create_table('file_processing', schema, indexes)
  end

  def calculate_file_hash(file_path)
    # Use SHA256 for content hashing
    Digest::SHA256.file(file_path).hexdigest
  rescue
    # If hashing fails, return nil
    nil
  end
end