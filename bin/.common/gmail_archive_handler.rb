# frozen_string_literal: true

require 'google/apis/gmail_v1'
require 'set'

# Handles Gmail message archiving operations
# Provides functionality to archive messages by sender, domain, etc.
class GmailArchiveHandler
  include View

  def initialize(gmail_service, gmail_db)
    @gmail_service = gmail_service
    @gmail_db = gmail_db
  end

  def archive_by_sender(user_id, interactive_script)
    log_info('📦 Archive emails by sender')
    puts

    begin
      # Ensure cache is up to date
      ensure_cache_ready(user_id)

      # Get all senders
      all_senders = @gmail_db.get_top_inbox_senders(limit: 200)
      
      if all_senders.empty?
        log_info('No senders found in inbox')
        return
      end

      puts
      log_info("📊 Found #{all_senders.length} senders in your inbox")
      puts

      # Use the interactive selectable list
      header = "📦 Archive Emails by Sender\n📊 Select senders to archive their messages"
      
      display_proc = create_sender_display_proc

      # Show interactive list
      selected_senders = interactive_script.interactive_selectable_list(
        all_senders,
        display_proc: display_proc,
        multi_select: true,
        header: header
      )
      
      return if selected_senders.empty?

      # Show final selection and confirm
      total_to_archive = selected_senders.sum { |s| s[:count] }
      show_selection_summary(selected_senders, total_to_archive, 'sender(s)')
      
      return unless confirm_archive_operation(interactive_script, total_to_archive, selected_senders.length, 'sender(s)')
      
      progress_bar = TTY::ProgressBar.new(
        "Archiving messages [:bar] :current/:total",
        total: total_to_archive,
        width: 30
      )

      total_archived = 0
      total_cache_updated = 0
      # Perform the archive operation for each sender
      selected_senders.each do |sender|
        archived_count_for_sender = archive_messages_from_sender(user_id, sender[:email], progress_bar)
        total_archived += archived_count_for_sender
        # Cache update already handled in archive_messages_from_sender method
        total_cache_updated += sender[:count] # Use expected count since cache should be updated
      end
      progress_bar.finish

      show_archive_completion(total_archived, total_cache_updated, "#{selected_senders.length} sender(s)")
      log_complete("Archive operation completed for #{selected_senders.length} sender(s)")


    rescue StandardError => e
      log_error("Error during archive operation: #{e.message}")
      log_debug("Full error: #{e.backtrace.join("\n")}")
    end
  end

  def archive_by_domain(user_id, interactive_script)
    log_info('🌐 Archive emails by domain')
    puts

    begin
      # Ensure cache is up to date
      ensure_cache_ready(user_id)

      # Get all domains
      all_domains = @gmail_db.get_domain_stats(limit: 200)
      
      if all_domains.empty?
        log_info('No domains found in inbox')
        return
      end

      puts
      log_info("📊 Found #{all_domains.length} domains in your inbox")
      puts

      # Use the interactive selectable list
      header = "🌐 Archive Emails by Domain\n📊 Select domains to archive their messages"
      
      display_proc = create_domain_display_proc

      # Show interactive list
      selected_domains = interactive_script.interactive_selectable_list(
        all_domains,
        display_proc: display_proc,
        multi_select: true,
        header: header
      )
      
      return if selected_domains.empty?

      # Show final selection and confirm
      total_to_archive = selected_domains.sum { |d| d[:count] }
      show_domain_selection_summary(selected_domains, total_to_archive)
      
      return unless confirm_archive_operation(interactive_script, total_to_archive, selected_domains.length, 'domain(s)')
      
      progress_bar = TTY::ProgressBar.new(
        "Archiving messages [:bar] :current/:total",
        total: total_to_archive,
        width: 30
      )

      total_archived = 0
      total_cache_updated = 0
      # Perform the archive operation for each domain
      selected_domains.each do |domain_info|
        archived_count_for_domain = archive_messages_from_domain(user_id, domain_info[:domain], progress_bar)
        total_archived += archived_count_for_domain
        # Cache update already handled in archive_messages_from_domain method
        total_cache_updated += domain_info[:count] # Use expected count since cache should be updated
      end
      progress_bar.finish

      show_archive_completion(total_archived, total_cache_updated, "#{selected_domains.length} domain(s)")
      log_complete("Archive operation completed for #{selected_domains.length} domain(s)")

    rescue StandardError => e
      log_error("Error during archive operation: #{e.message}")
      log_debug("Full error: #{e.backtrace.join("\n")}")
    end
  end

  def archive_chronologically(user_id, interactive_script, order: :oldest_first)
    order_text = order == :oldest_first ? 'oldest first' : 'newest first'
    emoji = order == :oldest_first ? '⏰' : '🕒'
    
    log_info("#{emoji} Archive emails chronologically (#{order_text})")
    puts

    begin
      # Ensure cache is up to date
      ensure_cache_ready(user_id)

      # Get messages chronologically
      all_messages = @gmail_db.messages_chronologically(order: order, limit: 200)
      log_debug("Retrieved #{all_messages.length} messages for chronological display")
      
      if all_messages.empty?
        log_info('No messages found in inbox')
        log_debug('Checking if there are any inbox messages at all...')
        inbox_count = @gmail_db.inbox_message_count
        log_debug("Total inbox messages in cache: #{inbox_count}")
        return
      end

      puts
      log_info("📊 Found #{all_messages.length} messages in your inbox (#{order_text})")
      puts

      # Use the interactive selectable list
      header = "#{emoji} Archive Emails by Date (#{order_text.capitalize})\n📊 Select messages to archive"
      
      display_proc = create_chronological_display_proc

      # Show interactive list
      selected_messages = interactive_script.interactive_selectable_list(
        all_messages,
        display_proc: display_proc,
        multi_select: true,
        header: header
      )
      
      return if selected_messages.empty?

      # Show final selection and confirm
      total_to_archive = selected_messages.length
      show_chronological_selection_summary(selected_messages, order_text)
      
      return unless confirm_archive_operation(interactive_script, total_to_archive, total_to_archive, 'message(s)')
      
      progress_bar = TTY::ProgressBar.new(
        "Archiving messages [:bar] :current/:total",
        total: total_to_archive,
        width: 30
      )

      # Get message IDs and archive them via Gmail API
      message_ids = selected_messages.map { |msg| msg['id'] }
      archived_count = archive_message_ids(user_id, message_ids, progress_bar)
      
      # Update cache to mark messages as archived (only if API calls succeeded)
      cache_updated = 0
      if archived_count > 0
        selected_messages.each do |msg|
          @gmail_db.archive_message_by_id(msg['id'])
          cache_updated += 1
        end
      end

      progress_bar.finish

      show_archive_completion(archived_count, cache_updated, "#{total_to_archive} message(s)")
      log_complete("Chronological archive operation completed")

    rescue StandardError => e
      log_error("Error during chronological archive operation: #{e.message}")
      log_debug("Full error: #{e.backtrace.join("\n")}")
    end
  end

  def archive_unread(user_id, interactive_script)
    log_info('📭 Archive unread emails')
    puts

    begin
      # Ensure cache is up to date
      ensure_cache_ready(user_id)

      # Get unread messages
      unread_messages = @gmail_db.unread_messages(limit: 200)
      log_debug("Retrieved #{unread_messages.length} unread messages")
      
      if unread_messages.empty?
        log_info('No unread messages found in inbox')
        log_debug('Checking if there are any inbox messages at all...')
        inbox_count = @gmail_db.inbox_message_count
        log_debug("Total inbox messages in cache: #{inbox_count}")
        return
      end

      puts
      log_info("📊 Found #{unread_messages.length} unread messages in your inbox")
      puts

      # Use the interactive selectable list
      header = "📭 Archive Unread Emails\n📊 Select unread messages to archive"
      
      display_proc = create_unread_display_proc

      # Show interactive list
      selected_messages = interactive_script.interactive_selectable_list(
        unread_messages,
        display_proc: display_proc,
        multi_select: true,
        header: header
      )
      
      return if selected_messages.empty?

      # Show final selection and confirm
      total_to_archive = selected_messages.length
      show_unread_selection_summary(selected_messages)
      
      return unless confirm_archive_operation(interactive_script, total_to_archive, total_to_archive, 'unread message(s)')
      
      progress_bar = TTY::ProgressBar.new(
        "Archiving unread messages [:bar] :current/:total",
        total: total_to_archive,
        width: 30
      )

      # Get message IDs and archive them via Gmail API
      message_ids = selected_messages.map { |msg| msg['id'] }
      archived_count = archive_message_ids(user_id, message_ids, progress_bar)
      
      # Update cache to mark messages as archived (only if API calls succeeded)
      cache_updated = 0
      if archived_count > 0
        selected_messages.each do |msg|
          @gmail_db.archive_message_by_id(msg['id'])
          cache_updated += 1
        end
      end

      progress_bar.finish

      show_archive_completion(archived_count, cache_updated, "#{total_to_archive} unread message(s)")
      log_complete("Unread archive operation completed")

    rescue StandardError => e
      log_error("Error during unread archive operation: #{e.message}")
      log_debug("Full error: #{e.backtrace.join("\n")}")
    end
  end



  def archive_messages_from_sender(user_id, sender_email, progress_bar)
    messages_to_archive = @gmail_db.messages_by_sender(sender_email)
    message_ids = messages_to_archive.map { |msg| msg['id'] }
    return 0 if message_ids.empty?

    archived_count = archive_message_ids(user_id, message_ids, progress_bar)
    # Always update cache regardless of API response - messages may have been archived already
    cache_updated = @gmail_db.archive_sender_messages(sender_email)
    log_debug("Cache updated: #{cache_updated} messages marked as archived for sender #{sender_email}")
    archived_count
  end

  def archive_messages_from_domain(user_id, domain, progress_bar)
    messages_to_archive = @gmail_db.messages_by_domain(domain)
    message_ids = messages_to_archive.map { |msg| msg['id'] }
    return 0 if message_ids.empty?

    archived_count = archive_message_ids(user_id, message_ids, progress_bar)
    # Always update cache regardless of API response - messages may have been archived already
    cache_updated = @gmail_db.archive_domain_messages(domain)
    log_debug("Cache updated: #{cache_updated} messages marked as archived for domain #{domain}")
    archived_count
  end

  def parse_selection(input_str, max_value)
    indices = Set.new
    parts = input_str.split(',').map(&:strip)

    parts.each do |part|
      if part.include?('-')
        start, end_val = part.split('-').map(&:to_i)
        (start..end_val).each { |i| indices << i - 1 if i.between?(1, max_value) }
      else
        num = part.to_i
        indices << num - 1 if num.between?(1, max_value)
      end
    end

    indices.to_a.sort
  end

  def parse_selection_for_infinite_scroll(input_str, _current_display, _end_display)
    indices = []
    parts = input_str.split(',').map(&:strip)

    parts.each do |part|
      if part.include?('-')
        start_num, end_num = part.split('-').map(&:to_i)
        raise 'Invalid range format' if start_num.nil? || end_num.nil?

        # Convert to 0-based indices
        start_idx = start_num - 1
        end_idx = end_num - 1

        # Validate range is within current display or global range
        (start_idx..end_idx).each do |idx|
          indices << idx if idx >= 0 && idx < 200 # Global limit we're using
        end
      else
        num = part.to_i
        raise 'Invalid number format' if num.zero? && part != '0'

        idx = num - 1
        indices << idx if idx >= 0 && idx < 200 # Global limit we're using
      end
    end

    raise 'No valid selections found' if indices.empty?

    indices.uniq.sort
  end

  private

  def ensure_cache_ready(user_id)
    cached_count = @gmail_db.inbox_message_count
    if cached_count == 0
      log_info('🔄 Building cache for archive analysis')
      @gmail_service.update_message_cache(user_id, @gmail_db)
    else
      log_info('📦 Using cached data for archive selection')
    end
  end

  def create_sender_display_proc
    proc do |sender|
      display_name = sender[:name] == sender[:email] ? sender[:email] : "#{sender[:name]} <#{sender[:email]}>"
      main_line = "#{display_name} (#{sender[:count]} messages)"
      
      # Add email as second line if name is different from email
      main_line += "\n      📧 #{sender[:email]}" if sender[:name] != sender[:email]
      
      main_line
    end
  end

  def create_domain_display_proc
    proc do |domain_info|
      main_line = "#{domain_info[:domain]} (#{domain_info[:count]} messages)"
      
      # Add sample sender names as second line
      if domain_info[:sample_names] && !domain_info[:sample_names].empty?
        # Limit sample names to avoid overly long lines
        sample_names = domain_info[:sample_names].split(', ').first(3).join(', ')
        sample_names += '...' if domain_info[:sample_names].split(', ').length > 3
        main_line += "\n      📧 #{sample_names}"
      end
      
      main_line
    end
  end

  def create_chronological_display_proc
    proc do |message|
      begin
        log_debug("Processing message for display: #{message.class} - Keys: #{message.keys rescue 'N/A'}")
        
        # Format date nicely
        date_received = message['date_received']
        log_debug("Date received: #{date_received} (#{date_received.class})")
        
        date = Time.at(date_received).strftime('%Y-%m-%d %H:%M')
        from_name = message['from_name'] || message['from_email'] || 'Unknown'
        subject = message['subject'] || '(no subject)'
        
        # Truncate long subjects
        display_subject = subject.length > 50 ? "#{subject[0..47]}..." : subject
        
        main_line = "#{date} | #{display_subject}"
        main_line += "\n      📧 #{from_name}"
        
        main_line
      rescue StandardError => e
        log_debug("Error in display proc: #{e.message}")
        log_debug("Message data: #{message.inspect}")
        "Error displaying message: #{e.message}"
      end
    end
  end

  def create_unread_display_proc
    proc do |message|
      begin
        log_debug("Processing unread message for display: #{message.class} - Keys: #{message.keys rescue 'N/A'}")
        
        # Format date nicely
        date_received = message['date_received']
        log_debug("Date received: #{date_received} (#{date_received.class})")
        
        date = Time.at(date_received).strftime('%Y-%m-%d %H:%M')
        from_name = message['from_name'] || message['from_email'] || 'Unknown'
        subject = message['subject'] || '(no subject)'
        
        # Truncate long subjects
        display_subject = subject.length > 50 ? "#{subject[0..47]}..." : subject
        
        main_line = "📭 #{date} | #{display_subject}"
        main_line += "\n      📧 #{from_name}"
        
        main_line
      rescue StandardError => e
        log_debug("Error in unread display proc: #{e.message}")
        log_debug("Message data: #{message.inspect}")
        "Error displaying unread message: #{e.message}"
      end
    end
  end

  def show_selection_summary(selected_items, total_to_archive, item_type)
    puts
    log_info('📋 Final Selection:')
    selected_items.each_with_index do |item, index|
      if item_type.include?('sender')
        puts "  #{index + 1}. #{item[:name]} (#{item[:email]}) - #{item[:count]} messages"
      else
        puts "  #{index + 1}. #{item[:domain]} - #{item[:count]} messages"
      end
    end
    puts
    log_info("📊 Total: #{selected_items.length} #{item_type}, #{total_to_archive} messages")
    puts
  end

  def show_domain_selection_summary(selected_domains, total_to_archive)
    puts
    log_info('📋 Final Selection:')
    selected_domains.each_with_index do |domain_info, index|
      puts "  #{index + 1}. #{domain_info[:domain]} - #{domain_info[:count]} messages"
    end
    puts
    log_info("📊 Total: #{selected_domains.length} domains, #{total_to_archive} messages")
    puts
  end

  def show_chronological_selection_summary(selected_messages, order_text)
    puts
    log_info('📋 Final Selection:')
    selected_messages.first(5).each_with_index do |message, index|
      date = Time.at(message['date_received']).strftime('%Y-%m-%d')
      subject = message['subject'] || '(no subject)'
      subject = subject.length > 40 ? "#{subject[0..37]}..." : subject
      puts "  #{index + 1}. #{date} - #{subject}"
    end
    
    if selected_messages.length > 5
      puts "  ... and #{selected_messages.length - 5} more messages"
    end
    
    puts
    log_info("📊 Total: #{selected_messages.length} messages (#{order_text})")
    puts
  end

  def show_unread_selection_summary(selected_messages)
    puts
    log_info('📋 Final Selection:')
    selected_messages.first(5).each_with_index do |message, index|
      date = Time.at(message['date_received']).strftime('%Y-%m-%d')
      subject = message['subject'] || '(no subject)'
      from_name = message['from_name'] || message['from_email'] || 'Unknown'
      subject = subject.length > 40 ? "#{subject[0..37]}..." : subject
      puts "  #{index + 1}. #{date} - #{subject} (from #{from_name})"
    end
    
    if selected_messages.length > 5
      puts "  ... and #{selected_messages.length - 5} more unread messages"
    end
    
    puts
    log_info("📊 Total: #{selected_messages.length} unread messages")
    puts
  end

  def confirm_archive_operation(interactive_script, total_messages, item_count, item_type)
    if interactive_script.respond_to?(:confirm_action)
      interactive_script.confirm_action("⚠️  Archive ALL #{total_messages} messages from #{item_count} selected #{item_type}?")
    else
      # Fallback if confirm_action is not available
      puts "⚠️  Archive ALL #{total_messages} messages from #{item_count} selected #{item_type}? (y/n)"
      response = STDIN.gets.strip.downcase
      %w[y yes].include?(response)
    end
  end

  def archive_message_ids(user_id, message_ids, progress_bar)
    archived_count = 0
    log_debug("Starting to archive #{message_ids.length} messages")

    message_ids.each_slice(100) do |batch_ids|
      begin
        log_debug("Archiving batch of #{batch_ids.length} messages")
        
        modify_request = Google::Apis::GmailV1::BatchModifyMessagesRequest.new(
          ids: batch_ids,
          remove_label_ids: ['INBOX']
        )

        @gmail_service.batch_modify_messages(user_id, modify_request)

        archived_count += batch_ids.length
        progress_bar.advance(batch_ids.length)
        log_debug("Successfully archived batch of #{batch_ids.length} messages")
      rescue StandardError => e
        log_warning("Failed to archive batch: #{e.message}")
        log_debug("Batch error details: #{e.class}: #{e.message}")
        progress_bar.advance(batch_ids.length)
      end
    end

    log_debug("Total archived count: #{archived_count}")
    archived_count
  end

  def show_archive_completion(archived_count, cache_archived_count, identifier)
    puts
    log_success('✅ Archive operation completed')
    log_info("📦 Messages archived: #{archived_count}")
    log_info("💾 Cache updated: #{cache_archived_count} messages marked as archived")

    # Show updated inbox stats
    updated_inbox_count = @gmail_db.inbox_message_count
    log_info("📊 Remaining inbox messages: #{updated_inbox_count}")

    puts
    log_info("💡 Archived messages can be found in Gmail's All Mail label")
  end
end