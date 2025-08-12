#!/usr/bin/env ruby
# LM Studio Chat Interface with Conversation Management
# Author: Hemant Verma <fameoflight@gmail.com>
#
# A Ruby script for maintaining conversations with LM Studio models
# Features: model loading, conversation persistence, default model management
#
# OPTIONAL GEM DEPENDENCIES (for enhanced experience):
#   gem install tty-prompt     # Best CLI input experience with autocomplete
#   gem install tty-markdown   # Beautiful markdown rendering in terminal
#   gem install rouge          # Syntax highlighting for code blocks
#
# The script works without these gems but provides enhanced features when available.

require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require 'optparse'
require 'time'

# Markdown Renderer Interface - easily replaceable with other libraries
class MarkdownRenderer
  def initialize
    @backend = detect_best_backend
  end

  def render(text)
    @backend.render(text)
  end

  def backend_name
    @backend.class.name.split('::').last
  end

  def show_enhancement_info
    @backend.show_enhancement_info
  end

  private

  def detect_best_backend
    # Try TTY-Markdown first (best experience)
    begin
      require 'tty-markdown'
      return TTYMarkdownBackend.new
    rescue LoadError
    end

    # Fall back to basic text rendering
    BasicMarkdownBackend.new
  end
end

# TTY-Markdown backend (best experience)
class TTYMarkdownBackend
  def initialize
    require 'tty-markdown'
  end

  def render(text)
    TTY::Markdown.parse(text)
  end

  def show_enhancement_info
    # No info needed - this is the best backend
  end
end

# Basic markdown backend (fallback)
class BasicMarkdownBackend
  def render(text)
    # Simple markdown-like formatting for basic terminals
    result = text.dup
    
    # Headers (must be done first to avoid conflicts)
    result.gsub!(/^### (.+)$/, "\e[1m\e[33m### \\1\e[0m") # H3 headers (bold yellow)
    result.gsub!(/^## (.+)$/, "\e[1m\e[32m## \\1\e[0m")   # H2 headers (bold green)  
    result.gsub!(/^# (.+)$/, "\e[1m\e[31m# \\1\e[0m")     # H1 headers (bold red)
    
    # Code blocks (triple backticks)
    result.gsub!(/```(\w+)?\n(.*?)\n```/m, "\e[44m\e[37m\\2\e[0m") # Code blocks (blue bg)
    
    # Inline formatting
    result.gsub!(/\*\*(.*?)\*\*/, "\e[1m\\1\e[0m")        # Bold
    result.gsub!(/\*([^*]+)\*/, "\e[3m\\1\e[0m")          # Italic (avoid matching **)
    result.gsub!(/`([^`]+)`/, "\e[36m\\1\e[0m")           # Inline code (cyan)
    
    # Lists
    result.gsub!(/^- (.+)$/, "\e[92m•\e[0m \\1")          # Bullet points (bright green)
    result.gsub!(/^\d+\. (.+)$/, "\e[92m\\0\e[0m")        # Numbered lists
    
    result
  end

  def show_enhancement_info
    puts "💡 Using basic markdown - Install TTY-Markdown for better rendering:"
    puts "   gem install tty-markdown"
    puts "   gem install rouge  # For syntax highlighting"
  end
end

# CLI Input Interface - easily replaceable with other libraries
class CLIInterface
  def initialize
    @backend = detect_best_backend
  end

  def ask(prompt, &block)
    @backend.ask(prompt, &block)
  end

  def yes?(question)
    @backend.yes?(question)
  end

  def show_enhancement_info
    @backend.show_enhancement_info
  end

  def backend_name
    @backend.class.name.split('::').last
  end

  private

  def detect_best_backend
    # Try TTY-Prompt first (best experience)
    begin
      require 'tty-prompt'
      return TTYBackend.new
    rescue LoadError
    end

    # Fall back to Readline (basic functionality)
    begin
      require 'readline'
      return ReadlineBackend.new
    rescue LoadError
    end

    # Final fallback to basic input
    BasicInputBackend.new
  end
end

# TTY-Prompt backend (best experience)
class TTYBackend
  def initialize
    require 'tty-prompt'
    @prompt = TTY::Prompt.new
  end

  def ask(prompt, &block)
    if block_given?
      result = @prompt.ask(prompt, &block)
    else
      result = @prompt.ask(prompt) do |q|
        q.modify :strip
        q.validate /\A.+\z/, "Please enter something"
        q.messages[:valid?] = ""
      end
    end
    
    # Process escape sequences like \n
    result&.gsub(/\\n/, "\n")&.gsub(/\\t/, "\t")
  end

  def yes?(question)
    @prompt.yes?(question)
  end

  def show_enhancement_info
    # No info needed - this is the best backend
  end
end

# Readline backend (moderate experience)  
class ReadlineBackend
  def initialize
    require 'readline'
  end

  def ask(prompt, &block)
    print "#{prompt} "
    input = Readline.readline("", true)&.strip || ""
    
    if input.nil?
      puts "\n👋 Goodbye!"
      exit
    end
    
    # Process escape sequences like \n
    input&.gsub(/\\n/, "\n")&.gsub(/\\t/, "\t")
  end

  def yes?(question)
    print "#{question} (y/N): "
    response = gets.chomp.downcase
    response == 'y' || response == 'yes'
  end

  def show_enhancement_info
    puts "💡 Using Readline - Install TTY-Prompt for better experience:"
    puts "   gem install tty-prompt"
  end
end

# Basic input backend (fallback)
class BasicInputBackend  
  def ask(prompt, &block)
    print "#{prompt} "
    input = gets.chomp.strip
    
    # Process escape sequences like \n
    input&.gsub(/\\n/, "\n")&.gsub(/\\t/, "\t")
  end

  def yes?(question)
    print "#{question} (y/N): "
    response = gets.chomp.downcase
    response == 'y' || response == 'yes'
  end

  def show_enhancement_info
    puts "⚠️  Using basic input - Install TTY-Prompt for better experience:"
    puts "   gem install tty-prompt"
    puts "   Or install Readline support for your Ruby"
  end
end

class LMChat
  CONVERSATIONS_DIR = File.expand_path("~/.lm_conversations")
  CONFIG_FILE = File.expand_path("~/.lm_chat_config.json")
  DEFAULT_PORT = 1234
  DEFAULT_HOST = "localhost"

  def initialize
    @host = DEFAULT_HOST
    @port = DEFAULT_PORT
    @temperature = 0.7
    @max_tokens = 1000
    @conversation = []
    @conversation_id = nil
    @default_model = nil
    @available_models = []
    @conversations_cache = []
    @streaming_enabled = true  # Streaming enabled by default
    
    # Initialize CLI interface with best available backend
    @cli = CLIInterface.new
    @markdown = MarkdownRenderer.new
    
    # Define available commands with descriptions
    @chat_commands = {
      "/help" => "Show help information",
      "/save" => "Save current conversation",
      "/models" => "List available models", 
      "/load" => "Load a specific model",
      "/default" => "Set default model (/default model-name)",
      "/new" => "Start new conversation",
      "/resume" => "Resume a conversation",
      "/conversations" => "List saved conversations",
      "/delete" => "Delete a conversation", 
      "/clean" => "Delete conversation(s) (/clean all or /clean <id>)",
      "/temperature" => "Set temperature (0.0-2.0)",
      "/tokens" => "Set max tokens",
      "/status" => "Show current status",
      "/config" => "Show configuration settings",
      "/clear" => "Clear the terminal screen",
      "/quit" => "Save and exit"
    }
    
    ensure_directories
    load_config
  end

  def run(args)
    options = parse_options(args)
    
    case options[:command]
    when :chat
      start_chat(options)
    when :list_models
      list_models
    when :load_model
      load_model(options[:model], options[:identifier])
    when :set_default
      set_default_model(options[:model])
    when :list_conversations
      list_conversations
    when :load_conversation
      load_conversation(options[:conversation_id])
    when :delete_conversation
      delete_conversation(options[:conversation_id])
    else
      show_help
    end
  end

  private

  def parse_options(args)
    options = { command: :chat }
    
    OptionParser.new do |opts|
      opts.banner = "Usage: lm-chat [options] [prompt]"
      opts.separator ""
      opts.separator "Commands:"
      
      opts.on("-m", "--models", "List available models") do
        options[:command] = :list_models
      end
      
      opts.on("-l", "--load MODEL", "Load a specific model") do |model|
        options[:command] = :load_model
        options[:model] = model
      end
      
      opts.on("-i", "--identifier ID", "Set identifier when loading model") do |id|
        options[:identifier] = id
      end
      
      opts.on("-d", "--default MODEL", "Set default model") do |model|
        options[:command] = :set_default
        options[:model] = model
      end
      
      opts.on("-c", "--conversations", "List saved conversations") do
        options[:command] = :list_conversations
      end
      
      opts.on("-r", "--resume ID", "Resume a conversation") do |id|
        options[:command] = :load_conversation
        options[:conversation_id] = id
      end
      
      opts.on("--delete ID", "Delete a conversation") do |id|
        options[:command] = :delete_conversation
        options[:conversation_id] = id
      end
      
      opts.on("-t", "--temperature TEMP", Float, "Set temperature (0.0-2.0)") do |temp|
        @temperature = temp.clamp(0.0, 2.0)
      end
      
      opts.on("--max-tokens TOKENS", Integer, "Set max tokens") do |tokens|
        @max_tokens = tokens
      end
      
      opts.on("-p", "--port PORT", Integer, "LM Studio server port") do |port|
        @port = port
      end
      
      opts.on("-n", "--new", "Start a new conversation") do
        options[:new_conversation] = true
      end
      
      opts.on("-h", "--help", "Show this help") do
        puts opts
        exit
      end
    end.parse!(args)
    
    # If there are remaining args, treat as initial prompt
    options[:prompt] = args.join(" ") unless args.empty?
    options
  end

  def ensure_directories
    FileUtils.mkdir_p(CONVERSATIONS_DIR)
  end

  def load_config
    if File.exist?(CONFIG_FILE)
      config = JSON.parse(File.read(CONFIG_FILE))
      @default_model = config["default_model"]
      @port = config["port"] || DEFAULT_PORT
      @host = config["host"] || DEFAULT_HOST
      @temperature = config["temperature"] || 0.7
      @max_tokens = config["max_tokens"] || 1000
      @streaming_enabled = config["streaming_enabled"].nil? ? true : config["streaming_enabled"]
    end
  end

  def save_config
    config = {
      "default_model" => @default_model,
      "port" => @port,
      "host" => @host,
      "temperature" => @temperature,
      "max_tokens" => @max_tokens,
      "streaming_enabled" => @streaming_enabled
    }
    File.write(CONFIG_FILE, JSON.pretty_generate(config))
  end

  def list_models
    puts "🔍 Fetching available models..."
    
    if !server_running?
      puts "❌ LM Studio server not running. Start with: lms server start"
      return
    end
    
    begin
      response = make_request("/v1/models")
      if response["data"]
        puts "📋 Available models:"
        response["data"].each_with_index do |model, i|
          marker = model["id"] == @default_model ? " (default)" : ""
          puts "  #{i + 1}. #{model["id"]}#{marker}"
        end
      else
        puts "⚠️  No models found or server error"
      end
    rescue => e
      puts "❌ Error fetching models: #{e.message}"
    end
  end

  def load_model(model_name, identifier = nil)
    puts "📦 Loading model: #{model_name}"
    
    cmd = "lms load \"#{model_name}\""
    cmd += " --identifier=\"#{identifier}\"" if identifier
    
    success = system(cmd)
    if success
      puts "✅ Model loaded successfully"
      @default_model = identifier || model_name if identifier
      save_config
    else
      puts "❌ Failed to load model"
    end
  end

  def set_default_model(model_name)
    @default_model = model_name
    save_config
    puts "✅ Default model set to: #{model_name}"
  end

  def start_chat(options)
    if options[:new_conversation]
      start_new_conversation
    elsif !@conversation_id
      # Try to load most recent conversation
      recent_conv = most_recent_conversation
      if recent_conv
        puts "📂 Resuming most recent conversation: #{recent_conv}"
        load_conversation(recent_conv)
      else
        start_new_conversation
      end
    end
    
    if !server_running?
      puts "❌ LM Studio server not running. Starting server..."
      system("lms server start --port #{@port}")
      sleep(2) # Give server time to start
    end
    
    # Load default model if configured and no model loaded
    if @default_model && !model_loaded?
      puts "🔄 Loading default model: #{@default_model}"
      load_model(@default_model)
    end
    
    # Send initial prompt if provided
    if options[:prompt]
      send_message(options[:prompt])
    end
    
    # Show current settings on startup
    show_startup_info
    
    # Start interactive chat
    interactive_chat unless options[:prompt]
  end

  def start_new_conversation
    @conversation_id = generate_conversation_id
    @conversation = []
    puts "🆕 Started new conversation: #{@conversation_id}"
  end

  def interactive_chat
    puts "\n🤖 LM Studio Chat Interface"
    puts "✨ Multi-line input enabled, streaming with real-time formatting"
    
    # Show enhancement info if not using the best backends
    @cli.show_enhancement_info
    @markdown.show_enhancement_info
    
    puts "💡 Type '/' for commands, or start chatting"
    puts "📝 Enter to send, Shift+Enter for new line, 'exit' to quit\n"
    
    # Cache models and conversations for completion
    refresh_caches
    
    loop do
      input = get_user_input
      
      # Handle exit commands (with or without slash)
      case input.downcase
      when "exit", "quit", "/exit", "/quit", "/q"
        save_conversation
        puts "👋 Goodbye!"
        break
      when ""
        next
      end
      
      # Handle slash commands
      if input.start_with?("/")
        case input
        when "/help", "/h"
          show_chat_help
        when "/save", "/s"
          save_conversation
          puts "💾 Conversation saved"
        when "/models", "/m"
          list_models
          refresh_caches
        when "/new", "/n"
          save_conversation if @conversation_id
          start_new_conversation
        when "/conversations", "/c"
          list_conversations
          refresh_caches
        when /^\/clean (.+)/
          target = $1.strip
          if target == "all"
            clean_all_conversations
          else
            delete_conversation(target)
          end
          refresh_caches
        when "/clean"
          puts "❌ Usage: /clean all  or  /clean <conversation-id>"
          puts "💡 Use /conversations to see available conversation IDs"
        when "/config"
          show_startup_info
        when "/clear"
          clear_terminal
        when "/status"
          show_status
        when /^\/load (.+)/
          model_name = $1
          load_model(model_name)
          refresh_caches
        when /^\/default (.+)/
          model_name = $1.strip
          set_default_model(model_name)
        when "/default"
          puts "❌ Usage: /default <model-name>"
          puts "💡 Use /models to see available models"
        when /^\/resume (.+)/
          conversation_id = $1
          save_conversation if @conversation_id
          load_conversation(conversation_id)
        when /^\/delete (.+)/
          conversation_id = $1
          delete_conversation(conversation_id)
          refresh_caches
        when /^\/temperature (.+)/, /^\/temp (.+)/
          temp = $1.to_f
          if temp >= 0.0 && temp <= 2.0
            @temperature = temp
            puts "🌡️  Temperature set to: #{@temperature}"
            save_config
          else
            puts "❌ Temperature must be between 0.0 and 2.0"
          end
        when /^\/tokens (.+)/
          tokens = $1.to_i
          if tokens > 0
            @max_tokens = tokens
            puts "📊 Max tokens set to: #{@max_tokens}"
            save_config
          else
            puts "❌ Max tokens must be positive"
          end
        else
          puts "❌ Unknown command: #{input}"
          puts "💡 Type '/help' for available commands or just type your message"
        end
      else
        # Regular chat message
        send_message(input)
      end
    end
  end

  def get_user_input
    require 'io/console'
    
    print "\n💭 You: "
    input = ""
    cursor_col = 0
    
    begin
      $stdin.raw do
        loop do
          char = $stdin.getc
          
          case char.ord
          when 3   # Ctrl+C
            puts "\n👋 Goodbye!"
            exit
          when 13  # Enter
            # Regular Enter - send message
            puts ""
            break
          when 10  # Shift+Enter (line feed)
            # Add newline and continue
            input += "\n"
            cursor_col = 0
            puts ""
            print "     " # Indent next line
          when 127, 8  # Backspace
            unless input.empty?
              if input[-1] == "\n"
                # Remove newline
                input = input[0...-1]
                print "\e[A\e[999C"  # Go up and to end of line
                cursor_col = input.split("\n").last&.length || 0
              else
                input = input[0...-1] 
                print "\b \b"
                cursor_col -= 1
              end
            end
          when 9   # Tab
            input += "  "  # Two spaces for tab
            print "  "
            cursor_col += 2
          else
            if char.ord >= 32 && char.ord < 127  # Printable characters
              input += char
              print char
              cursor_col += 1
            end
          end
        end
      end
      
      # Handle escape sequences and return
      input = input.gsub(/\\n/, "\n").gsub(/\\t/, "\t").strip
      return input.empty? ? get_user_input : input
      
    rescue Interrupt
      puts "\n👋 Goodbye!"
      exit
    end
  end

  def show_command_help_if_partial(input)
    matches = @chat_commands.keys.select { |cmd| cmd.start_with?(input) }
    
    if matches.length > 1
      puts "\n💡 Available commands:"
      matches.sort.each do |cmd|
        puts "  #{cmd} - #{@chat_commands[cmd]}"
      end
    elsif matches.length == 1 && matches.first != input
      puts "💡 Did you mean: #{matches.first} - #{@chat_commands[matches.first]}"
    end
  end


  def refresh_caches
    # Cache available models
    begin
      if server_running?
        response = make_request("/v1/models")
        @available_models = response["data"]&.map { |m| m["id"] } || []
      end
    rescue
      @available_models = []
    end
    
    # Cache conversation IDs
    files = Dir.glob(File.join(CONVERSATIONS_DIR, "*.json"))
    @conversations_cache = files.map { |f| File.basename(f, ".json") }.sort.reverse
  end

  def show_startup_info
    puts "\n⚙️  LM Studio Chat Settings:"
    puts "📁 Config file: #{CONFIG_FILE}"
    puts "💬 Conversations: #{CONVERSATIONS_DIR}"
    puts "🔗 Server: #{@host}:#{@port} #{server_running? ? '✅' : '❌'}"
    puts "🤖 Default model: #{@default_model || 'None set'}"
    puts "🌡️  Temperature: #{@temperature}"
    puts "📊 Max tokens: #{@max_tokens}"
    streaming_emoji = @streaming_enabled ? "🌊" : "📄"
    streaming_status = @streaming_enabled ? "enabled" : "disabled"
    puts "#{streaming_emoji} Streaming: #{streaming_status}"
    
    if @conversation_id
      puts "📝 Current conversation: #{@conversation_id} (#{@conversation.length} messages)"
    end
    
    puts "─" * 50
  end

  def show_status
    puts "\n📊 Current Status:"
    puts "🔗 Server: #{server_running? ? '✅ Running' : '❌ Not running'} (#{@host}:#{@port})"
    puts "🤖 Default Model: #{@default_model || 'None set'}"
    puts "🌡️  Temperature: #{@temperature}"
    puts "📊 Max Tokens: #{@max_tokens}"
    streaming_emoji = @streaming_enabled ? "🌊" : "📄"
    streaming_status = @streaming_enabled ? "enabled" : "disabled"
    puts "#{streaming_emoji} Streaming: #{streaming_status}"
    puts "💬 Current Conversation: #{@conversation_id || 'None'}"
    puts "📝 Messages in conversation: #{@conversation.length}"
    
    if @available_models.any?
      puts "🎯 Available Models: #{@available_models.join(', ')}"
    end
    
    puts "\n📁 Settings stored in:"
    puts "   Config: #{CONFIG_FILE}"
    puts "   Conversations: #{CONVERSATIONS_DIR}"
  end

  def send_message(message)
    return if message.strip.empty?
    
    @conversation << { role: "user", content: message, timestamp: Time.now.iso8601 }
    
    puts ""
    print "🤖 Assistant: "
    
    begin
      # Stream normally, then apply formatting at the end
      assistant_message = stream_chat_request(@conversation.map { |msg| { role: msg[:role], content: msg[:content] } })
      
      if assistant_message && !assistant_message.strip.empty?
        @conversation << { 
          role: "assistant", 
          content: assistant_message, 
          timestamp: Time.now.iso8601 
        }
        
        # Auto-save conversation
        save_conversation
        puts "" # Add blank line after response
      else
        puts "❌ No response from model"
      end
    rescue => e
      puts "❌ Error: #{e.message}"
    end
  end

  def make_chat_request(messages)
    uri = URI("http://#{@host}:#{@port}/v1/chat/completions")
    
    payload = {
      messages: messages,
      temperature: @temperature,
      max_tokens: @max_tokens,
      stream: false
    }
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json
    
    response = http.request(request)
    JSON.parse(response.body) if response.code == "200"
  end

  def stream_chat_request_with_formatting(messages)
    require 'net/http'
    require 'json'
    
    uri = URI("http://#{@host}:#{@port}/v1/chat/completions")
    
    payload = {
      messages: messages,
      temperature: @temperature,
      max_tokens: @max_tokens,
      stream: true
    }
    
    full_response = ""
    current_word = ""
    
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "text/event-stream"
      request.body = payload.to_json
      
      http.request(request) do |response|
        if response.code != "200"
          puts "❌ Stream request failed: #{response.code}"
          return nil
        end
        
        response.read_body do |chunk|
          chunk.split("\n").each do |line|
            next unless line.start_with?("data: ")
            
            data = line[6..-1].strip
            next if data == "[DONE]" || data.empty?
            
            begin
              json_data = JSON.parse(data)
              if json_data["choices"] && json_data["choices"][0]["delta"]["content"]
                content = json_data["choices"][0]["delta"]["content"]
                
                # Apply real-time formatting as we build words
                current_word += content
                full_response += content
                
                # When we hit a space or newline, format and print the completed word
                if content.match?(/\s/)
                  formatted_word = format_word_realtime(current_word)
                  print formatted_word
                  current_word = ""
                else
                  # For non-space characters, just print them (building the word)
                  print content
                end
                
                $stdout.flush
              end
            rescue JSON::ParserError
              next
            end
          end
        end
      end
    end
    
    # Print any remaining word
    if !current_word.empty?
      formatted_word = format_word_realtime(current_word)
      print formatted_word
    end
    
    puts # Final newline
    full_response
  rescue => e
    puts "❌ Streaming error: #{e.message}"
    nil
  end

  def stream_chat_request(messages)
    require 'net/http'
    require 'json'
    
    uri = URI("http://#{@host}:#{@port}/v1/chat/completions")
    
    payload = {
      messages: messages,
      temperature: @temperature,
      max_tokens: @max_tokens,
      stream: true
    }
    
    full_response = ""
    
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "text/event-stream"
      request.body = payload.to_json
      
      http.request(request) do |response|
        if response.code != "200"
          puts "❌ Stream request failed: #{response.code}"
          return nil
        end
        
        response.read_body do |chunk|
          # Parse Server-Sent Events format
          chunk.split("\n").each do |line|
            next unless line.start_with?("data: ")
            
            data = line[6..-1].strip  # Remove "data: " prefix
            next if data == "[DONE]" || data.empty?
            
            begin
              json_data = JSON.parse(data)
              if json_data["choices"] && json_data["choices"][0]["delta"]["content"]
                content = json_data["choices"][0]["delta"]["content"]
                print content  # Just print raw content, no formatting
                full_response += content
                $stdout.flush
              end
            rescue JSON::ParserError
              # Skip malformed JSON
              next
            end
          end
        end
      end
    end
    
    # Just add a newline after streaming - no complex cursor positioning
    puts ""
    
    # If there's markdown content, show formatted version separately
    if full_response && !full_response.strip.empty? && has_markdown_content?(full_response)
      # puts "🎨 Formatted:"
      puts @markdown.render(full_response)
    end
    
    full_response
  rescue => e
    puts "❌ Streaming error: #{e.message}"
    nil
  end

  def toggle_streaming
    @streaming_enabled = !@streaming_enabled
    status = @streaming_enabled ? "enabled" : "disabled"
    emoji = @streaming_enabled ? "🌊" : "📄"
    puts "#{emoji} Streaming #{status}"
    
    if @streaming_enabled
      puts "💡 Responses will now stream in real-time"
    else
      puts "💡 Responses will be delivered all at once"
    end
    
    # Save the streaming preference to config
    save_config
  end

  def toggle_pretty_mode
    @pretty_mode = !@pretty_mode
    
    if @pretty_mode
      @streaming_enabled = false
      puts "🎨 Pretty mode enabled - Responses with instant beautiful markdown"
      puts "💡 No streaming, but immediate formatted output"
    else
      @streaming_enabled = true  
      puts "🌊 Pretty mode disabled - Back to streaming mode"
      puts "💡 Real-time responses with post-formatting"
    end
  end

  def has_markdown_content?(text)
    # Check if text contains common markdown patterns
    text.match?(/\*\*.*?\*\*/) ||     # Bold
    text.match?(/\*.*?\*/) ||         # Italic
    text.match?(/`.*?`/) ||           # Inline code
    text.match?(/^#+\s/) ||           # Headers
    text.match?(/```/) ||             # Code blocks
    text.match?(/^-\s/) ||            # Lists
    text.match?(/^\d+\.\s/)           # Numbered lists
  end

  def format_word_realtime(word)
    # Format completed words in real-time
    
    # Code blocks and inline code
    if word.include?('`')
      word.gsub(/`([^`]*)`/, "\e[36m`\\1`\e[0m")
           .gsub(/`/, "\e[36m`\e[0m")
    # Bold text  
    elsif word.include?('**')
      word.gsub(/\*\*([^*]*)\*\*/, "\e[1m**\\1**\e[0m")
           .gsub(/\*\*/, "\e[1m**\e[0m")
    # Headers
    elsif word.match?(/^#+/)
      "\e[1m\e[32m#{word}\e[0m"
    # Italic (single asterisk, avoid matching **)
    elsif word.match?(/\*[^*]+\*/)
      word.gsub(/\*([^*]+)\*/, "\e[3m*\\1*\e[0m")
    else
      word
    end
  end

  def clear_terminal
    # Cross-platform terminal clear
    if RUBY_PLATFORM =~ /win32|win64|\.NET|windows|cygwin|mingw32/i
      system('cls')
    else
      system('clear')
    end
    
    # Re-show the chat header after clearing
    puts "🤖 LM Studio Chat Interface"
    puts "💭 Chat cleared - conversation history preserved"
    puts ""
  end

  def make_request(endpoint)
    uri = URI("http://#{@host}:#{@port}#{endpoint}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body) if response.code == "200"
  end

  def server_running?
    begin
      make_request("/v1/models")
      true
    rescue
      false
    end
  end

  def model_loaded?
    begin
      response = make_request("/v1/models")
      response && response["data"] && !response["data"].empty?
    rescue
      false
    end
  end

  def save_conversation
    return unless @conversation_id && !@conversation.empty?
    
    conversation_file = File.join(CONVERSATIONS_DIR, "#{@conversation_id}.json")
    
    data = {
      id: @conversation_id,
      created_at: @conversation.first[:timestamp],
      updated_at: Time.now.iso8601,
      model: @default_model,
      temperature: @temperature,
      max_tokens: @max_tokens,
      messages: @conversation
    }
    
    File.write(conversation_file, JSON.pretty_generate(data))
  end

  def load_conversation(conversation_id)
    conversation_file = File.join(CONVERSATIONS_DIR, "#{conversation_id}.json")
    
    unless File.exist?(conversation_file)
      puts "❌ Conversation #{conversation_id} not found"
      return
    end
    
    begin
      data = JSON.parse(File.read(conversation_file), symbolize_names: true)
      @conversation_id = data[:id]
      @conversation = data[:messages]
      @temperature = data[:temperature] || 0.7
      @max_tokens = data[:max_tokens] || 1000
      
      puts "📂 Loaded conversation: #{conversation_id}"
      puts "💬 #{@conversation.length} messages"
      
      # Show last few messages for context
      puts "\n📋 Recent messages:"
      @conversation.last(4).each do |msg|
        role_emoji = msg[:role] == "user" ? "💭" : "🤖"
        content = msg[:content].length > 100 ? "#{msg[:content][0..100]}..." : msg[:content]
        puts "#{role_emoji} #{msg[:role].capitalize}: #{content}"
      end
      
    rescue => e
      puts "❌ Error loading conversation: #{e.message}"
    end
  end

  def list_conversations
    files = Dir.glob(File.join(CONVERSATIONS_DIR, "*.json")).sort_by { |f| File.mtime(f) }.reverse
    
    if files.empty?
      puts "📭 No saved conversations found"
      return
    end
    
    puts "💬 Saved conversations:"
    files.each_with_index do |file, i|
      begin
        data = JSON.parse(File.read(file))
        id = data["id"]
        created = Time.parse(data["created_at"]).strftime("%Y-%m-%d %H:%M")
        message_count = data["messages"]&.length || 0
        model = data["model"] || "unknown"
        
        puts "  #{i + 1}. #{id} - #{created} (#{message_count} msgs, #{model})"
      rescue
        next
      end
    end
  end

  def delete_conversation(conversation_id)
    conversation_file = File.join(CONVERSATIONS_DIR, "#{conversation_id}.json")
    
    if File.exist?(conversation_file)
      File.delete(conversation_file)
      puts "🗑️  Deleted conversation: #{conversation_id}"
    else
      puts "❌ Conversation #{conversation_id} not found"
    end
  end

  def clean_all_conversations
    files = Dir.glob(File.join(CONVERSATIONS_DIR, "*.json"))
    
    if files.empty?
      puts "📭 No conversations to delete"
      return
    end
    
    confirmed = @cli.yes?("🗑️  Delete all #{files.length} conversations? This cannot be undone.")
    
    if confirmed
      deleted_count = 0
      files.each do |file|
        File.delete(file)
        deleted_count += 1
      end
      
      # Clear current conversation if it was deleted
      @conversation = []
      @conversation_id = nil
      
      puts "🗑️  Deleted #{deleted_count} conversations"
      puts "🆕 Current conversation cleared - start fresh with your next message"
    else
      puts "❌ Deletion cancelled"
    end
  end

  def most_recent_conversation
    files = Dir.glob(File.join(CONVERSATIONS_DIR, "*.json"))
    return nil if files.empty?
    
    most_recent = files.max_by { |f| File.mtime(f) }
    File.basename(most_recent, ".json")
  end

  def generate_conversation_id
    "chat_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  end

  def show_chat_help
    puts <<~HELP
      
      🤖 Available Commands (like Claude Code):
      
      /help              - Show this help
      /save              - Save current conversation  
      /models            - List available models
      /load <model>      - Load a specific model
      /default <model>   - Set default model (without loading)
      /new               - Start new conversation
      /resume <id>       - Resume a conversation  
      /conversations     - List saved conversations
      /delete <id>       - Delete a specific conversation
      /clean all         - Delete all conversations (with confirmation)
      /clean <id>        - Delete a specific conversation (same as /delete)
      /temperature <val> - Set temperature (0.0-2.0)
      /tokens <num>      - Set max tokens
      /stream            - Toggle streaming mode on/off
      /pretty            - Toggle pretty mode (instant markdown)
      /clear             - Clear the terminal screen
      /status            - Show current status
      /config            - Show configuration settings
      
      💡 Exit: Just type 'exit', 'quit', or '/quit'
      💬 Chat: Type anything else to send a message to the model
      
    HELP
  end

  def show_help
    puts <<~HELP
      🤖 LM Studio Chat Interface
      
      Usage: lm-chat [options] [prompt]
      
      Options:
        -m, --models              List available models
        -l, --load MODEL          Load a specific model
        -i, --identifier ID       Set identifier when loading model
        -d, --default MODEL       Set default model
        -c, --conversations       List saved conversations
        -r, --resume ID          Resume a conversation
        --delete ID              Delete a conversation
        -t, --temperature TEMP   Set temperature (0.0-2.0)
        --max-tokens TOKENS      Set max tokens
        -p, --port PORT          LM Studio server port
        -n, --new                Start a new conversation
        -h, --help               Show this help
      
      Examples:
        lm-chat                           # Start interactive chat
        lm-chat "Hello, how are you?"     # Send single message
        lm-chat -m                        # List models
        lm-chat -l "llama-2-7b-chat"     # Load model
        lm-chat -d "llama-2-7b-chat"     # Set default model
        lm-chat -c                        # List conversations
        lm-chat -r chat_20240101_120000   # Resume conversation
        lm-chat -n "Start fresh chat"     # New conversation with prompt
      
      In interactive mode, use /help for chat commands.
      
    HELP
  end
end

if __FILE__ == $0
  chat = LMChat.new
  chat.run(ARGV)
end