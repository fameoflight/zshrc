#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: data
# @description: Check OpenRouter API usage and credit balance
# @tags: api, monitoring, llm

require_relative '../../.common/script_base'
require_relative '../lib/archive/config_manager'
require 'net/http'
require 'uri'
require 'json'

# OpenRouter Usage Checker
# Checks API usage and statistics for OpenRouter.ai accounts
class OpenRouterUsageScript < ScriptBase
  def script_emoji; '📊'; end
  def script_title; 'OpenRouter Usage Checker'; end
  def script_description; 'Check OpenRouter API usage and account statistics'; end
  def script_arguments; '[OPTIONS]'; end

  def initialize
    super
    @config_manager = ConfigManager.new('openrouter-usage')
    @api_base_url = 'https://openrouter.ai/api/v1'
  end

  def add_custom_options(opts)
    opts.on('-k', '--set-key', 'Set OpenRouter API key') do
      @options[:set_key] = true
    end

    opts.on('--show-key', 'Show current API key (truncated)') do
      @options[:show_key] = true
    end

    opts.on('--reset-key', 'Remove saved API key') do
      @options[:reset_key] = true
    end

    opts.on('-j', '--json', 'Output usage data in JSON format') do
      @options[:json_output] = true
    end
  end

  def validate!
    super
    # No additional validation needed
  end

  def run
    log_banner(script_title)

    # Handle key management options first
    handle_key_management if key_management_requested?
    return unless should_proceed_with_usage_check?

    # Ensure we have an API key
    unless @config_manager.has_api_key?
      log_error("No API key found. Please set one using --set-key option")
      show_usage_example
      return
    end

    # Fetch and display usage data
    fetch_and_display_usage

    show_completion(script_title)
  end

  private

  def handle_key_management
    if @options[:set_key]
      log_progress("Setting OpenRouter API key")
      success = @config_manager.prompt_and_save_api_key('OpenRouter')
      if success
        puts "API key saved to: #{@config_manager.config_path}"
      end
      return false
    end

    if @options[:show_key]
      api_key = @config_manager.get_api_key
      if api_key && !api_key.empty?
        puts "Current API key: ***#{api_key[-4..-1]}"
        puts "Config file: #{@config_manager.config_path}"
      else
        log_warning("No API key found")
      end
      return false
    end

    if @options[:reset_key]
      if confirm_action("Remove saved OpenRouter API key?", force: false)
        @config_manager.delete_config!
        log_success("API key removed")
      else
        log_info("Operation cancelled")
      end
      return false
    end

    true
  end

  def key_management_requested?
    @options[:set_key] || @options[:show_key] || @options[:reset_key]
  end

  def should_proceed_with_usage_check?
    return false if key_management_requested?

    # Always validate API key before proceeding
    validate_api_key
  end

  def validate_api_key
    # First check if we have an API key
    unless @config_manager.has_api_key?
      log_error("No API key found. Please set your OpenRouter API key.")
      prompt_for_api_key
      return false unless @config_manager.has_api_key?
    end

    # Try to validate the API key with a quick API call
    begin
      log_progress("Validating API key")
      test_response = fetch_usage_data
      true
    rescue StandardError => e
      log_error("API key validation failed: #{e.message}")
      log_info("Please check your API key or set a new one")

      if confirm_action("Would you like to set a new API key?")
        prompt_for_api_key
        return @config_manager.has_api_key?
      end
      false
    end
  end

  def prompt_for_api_key
    log_info("You can get your API key from: https://openrouter.ai/keys")
    if confirm_action("Set OpenRouter API key now?")
      success = @config_manager.prompt_and_save_api_key('OpenRouter')
      if success
        log_success("API key saved successfully")
      else
        log_error("Failed to save API key")
      end
    end
  end

  def fetch_and_display_usage
    log_progress("Fetching OpenRouter usage data")

    begin
      usage_data = fetch_usage_data
      display_usage_data(usage_data)
    rescue StandardError => e
      log_error("Failed to fetch usage data: #{e.message}")
      log_info("Please check your API key and try again")
    end
  end

  def fetch_usage_data
    api_key = @config_manager.get_api_key
    uri = URI("#{@api_base_url}/key")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    case response.code
    when '200'
      JSON.parse(response.body, symbolize_names: true)
    when '401'
      raise StandardError, "Invalid API key"
    when '403'
      raise StandardError, "Access forbidden - check API permissions"
    when '429'
      raise StandardError, "Rate limit exceeded - please try again later"
    else
      raise StandardError, "HTTP #{response.code}: #{response.message}"
    end
  end

  def display_usage_data(data)
    if @options[:json_output]
      puts JSON.pretty_generate(data)
      return
    end

    return unless data && data[:data]

    usage = data[:data]

    log_section("OpenRouter Account Information")
    puts "Label: #{usage[:label] || 'N/A'}"
    puts "Free Tier: #{usage[:is_free_tier] ? 'Yes' : 'No'}"

    if usage[:limit]
      puts "Credit Limit: $#{format_number(usage[:limit])}"
      puts "Remaining Credits: $#{format_number(usage[:limit_remaining])}" if usage[:limit_remaining]
      puts "Limit Reset: #{usage[:limit_reset] || 'Never'}" if usage[:limit_reset]
    else
      puts "Credit Limit: Unlimited"
    end

    puts "Include BYOK in Limit: #{usage[:include_byok_in_limit] ? 'Yes' : 'No'}"

    log_section("Usage Statistics")
    puts "All-time Usage: #{format_credits(usage[:usage])} credits"
    puts "Daily Usage: #{format_credits(usage[:usage_daily])} credits"
    puts "Weekly Usage: #{format_credits(usage[:usage_weekly])} credits"
    puts "Monthly Usage: #{format_credits(usage[:usage_monthly])} credits"

    log_section("BYOK (Bring Your Own Key) Usage")
    puts "BYOK All-time Usage: #{format_credits(usage[:byok_usage])} credits"
    puts "BYOK Daily Usage: #{format_credits(usage[:byok_usage_daily])} credits"
    puts "BYOK Weekly Usage: #{format_credits(usage[:byok_usage_weekly])} credits"
    puts "BYOK Monthly Usage: #{format_credits(usage[:byok_usage_monthly])} credits"

    # Show rate limits and free tier information
    log_section("Rate Limits & Free Tier Information")
    puts "Account Type: #{usage[:is_free_tier] ? 'Free Tier' : 'Paid Account'}"

    if usage[:is_free_tier]
      puts "Free Model Limits:"
      puts "  • Rate Limit: 20 requests per minute"

      # Estimate daily limit based on usage
      total_usage = usage[:usage] || 0
      if total_usage < 10
        puts "  • Daily Limit: 50 :free model requests per day"
      else
        puts "  • Daily Limit: 1000 :free model requests per day (requires 10+ credits purchased)"
      end
    else
      puts "No free model daily limits - paid account"
    end

    # Show usage percentage if there's a limit
    if usage[:limit] && usage[:limit] > 0 && usage[:limit_remaining]
      used_percentage = ((usage[:limit] - usage[:limit_remaining]) / usage[:limit] * 100).round(2)
      puts
      puts "Usage: #{used_percentage}% of limit"

      # Visual progress bar
      bar_length = 30
      used_length = (bar_length * used_percentage / 100).to_i
      remaining_length = bar_length - used_length

      bar = "█" * used_length + "░" * remaining_length
      puts "┌#{'─' * bar_length}┐"
      puts "│#{bar}│ #{used_percentage}%"
      puts "└#{'─' * bar_length}┘"
    end
  end

  def format_credits(value)
    return '0.000000' unless value
    value.is_a?(Integer) ? sprintf('%.6f', value) : sprintf('%.6f', value)
  end

  def format_number(value)
    return '0' unless value
    sprintf('%.2f', value)
  end

  def show_usage_example
    puts
    puts "To set your API key:"
    puts "  #{script_name} --set-key"
    puts
    puts "Get your API key from: https://openrouter.ai/keys"
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                              # Show current usage"
    puts "  #{script_name} --set-key                   # Set API key"
    puts "  #{script_name} --show-key                  # Show saved API key"
    puts "  #{script_name} --json                      # Output in JSON format"
    puts "  #{script_name} --reset-key                 # Remove saved API key"
  end
end

OpenRouterUsageScript.execute if __FILE__ == $0