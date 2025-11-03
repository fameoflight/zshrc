# frozen_string_literal: true

require_relative 'script_base'
require 'tty-prompt'
require 'set'

# Base class for interactive Ruby scripts with menu systems
class InteractiveScriptBase < ScriptBase
  attr_reader :prompt

  def initialize
    super
    @prompt = TTY::Prompt.new
    @continue_running = true
  end

  # Override in subclass to define menu options
  def menu_options
    raise NotImplementedError, "Subclass must implement menu_options method"
  end

  # Override in subclass to handle menu choices
  def handle_menu_choice(choice)
    raise NotImplementedError, "Subclass must implement handle_menu_choice method"
  end

  # Override in subclass to perform any setup before starting interactive mode
  def setup_interactive_mode
    # Default: no setup needed
  end

  # Override in subclass to perform any cleanup after interactive mode
  def cleanup_interactive_mode
    # Default: no cleanup needed
  end

  # Main interactive loop
  def start_interactive_mode
    setup_interactive_mode
    
    loop do
      break unless @continue_running
      
      show_header
      choice = show_menu
      
      break if choice == :exit
      
      handle_menu_choice(choice)
      wait_for_continue unless choice == :exit
    end
    
    cleanup_interactive_mode
    show_goodbye
  end

  # Display header for each menu iteration
  def show_header
    puts
    log_info tool_title
    puts
  end

  # Show the interactive menu
  def show_menu
    @prompt.select("What would you like to do?", cycle: true) do |menu|
      menu_options.each do |option|
        if option.is_a?(Hash)
          menu.choice option[:label], option[:value]
        else
          menu.choice option[:label], option[:value] if option.respond_to?(:each_pair)
        end
      end
      
      # Always add exit option
      menu.choice "❌ Exit", :exit
    end
  end

  # Wait for user input before continuing
  def wait_for_continue
    puts
    @prompt.keypress("Press any key to continue...", timeout: 30)
  end

  # Show goodbye message
  def show_goodbye
    log_info "👋 Goodbye!"
  end

  # Stop the interactive loop
  def exit_interactive_mode
    @continue_running = false
  end

  # Get tool title - override in subclass
  def tool_title
    script_name.gsub('-', ' ').split.map(&:capitalize).join(' ')
  end

  # Common prompt helpers
  def ask_number(question, default: nil, min: nil, max: nil)
    @prompt.ask(question, default: default) do |q|
      q.validate(/^\d+$/, "Please enter a number")
      q.convert ->(input) { input.to_i }
      q.validate ->(input) { input.to_i >= min } if min
      q.validate ->(input) { input.to_i <= max } if max
    end
  end

  def ask_yes_no(question, default: nil)
    @prompt.yes?(question, default: default)
  end

  def ask_choice(question, choices)
    @prompt.select(question, choices, cycle: true)
  end

  def ask_multi_choice(question, choices)
    @prompt.multi_select(question, choices)
  end

  def ask_string(question, default: nil, required: true)
    @prompt.ask(question, default: default) do |q|
      q.validate ->(input) { !input.strip.empty? } if required
    end
  end

  def confirm_action(message)
    @prompt.yes?("#{message} Continue?", default: false)
  end

  # Progress and status helpers
  def with_progress(title, total: nil)
    if total
      bar = TTY::ProgressBar.new(
        "#{title} [:bar] :current/:total (:percent%)",
        total: total,
        width: 30,
        bar_format: :block
      )
    else
      bar = TTY::ProgressBar.new(
        "#{title} [:bar] :current",
        total: nil,
        width: 30,
        bar_format: :block
      )
    end
    
    yield bar
    bar.finish
    puts
  end

  def show_table(data, headers: nil)
    return log_info "No data to display" if data.empty?
    
    # Simple table display
    if headers
      puts headers.join(" | ")
      puts "-" * headers.join(" | ").length
    end
    
    data.each do |row|
      if row.is_a?(Array)
        puts row.join(" | ")
      elsif row.is_a?(Hash)
        puts row.values.join(" | ")
      else
        puts row.to_s
      end
    end
  end

  # Menu option builder helpers
  def menu_option(emoji, text, value)
    { label: "#{emoji} #{text}", value: value }
  end

  def separator
    { separator: true }
  end

  # Common menu options that can be reused
  def refresh_option(value = :refresh)
    menu_option("🔄", "Refresh data", value)
  end

  def settings_option(value = :settings)
    menu_option("⚙️", "Settings", value)
  end

  def help_option(value = :help)
    menu_option("❓", "Help", value)
  end

  def clear_cache_option(value = :clear_cache)
    menu_option("🗑️", "Clear cache", value)
  end

  # Status display helpers
  def show_status(title, items)
    log_success title
    items.each do |key, value|
      puts "#{' ' * 4}#{key}: #{value}"
    end
    puts
  end

  def show_list(title, items, numbered: true)
    return log_info "No #{title.downcase} to display" if items.empty?
    
    log_success title
    puts
    
    items.each_with_index do |item, index|
      prefix = numbered ? "#{' ' * 2}#{(index + 1).to_s.rjust(2)}. " : "#{' ' * 4}• "
      
      if item.is_a?(Hash)
        # Display hash as key-value pairs
        main_line = item.values.first
        puts "#{prefix}#{main_line}"
        item.each_with_index do |(k, v), i|
          next if i == 0 # Skip first item (already shown)
          puts "#{' ' * 6}#{k}: #{v}"
        end
      else
        puts "#{prefix}#{item}"
      end
      puts
    end
  end

  # Error handling for interactive mode
  def handle_interactive_error(error)
    log_error "An error occurred: #{error.message}"
    
    if @options[:debug] || @options[:verbose]
      puts
      log_info "Stack trace:"
      error.backtrace.first(5).each { |line| puts "  #{line}" }
    end
    
    puts
    if @prompt.yes?("Would you like to continue?", default: true)
      return
    else
      exit_interactive_mode
    end
  end

  # Wrap menu actions with error handling
  def safe_execute(&block)
    yield
  rescue StandardError => e
    handle_interactive_error(e)
  end

  # Cache management helpers (if using cache)
  def with_cache_check(cache_method, update_method, force_update: false)
    if cache_method.call == 0 || force_update
      log_info "🔄 Updating data cache"
      update_method.call
    else
      log_info "📦 Using cached data"
    end
  end

  # Interactive selectable list with keyboard navigation
  # items: Array of items to display
  # display_proc: Proc that takes an item and returns display text
  # multi_select: Boolean, allows multiple selections
  # Returns: Array of selected items (even for single select)
  def interactive_selectable_list(items, display_proc:, multi_select: true, header: nil)
    return [] if items.empty?

    if header
      puts header
      puts
    end

    # Convert items to choices for TTY::Prompt
    choices = items.map.with_index do |item, index|
      display_text = display_proc.call(item)
      { name: display_text, value: item }
    end

    # Add exit option to choices
    exit_choice = { name: "🚪 Exit (ESC)", value: :__exit__ }
    choices_with_exit = choices + [exit_choice]

    # Create a custom prompt with ESC handling
    begin
      if multi_select
        selected = @prompt.multi_select("Select items:", choices_with_exit, per_page: 15, cycle: true)
        
        # Check if exit was selected and remove it from results
        if selected && selected.include?(:__exit__)
          log_info "Selection cancelled by user"
          return []
        end
        
        selected || []
      else
        selected = @prompt.select("Select item:", choices_with_exit, per_page: 15, cycle: true)
        
        # Check if exit was selected
        if selected == :__exit__
          log_info "Selection cancelled by user"
          return []
        end
        
        [selected] # Return as array for consistency
      end
    rescue TTY::Reader::InputInterrupt
      # User pressed Ctrl+C to exit
      log_info "Selection cancelled by user"
      return []
    end
  end

  # Enhanced selectable list with custom actions and keyboard shortcuts
  # items: Array of items to display
  # options:
  #   display_proc: Proc that takes an item and returns display text
  #   actions: Hash of key -> { description: String, callback: Proc }
  #   per_page: Number of items to show per page (default: 10)
  #   header: Optional header text
  # Returns: { selected: Array, action_taken: Symbol }
  def interactive_select_with_actions(items, options = {})
    return { selected: [], action_taken: nil } if items.empty?

    # Set defaults
    display_proc = options[:display_proc] || proc { |item| item.to_s }
    actions = options[:actions] || {}
    per_page = options[:per_page] || 10
    header = options[:header]

    if header
      puts header
      puts
    end

    # Show available actions if any
    if actions.any?
      puts "🎮 Available actions:"
      actions.each do |key, config|
        puts "  • #{key}: #{config[:description]}"
      end
      puts
    end

    # Create choices with enhanced display
    choices = items.map.with_index do |item, index|
      display_text = display_proc.call(item)
      { name: "#{index + 1}. #{display_text}", value: item }
    end

    begin
      # Show the multi-select menu
      selected = @prompt.multi_select(
        "Select items:",
        choices,
        per_page: per_page,
        cycle: true,
        help: "↑/↓/Space to select, Enter to confirm, ESC to exit"
      )

      # After selection, offer to perform actions
      if actions.any? && selected && selected.any?
        action_choices = []
        actions.each do |key, config|
          action_choices << "#{key}: #{config[:description]}"
        end

        action_choices << "Continue with selection"

        action = @prompt.select("What would you like to do?", action_choices, cycle: true)

        if action != "Continue with selection"
          # Find and execute the selected action
          action_key = nil
          actions.each do |key, config|
            if action == "#{key}: #{config[:description]}"
              action_key = key
              break
            end
          end

          if action_key && actions[action_key]
            # Call the action callback with context
            actions[action_key][:callback].call({
              selected_items: selected,
              all_items: items,
              prompt: @prompt
            })

            # Show menu again after action
            return interactive_select_with_actions(items, options)
          end
        end
      end

      return { selected: selected || [], action_taken: :select }
    rescue TTY::Reader::InputInterrupt
      log_info "Selection cancelled by user"
      return { selected: [], action_taken: :cancelled }
    end
  end

  private

  def build_help_text(actions)
    help_parts = ["↑/↓/Space to select", "Enter to confirm", "ESC to exit"]

    if actions.any?
      action_keys = actions.keys.map { |k| "'#{k}'" }.join(", ")
      help_parts << "#{action_keys} for actions"
    end

    help_parts.join(", ")
  end
end

# Menu option class for more complex menu definitions
class MenuOption
  attr_reader :emoji, :text, :value, :description, :enabled

  def initialize(emoji:, text:, value:, description: nil, enabled: true)
    @emoji = emoji
    @text = text  
    @value = value
    @description = description
    @enabled = enabled
  end

  def label
    label = "#{@emoji} #{@text}"
    label += " (disabled)" unless @enabled
    label
  end

  def disabled?
    !@enabled
  end
end