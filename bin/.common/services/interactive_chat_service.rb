#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'base_service'
require_relative 'conversation_service'
require_relative 'markdown_renderer'

# Service for managing interactive chat sessions with content
class InteractiveChatService < BaseService
  def initialize(llm_service, options = {})
    super(options)
    @llm = llm_service
    @markdown = MarkdownRenderer.new(options)
    @default_temperature = options[:temperature] || 0.3
    @default_max_tokens = options[:max_tokens] || 1000
    @auto_reload = options.fetch(:auto_reload, true)
    @min_context = options[:min_context]
  end

  # Start interactive chat session
  def start_chat_session(content_data, summary = nil, options = {})
    log_section("💬 Interactive Chat")

    # Store summary for use in chat loop
    @summary = summary

    # Display welcome message and instructions
    show_chat_instructions

    # Initialize conversation with system context
    system_context = build_system_context(content_data, summary)
    @conversation = ConversationService.new(@llm, system_prompt: system_context)

    # Main chat loop
    run_chat_loop(options)
  end

  # Run the main chat interaction loop
  def run_chat_loop(options = {})
    loop do
      print "\n🎥 Ask about the content: "
      question = get_user_input

      break if should_exit_chat?(question)

      next if question.empty?

      # Handle special commands
      if handle_special_commands(question, @summary)
        next
      end

      # Process user question
      process_user_question(question, options)
    end

    log_success("Chat session ended")
    log_info("Total conversation: #{@conversation.summary[:user_messages]} questions asked")
  end

  # Process a user question and generate response
  def process_user_question(question, options = {})
    log_progress("Thinking")

    # Send message using ConversationService
    response = @conversation.send_message(
      question,
      max_tokens: options[:max_tokens] || @default_max_tokens,
      temperature: options[:temperature] || @default_temperature,
      auto_reload: options[:auto_reload] || @auto_reload,
      min_context: options[:min_context] || @min_context
    )

    if response && !response.empty?
      puts "\n🤖 "
      log_debug("Response length: #{response.length} characters")
      display_response(response)
      puts
    else
      log_error("Failed to get response from LLM")
    end
  end

  # Display chat instructions
  def show_chat_instructions
    puts "\nYou can now ask questions about the content."
    puts "Type 'exit', 'quit', or 'q' to end the conversation."
    puts "Type 'summary' to show the summary again."
    puts "Type 'history' to see conversation summary."
    puts "Type 'help' to see available commands.\n"
  end

  # Check if user wants to exit chat
  def should_exit_chat?(input)
    ['exit', 'quit', 'q'].include?(input.downcase)
  end

  # Handle special chat commands
  def handle_special_commands(command, summary = nil)
    case command.downcase
    when 'summary'
      display_summary(summary) if summary
      true
    when 'history'
      display_conversation_history
      true
    when 'help'
      display_chat_help
      true
    when 'clear'
      clear_screen
      true
    when 'context'
      display_context_info
      true
    else
      false
    end
  end

  # Display summary using markdown renderer
  def display_summary(summary)
    @markdown.render_summary(summary)
  end

  # Display conversation history
  def display_conversation_history
    puts "\n📊 Conversation Summary:"
    summary_info = @conversation.summary
    puts "  Messages: #{summary_info[:total_messages]}"
    puts "  Your questions: #{summary_info[:user_messages]}"
    puts "  AI responses: #{summary_info[:assistant_messages]}"
  end

  # Display chat help
  def display_chat_help
    puts "\n📖 Available Commands:"
    puts "  help     - Show this help message"
    puts "  summary  - Display the content summary again"
    puts "  history  - Show conversation statistics"
    puts "  context  - Show current context information"
    puts "  clear    - Clear the screen"
    puts "  exit/quit/q - End the conversation"
    puts "\n💡 Tips:"
    puts "  - Ask specific questions about the content"
    puts "  - Request explanations of complex topics"
    puts "  - Ask for examples or clarifications"
    puts "  - The AI remembers previous questions in the conversation"
  end

  # Display context information
  def display_context_info
    puts "\n🧠 Current Context:"
    puts "  Model: #{@llm.current_model || 'Auto-detect'}"
    puts "  Temperature: #{@default_temperature}"
    puts "  Max Tokens: #{@default_max_tokens}"
    puts "  Auto-reload: #{@auto_reload ? 'Enabled' : 'Disabled'}"
    puts "  Min Context: #{@min_context || 'Auto'}"
  end

  # Clear screen
  def clear_screen
    system('clear') || system('cls')
  end

  # Get user input from stdin
  def get_user_input
    STDIN.gets.chomp.strip
  end

  # Display response using markdown renderer
  def display_response(response)
    @markdown.render_response(response)
  end

  # Build system context for the conversation
  def build_system_context(content_data, summary = nil)
    case content_data
    when Hash
      if content_data[:video_info]
        build_video_context(content_data, summary)
      elsif content_data[:document_info]
        build_document_context(content_data, summary)
      else
        build_generic_context(content_data, summary)
      end
    when String
      build_text_context(content_data, summary)
    else
      build_generic_context(content_data, summary)
    end
  end

  # Build context for video content
  def build_video_context(video_data, summary = nil)
    video_info = video_data[:video_info]
    full_text = video_data[:full_text]

    <<~CONTEXT
      You are an AI assistant helping users understand and discuss a YouTube video.

      **Video Information:**
      - Title: #{video_info[:title]}
      - Duration: #{video_info[:duration]}
      - Uploader: #{video_info[:uploader]}

      **Video Summary:**
      #{summary || 'No summary available'}

      **Full Transcript:**
      #{truncate_text(full_text, 8000)}

      **Instructions:**
      - Answer questions based on the video content
      - Be specific and reference the actual content when possible
      - If asked about something not covered in the video, say so clearly
      - Keep responses concise but informative
      - You can quote specific parts of the transcript when relevant
    CONTEXT
  end

  # Build context for document content
  def build_document_context(document_data, summary = nil)
    doc_info = document_data[:document_info]
    full_text = document_data[:full_text]

    <<~CONTEXT
      You are an AI assistant helping users understand and discuss a document.

      **Document Information:**
      - Title: #{doc_info[:title] || 'Unknown'}
      - Author: #{doc_info[:author] || 'Unknown'}
      - Type: #{doc_info[:type] || 'Document'}

      **Document Summary:**
      #{summary || 'No summary available'}

      **Full Text:**
      #{truncate_text(full_text, 8000)}

      **Instructions:**
      - Answer questions based on the document content
      - Be specific and reference the actual content when possible
      - If asked about something not covered in the document, say so clearly
      - Keep responses concise but informative
      - You can quote specific parts of the document when relevant
    CONTEXT
  end

  # Build context for generic content
  def build_generic_context(content_data, summary = nil)
    full_text = content_data[:full_text] || content_data.to_s

    <<~CONTEXT
      You are an AI assistant helping users understand and discuss content.

      **Content Summary:**
      #{summary || 'No summary available'}

      **Full Content:**
      #{truncate_text(full_text, 8000)}

      **Instructions:**
      - Answer questions based on the content
      - Be specific and reference the actual content when possible
      - If asked about something not covered, say so clearly
      - Keep responses concise but informative
    CONTEXT
  end

  # Build context for plain text
  def build_text_context(text, summary = nil)
    <<~CONTEXT
      You are an AI assistant helping users understand and discuss text content.

      **Content Summary:**
      #{summary || 'No summary available'}

      **Full Text:**
      #{truncate_text(text, 8000)}

      **Instructions:**
      - Answer questions based on the text content
      - Be specific and reference the actual content when possible
      - Keep responses concise but informative
    CONTEXT
  end

  # Truncate text to specified length
  def truncate_text(text, max_length)
    return text unless text && text.length > max_length

    text[0..max_length] + "..."
  end

  # Get conversation statistics
  def get_conversation_stats
    @conversation&.summary || {}
  end

  # Export conversation history
  def export_conversation(format = :text)
    return nil unless @conversation

    case format
    when :text
      export_conversation_text
    when :json
      export_conversation_json
    when :markdown
      export_conversation_markdown
    else
      nil
    end
  end

  private

  def export_conversation_text
    history = @conversation.conversation_history
    return "" unless history&.any?

    output = []
    output << "Conversation Export - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    output << "=" * 50

    history.each do |message|
      role = message[:role] == 'user' ? 'You' : 'AI'
      output << "\n#{role}:"
      output << message[:content]
    end

    output.join("\n")
  end

  def export_conversation_json
    history = @conversation.conversation_history
    return "{}" unless history&.any?

    {
      export_time: Time.now.iso8601,
      conversation: history
    }.to_json
  end

  def export_conversation_markdown
    history = @conversation.conversation_history
    return "" unless history&.any?

    output = []
    output << "# Conversation Export"
    output << "*Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}*"
    output << ""

    history.each do |message|
      role = message[:role] == 'user' ? 'You' : 'Assistant'
      output << "## #{role}"
      output << ""
      output << message[:content]
      output << ""
    end

    output.join("\n")
  end
end