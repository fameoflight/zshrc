#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/interactive_script_base'
require_relative '.common/logger'
require_relative '.common/gmail_database'
require_relative '.common/gmail_service'
require_relative '.common/gmail_archive_handler'
require_relative '.common/format'
require_relative '.common/concerns/gmail_view'
require_relative '.common/concerns/account_manager'

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
require 'securerandom'
require 'io/console'

# Description: Fetches and manages Gmail inbox.
class GmailInbox < InteractiveScriptBase
  include GmailView
  include AccountManager
  include Format

  attr_reader :account_name, :gmail_service, :gmail_db, :archive_handler

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
        • 📭 Archive unread emails
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
    if @options[:reset_auth]
      select_account unless @account_name
      gmail_service = GmailService.new(@account_name, AccountManager::CREDENTIALS_PATH, AccountManager::TOKEN_DIR)
      gmail_service.reset_authentication
      return
    end

    # Handle clear cache option
    if @options[:clear_cache]
      select_account unless @account_name
      clear_cache
      log_success "Cache cleared for account '#{@account_name}'"
      return
    end

    select_account

    # Initialize services
    @gmail_service = GmailService.new(@account_name, AccountManager::CREDENTIALS_PATH, AccountManager::TOKEN_DIR)
    @gmail_service.check_credentials
    @gmail_db = GmailDatabase.new(cache_path)

    user_id = 'me'

    # Handle legacy command-line options for backwards compatibility
    if @options[:summary_only]
      show_inbox_summary(@gmail_service.service, user_id)
      show_completion('Gmail Inbox Summary')
      return
    elsif @options[:limit]
      show_recent_messages(@gmail_service.service, user_id, @options[:limit])
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
      menu_option('📭', 'Archive unread emails', :archive_unread),
      menu_option('⏰', 'Archive emails by date (oldest first)', :archive_chronological_old),
      menu_option('🕒', 'Archive emails by date (newest first)', :archive_chronological_new),
      menu_option('🔍', 'Search emails', :search_emails),
      menu_option('🗑️', 'Find unsubscribe emails', :find_unsubscribe),
      refresh_option(:refresh_cache),
      clear_cache_option(:clear_cache)
    ]
  end

  def setup_interactive_mode
    # Setup Gmail service and related components
    @gmail_service = GmailService.new(@account_name, AccountManager::CREDENTIALS_PATH, AccountManager::TOKEN_DIR)
    @gmail_db = GmailDatabase.new(cache_path)
    @archive_handler = GmailArchiveHandler.new(@gmail_service, @gmail_db)
    @user_id = 'me'
  end

  def handle_menu_choice(choice)
    safe_execute do
      case choice
      when :summary
        show_inbox_summary(@gmail_service.service, @user_id)
      when :recent_messages
        limit = ask_number('How many recent messages?', default: 10)
        show_recent_messages(@gmail_service.service, @user_id, limit)
      when :messages_with_attachments
        show_messages_with_attachments
      when :top_senders
        limit = ask_number('How many top senders to show?', default: 10)
        show_top_senders(@gmail_service.service, @user_id, limit)
      when :archive_by_sender
        @archive_handler.archive_by_sender(@user_id, self)
      when :archive_by_domain
        @archive_handler.archive_by_domain(@user_id, self)
      when :archive_unread
        @archive_handler.archive_unread(@user_id, self)
      when :archive_chronological_old
        @archive_handler.archive_chronologically(@user_id, self, order: :oldest_first)
      when :archive_chronological_new
        @archive_handler.archive_chronologically(@user_id, self, order: :newest_first)
      when :search_emails
        search_emails
      when :find_unsubscribe
        find_unsubscribe_emails
      when :refresh_cache
        refresh_cache(@user_id)
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

  def show_messages_with_attachments
    log_info '📎 Finding messages with attachments'
    puts

    begin
      # Ensure cache is up to date
      cached_count = gmail_db.inbox_message_count
      if cached_count == 0
        log_info '🔄 Building initial cache to find attachments'
        @gmail_service.update_message_cache(@user_id, @gmail_db)

        # Check again after caching
        cached_count = gmail_db.inbox_message_count
        if cached_count == 0
          log_info 'No messages found in your inbox'
          return
        end
      else
        log_info '📦 Using cached data to search for attachments'
        # Quick incremental update
        @gmail_service.update_message_cache(@user_id, @gmail_db, force_update: false)
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

  def show_setup_instructions
    puts <<~INSTRUCTIONS
      🛠️  Gmail Inbox Setup Instructions

          📝 Step 1: Create Google Cloud Project & Enable Gmail API
              • Go to: https://console.cloud.google.com/
              • Create a new project (or select existing one)#{'  '}
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
              • Save the file as: #{AccountManager::CREDENTIALS_PATH}

          🚀 Step 4: Run Script Again
              • Once credentials are saved, run: gmail-inbox
    INSTRUCTIONS
  end

  private

  def gmail_db
    @gmail_db ||= GmailDatabase.new(cache_path)
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

  def refresh_cache(user_id)
    log_info '🔄 Refreshing message cache'

    # Get latest messages from Gmail
    @gmail_service.update_message_cache(user_id, @gmail_db, force_update: true)

    log_success 'Cache refreshed with latest messages'
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
end

# Execute the script
GmailInbox.execute if __FILE__ == $0