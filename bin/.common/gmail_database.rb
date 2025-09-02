# frozen_string_literal: true

require_relative 'database'

# Specialized Gmail database class
class GmailDatabase < Database
  MESSAGE_SCHEMA = <<~SQL
    id TEXT PRIMARY KEY,
    thread_id TEXT,
    from_email TEXT,
    from_name TEXT,
    subject TEXT,
    date_received INTEGER,
    snippet TEXT,
    body TEXT,
    labels TEXT,
    processed_at INTEGER DEFAULT (strftime('%s', 'now'))
  SQL

  MESSAGE_INDEXES = [
    { name: 'from_email', columns: 'from_email' },
    { name: 'date', columns: 'date_received' },
    { name: 'labels', columns: 'labels' }
  ].freeze

  def initialize(db_path = nil)
    default_path = File.expand_path('../../credentials/gmail_cache.db', __dir__)
    super(db_path || default_path)
    setup_schema
  end

  def setup_schema
    create_table('messages', MESSAGE_SCHEMA, MESSAGE_INDEXES)
  end

  # Gmail-specific methods
  def message_exists?(message_id)
    !execute_single('SELECT id FROM messages WHERE id = ?', [message_id]).nil?
  end

  def store_message(message_data)
    upsert('messages', message_data)
  end

  def store_messages(messages)
    batch_upsert('messages', messages)
  end

  def inbox_message_count
    count('messages', where: "labels LIKE '%INBOX%'")
  end

  def sender_stats(limit: nil)
    results = group_count(
      'messages',
      'from_email, from_name',
      where: "labels LIKE '%INBOX%' AND from_email IS NOT NULL",
      order: 'COUNT(*) DESC',
      limit: limit
    )
    
    stats = {}
    results.each do |row|
      email = row['from_email']
      name = row['from_name'] || email
      count = row['count']
      stats[email] = { name: name, count: count }
    end
    stats
  end

  def latest_message_date
    execute_scalar('SELECT MAX(date_received) FROM messages WHERE labels LIKE ?', ['%INBOX%'])
  end

  def messages_since(timestamp, limit: nil)
    select(
      'messages',
      where: 'date_received > ? AND labels LIKE ?',
      params: [timestamp, '%INBOX%'],
      order: 'date_received DESC',
      limit: limit
    )
  end

  def recent_messages(limit: 10)
    select(
      'messages',
      where: "labels LIKE '%INBOX%'",
      order: 'date_received DESC',
      limit: limit
    )
  end

  def purge_old_messages(days_to_keep = 90)
    cutoff = Time.now.to_i - (days_to_keep * 24 * 60 * 60)
    deleted = delete('messages', where: 'date_received < ?', params: [cutoff])
    vacuum! if deleted > 0
    deleted
  end

  def messages_by_sender(email)
    select(
      'messages',
      where: "from_email = ? AND labels LIKE '%INBOX%'",
      params: [email],
      order: 'date_received DESC'
    )
  end

  def sender_message_count(email)
    count('messages', where: "from_email = ? AND labels LIKE '%INBOX%'", params: [email])
  end

  def archive_sender_messages(email)
    # Update labels to remove INBOX and add archived status
    with_connection do |db|
      # Find all inbox messages from this sender
      messages = db.execute(
        "SELECT id, labels FROM messages WHERE from_email = ? AND labels LIKE '%INBOX%'",
        [email]
      )
      
      messages.each do |message|
        current_labels = message['labels'] || ''
        # Remove INBOX from labels
        new_labels = current_labels.split(',').reject { |label| label.strip == 'INBOX' }.join(',')
        
        db.execute(
          "UPDATE messages SET labels = ? WHERE id = ?",
          [new_labels, message['id']]
        )
      end
      
      messages.length
    end
  end

  def search_messages(query, limit: 25)
    select(
      'messages',
      where: "body LIKE ?",
      params: ["%#{query}%"],
      order: 'date_received DESC',
      limit: limit
    )
  end

  def find_unsubscribe_emails(limit: 25)
    select(
      'messages',
      where: "body LIKE '%unsubscribe%'",
      order: 'date_received DESC',
      limit: limit
    )
  end

  def get_top_inbox_senders(limit: 10)
    results = group_count(
      'messages',
      'from_email, from_name',
      where: "labels LIKE '%INBOX%' AND from_email IS NOT NULL",
      order: 'count DESC',
      limit: limit
    )
    
    results.map do |row|
      {
        email: row['from_email'],
        name: row['from_name'] || row['from_email'],
        count: row['count']
      }
    end
  end

  def debug_cache_info
    with_connection do |db|
      info = {}
      info[:total_messages] = db.execute('SELECT COUNT(*) FROM messages').first.first
      info[:inbox_messages] = db.execute("SELECT COUNT(*) FROM messages WHERE labels LIKE '%INBOX%'").first.first
      info[:messages_with_sender] = db.execute("SELECT COUNT(*) FROM messages WHERE from_email IS NOT NULL").first.first
      info[:inbox_with_sender] = db.execute("SELECT COUNT(*) FROM messages WHERE labels LIKE '%INBOX%' AND from_email IS NOT NULL").first.first
      info[:messages_without_labels] = db.execute('SELECT COUNT(*) FROM messages WHERE labels IS NULL OR labels = ""').first.first
      
      # Sample of label formats
      sample_labels = db.execute('SELECT DISTINCT labels FROM messages LIMIT 10').map { |row| row.first }
      info[:sample_labels] = sample_labels
      
      info
    end
  end
end