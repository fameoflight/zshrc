# frozen_string_literal: true

require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'timeout'
require 'securerandom'
require 'tty-progressbar'
require_relative 'view'

# Gmail API service wrapper
# Handles authentication, message fetching, and caching operations
class GmailService
  include View

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Gmail Inbox Fetcher'
  SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_MODIFY

  attr_reader :service, :account_name, :credentials_path, :token_dir

  def initialize(account_name, credentials_path, token_dir)
    @account_name = account_name
    @credentials_path = credentials_path
    @token_dir = token_dir
    @interrupted = false
    @original_int_handler = nil
    ensure_directories
    setup_service
  end

  def setup_service
    @service = Google::Apis::GmailV1::GmailService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def ensure_directories
    dirs = [
      File.dirname(@credentials_path),
      @token_dir,
      File.dirname(@token_dir) # Ensure parent directory exists
    ]

    dirs.each do |dir|
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end
  end

  def token_path
    File.join(@token_dir, "#{@account_name}.yaml")
  end

  def check_credentials
    return if File.exist?(@credentials_path)

    log_error('🔒 Gmail API credentials not found')
    puts
    show_setup_instructions
    FileUtils.mkdir_p(File.dirname(@credentials_path)) unless Dir.exist?(File.dirname(@credentials_path))
    exit 1
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file(@credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    credentials = authorizer.get_credentials(@account_name)

    if credentials.nil?
      credentials = handle_first_time_auth(authorizer)
    else
      log_info("Authenticated using stored credentials for '#{@account_name}'")
    end

    credentials
  end

  def reset_authentication
    if File.exist?(token_path)
      log_info("🔄 Removing stored authentication for '#{@account_name}'")
      File.delete(token_path)
      log_success('Authentication reset. You\'ll be prompted to re-authorize on next run')
    else
      log_info("No stored authentication found for '#{@account_name}'")
    end
  end

  def update_message_cache(user_id, gmail_db, force_update: false)
    @interrupted = false
    setup_interrupt_handler

    # Thread management
    num_threads = 10
    work_queue = Queue.new
    results_queue = Queue.new
    progress_mutex = Mutex.new
    credentials = @service.authorization

    # Get the latest message date from cache to only fetch newer messages
    gmail_db.latest_message_date unless force_update
    new_messages = 0
    batch_messages = []

    # Check if there's a previous interrupted session
    cached_count = gmail_db.inbox_message_count

    # First, get accurate count for progress bar by counting all message IDs
    log_progress('Getting accurate message count')
    actual_total = count_all_messages(user_id)
    return if @interrupted

    # Show progress info
    if cached_count > 0
      remaining = actual_total - cached_count
      log_info("📦 Found #{cached_count} cached messages, #{remaining} remaining to process")
    end

    # Progress bar with accurate total and current position
    current_progress = cached_count
    progress = create_progress_bar(actual_total, current_progress)

    begin
      # Fetch all message IDs and queue them for processing
      queue_messages_for_processing(user_id, work_queue, num_threads)
      return if @interrupted

      # Create worker threads
      threads = create_worker_threads(num_threads, work_queue, results_queue, user_id,
                                      credentials, progress_mutex, progress, force_update, gmail_db)

      # Results processing thread
      results_processor = create_results_processor(results_queue, batch_messages,
                                                   progress_mutex, progress, gmail_db)

      # Wait for completion
      threads.each(&:join)
      results_queue << :done
      results_processor.join

      # Store any remaining messages
      gmail_db.store_messages(batch_messages) unless batch_messages.empty?
    rescue Interrupt
      handle_graceful_interruption(batch_messages, gmail_db)
      return
    ensure
      progress.finish unless @interrupted
      restore_interrupt_handler
    end

    show_completion_message(gmail_db, new_messages)
  end

  def list_messages(user_id, max_results: 10, label_ids: ['INBOX'])
    @service.list_user_messages(user_id, max_results: max_results, label_ids: label_ids)
  rescue Google::Apis::AuthorizationError, Google::Apis::ClientError => e
    result = handle_auth_failure(e)
    retry if result == :retry
  end

  def get_message(user_id, message_id, format: 'full')
    @service.get_user_message(user_id, message_id, format: format)
  rescue Google::Apis::AuthorizationError, Google::Apis::ClientError => e
    result = handle_auth_failure(e)
    retry if result == :retry
  end

  def batch_modify_messages(user_id, modify_request)
    @service.batch_modify_messages(user_id, modify_request)
  rescue Google::Apis::AuthorizationError, Google::Apis::ClientError => e
    result = handle_auth_failure(e)
    retry if result == :retry
  end

  # Utility method for file size formatting

  private

  def handle_auth_failure(error)
    # Only handle authentication errors
    if error.is_a?(Google::Apis::AuthorizationError) ||
       (error.is_a?(Google::Apis::ClientError) && [401, 403].include?(error.status_code))

      log_warning("🔒 Authentication failed: #{error.message}")

      # Try to refresh the token first
      if try_token_refresh
        log_info('✅ Token refreshed successfully, retrying operation')
        return :retry
      end

      # If refresh failed, clear everything
      log_error('❌ Token refresh failed')
      log_info('🧹 Clearing invalid token and cache...')

      # Clear token file
      File.delete(token_path) if File.exist?(token_path)

      # Clear cache if we have access to it
      cache_file = File.join(File.dirname(@token_dir), 'cache', "#{@account_name}.sqlite.db")
      File.delete(cache_file) if File.exist?(cache_file)

      log_error('❌ Please run the command again to re-authenticate')
      exit 1
    else
      # Re-raise other errors
      raise error
    end
  end

  def try_token_refresh
    log_debug('🔄 Attempting to refresh token...')

    # Get fresh credentials from the authorizer
    client_id = Google::Auth::ClientId.from_file(@credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

    # Try to get credentials (this should trigger refresh if possible)
    fresh_credentials = authorizer.get_credentials(@account_name)

    if fresh_credentials
      # Update the service with fresh credentials
      @service.authorization = fresh_credentials
      log_debug('✅ Successfully refreshed credentials')
      true
    else
      log_debug('❌ Could not get fresh credentials')
      false
    end
  rescue StandardError => e
    log_debug("❌ Token refresh failed: #{e.message}")
    false
  end

  def handle_first_time_auth(authorizer)
    url = authorizer.get_authorization_url(base_url: OOB_URI)

    log_info("🔐 First-time setup for account '#{@account_name}'")
    puts
    show_auth_instructions(url)

    code = get_auth_code_from_user
    validate_and_store_credentials(authorizer, code)
  end

  def show_setup_instructions
    puts <<~INSTRUCTIONS
      🛠️  Gmail Inbox Setup Instructions

          📝 Step 1: Create Google Cloud Project & Enable Gmail API
              • Go to: https://console.cloud.google.com/
              • Create a new project (or select existing one)
              • Navigate to: APIs & Services → Library
              • Search for "Gmail API" and click "Enable"

          🔐 Step 2: Create OAuth Credentials
              • Go to: APIs & Services → Credentials
              • Click: "+ CREATE CREDENTIALS" → "OAuth client ID"
              • If prompted, configure consent screen:
                  - User Type: External (no verification needed for personal use)
                  - Fill required fields, then "Save and Continue" through all steps
              • For Application type: select "Desktop application"
              • Click "Create"

          💾 Step 3: Download & Save Credentials
              • Click "DOWNLOAD JSON" button
              • Save the file as: #{@credentials_path}

          🚀 Step 4: Run Script Again
              • Once credentials are saved, run: gmail-inbox
    INSTRUCTIONS
  end

  def show_auth_instructions(url)
    puts '    📋 Follow these steps:'
    puts '    1️⃣  Copy this URL and open it in your browser:'
    puts
    puts "        #{url}"
    puts
    puts '    2️⃣  Sign in to your Google account and authorize the app'
    puts '    3️⃣  Copy the authorization code from the browser'
    puts '    4️⃣  Paste the code below and press Enter'
    puts
    puts '─' * 80
    print '🔑 Authorization code: '
  end

  def get_auth_code_from_user
    code = STDIN.gets.strip

    if code.empty? || %w[exit quit].include?(code.downcase)
      log_info('Setup cancelled by user')
      exit 0
    end

    # Basic validation - Google auth codes are typically long alphanumeric strings
    if code.length < 10 || code.match?(/\s/)
      log_error('Invalid authorization code format. Please copy the full code from your browser')
      exit 1
    end

    code
  end

  def validate_and_store_credentials(authorizer, code)
    log_progress('Validating authorization code')

    begin
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: @account_name, code: code, base_url: OOB_URI
      )

      if credentials
        log_success('Authorization successful! Credentials saved for future use')
        puts
        credentials
      else
        handle_auth_failure
      end
    rescue StandardError => e
      handle_auth_error(e)
    end
  end

  def handle_auth_failure
    log_error('Authorization failed. The code may be invalid or expired')
    cleanup_failed_token
    puts
    log_info("💡 Try running 'gmail-inbox --reset-auth' and then 'gmail-inbox' to get a fresh authorization URL")
    exit 1
  end

  def handle_auth_error(error)
    log_error("Authorization failed: #{error.message}")
    cleanup_failed_token
    puts
    show_auth_troubleshooting
    exit 1
  end

  def show_auth_troubleshooting
    log_info('💡 Common issues:')
    log_info('   • Code expired (they expire quickly - get a fresh one)')
    log_info('   • Code was copied incorrectly (make sure to copy the entire code)')
    log_info('   • Wrong OAuth app type (should be \'Desktop application\')')
    puts
    log_info('Run \'gmail-inbox --reset-auth\' and try again with a fresh authorization code')
  end

  def cleanup_failed_token
    return unless File.exist?(token_path)

    log_info("🧹 Cleaning up failed authentication token for '#{@account_name}'")
    File.delete(token_path)
  end

  def count_all_messages(user_id)
    actual_total = 0
    count_token = nil

    loop do
      return actual_total if @interrupted

      count_result = @service.list_user_messages(
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

    actual_total
  rescue Interrupt
    handle_graceful_interruption([], nil)
    actual_total
  end

  def create_progress_bar(total, current)
    progress = TTY::ProgressBar.new(
      "🔄 Updating cache [:bar] :current/#{total} (:percent)",
      total: total,
      width: 30,
      bar_format: :block
    )
    progress.current = current
    progress
  end

  def queue_messages_for_processing(user_id, work_queue, num_threads)
    next_page_token = nil

    loop do
      return if @interrupted

      result = @service.list_user_messages(
        user_id,
        label_ids: ['INBOX'],
        max_results: 100,
        page_token: next_page_token
      )

      break unless result.messages

      result.messages.each { |message| work_queue << message }
      next_page_token = result.next_page_token
      break unless next_page_token
    end

    # Signal that no more work will be added
    num_threads.times { work_queue << :done }
  end

  def create_worker_threads(num_threads, work_queue, results_queue, user_id, credentials,
                            progress_mutex, progress, force_update, gmail_db)
    threads = []

    num_threads.times do
      threads << Thread.new do
        process_messages_in_thread(work_queue, results_queue, user_id, credentials,
                                   progress_mutex, progress, force_update, gmail_db)
      end
    end

    threads
  end

  def process_messages_in_thread(work_queue, results_queue, user_id, credentials,
                                 progress_mutex, progress, force_update, gmail_db)
    # Create a thread-local service object
    thread_service = Google::Apis::GmailV1::GmailService.new
    thread_service.client_options.application_name = APPLICATION_NAME
    thread_service.authorization = credentials

    loop do
      message = work_queue.pop
      break if message == :done || @interrupted

      # Check if message already exists in cache
      if !force_update && gmail_db.message_exists?(message.id)
        # Still need to check if labels have changed (e.g., archived)
        # Get minimal message info to check current labels
        begin
          current_msg = thread_service.get_user_message(user_id, message.id, format: 'minimal')
          current_labels = current_msg.label_ids || []

          # Update labels in cache if they've changed
          gmail_db.update_message_labels(message.id, current_labels.join(','))
        rescue StandardError => e
          # If we can't get current labels, skip this optimization
          log_debug("Couldn't check labels for existing message #{message.id}: #{e.message}")
        end

        progress_mutex.synchronize { progress.advance(1) }
        next
      end

      process_single_message(thread_service, user_id, message, results_queue,
                             progress_mutex, progress)
    end
  end

  def process_single_message(thread_service, user_id, message, results_queue,
                             progress_mutex, progress)
    # Fetch full message details with timeout protection
    msg = Timeout.timeout(30) do
      thread_service.get_user_message(user_id, message.id, format: 'full')
    end

    # Extract and queue result
    result = extract_message_data(msg, message.id)
    results_queue << result
  rescue Timeout::Error
    log_warning("Timeout processing message #{message.id} - skipping")
    progress_mutex.synchronize { progress.advance(1) }
  rescue StandardError => e
    log_warning("Failed to process message #{message.id}: #{e.message}")
    progress_mutex.synchronize { progress.advance(1) }
  end

  def extract_message_data(msg, message_id)
    headers = msg.payload.headers
    from_header = headers.find { |h| h.name == 'From' }&.value
    subject = headers.find { |h| h.name == 'Subject' }&.value
    date_header = headers.find { |h| h.name == 'Date' }&.value

    from_email = from_header ? extract_email(from_header) : nil
    from_name = from_header ? extract_name(from_header) : nil
    date_received = date_header ? Time.parse(date_header).to_i : nil
    labels = msg.label_ids.join(',') if msg.label_ids

    # Extract attachment information
    attachments = extract_attachments(msg.payload, message_id)

    {
      id: message_id,
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

  def create_results_processor(results_queue, batch_messages, progress_mutex, progress, gmail_db)
    Thread.new do
      batch_attachments = []

      loop do
        result = results_queue.pop
        break if result == :done

        # Separate attachments from message data
        attachments = result.delete(:attachments) || []
        batch_messages << result
        batch_attachments.concat(attachments) if attachments.any?

        progress_mutex.synchronize { progress.advance(1) }

        next unless batch_messages.length >= 50

        gmail_db.store_messages(batch_messages)
        gmail_db.store_attachments(batch_attachments) if batch_attachments.any?
        batch_messages.clear
        batch_attachments.clear
      end

      # Store any remaining attachments
      gmail_db.store_attachments(batch_attachments) if batch_attachments.any?
    end
  end

  def setup_interrupt_handler
    @original_int_handler = Signal.trap('INT') do
      @interrupted = true
      puts "\n"
      log_info('🛑 Interruption received, finishing current batch...')
      log_info('⏳ Please wait while we save progress...')
    end
  end

  def restore_interrupt_handler
    Signal.trap('INT', @original_int_handler) if @original_int_handler
  end

  def handle_graceful_interruption(batch_messages, gmail_db)
    # Save any messages in the current batch
    return if batch_messages.empty? || gmail_db.nil?

    log_progress('Saving current batch')
    gmail_db.store_messages(batch_messages)
    log_info("💾 Saved #{batch_messages.length} messages from current batch")
    @interrupted = true
  end

  def show_completion_message(gmail_db, new_messages)
    if @interrupted
      log_info('🛑 Cache update interrupted by user')
      log_info("💾 Progress saved: #{new_messages} new messages cached")
      log_info('🔄 Run the command again to continue where you left off')
    else
      final_count = gmail_db.inbox_message_count
      if new_messages == 0
        log_info("✅ Cache is already up to date (#{final_count} messages)")
      else
        log_success("✅ Cache updated with #{new_messages} new messages")
        log_info("📦 Total messages in cache: #{final_count}")
      end
    end
  end
end
