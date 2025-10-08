# frozen_string_literal: true

require_relative '../view'

# View concern for GmailInbox script
module GmailView
  include View

  def display_messages_with_attachments(messages)
    # Safety check for pastel initialization
    @pastel ||= Pastel.new
    log_debug('Pastel initialized for attachments display')

    # Create header with large font
    begin
      puts create_header('ATTACHMENTS', color: :magenta)
      log_debug('Header created successfully')
    rescue StandardError => e
      log_error("Header creation error: #{e.message}")
      log_debug("Full error: #{e.backtrace.join("\n")}")

      # Fallback header box
      header_box = TTY::Box.frame(
        padding: 1,
        title: { top_center: '📎 Messages with Attachments' },
        border: :thick,
        style: { border: { fg: :magenta } }
      ) do
        "#{messages.length} messages found"
      end
      puts header_box
    end
    puts

    # Create table data for messages
    table_data = []
    messages.each_with_index do |msg, index|
      attachments = msg['attachments'] || []
      next if attachments.empty?

      begin
        date_str = Time.at(msg['date_received']).strftime('%m/%d %I:%M%p')
        from_name = msg['from_name'] || msg['from_email'] || 'Unknown'

        # Truncate subject for table
        subject = msg['subject'].length > 40 ? "#{msg['subject'][0..37]}..." : msg['subject']

        # Get attachment summary
        total_size = attachments.sum { |a| a['size'] || 0 }
        attachment_summary = "#{attachments.length} files (#{format_file_size(total_size)})"

        log_debug("Processing attachment message #{index + 1}: #{subject[0..20]}...")
        log_debug("From: #{from_name}, Date: #{date_str}, Summary: #{attachment_summary}")

        # Use safe decoration methods
        col1 = safe_decorate("#{index + 1}", :yellow)
        col2 = safe_decorate(subject, :white)
        col3 = safe_decorate(from_name, :green)
        col4 = safe_decorate(date_str, :cyan)
        col5 = safe_decorate(attachment_summary, :magenta)

        table_data << [col1, col2, col3, col4, col5]
        log_debug("Message #{index + 1} processed successfully")
      rescue StandardError => e
        log_error("Error processing attachment message #{index + 1}: #{e.message}")
        log_debug("Subject: #{msg['subject']}")
        log_debug("From: #{msg['from_name']} / #{msg['from_email']}")
        log_debug("Full backtrace: #{e.backtrace.join("\n")}")

        # Fallback without colors
        table_data << [
          "#{index + 1}",
          subject || 'Unknown Subject',
          from_name,
          date_str || 'Unknown Date',
          attachment_summary || 'Unknown Size'
        ]
      end
    end

    # Display main table
    if table_data.any?
      log_debug("Creating table with #{table_data.length} rows")

      begin
        headers = ['#', 'Subject', 'From', 'Date', 'Attachments']
        puts create_table(headers, table_data)
        log_debug('Table rendered successfully')
      rescue StandardError => e
        log_error("Table creation/rendering failed: #{e.message}")
        log_debug("Full error: #{e.backtrace.join("\n")}")

        # Fallback to simple display
        log_info('Using simple display format...')
        table_data.each_with_index do |row, idx|
          puts "#{idx + 1}. #{row[1]} - #{row[2]} - #{row[3]} - #{row[4]}"
        end
      end
      puts

      # Show detailed attachment info in a separate section
      messages.each_with_index do |msg, index|
        attachments = msg['attachments'] || []
        next if attachments.empty?

        puts safe_decorate("#{index + 1}. #{msg['subject']}", :yellow)

        # Create attachment details table
        attachment_data = attachments.map do |attachment|
          [
            safe_decorate('📄', :cyan),
            safe_decorate(attachment['filename'], :white),
            safe_decorate(attachment['mime_type'], :green),
            safe_decorate(format_file_size(attachment['size']), :yellow)
          ]
        end

        attachment_headers = ['', 'File', 'Type', 'Size']
        puts create_table(attachment_headers, attachment_data)
        puts
      end

      # Summary box
      total_files = messages.sum { |m| (m['attachments'] || []).length }
      puts create_status_box("📊 Found #{total_files} attachments across #{messages.length} messages",
                             status: :success)
    end
  rescue StandardError => e
    log_error "Error in display_messages_with_attachments: #{e.message}"
    log_error 'Full backtrace:'
    e.backtrace.each { |line| log_error "  #{line}" }

    # Fallback simple display
    puts "Messages with Attachments (#{messages.length} found):"
    messages.each_with_index do |msg, i|
      puts "#{i + 1}. #{msg['subject']} - #{msg['from_name'] || msg['from_email']}"
    end
  end

  def show_recent_messages(service, user_id, limit = 10)
    # Safety check for pastel initialization
    @pastel ||= Pastel.new

    # Create a beautiful header box
    puts create_box(
      "Fetching #{limit} most recent inbox messages...",
      title: '📧 Recent Messages',
      color: :cyan
    )
    puts

    result = service.list_user_messages(user_id, max_results: limit, label_ids: ['INBOX'])

    if result.messages.nil? || result.messages.empty?
      puts create_empty_state('No messages found in your inbox')
      return
    end

    messages_data = []

    with_progress('📧 Loading messages', total: result.messages.count) do |progress|
      result.messages.each do |message|
        msg = service.get_user_message(user_id, message.id)
        subject = msg.payload.headers.find { |h| h.name == 'Subject' }&.value || '(no subject)'
        from = msg.payload.headers.find { |h| h.name == 'From' }&.value || '(unknown sender)'
        date = msg.payload.headers.find { |h| h.name == 'Date' }&.value

        # Clean up the from field
        from_clean = from.gsub(/<.*?>/, '').strip
        from_clean = from_clean.empty? ? from : from_clean

        # Format date
        date_str = date ? Time.parse(date).strftime('%m/%d %I:%M%p') : 'unknown date'

        # Truncate long subjects for table display
        display_subject = subject.length > 50 ? "#{subject[0..47]}..." : subject

        begin
          log_debug("Processing message #{message.id}: #{subject[0..20]}...")
          messages_data << [
            safe_decorate('📨', :cyan),
            safe_decorate(display_subject, :white),
            safe_decorate("👤 #{from_clean}", :green),
            safe_decorate("📅 #{date_str}", :yellow)
          ]
          log_debug('Message processed successfully')
        rescue StandardError => e
          log_error("UI error in message processing: #{e.message}")
          log_debug("Subject: #{subject}")
          log_debug("From: #{from_clean}")
          log_debug("Date: #{date_str}")
          # Fallback without colors
          messages_data << ['📨', display_subject, "👤 #{from_clean}", "📅 #{date_str}"]
        end

        progress.advance(1)
      rescue StandardError => e
        log_warning "Could not fetch details for message: #{e.message}"
        progress.advance(1)
      end
    end

    # Create a beautiful table
    log_debug("Creating table with #{messages_data.length} messages")
    headers = ['', 'Subject', 'From', 'Date']
    puts create_table(headers, messages_data)
    puts

    # Summary box
    puts create_status_box("✅ Displayed #{messages_data.length} recent messages", status: :success)
  rescue StandardError => e
    log_error("Error in show_recent_messages: #{e.message}")
    log_debug("Full backtrace: #{e.backtrace.join("\n")}")

    # Fallback simple display
    puts "Recent Messages (#{messages_data&.length || 0} found):"
    messages_data&.each_with_index do |msg, i|
      puts "#{i + 1}. #{msg[1]} - #{msg[2]} - #{msg[3]}"
    end
  end

  def show_top_senders(_service, user_id, limit = 10)
    log_info '👥 Analyzing top senders in your inbox'
    puts

    begin
      # Ensure cache is up to date
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building initial cache for sender analysis'
        @gmail_service.update_message_cache(user_id, @gmail_db)
      else
        log_info '📦 Using cached data for fast analysis'
        # Quick incremental update
        @gmail_service.update_message_cache(user_id, @gmail_db, force_update: false)
      end

      puts

      # Get sender stats from cache - much faster!
      log_progress 'Analyzing sender patterns from cache'

      # Debug: Check cache status
      total_cached = gmail_db.execute_scalar('SELECT COUNT(*) FROM messages')
      inbox_cached = gmail_db.inbox_message_count

      log_debug("📊 Cache status: #{total_cached} total messages, #{inbox_cached} in inbox")

      sender_stats = gmail_db.sender_stats(limit: limit * 2) # Get extra for processing

      if sender_stats.empty?
        log_info 'No sender data found in cache'
        log_info "💡 Try running 'Refresh cache' to rebuild the cache completely"
        return
      end

      total_messages = sender_stats.values.sum { |stats| stats[:count] }

      # Show discrepancy if any
      if total_messages != inbox_cached
        log_warning '⚠️  Mismatch detected:'
        log_warning "   Cache reports #{inbox_cached} inbox messages"
        log_warning "   But sender analysis found #{total_messages} messages"
        log_warning '   Consider refreshing cache for accurate counts'
      end

      # Sort senders by count and take top N
      top_senders = sender_stats.sort_by { |_email, stats| -stats[:count] }.first(limit)

      # Create beautiful header with large font
      begin
        font = TTY::Font.new(:doom)
        puts safe_decorate(font.write('TOP SENDERS'), :cyan)
      rescue StandardError
        # Fallback if font not available
        puts create_box(
          "#{total_messages} messages analyzed",
          title: '👥 Top Senders Analysis',
          color: :cyan
        )
      end
      puts

      # Create table data
      table_data = top_senders.map.with_index do |(email, stats), index|
        name = stats[:name]
        count = stats[:count]
        percentage = ((count.to_f / total_messages) * 100).round(1)

        # Truncate long names for display
        display_name = name.length > 25 ? "#{name[0..22]}..." : name

        [
          safe_decorate("#{index + 1}", :yellow),
          safe_decorate(display_name, :white),
          safe_decorate("#{count} msgs", :green),
          safe_decorate("#{percentage}%", :cyan),
          safe_decorate(email, :dim)
        ]
      end

      # Create and display the table
      headers = ['#', 'Sender', 'Messages', '%', 'Email']
      puts create_table(headers, table_data)
      puts

      # Summary box
      puts create_status_box(
        "💡 Analysis completed in seconds using cached data!\n📊 Top #{limit} senders from #{total_messages} total messages",
        status: :success
      )
    rescue StandardError => e
      log_warning "Error analyzing top senders: #{e.message}"
    end
  end

  def show_inbox_summary(service, user_id)
    log_info '📊 Inbox Summary'
    puts

    # Safety check for pastel initialization
    unless @pastel
      log_debug 'Pastel not initialized, creating new instance'
      @pastel = Pastel.new
    end
    log_debug "Pastel instance: #{@pastel.class}"

    begin
      # Check if we need to update cache first
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building initial cache'
        @gmail_service.update_message_cache(user_id, @gmail_db)
        gmail_db.inbox_message_count
      else
        log_info "📦 Using cached data (#{cached_count} messages)"
        # Update cache with any new messages (incremental)
        @gmail_service.update_message_cache(user_id, @gmail_db, force_update: false)
      end

      # Show conversation vs message breakdown
      begin
        total_messages = gmail_db.inbox_message_count
        conversation_count = gmail_db.inbox_conversation_count
        
        puts
        
        log_info "💾 Individual messages: #{total_messages}"
        log_info "💬 Conversations/threads: #{conversation_count}"
        
        if conversation_count > 0
          avg_msgs_per_conversation = (total_messages.to_f / conversation_count).round(1)
          log_info "📊 Average messages per conversation: #{avg_msgs_per_conversation}"
        end
        
        live_result = service.list_user_messages(user_id, label_ids: ['INBOX'], max_results: 1)
        live_estimate = live_result.result_size_estimate || 0
        log_info "🔍 Gmail API estimate: #{live_estimate} inbox messages"
        
        if live_estimate != total_messages
          log_info "💡 Gmail web groups messages into conversations"
          log_info "   Web view shows ~#{conversation_count} items, script counts #{total_messages} individual messages"
        end
      rescue StandardError => e
        log_error "Could not get conversation comparison: #{e.message}"
      end

      puts

      # Get counts from cache and live API
      log_progress 'Getting current inbox statistics'

      # Get total from cache (much faster)
      total_messages = gmail_db.inbox_message_count

      # Get unread count from live API (need current status)
      unread_result = service.list_user_messages(user_id, label_ids: %w[INBOX UNREAD], max_results: 1)
      unread_count_estimate = unread_result.result_size_estimate || 0

      # For accuracy, let's count unread messages properly but with progress bar
      unread_progress = TTY::ProgressBar.new(
        '📩 Counting unread messages [:bar] :current',
        total: unread_count_estimate > 0 ? unread_count_estimate : 100,
        width: 30,
        bar_format: :block
      )

      unread_messages = 0
      next_page_token = nil

      loop do
        unread_result = service.list_user_messages(
          user_id,
          label_ids: %w[INBOX UNREAD],
          max_results: 500,
          page_token: next_page_token
        )

        break unless unread_result.messages

        batch_size = unread_result.messages.length
        unread_messages += batch_size
        unread_progress.advance(batch_size)

        next_page_token = unread_result.next_page_token
        break unless next_page_token
      end

      unread_progress.finish
      puts

      # Calculate read messages
      read_messages = total_messages - unread_messages

      # Create beautiful inbox summary with tty-font header
      begin
        font = TTY::Font.new(:block)
        puts safe_decorate(font.write('INBOX'), :green)
      rescue StandardError => e
        # Fallback header
        log_debug "Font error: #{e.message}"
        puts safe_decorate('📊 INBOX SUMMARY', :bold, :green)
        puts '=' * 50
      end
      puts

      # Create stats table
      log_debug 'Creating stats table...'
      begin
        stats_data = [
          [safe_decorate('📬', :cyan), safe_decorate('Total Messages', :white),
           safe_decorate("#{total_messages}", :yellow), safe_decorate('(from cache)', :dim)],
          [safe_decorate('📩', :blue), safe_decorate('Unread Messages', :white),
           safe_decorate("#{unread_messages}", :red), safe_decorate('(live count)', :dim)],
          [safe_decorate('📖', :green), safe_decorate('Read Messages', :white),
           safe_decorate("#{read_messages}", :green), safe_decorate('', :dim)]
        ]
        log_debug 'Basic stats data created'

        if total_messages > 0
          unread_percentage = ((unread_messages.to_f / total_messages) * 100).round(1)
          color = if unread_percentage > 50
                    :red
                  else
                    unread_percentage > 25 ? :yellow : :green
                  end
          log_debug "Adding percentage row with color: #{color}"
          stats_data << [
            safe_decorate(
              '📈',
              :magenta
            ),
            safe_decorate('Unread Percentage', :white),
            safe_decorate("#{unread_percentage}%", color),
            safe_decorate('', :dim)
          ]
        end
        log_debug 'Stats data complete'

        # Create and display stats table
        log_debug 'Creating table headers...'
        headers = ['', 'Metric', 'Count', 'Source']
        puts create_table(headers, stats_data)
        log_debug('Table created successfully')
      rescue StandardError => e
        log_error("Error in stats table creation: #{e.message}")
        log_debug("Backtrace: #{e.backtrace.join("\n")}")
        raise e
      end
      puts

      # Status box based on inbox health
      if unread_messages == 0
        puts create_status_box('🎉 Inbox Zero achieved! Great job!', status: :success)
      elsif unread_percentage > 75
        puts create_status_box("⚠️  High unread rate (#{unread_percentage}%) - consider email management",
                               status: :error)
      else
        puts create_status_box("📊 #{unread_messages} messages awaiting attention", status: :warning)
      end
    rescue StandardError => e
      log_error "Could not fetch inbox summary: #{e.message}"
      log_error 'Backtrace:'
      e.backtrace.first(10).each { |line| log_error "  #{line}" }
    end
  end

  def display_search_results(results)
    if results.empty?
      log_info 'No matching emails found'
      return
    end

    show_list('Search Results', results.map do |msg|
      {
        subject: "📨 #{msg['subject']}",
        from: "👤 #{msg['from_name']}",
        date: "📅 #{Time.at(msg['date_received']).strftime('%m/%d %I:%M%p')}"
      }
    end)
  end
end
