#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: LLM-powered command and script generator from natural language
# @tags: llm, automation, code-generation

require_relative '../../.common/script_base'
require_relative '../lib/archive/services/llm_service'
require_relative '../lib/archive/services/conversation_service'
require 'json'

# LLM-powered command and script generator
# Uses local LLM Studio to generate commands and scripts from natural language descriptions
class LLMGenerator < ScriptBase
  def script_emoji
    '🤖'
  end

  def script_title
    'LLM Command & Script Generator'
  end

  def script_description
    'Generate commands and scripts using local LLM from natural language descriptions'
  end

  def script_arguments
    '[OPTIONS] "<description>"'
  end

  def add_custom_options(opts)
    opts.on('-c', '--command', 'Generate a single command (default)') do
      @options[:type] = :command
    end

    opts.on('-s', '--script', 'Generate a complete script') do
      @options[:type] = :script
    end

    opts.on('-b', '--bash', 'Generate bash script/command') do
      @options[:shell] = :bash
    end

    opts.on('-z', '--zsh', 'Generate zsh script/command (default)') do
      @options[:shell] = :zsh
    end

    opts.on('-r', '--ruby', 'Generate ruby script') do
      @options[:shell] = :ruby
    end

    opts.on('-p', '--python', 'Generate python script') do
      @options[:shell] = :python
    end

    opts.on('-e', '--execute', 'Execute generated command immediately') do
      @options[:execute] = true
    end

    opts.on('-o', '--output FILE', 'Save generated script to file') do |file|
      @options[:output_file] = file
    end

    opts.on('-m', '--model MODEL', 'Use specific model') do |model|
      @options[:model] = model
    end

    opts.on('--temp TEMPERATURE', Float, 'Set temperature (0.0-1.0)') do |temp|
      @options[:temperature] = temp
    end

    opts.on('--max-tokens TOKENS', Integer, 'Maximum tokens to generate') do |tokens|
      @options[:max_tokens] = tokens
    end

    opts.on('--max-retries RETRIES', Integer, 'Maximum retry attempts on failure (default: 2)') do |retries|
      @options[:max_retries] = retries
    end

    opts.on('--auto-retry', 'Automatically retry failed commands without asking') do
      @options[:auto_retry] = true
    end

    opts.on('--interactive', 'Interactive mode with prompts') do
      @options[:interactive] = true
    end

    opts.on('--list-models', 'List available models and exit') do
      @options[:list_models] = true
    end
  end

  def default_options
    llm_defaults = {
      type: :command,
      shell: :zsh,
      execute: false,
      output_file: nil,
      model: nil,
      temperature: 0.7,
      max_tokens: 64 * 64,
      max_retries: 2,
      auto_retry: false,
      interactive: false,
      list_models: false
    }

    # ScriptBase will handle loading saved settings automatically
    super.merge(llm_defaults)
  end

  def initialize_conversation
    @conversation = ConversationService.new(@llm)
  end

  def validate!
    super

    # Initialize LLM service with MODEL specification
    model_spec = @options[:model] || ENV['MODEL'] || 'ollama:llama3:70b'

    llm_options = {
      model: model_spec,
      debug: debug?,
      logger: self,
      timeout: 60,
      temperature: @options[:temperature],
      max_tokens: @options[:max_tokens]
    }

    @llm = LLMService.new(llm_options)

    unless @llm.available?
      log_error('LLM Studio is not available')
      log_info('Please ensure LM Studio is running on http://localhost:1234')
      log_info('Load a model and start the server before using this tool')
      exit 1
    end

    # Initialize conversation tracking
    initialize_conversation

    # Handle model listing
    if @options[:list_models]
      show_available_models
      exit 0
    end

    # Get description - either from args or interactively
    @description = if @args.empty?
                     get_task_description('📝 What do you want to generate?')
                   else
                     @args.join(' ')
                   end
  end

  def show_available_models
    log_info('Available models:')

    models = @llm.models
    current_model = @llm.instance_variable_get(:@model)

    if models.empty?
      log_warning('No models found in LLM Studio')
      return
    end

    models.each_with_index do |model, index|
      marker = model == current_model ? ' ← current' : ''
      puts "  #{index + 1}. #{model}#{marker}"
    end
  end

  def show_examples
    puts 'Examples:'
    puts '  # Interactive mode - prompts for description and settings'
    puts "  #{script_name}                                    # Basic interactive mode"
    puts "  #{script_name} --interactive                      # Full interactive configuration"
    puts "  #{script_name} --list-models                      # Show available models"
    puts ''
    puts '  # Generate simple commands'
    puts "  #{script_name} \"find all PDF files larger than 10MB\""
    puts "  #{script_name} \"kill process on port 3000\""
    puts "  #{script_name} \"compress all images in current directory\""
    puts ''
    puts '  # Generate and execute immediately with retry on failure'
    puts "  #{script_name} -e \"show disk usage by directory\""
    puts "  #{script_name} -e --max-retries 3 \"complex command that might fail\""
    puts ''
    puts '  # Auto-retry failed commands without asking'
    puts "  #{script_name} -e --auto-retry \"find files with complex regex\""
    puts ''
    puts '  # Generate complete scripts'
    puts "  #{script_name} -s \"backup script for development projects\""
    puts "  #{script_name} -s -r \"ruby script to rename files with timestamp\""
    puts ''
    puts '  # Save to file'
    puts "  #{script_name} -s -o backup.sh \"automated backup script\""
    puts ''
    puts '  # Different languages/shells'
    puts "  #{script_name} -b \"bash command to monitor system resources\""
    puts "  #{script_name} -p \"python script to parse JSON logs\""
    puts ''
    puts '  # Advanced settings'
    puts "  #{script_name} --temp 0.3 --max-tokens 500 \"generate precise command\""
    puts "  #{script_name} -m my-model \"use specific model\""
  end

  def run
    log_banner(script_title)

    # Show complete configuration
    show_current_configuration

    case @options[:type]
    when :command
      generate_command
    when :script
      generate_script
    end

    # Show conversation summary if debug mode
    if debug? && @conversation
      puts
      log_debug('Conversation Summary:')
      summary = @conversation.summary
      log_debug("  Total messages: #{summary[:total_messages]}")
      log_debug("  User messages: #{summary[:user_messages]}")
      log_debug("  Assistant messages: #{summary[:assistant_messages]}")
      log_debug("  Has system prompt: #{summary[:has_system_prompt]}")
    end

    show_completion(script_title)
  end

  def show_current_configuration
    require 'tty-box'

    current_model = @llm.instance_variable_get(:@model)

    # Better formatted configuration
    config_sections = []

    # LLM Settings
    config_sections << '╭─ 🤖 LLM Settings ─────────────────────────'
    config_sections << "│  Model:        #{current_model}"
    config_sections << "│  Temperature:  #{@options[:temperature]}"
    config_sections << "│  Max Tokens:    #{@options[:max_tokens]}"
    config_sections << '╰────────────────────────────────────────'

    # Generation Settings
    config_sections << '╭─ ⚙️  Generation Settings ───────────────────'
    config_sections << "│  Type:          #{@options[:type]}"
    config_sections << "│  Shell/Lang:    #{@options[:shell]}"
    config_sections << "│  Max Retries:   #{@options[:max_retries]}"
    config_sections << "│  Auto-retry:     #{@options[:auto_retry] ? '✅ Yes' : '❌ No'}"
    config_sections << '╰────────────────────────────────────────'

    # Additional Settings
    if @options[:output_file] || @options[:execute]
      config_sections << '╭─ 📋 Additional Settings ──────────────────'
      config_sections << "│  Output File:   #{@options[:output_file]}" if @options[:output_file]
      config_sections << '│  Execute:       ✅ Yes' if @options[:execute]
      config_sections << '╰────────────────────────────────────────'
    end

    box_content = config_sections.join("\n")

    box = TTY::Box.frame(
      box_content,
      title: { top_left: ' 🎛️  Current Configuration ' },
      border: :thick,
      padding: [1, 2],
      style: {
        fg: :bright_white,
        bg: :black,
        border: {
          fg: :magenta,
          bg: :black
        }
      }
    )

    puts box
    puts
  end

  # =========================================================================
  # INTERACTIVE SETTINGS MENU - LLM-specific settings
  # =========================================================================

  def interactive_settings_menu
    current_model = @llm&.instance_variable_get(:@model) || 'Not loaded'

    [
      {
        key: :model,
        label: "Model (#{current_model})",
        icon: '🤖'
      },
      {
        key: :temperature,
        label: "Temperature (#{@options[:temperature]})",
        icon: '🌡️'
      },
      {
        key: :max_tokens,
        label: "Max Tokens (#{@options[:max_tokens]})",
        icon: '📏'
      },
      {
        key: :type,
        label: "Generation Type (#{@options[:type]})",
        icon: '🎯'
      },
      {
        key: :shell,
        label: "Shell/Language (#{@options[:shell]})",
        icon: '🐚'
      },
      {
        key: :auto_retry,
        label: "Auto Retry (#{@options[:auto_retry] ? 'Yes' : 'No'})",
        icon: '🔁'
      }
    ]
  end

  def generate_command
    system_prompt = build_command_system_prompt

    # Set up conversation with system prompt
    @conversation.set_system_prompt(system_prompt)

    # Send user message and get response
    response = @conversation.send_message(@description, {
                                            temperature: @options[:temperature],
                                            max_tokens: @options[:max_tokens]
                                            # Note: streaming not supported with conversation service yet
                                          })

    unless response
      log_error('Failed to generate command')
      return
    end

    # Extract command from response
    command = extract_command_from_response(response)

    log_success('Command generated:')
    puts
    puts "  #{command}"
    puts

    if @options[:execute]
      execute_generated_command(command)
    else
      # Show enhanced action menu: Use It | Edit | Settings | Cancel
      show_enhanced_action_menu(command)
    end
  end

  def show_enhanced_action_menu(command)
    # Show command in nice visual format first
    show_command_visual(command)

    loop do
      choices = [
        { name: '✅ Use It', value: :use_it },
        { name: '📋 Copy Command', value: :copy },
        { name: '✏️  Edit Prompt', value: :edit },
        { name: '📖 Show Conversation', value: :show_conversation },
        { name: '⚙️  Settings', value: :settings },
        { name: '❌ Cancel', value: :cancel }
      ]

      result = @interactive_menu.select_from_choices(
        'What would you like to do?',
        choices
      )

      case result
      when :use_it
        execute_generated_command_directly(command)
        break
      when :copy
        copy_command_to_clipboard(command)
        log_success('Command copied to clipboard! You can paste it in your terminal.')
        next # Show menu again after copying
      when :edit
        edited_prompt = edit_prompt(@description)
        if edited_prompt && edited_prompt != @description
          log_info('Prompt edited. Continuing conversation with new description...')

          # Add context about the edit to maintain conversation flow
          edit_context = "Actually, let me clarify my request: #{edited_prompt}"
          @description = edit_context

          # Continue the conversation with the edited prompt
          regenerate_command
          break
        end
      when :show_conversation
        show_conversation_history
        next # Show menu again after displaying conversation
      when :settings
        show_settings_menu
        # After settings, regenerate the command with new settings
        log_info('Regenerating command with updated settings...')
        regenerate_command
        break
      when :cancel
        log_info('Operation cancelled')
        break
      end
    end
  end

  def show_command_visual(command)
    require 'tty-box'

    box = TTY::Box.frame(
      command,
      title: { top_left: ' Generated Command ' },
      border: :thick,
      padding: [1, 2],
      style: {
        fg: :bright_yellow,
        bg: :black,
        border: {
          fg: :cyan,
          bg: :black
        }
      }
    )

    puts box
    puts
  end

  def copy_command_to_clipboard(command)
    # Try different clipboard methods based on OS
    if RbConfig::CONFIG['host_os'] =~ /darwin/
      # macOS
      system("echo '#{command}' | pbcopy")
    elsif RbConfig::CONFIG['host_os'] =~ /linux/
      # Linux - try xclip first, then xsel
      if system('which xclip > /dev/null 2>&1')
        system("echo '#{command}' | xclip -selection clipboard")
      elsif system('which xsel > /dev/null 2>&1')
        system("echo '#{command}' | xsel --clipboard --input")
      end
    end

    # Also show the command for manual copying
    log_info('Command (manual copy):')
    puts "  #{command}"
    puts
  end

  def show_post_execution_menu(command, full_output)
    loop do
      choices = [
        { name: '🔄 Run Again', value: :run_again },
        { name: '📄 Show Full Output', value: :show_full },
        { name: '✏️  Edit Command', value: :edit_command },
        { name: '💬 Edit Prompt (Continue Conversation)', value: :edit_prompt },
        { name: '📖 Show Conversation', value: :show_conversation },
        { name: '⚙️  Settings', value: :settings },
        { name: '❌ Done', value: :done }
      ]

      result = @interactive_menu.select_from_choices(
        "Command completed. What's next?",
        choices
      )

      case result
      when :run_again
        execute_generated_command_directly(command)
        break
      when :show_full
        log_info('📄 Full output:')
        puts full_output
        puts
        # Show menu again
        next
      when :edit_command
        edited_command = edit_generated_command(command)
        if edited_command && edited_command != command
          log_info('Command edited. Executing updated version...')
          execute_generated_command_directly(edited_command)
        end
        break
      when :edit_prompt
        # Get the original user description, not the current command
        last_user_msg = @conversation&.last_user_message || @description
        edited_prompt = edit_prompt(last_user_msg)
        if edited_prompt && edited_prompt != last_user_msg
          log_info('Prompt edited. Continuing conversation with new description...')

          # Add context about the edit to maintain conversation flow
          edit_context = "Actually, let me clarify my request: #{edited_prompt}"
          @description = edit_context

          # Continue the conversation with the edited prompt
          regenerate_command
          break
        end
        next # Show menu again if no edit was made
      when :new_request
        new_description = get_task_description('✨ What new command would you like to generate?')
        if new_description
          log_info('Starting fresh conversation with new request...')
          # Fork the conversation to keep context available but start fresh
          @conversation = @conversation.fork
          @description = new_description
          # Generate new command with fresh conversation
          generate_command
          break
        end
        next # Show menu again if no new request was entered
      when :show_conversation
        show_conversation_history
        next # Show menu again after displaying conversation
      when :settings
        show_settings_menu
        log_info('Regenerating command with updated settings...')
        regenerate_command
        break
      when :done
        log_info('Operation completed')
        break
      end
    end
  end

  def edit_generated_command(original_command)
    require 'tty-prompt'
    prompt = TTY::Prompt.new

    prompt.ask('✏️  Edit the command:', default: original_command) do |q|
      q.required(true)
      q.modify :strip
    end
  end

  def edit_prompt(original_prompt)
    require 'tty-prompt'
    prompt = TTY::Prompt.new

    prompt.ask('✏️  Edit your prompt:', default: original_prompt) do |q|
      q.required(true)
      q.modify :strip
    end
  end

  def regenerate_command
    # Continue the conversation with the updated description
    log_info('🔄 Regenerating command with conversation context...')

    response = @conversation.continue(@description, {
                                        temperature: @options[:temperature],
                                        max_tokens: @options[:max_tokens]
                                      })

    unless response
      log_error('Failed to regenerate command')
      return
    end

    # Extract command from response
    command = extract_command_from_response(response)

    log_success('Updated command generated with conversation context:')
    puts
    puts "  #{command}"
    puts

    # Show the action menu again with the new command
    show_enhanced_action_menu(command)
  end

  def generate_script
    system_prompt = build_script_system_prompt
    user_prompt = @description

    response = @llm.complete(user_prompt, {
                               system: system_prompt,
                               temperature: @options[:temperature],
                               max_tokens: @options[:max_tokens]
                             })

    unless response
      log_error('Failed to generate script')
      return
    end

    # Extract and clean script from response
    script_content = extract_script_from_response(response)

    if @options[:output_file]
      save_script_to_file(script_content)
    else
      display_script(script_content)
    end
  end

  def build_command_system_prompt
    shell_name = @options[:shell].to_s

    <<~PROMPT
      You are a command line expert specializing in #{shell_name} commands.
      Generate a single, efficient command for the given task.

      Rules:
      - Output ONLY the command, no explanations or formatting
      - Use #{shell_name}-compatible syntax with proper spacing
      - Prefer commonly available tools (find, grep, awk, sed, etc.)
      - Include proper escaping and safety measures
      - For macOS systems, consider BSD vs GNU tool differences
      - If multiple approaches exist, choose the most reliable one
      - Ensure proper spacing: use "find ." not "find."
      - Use full paths when needed for clarity

      Example format:
      find . -name "*.pdf" -size +10M -ls

      The command should be ready to copy and paste into a terminal.
    PROMPT
  end

  def build_script_system_prompt
    case @options[:shell]
    when :bash, :zsh
      shell_name = @options[:shell].to_s
      <<~PROMPT
        You are an expert #{shell_name} script writer.
        Generate a complete, well-structured #{shell_name} script for the given task.

        Requirements:
        - Start with proper shebang (#!/bin/#{shell_name})
        - Use 'set -euo pipefail' for error handling
        - Include helpful comments
        - Use functions for complex logic
        - Add input validation where appropriate
        - Handle errors gracefully
        - Follow #{shell_name} best practices
        - Make the script portable and robust

        Format as a complete script ready to save and execute.
      PROMPT
    when :ruby
      <<~PROMPT
        You are an expert Ruby developer.
        Generate a complete, well-structured Ruby script for the given task.

        Requirements:
        - Start with proper shebang (#!/usr/bin/env ruby)
        - Add 'frozen_string_literal: true' comment
        - Use proper Ruby idioms and style
        - Include error handling with begin/rescue
        - Add helpful comments
        - Use appropriate gems if needed (mention if they need installation)
        - Follow Ruby best practices
        - Make the script clear and maintainable

        Format as a complete script ready to save and execute.
      PROMPT
    when :python
      <<~PROMPT
        You are an expert Python developer.
        Generate a complete, well-structured Python script for the given task.

        Requirements:
        - Start with proper shebang (#!/usr/bin/env python3)
        - Use Python 3 syntax and features
        - Include proper imports at the top
        - Add helpful docstrings and comments
        - Use exception handling (try/except)
        - Follow PEP 8 style guidelines
        - Include main guard (if __name__ == '__main__':)
        - Make the script robust and maintainable

        Format as a complete script ready to save and execute.
      PROMPT
    end
  end

  def extract_command_from_response(response)
    # Remove any markdown code blocks
    cleaned = response.gsub(/```[a-z]*\n?/, '').gsub(/```/, '')

    # Split into lines and find the actual command
    lines = cleaned.split("\n").map(&:strip).reject(&:empty?)

    # Look for the line that looks like a command (not starting with #, etc.)
    command_line = lines.find { |line| !line.start_with?('#', '//', '--', '/*') }

    command = command_line || lines.first || response.strip

    # Clean up common formatting issues
    fix_common_command_issues(command)
  end

  def fix_common_command_issues(command)
    return command unless command

    fixed = command.dup

    # Fix common spacing issues
    fixed = fixed.gsub(/find\./, 'find .')  # find. -> find .
    fixed = fixed.gsub(/ls\./, 'ls .')      # ls. -> ls .
    fixed = fixed.gsub(/cd\./, 'cd .')      # cd. -> cd .

    # Fix other common patterns
    fixed = fixed.gsub(/(\w)\.(\s|$)/, '\1 .\2') # word. -> word .

    # Remove leading/trailing whitespace
    fixed = fixed.strip

    # Log the fix if we made changes
    log_debug("Fixed command formatting: '#{command}' -> '#{fixed}'") if fixed != command && debug?

    fixed
  end

  def extract_script_from_response(response)
    # If response contains code blocks, extract content
    if response.include?('```')
      # Extract content between code blocks
      script_match = response.match(/```(?:[a-z]*\n)?(.*?)```/m)
      return script_match[1].strip if script_match
    end

    # Otherwise return the whole response, cleaned up
    response.strip
  end

  def execute_generated_command(command)
    return if dry_run?

    execute_command_with_retry(command, @options[:max_retries])
  end

  def execute_generated_command_directly(command)
    return if dry_run?

    log_progress('🔄 Executing command...')

    # Capture both stdout and stderr
    start_time = Time.now
    output = `#{command} 2>&1`
    duration = Time.now - start_time
    success = $?.success?

    if success
      log_success("✅ Command executed successfully (took #{duration.round(2)}s)")

      if output.strip.empty?
        log_info('(No output)')
      else
        # Show first 10 lines of output
        lines = output.split("\n")
        truncated_output = lines.first(10)
        remaining_count = lines.length - 10

        log_info('📄 Output (showing first 10 lines):')
        puts truncated_output.join("\n")

        if remaining_count > 0
          puts
          log_info("... and #{remaining_count} more line(s)")
        end

        # If there was output, show the menu again
        if lines.length > 0
          puts
          log_info('What would you like to do next?')
          show_post_execution_menu(command, output)
        end
      end
      true
    else
      log_error("❌ Command failed with exit code: #{$?.exitstatus} (took #{duration.round(2)}s)")
      log_error("📋 Command: #{command}")

      # Show error output
      unless output.strip.empty?
        log_warning('📄 Error output:')
        puts output
      end

      # Handle retries with remaining attempts
      if @options[:max_retries] > 0
        handle_command_failure(command, output, @options[:max_retries])
      else
        log_error('💀 No retry attempts available')
        false
      end
    end
  end

  def execute_command_with_retry(command, retries_left)
    log_warning("🚀 About to execute: #{command}")

    unless force? || confirm_action('⚡ Execute this command?')
      log_info('❌ Command execution cancelled')
      return false
    end

    log_progress('🔄 Executing command...')

    # Capture both stdout and stderr
    start_time = Time.now
    output = `#{command} 2>&1`
    duration = Time.now - start_time
    success = $?.success?

    if success
      log_success("✅ Command executed successfully (took #{duration.round(2)}s)")
      unless output.strip.empty?
        log_info('📄 Output:')
        puts output
      end
      true
    else
      return handle_command_failure(command, output, retries_left) if retries_left > 0

      log_error('💀 No more retry attempts remaining')
      false

    end
  end

  def handle_command_failure(original_command, error_output, retries_left)
    log_error("❌ Command failed with exit code: #{$?.exitstatus}")
    log_error("📋 Original command: #{original_command}")

    # Show error details to user
    unless error_output.strip.empty?
      log_warning('📄 Error output:')
      puts error_output
      puts
    end

    log_warning("🔄 #{retries_left} retry attempt(s) remaining.")

    # Ask user if they want to retry with LLM improvement
    should_retry = @options[:auto_retry] ||
                   confirm_action('🔧 Would you like the LLM to analyze the error and suggest a fix?')

    unless should_retry
      log_info('❌ Retry cancelled by user')
      return false
    end

    # Generate improved command using error feedback
    log_info('🤖 Analyzing error and generating improved command...')
    improved_command = generate_improved_command(original_command, error_output)

    unless improved_command
      log_error('❌ Failed to generate improved command')
      return false
    end

    if improved_command == original_command
      log_warning('⚠️ LLM suggested the same command. Stopping to avoid infinite loop.')
      return false
    end

    log_success('✅ Improved command generated:')
    puts "  #{improved_command}"
    puts

    # Recursively try the improved command
    execute_command_with_retry(improved_command, retries_left - 1)
  end

  def generate_improved_command(original_command, error_output)
    # Create a separate conversation for error analysis to avoid polluting main conversation
    error_conversation = ConversationService.new(@llm)
    system_prompt = build_error_analysis_prompt
    error_conversation.set_system_prompt(system_prompt)

    user_prompt = <<~PROMPT
      Original command: #{original_command}

      Error output:
      #{error_output}

      The command failed. Please analyze the error and provide a corrected command.
      Focus on:
      - Fixing syntax errors
      - Handling missing dependencies
      - Correcting file paths
      - Adding necessary permissions
      - Using alternative approaches if the tool isn't available
    PROMPT

    response = error_conversation.send_message(user_prompt, {
                                                 temperature: 0.1, # Lower temperature for error fixing
                                                 max_tokens: 500
                                               })

    return nil unless response

    extract_command_from_response(response)
  end

  def build_error_analysis_prompt
    shell_name = @options[:shell].to_s

    <<~PROMPT
      You are a command line debugging expert specializing in #{shell_name}.
      Analyze command failures and provide corrected commands.

      When a command fails:
      1. Identify the root cause from the error output
      2. Provide a corrected command that addresses the issue
      3. Consider common problems: permissions, missing tools, wrong paths, syntax errors
      4. If the original tool isn't available, suggest alternatives
      5. For macOS, consider BSD vs GNU tool differences

      Rules:
      - Output ONLY the corrected command, no explanations
      - Don't repeat the same command if it's clearly wrong
      - Provide practical, working solutions
      - Consider the user's current environment and permissions

      Example:
      If 'grep -P' fails on macOS, suggest 'grep -E' or 'ggrep -P'
      If permissions denied, suggest adding 'sudo' where appropriate
    PROMPT
  end

  def save_script_to_file(script_content)
    file_path = File.expand_path(@options[:output_file])

    if File.exist?(file_path) && !force? && !confirm_action("File #{file_path} exists. Overwrite?")
      log_info('Script save cancelled')
      return
    end

    return log_info("[DRY-RUN] Would write script to: #{file_path}") if dry_run?

    begin
      File.write(file_path, script_content)
      File.chmod(0o755, file_path) # Make executable

      log_success("Script saved to: #{file_path}")
      log_info('Made executable with chmod +x')

      if %i[ruby python].include?(@options[:shell])
        log_info('You may need to install required gems/packages mentioned in the script')
      end
    rescue StandardError => e
      log_error("Failed to save script: #{e.message}")
    end
  end

  def display_script(script_content)
    log_success('Generated script:')
    puts
    puts script_content
    puts
    log_info('Use -o/--output FILE to save to a file, or copy the script above')
  end

  def show_conversation_history
    return unless @conversation

    require 'tty-box'

    summary = @conversation.summary
    log_info("📖 Conversation History (#{summary[:total_messages]} messages)")
    puts

    messages = @conversation.export_history
    messages.each_with_index do |msg, i|
      role_info = case msg[:role]
                  when 'system' then { emoji: '⚙️', label: 'System', color: :magenta }
                  when 'user' then { emoji: '👤', label: 'You', color: :cyan }
                  when 'assistant' then { emoji: '🤖', label: 'Assistant', color: :green }
                  else { emoji: '❓', label: 'Unknown', color: :white }
                  end

      content = msg[:content]
      # Limit content display for readability
      display_content = content.length > 200 ? "#{content[0...200]}..." : content

      box = TTY::Box.frame(
        display_content,
        title: { top_left: " #{role_info[:emoji]} #{role_info[:label]} ##{i + 1} " },
        border: :light,
        padding: [0, 1],
        style: {
          fg: role_info[:color],
          bg: :black,
          border: {
            fg: role_info[:color],
            bg: :black
          }
        }
      )

      puts box
      puts
    end

    log_info('This conversation context will be maintained when you edit prompts or regenerate commands.')
    puts
  end

  # =========================================================================
  # INTERACTIVE SETTINGS MENU - LLM-specific settings
  # =========================================================================

  def handle_setting_change(setting_key, menu_service)
    case setting_key
    when :model
      change_model_setting(menu_service)
    when :temperature
      change_temperature_setting(menu_service)
    when :max_tokens
      change_max_tokens_setting(menu_service)
    when :type
      change_type_setting(menu_service)
    when :shell
      change_shell_setting(menu_service)
    when :auto_retry
      change_auto_retry_setting(menu_service)
    else
      super
    end
  end

  def change_model_setting(menu_service)
    return unless @llm

    models = @llm.models
    if models.empty?
      log_warning('No models available')
      return
    end

    current_model = @llm.instance_variable_get(:@model)
    choices = models.map { |m| { name: m, value: m } }

    selected_model = menu_service.select_from_choices(
      '🤖 Select model:',
      choices,
      default: models.index(current_model)&.+(1)
    )

    return unless selected_model != current_model

    @llm.set_model(selected_model)
    @options[:model] = selected_model
    save_current_settings
    log_success("Model changed to: #{selected_model}")
  end

  def change_temperature_setting(menu_service)
    current_temp = @options[:temperature]

    new_temp = menu_service.select_from_choices(
      '🌡️ Select temperature:',
      [
        { name: '0.1 - Very focused', value: 0.1 },
        { name: '0.3 - Focused', value: 0.3 },
        { name: '0.5 - Balanced', value: 0.5 },
        { name: "0.7 - Creative (current: #{current_temp})", value: 0.7 },
        { name: '0.9 - Very creative', value: 0.9 },
        { name: 'Custom...', value: :custom }
      ]
    )

    if new_temp == :custom
      new_temp = TTY::Prompt.new.ask('Enter temperature (0.0-1.0):', convert: :float) do |q|
        q.in('0.0-1.0')
        q.default(current_temp)
      end
    end

    @options[:temperature] = new_temp
    @llm&.instance_variable_set(:@temperature, new_temp)
    save_current_settings
    log_success("Temperature changed to: #{new_temp}")
  end

  def change_max_tokens_setting(menu_service)
    current_tokens = @options[:max_tokens]

    new_tokens = menu_service.select_from_choices(
      '📏 Select max tokens:',
      [
        { name: '500 - Short responses', value: 500 },
        { name: '1000 - Medium responses', value: 1000 },
        { name: '2000 - Long responses', value: 2000 },
        { name: "4096 - Very long responses (current: #{current_tokens})", value: 4096 },
        { name: 'Custom...', value: :custom }
      ]
    )

    if new_tokens == :custom
      new_tokens = TTY::Prompt.new.ask('Enter max tokens (10-10000):', convert: :int) do |q|
        q.range(10..10_000)
        q.default(current_tokens)
      end
    end

    @options[:max_tokens] = new_tokens
    @llm&.instance_variable_set(:@max_tokens, new_tokens)
    save_current_settings
    log_success("Max tokens changed to: #{new_tokens}")
  end

  def change_type_setting(menu_service)
    new_type = menu_service.select_from_choices(
      '🎯 Select generation type:',
      [
        { name: 'Single command', value: :command },
        { name: 'Complete script', value: :script }
      ]
    )

    @options[:type] = new_type
    save_current_settings
    log_success("Generation type changed to: #{new_type}")
  end

  def change_shell_setting(menu_service)
    new_shell = menu_service.select_from_choices(
      '🐚 Select shell/language:',
      [
        { name: 'ZSH script', value: :zsh },
        { name: 'Bash script', value: :bash },
        { name: 'Ruby script', value: :ruby },
        { name: 'Python script', value: :python }
      ]
    )

    @options[:shell] = new_shell
    save_current_settings
    log_success("Shell/language changed to: #{new_shell}")
  end

  def change_auto_retry_setting(menu_service)
    new_auto_retry = menu_service.confirm('🔁 Enable auto-retry on command failures?', default: @options[:auto_retry])

    @options[:auto_retry] = new_auto_retry
    save_current_settings
    log_success("Auto-retry #{new_auto_retry ? 'enabled' : 'disabled'}")
  end
end

# Execute the script
LLMGenerator.execute if __FILE__ == $0
