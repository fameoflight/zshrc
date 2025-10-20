# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'
require 'thread'

# Database abstraction for Ruby scripts
class Database
  attr_reader :db_path, :db

  def initialize(db_path)
    @db_path = File.expand_path(db_path)
    @db_mutex = Mutex.new
    ensure_directory
  end

  # Open database connection
  def connect
    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    setup_pragmas
    @db
  end

  # Close database connection
  def close
    @db&.close
    @db = nil
  end

  # Execute with automatic connection management
  def with_connection
    @db_mutex.synchronize do
      was_connected = !@db.nil?
      connect unless was_connected

      begin
        yield @db
      ensure
        close unless was_connected
      end
    end
  end

  # Execute a single SQL statement
  def execute(sql, params = [])
    with_connection do |db|
      db.execute(sql, params)
    end
  end

  # Execute and return first row
  def execute_single(sql, params = [])
    with_connection do |db|
      db.execute(sql, params).first
    end
  end

  # Execute and return single value
  def execute_scalar(sql, params = [])
    result = execute_single(sql, params)
    result&.values&.first
  end

  # Check if table exists
  def table_exists?(table_name)
    sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
    !execute_single(sql, [table_name]).nil?
  end

  # Get table info
  def table_info(table_name)
    execute("PRAGMA table_info(#{table_name})")
  end

  # Create table with schema
  def create_table(table_name, schema, indexes = [])
    execute("CREATE TABLE IF NOT EXISTS #{table_name} (#{schema})")

    indexes.each do |index|
      index_name = "idx_#{table_name}_#{index[:name]}"
      columns = Array(index[:columns]).join(', ')
      unique = index[:unique] ? 'UNIQUE' : ''
      execute("CREATE #{unique} INDEX IF NOT EXISTS #{index_name} ON #{table_name}(#{columns})")
    end
  end

  # Insert or replace record
  def upsert(table_name, data)
    columns = data.keys.join(', ')
    placeholders = (['?'] * data.keys.length).join(', ')
    sql = "INSERT OR REPLACE INTO #{table_name} (#{columns}) VALUES (#{placeholders})"
    execute(sql, data.values)
  end

  # Insert multiple records in a transaction
  def batch_upsert(table_name, records)
    return if records.empty?

    first_record_keys = records.first.keys
    columns = first_record_keys.join(', ')
    placeholders = (['?'] * first_record_keys.length).join(', ')
    sql = "INSERT OR REPLACE INTO #{table_name} (#{columns}) VALUES (#{placeholders})"

    with_connection do |db|
      db.transaction do
        stmt = db.prepare(sql)
        records.each do |record|
          values = first_record_keys.map { |key| record[key] }
          stmt.execute(values)
        end
        stmt.close
      end
    end
  end

  # Select with WHERE clause
  def select(table_name, where: nil, params: [], order: nil, limit: nil)
    sql = "SELECT * FROM #{table_name}"
    sql += " WHERE #{where}" if where
    sql += " ORDER BY #{order}" if order
    sql += " LIMIT #{limit}" if limit

    execute(sql, params)
  end

  # Count records
  def count(table_name, where: nil, params: [])
    sql = "SELECT COUNT(*) FROM #{table_name}"
    sql += " WHERE #{where}" if where

    execute_scalar(sql, params) || 0
  end

  # Group by with count
  def group_count(table_name, group_by, where: nil, params: [], order: 'COUNT(*) DESC', limit: nil)
    sql = "SELECT #{group_by}, COUNT(*) as count FROM #{table_name}"
    sql += " WHERE #{where}" if where
    sql += " GROUP BY #{group_by}"
    sql += " ORDER BY #{order}" if order
    sql += " LIMIT #{limit}" if limit

    execute(sql, params)
  end

  # Delete records
  def delete(table_name, where: nil, params: [])
    sql = "DELETE FROM #{table_name}"
    sql += " WHERE #{where}" if where

    execute(sql, params)
  end

  # Drop table
  def drop_table(table_name)
    execute("DROP TABLE IF EXISTS #{table_name}")
  end

  # Get database file size in MB
  def size_mb
    return 0 unless File.exist?(@db_path)

    (File.size(@db_path) / 1024.0 / 1024.0).round(2)
  end

  # Database statistics
  def stats
    with_connection do |db|
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'")
      stats = { tables: {}, total_size_mb: size_mb }

      tables.each do |table|
        table_name = table['name']
        count = execute_scalar("SELECT COUNT(*) FROM #{table_name}")
        stats[:tables][table_name] = { count: count }
      end

      stats
    end
  end

  # Vacuum database (reclaim space)
  def vacuum!
    execute('VACUUM')
  end

  # Check if database file exists
  def exists?
    File.exist?(@db_path)
  end

  # Delete database file
  def destroy!
    close
    File.delete(@db_path) if File.exist?(@db_path)
  end

  def clear_data!
    with_connection do |db|
      db.execute('DROP TABLE IF EXISTS attachments')
      db.execute('DROP TABLE IF EXISTS messages')
    end
    # Re-create the tables
    gmail_db = GmailDatabase.new(@db_path)
    gmail_db.setup_schema
  end

  private

  def ensure_directory
    directory = File.dirname(@db_path)
    FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
  end

  def setup_pragmas
    # Performance optimizations
    @db.execute('PRAGMA journal_mode = WAL')
    @db.execute('PRAGMA synchronous = NORMAL')
    @db.execute('PRAGMA cache_size = 10000')
    @db.execute('PRAGMA temp_store = memory')
  end
end
