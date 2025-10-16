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

  ATTACHMENT_SCHEMA = <<~SQL
    id TEXT PRIMARY KEY,
    message_id TEXT,
    filename TEXT,
    mime_type TEXT,
    size INTEGER,
    FOREIGN KEY(message_id) REFERENCES messages(id)
  SQL

  MESSAGE_INDEXES = [
    { name: 'from_email', columns: 'from_email' },
    { name: 'date', columns: 'date_received' },
    { name: 'labels', columns: 'labels' }
  ].freeze

  def initialize(db_path = nil)
    default_path = File.expand_path('../../credentials/gmail_cache.sqlite.db', __dir__)
    super(db_path || default_path)
    setup_schema
  end

  def setup_schema
    create_table('messages', MESSAGE_SCHEMA, MESSAGE_INDEXES)
    create_table('attachments', ATTACHMENT_SCHEMA, [{ name: 'message_id', columns: 'message_id' }])
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

  def store_attachments(attachments)
    batch_upsert('attachments', attachments)
  end

  def inbox_message_count
    count('messages', where: "labels LIKE '%INBOX%'")
  end

  def inbox_conversation_count
    # Count unique thread_ids (conversations) in inbox
    execute_scalar("SELECT COUNT(DISTINCT thread_id) FROM messages WHERE labels LIKE '%INBOX%'")
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
          'UPDATE messages SET labels = ? WHERE id = ?',
          [new_labels, message['id']]
        )
      end

      messages.length
    end
  end

  def get_domain_stats(limit: nil)
    with_connection do |db|
      # Get all messages with email addresses
      sql = <<~SQL
        SELECT from_email, from_name
        FROM messages#{' '}
        WHERE labels LIKE '%INBOX%'#{' '}
        AND from_email IS NOT NULL#{' '}
        AND from_email LIKE '%@%'
      SQL

      results = db.execute(sql)

      # Process in Ruby to extract domains
      domain_stats = {}

      results.each do |row|
        email = row[0]
        name = row[1]

        # Extract domain - get everything after @, then get last 2 parts
        # e.g. a@b.linkedin.com -> linkedin.com
        full_domain = email.split('@').last
        domain_parts = full_domain.split('.')

        # For domains like linkedin.com or mail.linkedin.com, we want linkedin.com
        # Take the last 2 parts if there are more than 2 parts
        domain = if domain_parts.length >= 2
                   domain_parts.last(2).join('.')
                 else
                   full_domain
                 end

        next if domain.nil? || domain.empty?

        domain_stats[domain] ||= { count: 0, names: Set.new }
        domain_stats[domain][:count] += 1
        domain_stats[domain][:names] << name if name && !name.empty?
      end

      # Convert to final format and sort
      final_results = domain_stats.map do |domain, stats|
        {
          domain: domain,
          count: stats[:count],
          sample_names: stats[:names].to_a.first(5).join(', ')
        }
      end.sort_by { |d| -d[:count] }

      # Apply limit if specified
      final_results = final_results.first(limit) if limit

      final_results
    end
  end

  def messages_by_domain(domain)
    # Match messages where the domain matches exactly or as subdomain
    # For linkedin.com, this should match both @linkedin.com and @sub.linkedin.com
    select(
      'messages',
      where: "(from_email LIKE ? OR from_email LIKE ?) AND labels LIKE '%INBOX%'",
      params: ["%@#{domain}", "%@%.#{domain}"],
      order: 'date_received DESC'
    )
  end

  def messages_chronologically(order: :oldest_first, limit: 200)
    # Get all inbox messages ordered chronologically
    sort_order = order == :oldest_first ? 'ASC' : 'DESC'
    select(
      'messages',
      where: "labels LIKE '%INBOX%'",
      order: "date_received #{sort_order}",
      limit: limit
    )
  end

  def unread_messages(limit: 200)
    # Get unread messages (messages with UNREAD label and INBOX label)
    select(
      'messages',
      where: "labels LIKE '%UNREAD%' AND labels LIKE '%INBOX%'",
      order: 'date_received DESC',
      limit: limit
    )
  end

  def archive_domain_messages(domain)
    # Update labels to remove INBOX for all messages from domain
    with_connection do |db|
      # Find all inbox messages from this domain (exact match and subdomains)
      messages = db.execute(
        "SELECT id, labels FROM messages WHERE (from_email LIKE ? OR from_email LIKE ?) AND labels LIKE '%INBOX%'",
        ["%@#{domain}", "%@%.#{domain}"]
      )

      messages.each do |message|
        current_labels = message['labels'] || ''
        # Remove INBOX from labels
        new_labels = current_labels.split(',').reject { |label| label.strip == 'INBOX' }.join(',')

        db.execute(
          'UPDATE messages SET labels = ? WHERE id = ?',
          [new_labels, message['id']]
        )
      end

      messages.length
    end
  end

  def archive_message_by_id(message_id)
    # Update labels to remove INBOX for specific message
    with_connection do |db|
      message = db.execute(
        "SELECT labels FROM messages WHERE id = ? AND labels LIKE '%INBOX%'",
        [message_id]
      ).first

      return 0 unless message

      current_labels = message['labels'] || ''
      # Remove INBOX from labels
      new_labels = current_labels.split(',').reject { |label| label.strip == 'INBOX' }.join(',')

      db.execute(
        'UPDATE messages SET labels = ? WHERE id = ?',
        [new_labels, message_id]
      )

      1 # Return 1 to indicate one message was updated
    end
  end

  def search_messages(query, limit: 25)
    select(
      'messages',
      where: 'body LIKE ?',
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

  def get_attachments_for_message(message_id)
    select('attachments', where: 'message_id = ?', params: [message_id])
  end

  def messages_with_attachments(limit: 25)
    with_connection do |db|
      # First get the messages
      message_sql = <<~SQL
        SELECT DISTINCT m.*, COUNT(a.id) as attachment_count
        FROM messages m
        INNER JOIN attachments a ON m.id = a.message_id
        WHERE m.labels LIKE '%INBOX%'
        GROUP BY m.id
        ORDER BY m.date_received DESC
        LIMIT ?
      SQL

      messages = db.execute(message_sql, [limit]).map(&:to_h)

      # Then get attachments for each message (within the same connection)
      messages.each do |message|
        attachment_sql = 'SELECT * FROM attachments WHERE message_id = ?'
        attachments = db.execute(attachment_sql, [message['id']]).map(&:to_h)
        message['attachments'] = attachments
      end

      messages
    end
  end

  def attachment_stats
    with_connection do |db|
      results = {}

      # Total messages with attachments
      results[:messages_with_attachments] = db.execute(
        'SELECT COUNT(DISTINCT message_id) FROM attachments a INNER JOIN messages m ON a.message_id = m.id WHERE m.labels LIKE ?',
        ['%INBOX%']
      ).first.first

      # Total attachments
      results[:total_attachments] = db.execute(
        'SELECT COUNT(*) FROM attachments a INNER JOIN messages m ON a.message_id = m.id WHERE m.labels LIKE ?',
        ['%INBOX%']
      ).first.first

      # Most common file types
      results[:common_file_types] = db.execute(
        'SELECT mime_type, COUNT(*) as count FROM attachments a INNER JOIN messages m ON a.message_id = m.id WHERE m.labels LIKE ? GROUP BY mime_type ORDER BY count DESC LIMIT 10',
        ['%INBOX%']
      ).map { |row| { mime_type: row[0], count: row[1] } }

      results
    end
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
      info[:messages_with_sender] = db.execute('SELECT COUNT(*) FROM messages WHERE from_email IS NOT NULL').first.first
      info[:inbox_with_sender] =
        db.execute("SELECT COUNT(*) FROM messages WHERE labels LIKE '%INBOX%' AND from_email IS NOT NULL").first.first
      info[:messages_without_labels] =
        db.execute('SELECT COUNT(*) FROM messages WHERE labels IS NULL OR labels = ""').first.first

      # Sample of label formats
      sample_labels = db.execute('SELECT DISTINCT labels FROM messages LIMIT 10').map { |row| row.first }
      info[:sample_labels] = sample_labels

      info
    end
  end
end
