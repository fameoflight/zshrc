#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/interactive_script_base'
require_relative '.common/logger'
require_relative '.common/gmail_database'
require_relative '.common/ui_helpers'
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'tty-progressbar'
require 'tty-table'
require 'tty-box'
require 'tty-font'
require 'pastel'
require 'timeout'
require 'thread'
require 'securerandom'
require 'set'
require 'io/console'

# Description: Fetches and manages Gmail inbox.
class GmailInbox < InteractiveScriptBase
  include UIHelpers
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Gmail Inbox Fetcher'
  CREDENTIALS_PATH = File.expand_path('../credentials/gmail.json', __dir__)
  TOKEN_DIR = File.expand_path('../credentials/tokens', __dir__)
  CACHE_DIR = File.expand_path('../credentials/cache', __dir__)
  SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_MODIFY

  attr_reader :account_name

  def initialize
    super
    @account_name = @options[:account]
    @pastel = Pastel.new
  end


  def banner_text
    <<~BANNER
      📥 Gmail Inbox Interactive Tool - Analyze and explore your Gmail inbox

      Usage: #{script_name} [OPTIONS]

      Interactive Mode (default):
        #{script_name}              # Start interactive menu with multiple options

      Quick Actions:
        #{script_name} -l 25        # Show 25 most recent messages (non-interactive)
        #{script_name} --summary    # Show only inbox summary (non-interactive)
        #{script_name} --setup      # Show setup instructions
        #{script_name} --reset-auth # Reset stored authentication

      Interactive Features:
        • 📊 Inbox summary with statistics
        • 📧 Recent messages viewer
        • 👥 Top senders analysis
        • 🔄 Real-time data refresh
    BANNER
  end

  def add_custom_options(opts)
    opts.on('-a', '--account ACCOUNT', 'Specify the account to use') do |account|
      @options[:account] = account
    end

    opts.on('-l', '--limit LIMIT', Integer, 'Number of messages to fetch (default: 10)') do |limit|
      @options[:limit] = limit
    end

    opts.on('-s', '--setup', 'Show setup instructions again') do
      @options[:setup] = true
    end

    opts.on('--reset-auth', 'Reset stored authentication and re-authorize') do
      @options[:reset_auth] = true
    end

    opts.on('--summary', 'Show only inbox summary statistics') do
      @options[:summary_only] = true
    end

    opts.on('--clear-cache', 'Clear message cache and refresh all data') do
      @options[:clear_cache] = true
    end
  end

  def run
    log_banner('Gmail Inbox Interactive Tool')

    # Handle setup option
    if @options[:setup]
      show_setup_instructions
      return
    end

    # Handle reset auth option
    reset_authentication if @options[:reset_auth]

    # Handle clear cache option
    if @options[:clear_cache]
      select_account unless @account_name
      clear_cache
      log_success "Cache cleared for account '#{@account_name}'"
      return
    end

    select_account

    check_credentials

    service = Google::Apis::GmailV1::GmailService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    user_id = 'me'

    # Handle legacy command-line options for backwards compatibility
    if @options[:summary_only]
      show_inbox_summary(service, user_id)
      show_completion('Gmail Inbox Summary')
      return
    elsif @options[:limit]
      show_recent_messages(service, user_id, @options[:limit])
      show_completion('Gmail Inbox Messages')
      return
    end

    # Start interactive mode
    start_interactive_mode
  end

  # Interactive script methods (required by InteractiveScriptBase)
  def tool_title
    '📥 Gmail Inbox Interactive Tool'
  end

  def menu_options
    [
      menu_option('📊', 'Show inbox summary', :summary),
      menu_option('📧', 'Show recent messages', :recent_messages),
      menu_option('📎', 'Find messages with attachments', :messages_with_attachments),
      menu_option('👥', 'Top senders analysis', :top_senders),
      menu_option('📦', 'Archive emails by sender', :archive_by_sender),
      menu_option('🌐', 'Archive emails by domain', :archive_by_domain),
      menu_option('🔍', 'Search emails', :search_emails),
      menu_option('🗑️', 'Find unsubscribe emails', :find_unsubscribe),
      refresh_option(:refresh_cache),
      clear_cache_option(:clear_cache)
    ]
  end

  def setup_interactive_mode
    # Setup Gmail service
    @service = Google::Apis::GmailV1::GmailService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
    @user_id = 'me'
  end

  def handle_menu_choice(choice)
    safe_execute do
      case choice
      when :summary
        show_inbox_summary(@service, @user_id)
      when :recent_messages
        limit = ask_number('How many recent messages?', default: 10)
        show_recent_messages(@service, @user_id, limit)
      when :messages_with_attachments
        show_messages_with_attachments
      when :top_senders
        limit = ask_number('How many top senders to show?', default: 10)
        show_top_senders(@service, @user_id, limit)
      when :archive_by_sender
        archive_by_sender(@service, @user_id)
      when :archive_by_domain
        archive_by_domain(@service, @user_id)
      when :search_emails
        search_emails
      when :find_unsubscribe
        find_unsubscribe_emails
      when :refresh_cache
        refresh_cache(@service, @user_id)
      when :clear_cache
        clear_cache
        log_success 'Cache cleared - fresh data will be loaded on next action'
      end
    end
  end

  def search_emails
    query = ask_string('Enter search query:')
    log_info "🔍 Searching for emails containing '#{query}'"
    results = gmail_db.search_messages(query)
    display_search_results(results)
  end

  def find_unsubscribe_emails
    log_info '🗑️ Finding emails with unsubscribe links'
    results = gmail_db.find_unsubscribe_emails
    display_search_results(results)
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

  def show_messages_with_attachments
    log_info '📎 Finding messages with attachments'
    puts

    begin
      # Ensure cache is up to date
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building initial cache to find attachments'
        update_message_cache(@service, @user_id)
        
        # Check again after caching
        cached_count = gmail_db.inbox_message_count
        if cached_count == 0
          log_info 'No messages found in your inbox'
          return
        end
      else
        log_info '📦 Using cached data to search for attachments'
        # Quick incremental update
        update_message_cache(@service, @user_id, force_update: false)
      end

      puts

      # Get attachment statistics first
      begin
        stats = gmail_db.attachment_stats
      rescue StandardError => e
        log_warning "Could not get attachment statistics: #{e.message}"
        log_info 'This might happen if the cache is still building attachment data'
        log_info 'Try running "Refresh cache" to rebuild with attachment support'
        return
      end
      
      if stats[:messages_with_attachments] == 0
        log_info 'No messages with attachments found in your inbox'
        log_info '💡 This could mean:'
        log_info '   • Your recent inbox messages have no attachments'
        log_info '   • Attachment data is still being processed'
        log_info '   • Try "Refresh cache" to rebuild with full attachment support'
        return
      end

      # Show summary stats
      log_success "📊 Found #{stats[:messages_with_attachments]} messages with #{stats[:total_attachments]} total attachments"
      
      if stats[:common_file_types].any?
        puts
        log_info '📋 Most common file types:'
        stats[:common_file_types].first(5).each do |type_info|
          puts "  #{type_info[:mime_type]}: #{type_info[:count]} files"
        end
      end

      puts

      # Ask for limit
      limit = ask_number('How many messages with attachments to show?', default: 20)
      
      # Get messages with attachments
      begin
        messages = gmail_db.messages_with_attachments(limit: limit)
      rescue StandardError => e
        log_error "Could not retrieve messages with attachments: #{e.message}"
        log_info 'Try running "Refresh cache" to rebuild the database with attachment support'
        log_debug("Full error: #{e.backtrace.join("\n")}")
        return
      end
      
      if messages.empty?
        log_info 'No messages with attachments found'
        return
      end

      display_messages_with_attachments(messages)

    rescue StandardError => e
      log_error "Error finding messages with attachments: #{e.message}"
      log_debug("Full error: #{e.backtrace.join("\n")}")
    end
  end

  def display_messages_with_attachments(messages)
    begin
      # Safety check for pastel initialization
      unless @pastel
        @pastel = Pastel.new
      end
      log_debug("Pastel initialized for attachments display")

      # Create header with large font
      begin
        puts create_header("ATTACHMENTS", color: :magenta)
        log_debug("Header created successfully")
      rescue StandardError => font_error
        log_error("Header creation error: #{font_error.message}")
        log_debug("Full error: #{font_error.backtrace.join("\n")}")
        
        # Fallback header box
        header_box = TTY::Box.frame(
          padding: 1,
          title: { top_center: "📎 Messages with Attachments" },
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
        rescue StandardError => msg_error
          log_error("Error processing attachment message #{index + 1}: #{msg_error.message}")
          log_debug("Subject: #{msg['subject']}")
          log_debug("From: #{msg['from_name']} / #{msg['from_email']}")
          log_debug("Full backtrace: #{msg_error.backtrace.join("\n")}")
          
          # Fallback without colors
          table_data << [
            "#{index + 1}",
            subject || "Unknown Subject",
            from_name,
            date_str || "Unknown Date",
            attachment_summary || "Unknown Size"
          ]
        end
      end

      # Display main table
      if table_data.any?
        log_debug("Creating table with #{table_data.length} rows")
        
        begin
          headers = ['#', 'Subject', 'From', 'Date', 'Attachments']
          puts create_table(headers, table_data)
          log_debug("Table rendered successfully")
        rescue StandardError => table_error
          log_error("Table creation/rendering failed: #{table_error.message}")
          log_debug("Full error: #{table_error.backtrace.join("\n")}")
          
          # Fallback to simple display
          log_info("Using simple display format...")
          table_data.each_with_index do |row, idx|
            puts "#{idx + 1}. #{row[1]} - #{row[2]} - #{row[3]} - #{row[4]}"
          end
        end
        puts

      # Show detailed attachment info in a separate section
      messages.each_with_index do |msg, index|
        attachments = msg['attachments'] || []
        next if attachments.empty?

        puts @pastel.decorate("#{index + 1}. #{msg['subject']}", :yellow)
        
        # Create attachment details table
        attachment_data = attachments.map do |attachment|
          [
            @pastel.decorate("📄", :cyan),
            @pastel.decorate(attachment['filename'], :white),
            @pastel.decorate(attachment['mime_type'], :green),
            @pastel.decorate(format_file_size(attachment['size']), :yellow)
          ]
        end

        attachment_table = TTY::Table.new(
          [@pastel.decorate('', :dim), @pastel.decorate('File', :dim), @pastel.decorate('Type', :dim), @pastel.decorate('Size', :dim)],
          attachment_data
        )

        puts attachment_table.render(:unicode, padding: [0, 1])
        puts
      end

        # Summary box
        total_files = messages.sum { |m| (m['attachments'] || []).length }
        summary_box = TTY::Box.frame(
          padding: 1,
          border: :thick,
          style: { border: { fg: :green } }
        ) do
          @pastel.decorate("📊 Found #{total_files} attachments across #{messages.length} messages", :green)
        end
        puts summary_box
      end
    rescue StandardError => e
      log_error "Error in display_messages_with_attachments: #{e.message}"
      log_error "Full backtrace:"
      e.backtrace.each { |line| log_error "  #{line}" }
      
      # Fallback simple display
      puts "Messages with Attachments (#{messages.length} found):"
      messages.each_with_index do |msg, i|
        puts "#{i + 1}. #{msg['subject']} - #{msg['from_name'] || msg['from_email']}"
      end
    end
  end

  def format_file_size(size_bytes)
    return '0 B' if size_bytes.nil? || size_bytes == 0

    units = %w[B KB MB GB TB]
    size = size_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    if unit_index == 0
      "#{size.to_i} #{units[unit_index]}"
    else
      "#{size.round(1)} #{units[unit_index]}"
    end
  end

  private

  def select_account
    return if @account_name

    existing_accounts = Dir.glob(File.join(TOKEN_DIR, '*.yaml')).map { |f| File.basename(f, '.yaml') }

    if existing_accounts.empty?
      log_info 'No existing accounts found.'
      new_account_name = ask_string('Enter a name for your new account:')
      if confirm_action("Create new account '#{new_account_name}'?")
        @account_name = new_account_name
      else
        exit_with_message('Account creation cancelled.')
      end
    else
      choices = existing_accounts + ['[Create a new account]']
      selection = ask_choice('Select an account:', choices)

      if selection == '[Create a new account]'
        new_account_name = ask_string('Enter a name for your new account:')
        if confirm_action("Create new account '#{new_account_name}'?")
          @account_name = new_account_name
        else
          exit_with_message('Account creation cancelled.')
        end
      else
        @account_name = selection
      end
    end
    log_info "Using account: #{@account_name}"
  end

  def token_path
    File.join(TOKEN_DIR, "#{@account_name}.yaml")
  end

  def cache_path
    File.join(CACHE_DIR, "#{@account_name}.db")
  end

  def gmail_db
    @gmail_db ||= GmailDatabase.new(cache_path)
  end

  def show_recent_messages(service, user_id, limit = 10)
    begin
      # Safety check for pastel initialization
      unless @pastel
        @pastel = Pastel.new
      end

      # Create a beautiful header box
      header_box = TTY::Box.frame(
        padding: 1,
        title: { top_center: "📧 Recent Messages" },
        border: :thick,
        style: { border: { fg: :cyan } }
      ) do
        "Fetching #{limit} most recent inbox messages..."
      end
      puts header_box
      puts

    result = service.list_user_messages(user_id, max_results: limit, label_ids: ['INBOX'])

    if result.messages.nil? || result.messages.empty?
      empty_box = TTY::Box.frame(
        padding: 1,
        border: :thick,
        style: { border: { fg: :yellow } }
      ) do
        @pastel.decorate("📭 No messages found in your inbox", :yellow)
      end
      puts empty_box
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
            safe_decorate("📨", :cyan),
            safe_decorate(display_subject, :white),
            safe_decorate("👤 #{from_clean}", :green),
            safe_decorate("📅 #{date_str}", :yellow)
          ]
          log_debug("Message processed successfully")
        rescue StandardError => pastel_error
          log_error("UI error in message processing: #{pastel_error.message}")
          log_debug("Subject: #{subject}")
          log_debug("From: #{from_clean}")
          log_debug("Date: #{date_str}")
          # Fallback without colors
          messages_data << ["📨", display_subject, "👤 #{from_clean}", "📅 #{date_str}"]
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
      summary_box = TTY::Box.frame(
        padding: 1,
        border: :thick,
        style: { border: { fg: :green } }
      ) do
        @pastel.decorate("✅ Displayed #{messages_data.length} recent messages", :green)
      end
      puts summary_box
    rescue StandardError => e
      log_error("Error in show_recent_messages: #{e.message}")
      log_debug("Full backtrace: #{e.backtrace.join("\n")}")
      
      # Fallback simple display
      puts "Recent Messages (#{messages_data&.length || 0} found):"
      messages_data&.each_with_index do |msg, i|
        puts "#{i + 1}. #{msg[1]} - #{msg[2]} - #{msg[3]}"
      end
    end
  end

  def show_top_senders(service, user_id, limit = 10)
    log_info '👥 Analyzing top senders in your inbox'
    puts

    begin
      # Ensure cache is up to date
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building initial cache for sender analysis'
        update_message_cache(service, user_id)
      else
        log_info '📦 Using cached data for fast analysis'
        # Quick incremental update
        update_message_cache(service, user_id, force_update: false)
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
        puts @pastel.decorate(font.write("TOP SENDERS"), :cyan)
      rescue StandardError
        # Fallback if font not available
        header_box = TTY::Box.frame(
          padding: 1,
          title: { top_center: "👥 Top Senders Analysis" },
          border: :thick,
          style: { border: { fg: :cyan } }
        ) do
          "#{total_messages} messages analyzed"
        end
        puts header_box
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
          @pastel.decorate("#{index + 1}", :yellow),
          @pastel.decorate(display_name, :white),
          @pastel.decorate("#{count} msgs", :green),
          @pastel.decorate("#{percentage}%", :cyan),
          @pastel.decorate(email, :dim)
        ]
      end

      # Create and display the table
      headers = ['#', 'Sender', 'Messages', '%', 'Email']
      puts create_table(headers, table_data)
      puts

      # Summary box
      summary_box = TTY::Box.frame(
        padding: 1,
        border: :thick,
        style: { border: { fg: :green } }
      ) do
        @pastel.decorate("💡 Analysis completed in seconds using cached data!\n", :green) +
        @pastel.decorate("📊 Top #{limit} senders from #{total_messages} total messages", :white)
      end
      puts summary_box
    rescue StandardError => e
      log_warning "Error analyzing top senders: #{e.message}"
    end
  end

  def extract_email(from_field)
    # Extract email from "Name <email@domain.com>" or just "email@domain.com"
    match = from_field.match(/<(.+?)>/)
    match ? match[1].strip : from_field.strip
  end

  def extract_name(from_field)
    # Extract name from "Name <email@domain.com>" format
    if from_field.include?('<')
      name = from_field.split('<').first.strip
      name = name.gsub(/^["']|["']$/, '') # Remove surrounding quotes
      name.empty? ? extract_email(from_field) : name
    else
      from_field.strip
    end
  end

  def extract_attachments(payload, message_id)
    attachments = []
    
    # Helper method to recursively process parts
    process_parts = lambda do |parts|
      return unless parts

      parts.each do |part|
        # Check if this part has a filename (indicating an attachment)
        if part.filename && !part.filename.empty?
          attachments << {
            id: "#{message_id}_#{part.part_id || SecureRandom.uuid}",
            message_id: message_id,
            filename: part.filename,
            mime_type: part.mime_type,
            size: part.body&.size || 0
          }
        end

        # Recursively process nested parts
        process_parts.call(part.parts) if part.parts
      end
    end

    # Process the main payload
    if payload.filename && !payload.filename.empty?
      attachments << {
        id: "#{message_id}_root",
        message_id: message_id,
        filename: payload.filename,
        mime_type: payload.mime_type,
        size: payload.body&.size || 0
      }
    end

    # Process all parts
    process_parts.call(payload.parts)

    attachments
  end

  # Database management methods
  def clear_cache
    db_cleared = false
    if gmail_db.exists?
      gmail_db.destroy!
      log_info "🗑️ Message cache database cleared for '#{@account_name}'."
      db_cleared = true
    end

    token_cleared = false
    if File.exist?(token_path)
      File.delete(token_path)
      log_info "🗑️ Authentication token cleared for '#{@account_name}'."
      token_cleared = true
    end

    if db_cleared || token_cleared
      log_success "Cache clearing process complete for '#{@account_name}'."
      log_info 'You will need to re-authorize on the next run.' if token_cleared
    else
      log_info "No cache or token found to clear for '#{@account_name}'."
    end
  end

  def refresh_cache(service, user_id)
    log_info '🔄 Refreshing message cache'

    # Get latest messages from Gmail
    update_message_cache(service, user_id, force_update: true)

    log_success 'Cache refreshed with latest messages'
  end

  def update_message_cache(service, user_id, force_update: false)
    @interrupted = false
    setup_interrupt_handler

    # Thread management
    num_threads = 10
    work_queue = Queue.new
    results_queue = Queue.new
    threads = []
    progress_mutex = Mutex.new
    credentials = service.authorization


    # Get the latest message date from cache to only fetch newer messages
    gmail_db.latest_message_date unless force_update

    total_messages = 0
    next_page_token = nil
    new_messages = 0
    batch_messages = []

    # Check if there's a previous interrupted session
    cached_count = gmail_db.inbox_message_count

    # First, get accurate count for progress bar by counting all message IDs
    log_progress 'Getting accurate message count'
    actual_total = 0
    count_token = nil

    begin
      loop do
        return if @interrupted

        count_result = service.list_user_messages(
          user_id,
          label_ids: ['INBOX'],
          max_results: 500,
          page_token: count_token
        )

        break unless count_result.messages

        actual_total += count_result.messages.length
        count_token = count_result.next_page_token
        break unless count_token
      end
    rescue Interrupt
      handle_graceful_interruption(batch_messages)
      return
    end

    # Show progress info
    if cached_count > 0
      remaining = actual_total - cached_count
      log_info "📦 Found #{cached_count} cached messages, #{remaining} remaining to process"
    end

    # Progress bar with accurate total and current position
    current_progress = cached_count
    progress = TTY::ProgressBar.new(
      "🔄 Updating cache [:bar] :current/#{actual_total} (:percent)",
      total: actual_total,
      width: 30,
      bar_format: :block
    )

    # Set progress to current cache state
    progress.current = current_progress

    begin
      loop do
        return if @interrupted

        result = service.list_user_messages(
          user_id,
          label_ids: ['INBOX'],
          max_results: 100,
          page_token: next_page_token
        )

        break unless result.messages

        # Instead of processing sequentially, push to work queue
        result.messages.each do |message|
          work_queue << message
        end

        next_page_token = result.next_page_token
        break unless next_page_token
      end

      # Signal that no more work will be added
      num_threads.times { work_queue << :done }

      # Create worker threads
      num_threads.times do
        threads << Thread.new do
          # Create a thread-local service object
          thread_service = Google::Apis::GmailV1::GmailService.new
          thread_service.client_options.application_name = APPLICATION_NAME
          thread_service.authorization = credentials

          loop do
            message = work_queue.pop
            break if message == :done || @interrupted

            # Check if message already exists in cache
            if !force_update && gmail_db.message_exists?(message.id)
              progress_mutex.synchronize { progress.advance(1) }
              next
            end

            begin
              # Fetch full message details with timeout protection
              msg = Timeout.timeout(30) do
                thread_service.get_user_message(user_id, message.id, format: 'full')
              end

              # Extract metadata
              headers = msg.payload.headers
              from_header = headers.find { |h| h.name == 'From' }&.value
              subject = headers.find { |h| h.name == 'Subject' }&.value
              date_header = headers.find { |h| h.name == 'Date' }&.value

              from_email = from_header ? extract_email(from_header) : nil
              from_name = from_header ? extract_name(from_header) : nil
              date_received = date_header ? Time.parse(date_header).to_i : nil
              labels = msg.label_ids.join(',') if msg.label_ids

              # Extract attachment information
              attachments = extract_attachments(msg.payload, message.id)

              # Push result to queue
              results_queue << {
                id: message.id,
                thread_id: msg.thread_id,
                from_email: from_email,
                from_name: from_name,
                subject: subject,
                date_received: date_received,
                snippet: msg.snippet,
                body: msg.payload.parts&.find { |p| p.mime_type == 'text/plain' }&.body&.data,
                labels: labels,
                attachments: attachments
              }
            rescue Timeout::Error
              log_warning "Timeout processing message #{message.id} - skipping"
              progress_mutex.synchronize { progress.advance(1) }
            rescue StandardError => e
              log_warning "Failed to process message #{message.id}: #{e.message}"
              progress_mutex.synchronize { progress.advance(1) }
            end
          end
        end
      end

      # Results processing thread
      results_processor = Thread.new do
        batch_attachments = []
        
        loop do
          result = results_queue.pop
          break if result == :done

          # Separate attachments from message data
          attachments = result.delete(:attachments) || []
          batch_messages << result
          batch_attachments.concat(attachments) if attachments.any?
          
          new_messages += 1
          total_messages += 1
          progress_mutex.synchronize { progress.advance(1) }

          if batch_messages.length >= 50
            gmail_db.store_messages(batch_messages)
            gmail_db.store_attachments(batch_attachments) if batch_attachments.any?
            batch_messages.clear
            batch_attachments.clear
          end
        end
        
        # Store any remaining attachments
        gmail_db.store_attachments(batch_attachments) if batch_attachments.any?
      end


      # Wait for worker threads to finish
      threads.each(&:join)
      results_queue << :done # Signal results processor to finish
      results_processor.join

      # Store any remaining messages
      gmail_db.store_messages(batch_messages) unless batch_messages.empty?
    rescue Interrupt
      handle_graceful_interruption(batch_messages)
      return
    ensure
      progress.finish unless @interrupted
      restore_interrupt_handler
    end

    if @interrupted
      log_info '🛑 Cache update interrupted by user'
      log_info "💾 Progress saved: #{new_messages} new messages cached"
      log_info '🔄 Run the command again to continue where you left off'
    else
      final_count = gmail_db.inbox_message_count
      if new_messages == 0
        log_info "✅ Cache is already up to date (#{final_count} messages)"
      else
        log_success "✅ Cache updated with #{new_messages} new messages"
        log_info "📦 Total messages in cache: #{final_count}"
      end
    end
  end

  def setup_interrupt_handler
    @original_int_handler = Signal.trap('INT') do
      @interrupted = true
      puts "\n"
      log_info '🛑 Interruption received, finishing current batch...'
      log_info '⏳ Please wait while we save progress...'
    end
  end

  def restore_interrupt_handler
    Signal.trap('INT', @original_int_handler) if @original_int_handler
  end

  def handle_graceful_interruption(batch_messages)
    # Save any messages in the current batch
    unless batch_messages.empty?
      log_progress 'Saving current batch'
      gmail_db.store_messages(batch_messages)
      log_info "💾 Saved #{batch_messages.length} messages from current batch"
    end

    @interrupted = true
  end

  def archive_by_sender(service, user_id)
    log_info '📦 Archive emails by sender'
    puts

    begin
      # Ensure cache is up to date
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building cache for sender analysis'
        update_message_cache(service, user_id)
      else
        log_info '📦 Using cached data for sender selection'
      end

      # Get all senders
      all_senders = gmail_db.get_top_inbox_senders(limit: 200)
      
      if all_senders.empty?
        log_info 'No senders found in inbox'
        return
      end

      puts
      log_info "📊 Found #{all_senders.length} senders in your inbox"
      puts

      # Use the interactive selectable list
      header = "📦 Archive Emails by Sender\n📊 Select senders to archive their messages"
      
      display_proc = proc do |sender|
        display_name = sender[:name] == sender[:email] ? sender[:email] : "#{sender[:name]} <#{sender[:email]}>"
        main_line = "#{display_name} (#{sender[:count]} messages)"
        
        # Add email as second line if name is different from email
        if sender[:name] != sender[:email]
          main_line += "\n      📧 #{sender[:email]}"
        end
        
        main_line
      end

      # Show interactive list
      selected_senders = interactive_selectable_list(
        all_senders,
        display_proc: display_proc,
        multi_select: true,
        header: header
      )
      
      if selected_senders.empty?
        log_info 'No senders selected for archiving'
        return
      end
      
      # Show final selection summary
      total_to_archive = selected_senders.sum { |s| s[:count] }
      
      puts
      log_info '📋 Final Selection:'
      selected_senders.each_with_index do |sender, index|
        puts "  #{index + 1}. #{sender[:name]} (#{sender[:email]}) - #{sender[:count]} messages"
      end
      puts
      log_info "📊 Total: #{selected_senders.length} senders, #{total_to_archive} messages"
      puts
      
      # Final confirmation
      unless confirm_action("⚠️  Archive ALL #{total_to_archive} messages from #{selected_senders.length} selected sender(s)?")
        log_info 'Archive operation cancelled'
        return
      end
      
      # Perform the archive operation for each sender
      selected_senders.each do |sender|
        archive_messages_from_sender(service, user_id, sender[:email], sender[:count])
      end
      
      log_complete "Archive operation completed for #{selected_senders.length} sender(s)"

    rescue StandardError => e
      log_error "Error during archive operation: #{e.message}"
      if @options[:debug]
        puts
        e.backtrace.first(5).each { |line| puts "  #{line}" }
      end
    end
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

  def parse_selection_for_infinite_scroll(input_str, current_display, end_display)
    indices = []
    parts = input_str.split(',').map(&:strip)

    parts.each do |part|
      if part.include?('-')
        start_num, end_num = part.split('-').map(&:to_i)
        raise "Invalid range format" if start_num.nil? || end_num.nil?
        
        # Convert to 0-based indices
        start_idx = start_num - 1
        end_idx = end_num - 1
        
        # Validate range is within current display or global range
        (start_idx..end_idx).each do |idx|
          if idx >= 0 && idx < 200 # Global limit we're using
            indices << idx
          end
        end
      else
        num = part.to_i
        raise "Invalid number format" if num.zero? && part != '0'
        
        idx = num - 1
        if idx >= 0 && idx < 200 # Global limit we're using
          indices << idx
        end
      end
    end

    raise "No valid selections found" if indices.empty?
    indices.uniq.sort
  end
  def archive_messages_from_sender(service, user_id, sender_email, _expected_count)
    log_info "🔄 Archiving messages from #{sender_email}"
    puts

    # Get all message IDs from this sender in inbox
    messages_to_archive = gmail_db.messages_by_sender(sender_email)
    message_ids = messages_to_archive.map { |msg| msg['id'] }

    if message_ids.empty?
      log_info 'No messages to archive'
      return
    end

    archived_count = 0

    with_progress('📦 Archiving messages', total: message_ids.length) do |progress|
      # Archive messages in batches
      message_ids.each_slice(100) do |batch_ids|
        begin
          # Create modify request to remove INBOX label (which archives the message)
          modify_request = Google::Apis::GmailV1::BatchModifyMessagesRequest.new(
            ids: batch_ids,
            remove_label_ids: ['INBOX']
          )

          # Apply the modification via Gmail API
          service.batch_modify_messages(user_id, modify_request)

          archived_count += batch_ids.length
          progress.advance(batch_ids.length)
        rescue StandardError => e
          log_warning "Failed to archive batch: #{e.message}"
          # Continue with next batch
          progress.advance(batch_ids.length)
        end
      end
    end

    # Update local cache
    log_progress 'Updating local cache'
    cache_archived_count = gmail_db.archive_sender_messages(sender_email)

    puts
    log_success '✅ Archive operation completed'
    log_info "📦 Messages archived: #{archived_count}"
    log_info "💾 Cache updated: #{cache_archived_count} messages marked as archived"

    # Show updated inbox stats
    updated_inbox_count = gmail_db.inbox_message_count
    log_info "📊 Remaining inbox messages: #{updated_inbox_count}"

    puts
    log_info "💡 Archived messages can be found in Gmail's All Mail label"
  end

  def archive_by_domain(service, user_id)
    log_info '🌐 Archive emails by domain'
    puts

    begin
      # Ensure cache is up to date
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building cache for domain analysis'
        update_message_cache(service, user_id)
      else
        log_info '📦 Using cached data for domain selection'
      end

      # Get all domains
      all_domains = gmail_db.get_domain_stats(limit: 200)
      
      if all_domains.empty?
        log_info 'No domains found in inbox'
        return
      end

      puts
      log_info "📊 Found #{all_domains.length} domains in your inbox"
      puts

      # Use the interactive selectable list
      header = "🌐 Archive Emails by Domain\n📊 Select domains to archive their messages"
      
      display_proc = proc do |domain_info|
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

      # Show interactive list
      selected_domains = interactive_selectable_list(
        all_domains,
        display_proc: display_proc,
        multi_select: true,
        header: header
      )
      
      if selected_domains.empty?
        log_info 'No domains selected for archiving'
        return
      end
      
      # Show final selection summary
      total_to_archive = selected_domains.sum { |d| d[:count] }
      
      puts
      log_info '📋 Final Selection:'
      selected_domains.each_with_index do |domain_info, index|
        puts "  #{index + 1}. #{domain_info[:domain]} - #{domain_info[:count]} messages"
      end
      puts
      log_info "📊 Total: #{selected_domains.length} domains, #{total_to_archive} messages"
      puts
      
      # Final confirmation
      unless confirm_action("⚠️  Archive ALL #{total_to_archive} messages from #{selected_domains.length} selected domain(s)?")
        log_info 'Archive operation cancelled'
        return
      end
      
      # Perform the archive operation for each domain
      selected_domains.each do |domain_info|
        archive_messages_from_domain(service, user_id, domain_info[:domain], domain_info[:count])
      end
      
      log_complete "Archive operation completed for #{selected_domains.length} domain(s)"

    rescue StandardError => e
      log_error "Error during archive operation: #{e.message}"
      if @options[:debug]
        puts
        e.backtrace.first(5).each { |line| puts "  #{line}" }
      end
    end
  end

  def archive_messages_from_domain(service, user_id, domain, _expected_count)
    log_info "🔄 Archiving messages from #{domain}"
    puts

    # Get all message IDs from this domain in inbox
    messages_to_archive = gmail_db.messages_by_domain(domain)
    message_ids = messages_to_archive.map { |msg| msg['id'] }

    if message_ids.empty?
      log_info 'No messages to archive'
      return
    end

    archived_count = 0

    with_progress('🌐 Archiving messages', total: message_ids.length) do |progress|
      # Archive messages in batches
      message_ids.each_slice(100) do |batch_ids|
        begin
          # Create modify request to remove INBOX label (which archives the message)
          modify_request = Google::Apis::GmailV1::BatchModifyMessagesRequest.new(
            ids: batch_ids,
            remove_label_ids: ['INBOX']
          )

          # Apply the modification via Gmail API
          service.batch_modify_messages(user_id, modify_request)

          archived_count += batch_ids.length
          progress.advance(batch_ids.length)
        rescue StandardError => e
          log_warning "Failed to archive batch: #{e.message}"
          # Continue with next batch
          progress.advance(batch_ids.length)
        end
      end
    end

    # Update local cache
    log_progress 'Updating local cache'
    cache_archived_count = gmail_db.archive_domain_messages(domain)

    puts
    log_success '✅ Archive operation completed'
    log_info "🌐 Messages archived: #{archived_count}"
    log_info "💾 Cache updated: #{cache_archived_count} messages marked as archived"

    # Show updated inbox stats
    updated_inbox_count = gmail_db.inbox_message_count
    log_info "📊 Remaining inbox messages: #{updated_inbox_count}"

    puts
    log_info "💡 Archived messages can be found in Gmail's All Mail label"
  end

  def show_setup_instructions
    log_info '🛠️  Gmail Inbox Setup Instructions'
    puts
    puts <<~INSTRUCTIONS
      #{' ' * 4}📝 Step 1: Create Google Cloud Project & Enable Gmail API
      #{' ' * 8}• Go to: https://console.cloud.google.com/
      #{' ' * 8}• Create a new project (or select existing one)
      #{' ' * 8}• Navigate to: APIs & Services → Library
      #{' ' * 8}• Search for "Gmail API" and click "Enable"

      #{' ' * 4}🔐 Step 2: Create OAuth Credentials
      #{' ' * 8}• Go to: APIs & Services → Credentials
      #{' ' * 8}• Click: "+ CREATE CREDENTIALS" → "OAuth client ID"
      #{' ' * 8}• If prompted, configure consent screen:
      #{' ' * 12}- User Type: External (no verification needed for personal use)
      #{' ' * 12}- Fill required fields, then "Save and Continue" through all steps
      #{' ' * 8}• For Application type: select "Desktop application"
      #{' ' * 8}• Click "Create"

      #{' ' * 4}💾 Step 3: Download & Save Credentials
      #{' ' * 8}• Click "DOWNLOAD JSON" button
      #{' ' * 8}• Save the file as: #{CREDENTIALS_PATH}

      #{' ' * 4}🚀 Step 4: Run Script
      #{' ' * 8}• Run: gmail-inbox
    INSTRUCTIONS
  end

  def reset_authentication
    select_account unless @account_name
    if File.exist?(token_path)
      log_info "🔄 Removing stored authentication for '#{@account_name}'"
      File.delete(token_path)
      log_success "Authentication reset. You'll be prompted to re-authorize on next run"
    else
      log_info "No stored authentication found for '#{@account_name}'"
    end
  end

  def cleanup_failed_token
    return unless File.exist?(token_path)

    log_info "🧹 Cleaning up failed authentication token for '#{@account_name}'"
    File.delete(token_path)
  end

  def show_inbox_summary(service, user_id)
    log_info '📊 Inbox Summary'
    puts

    # Safety check for pastel initialization
    unless @pastel
      log_debug "Pastel not initialized, creating new instance"
      @pastel = Pastel.new
    end
    log_debug "Pastel instance: #{@pastel.class}"

    begin
      # Check if we need to update cache first
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building initial cache'
        update_message_cache(service, user_id)
        gmail_db.inbox_message_count
      else
        log_info "📦 Using cached data (#{cached_count} messages)"
        # Update cache with any new messages (incremental)
        update_message_cache(service, user_id, force_update: false)
      end

      puts

      # Get counts from cache and live API
      log_progress 'Getting current inbox statistics'

      # Get total from cache (much faster)
      total_messages = gmail_db.inbox_message_count

      # Debug: Check cache completeness
      total_in_cache = gmail_db.execute_scalar('SELECT COUNT(*) FROM messages')
      log_debug "📊 Cache contains #{total_in_cache} total messages (#{total_messages} in inbox)"

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
        puts @pastel.decorate(font.write("INBOX"), :green)
      rescue StandardError => e
        # Fallback header
        log_debug "Font error: #{e.message}"
        puts @pastel.decorate("📊 INBOX SUMMARY", :bold, :green)
        puts "=" * 50
      end
      puts

      # Create stats table
      log_debug "Creating stats table..."
      begin
        stats_data = [
          [@pastel.decorate("📬", :cyan), @pastel.decorate("Total Messages", :white), @pastel.decorate("#{total_messages}", :yellow), @pastel.decorate("(from cache)", :dim)],
          [@pastel.decorate("📩", :blue), @pastel.decorate("Unread Messages", :white), @pastel.decorate("#{unread_messages}", :red), @pastel.decorate("(live count)", :dim)],
          [@pastel.decorate("📖", :green), @pastel.decorate("Read Messages", :white), @pastel.decorate("#{read_messages}", :green), @pastel.decorate("", :dim)]
        ]
        log_debug "Basic stats data created"

        if total_messages > 0
          unread_percentage = ((unread_messages.to_f / total_messages) * 100).round(1)
          color = unread_percentage > 50 ? :red : unread_percentage > 25 ? :yellow : :green
          log_debug "Adding percentage row with color: #{color}"
          stats_data << [
            @pastel.decorate("📈", :magenta), @pastel.decorate("Unread Percentage", :white), @pastel.decorate("#{unread_percentage}%", color), @pastel.decorate("", :dim)
          ]
        end
        log_debug "Stats data complete"

        # Create and display stats table
        log_debug "Creating table headers..."
        stats_table = TTY::Table.new(
          [@pastel.decorate('', :cyan, :bold), @pastel.decorate('Metric', :cyan, :bold), @pastel.decorate('Count', :cyan, :bold), @pastel.decorate('Source', :cyan, :bold)],
          stats_data
        )
        log_debug "Table created successfully"
      rescue StandardError => e
        log_error "Error in stats table creation: #{e.message}"
        log_error "Backtrace: #{e.backtrace.first(5).join(', ')}"
        raise e
      end

      puts stats_table.render(:unicode, padding: [0, 1])
      puts

      # Status box based on inbox health
      if unread_messages == 0
        status_box = TTY::Box.frame(
          padding: 1,
          border: :thick,
          style: { border: { fg: :green } }
        ) do
          @pastel.decorate("🎉 Inbox Zero achieved! Great job!", :green)
        end
      elsif unread_percentage > 75
        status_box = TTY::Box.frame(
          padding: 1,
          border: :thick,
          style: { border: { fg: :red } }
        ) do
          @pastel.decorate("⚠️  High unread rate (#{unread_percentage}%) - consider email management", :red)
        end
      else
        status_box = TTY::Box.frame(
          padding: 1,
          border: :thick,
          style: { border: { fg: :yellow } }
        ) do
          @pastel.decorate("📊 #{unread_messages} messages awaiting attention", :yellow)
        end
      end

      puts status_box
    rescue StandardError => e
      log_error "Could not fetch inbox summary: #{e.message}"
      log_error "Backtrace:"
      e.backtrace.first(10).each { |line| log_error "  #{line}" }
    end
  end

  def check_credentials
    return if File.exist?(CREDENTIALS_PATH)

    log_error '🔒 Gmail API credentials not found'
    puts
    log_info '🛠️  One-time setup required. Follow these steps:'
    puts
    puts <<~INSTRUCTIONS
      #{' ' * 4}📝 Step 1: Create Google Cloud Project & Enable Gmail API
      #{' ' * 8}• Go to: https://console.cloud.google.com/
      #{' ' * 8}• Create a new project (or select existing one)
      #{' ' * 8}• Navigate to: APIs & Services → Library
      #{' ' * 8}• Search for "Gmail API" and click "Enable"

      #{' ' * 4}🔐 Step 2: Create OAuth Credentials
      #{' ' * 8}• Go to: APIs & Services → Credentials
      #{' ' * 8}• Click: "+ CREATE CREDENTIALS" → "OAuth client ID"
      #{' ' * 8}• If prompted, configure consent screen:
      #{' ' * 12}- User Type: External (no verification needed for personal use)
      #{' ' * 12}- Fill required fields, then "Save and Continue" through all steps
      #{' ' * 8}• For Application type: select "Desktop application"
      #{' ' * 8}• Click "Create"

      #{' ' * 4}💾 Step 3: Download & Save Credentials
      #{' ' * 8}• Click "DOWNLOAD JSON" button
      #{' ' * 8}• Save the file as: #{CREDENTIALS_PATH}

      #{' ' * 4}🚀 Step 4: Run Script Again
      #{' ' * 8}• Once credentials are saved, run: gmail-inbox
    INSTRUCTIONS
    puts
    log_info '💡 Need help? The credentials directory will be created automatically'

    # Ensure credentials directory exists
    credentials_dir = File.dirname(CREDENTIALS_PATH)
    unless Dir.exist?(credentials_dir)
      FileUtils.mkdir_p(credentials_dir)
      log_success "Created credentials directory: #{credentials_dir}"
    end

    exit 1
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = @account_name
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)

      log_info "🔐 First-time setup for account '#{@account_name}'"
      puts
      puts "#{' ' * 4}📋 Follow these steps:"
      puts "#{' ' * 4}1️⃣  Copy this URL and open it in your browser:"
      puts
      puts "#{' ' * 8}#{url}"
      puts
      puts "#{' ' * 4}2️⃣  Sign in to your Google account and authorize the app"
      puts "#{' ' * 4}3️⃣  Copy the authorization code from the browser"
      puts "#{' ' * 4}4️⃣  Paste the code below and press Enter"
      puts
      puts '─' * 80
      print '🔑 Authorization code: '

      code = STDIN.gets.strip

      if code.empty? || code.downcase == 'exit' || code.downcase == 'quit'
        log_info 'Setup cancelled by user'
        exit 0
      end

      # Basic validation - Google auth codes are typically long alphanumeric strings
      if code.length < 10 || code.match?(/\s/)
        log_error 'Invalid authorization code format. Please copy the full code from your browser'
        exit 1
      end

      log_progress 'Validating authorization code'

      begin
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: OOB_URI
        )

        if credentials
          log_success 'Authorization successful! Credentials saved for future use'
          puts
        else
          log_error 'Authorization failed. The code may be invalid or expired'
          cleanup_failed_token
          puts
          log_info "💡 Try running 'gmail-inbox --reset-auth' and then 'gmail-inbox' to get a fresh authorization URL"
          exit 1
        end
      rescue StandardError => e
        log_error "Authorization failed: #{e.message}"
        cleanup_failed_token
        puts
        log_info '💡 Common issues:'
        log_info '   • Code expired (they expire quickly - get a fresh one)'
        log_info '   • Code was copied incorrectly (make sure to copy the entire code)'
        log_info "   • Wrong OAuth app type (should be 'Desktop application')"
        puts
        log_info "Run 'gmail-inbox --reset-auth' and try again with a fresh authorization code"
        exit 1
      end
    else
      log_info "Authenticated using stored credentials for '#{@account_name}'"
    end
    credentials
  end
end

# Execute the script
GmailInbox.execute if __FILE__ == $0
