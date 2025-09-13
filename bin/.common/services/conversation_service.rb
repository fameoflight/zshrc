# frozen_string_literal: true

require_relative 'llm_service'

# Service for managing conversational interactions with LLM
# Maintains conversation history and provides easy methods for continuing conversations
class ConversationService
  attr_reader :messages, :system_prompt, :llm

  def initialize(llm_service, system_prompt: nil)
    @llm = llm_service
    @messages = []
    @system_prompt = system_prompt

    # Add system message if provided
    add_system_message(system_prompt) if system_prompt
  end

  # Set or update the system prompt (will replace existing system message)
  def set_system_prompt(prompt)
    @system_prompt = prompt

    # Remove any existing system message and add new one at the beginning
    @messages.reject! { |msg| msg[:role] == 'system' }
    @messages.unshift({ role: 'system', content: prompt })

    self
  end

  # Add a system message (usually at the start of conversation)
  def add_system_message(content)
    @messages << { role: 'system', content: content }
    self
  end

  # Add a user message to the conversation
  def add_user_message(content)
    @messages << { role: 'user', content: content }
    self
  end

  # Add an assistant message to the conversation (usually from LLM response)
  def add_assistant_message(content)
    @messages << { role: 'assistant', content: content }
    self
  end

  # Send the current conversation and get a response
  # This automatically adds the response to the conversation history
  def send_message(user_message, options = {})
    # Add user message to conversation
    add_user_message(user_message)

    # Send conversation to LLM
    response = @llm.chat(@messages, options)

    if response
      # Add LLM response to conversation history
      add_assistant_message(response)
    end

    response
  end

  # Continue the conversation with a new user message
  # Alias for send_message for clearer intent
  def continue(user_message, options = {})
    send_message(user_message, options)
  end

  # Get the last assistant response
  def last_response
    assistant_messages = @messages.select { |msg| msg[:role] == 'assistant' }
    assistant_messages.last&.dig(:content)
  end

  # Get the last user message
  def last_user_message
    user_messages = @messages.select { |msg| msg[:role] == 'user' }
    user_messages.last&.dig(:content)
  end

  # Clear conversation history but keep system prompt
  def clear_history
    system_msg = @messages.find { |msg| msg[:role] == 'system' }
    @messages = system_msg ? [system_msg] : []
    self
  end

  # Get conversation summary for display
  def summary
    user_count = @messages.count { |msg| msg[:role] == 'user' }
    assistant_count = @messages.count { |msg| msg[:role] == 'assistant' }

    {
      total_messages: @messages.length,
      user_messages: user_count,
      assistant_messages: assistant_count,
      has_system_prompt: @messages.any? { |msg| msg[:role] == 'system' }
    }
  end

  # Export conversation history (useful for debugging or saving)
  def export_history
    @messages.dup
  end

  # Import conversation history (useful for restoring conversations)
  def import_history(messages)
    @messages = messages.dup
    @system_prompt = @messages.find { |msg| msg[:role] == 'system' }&.dig(:content)
    self
  end

  # Create a new conversation with the same system prompt
  def fork
    new_conversation = self.class.new(@llm, system_prompt: @system_prompt)
    new_conversation
  end

  # Check if conversation has any messages
  def empty?
    @messages.empty?
  end

  # Get conversation length (number of messages)
  def length
    @messages.length
  end

  # Print conversation for debugging
  def debug_print
    puts "=== Conversation Debug ==="
    puts "Total messages: #{@messages.length}"
    @messages.each_with_index do |msg, i|
      role_emoji = case msg[:role]
                   when 'system' then '⚙️'
                   when 'user' then '👤'
                   when 'assistant' then '🤖'
                   else '❓'
                   end

      content_preview = msg[:content].length > 100 ?
                       "#{msg[:content][0...100]}..." :
                       msg[:content]

      puts "#{i + 1}. #{role_emoji} #{msg[:role]}: #{content_preview}"
    end
    puts "=========================="
  end
end