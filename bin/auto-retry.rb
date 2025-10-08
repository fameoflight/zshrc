#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/services/unified_llm_service'

# Auto-retry utility that uses local LLM to analyze command failures and determine retry strategies
class AutoRetry < ScriptBase
  def script_emoji; '🔄'; end
  def script_title; 'Auto-Retry Command'; end
  def script_description; 'Automatically reruns failed commands using LLM analysis'; end
  def script_arguments; '[OPTIONS] -- <command> [args...]'; end

  def initialize
    super
    @llm_service = nil
    @max_retries = 3
    @retry_delay = 1
    @current_attempt = 0
  end

  def add_custom_options(opts)
    opts.on('-m', '--max-retries NUM', Integer, 'Maximum retry attempts (default: 3)') do |num|
      @options[:max_retries] = num
    end
    opts.on('-d', '--delay SECONDS', Float, 'Delay between retries in seconds (default: 1.0)') do |delay|
      @options[:delay] = delay
    end
    opts.on('--provider PROVIDER', 'LLM provider (ollama, lm_studio, anthropic)') do |provider|
      @options[:provider] = provider
    end
    opts.on('--model MODEL', 'Specific model to use for analysis') do |model|
      @options[:model] = model
    end
    opts.on('--no-analysis', 'Skip LLM analysis, just retry on any failure') do
      @options[:no_analysis] = true
    end
  end

  def validate!
    super

    if args.empty?
      log_error("No command specified. Use -- to separate options from the command.")
      show_examples
      exit 1
    end

    @command_parts = args
    @max_retries = @options[:max_retries] || 3
    @retry_delay = @options[:delay] || 1.0

    # Initialize LLM service unless analysis is disabled
    unless @options[:no_analysis]
      begin
        @llm_service = UnifiedLLMService.new(
          logger: self,
          debug: debug?,
          preferred_provider: @options[:provider],
          model: @options[:model]
        )
        log_debug("LLM service initialized with provider: #{@llm_service.current_provider}")
      rescue => e
        log_warning("Failed to initialize LLM service: #{e.message}")
        log_info("Falling back to simple retry without analysis")
        @options[:no_analysis] = true
      end
    end
  end

  def run
    log_banner("Auto-Retry Command")

    command_string = @command_parts.join(' ')
    log_info("Command: #{command_string}")
    log_info("Max retries: #{@max_retries}")
    log_info("Analysis: #{@options[:no_analysis] ? 'disabled' : 'enabled'}")

    success = false
    @current_attempt = 0

    while @current_attempt <= @max_retries && !success
      @current_attempt += 1
      attempt_label = @current_attempt == 1 ? "Initial attempt" : "Retry #{@current_attempt - 1}/#{@max_retries}"

      log_section("#{attempt_label}")

      success = execute_command_attempt(command_string)

      if success
        log_success("Command succeeded on attempt #{@current_attempt}")
        break
      elsif @current_attempt <= @max_retries
        handle_failure(command_string)
      else
        log_error("Command failed after #{@max_retries + 1} attempts")
        exit 1
      end
    end

    show_completion("Auto-retry command")
  end

  def show_examples
    puts "\nExamples:"
    puts "  #{script_name} -- npm install                              # Retry npm install on failure"
    puts "  #{script_name} --max-retries 5 -- git push                # Retry up to 5 times"
    puts "  #{script_name} --delay 2.5 -- curl https://api.example.com # Wait 2.5s between retries"
    puts "  #{script_name} --provider ollama -- python test.py        # Use Ollama for analysis"
    puts "  #{script_name} --no-analysis -- flaky-command             # Simple retry without AI"
    puts ""
    puts "Note: Use -- to separate script options from the command to retry"
  end

  private

  def execute_command_attempt(command)
    log_progress("Executing: #{command}")

    start_time = Time.now

    # Use system() for real-time output, then capture for analysis if needed
    puts "\n--- Command Output ---"
    success = system(command)
    status_code = $?.exitstatus

    duration = Time.now - start_time

    if success
      log_success("Command completed successfully in #{duration.round(2)}s")
      return true
    else
      log_error("Command failed with exit code #{status_code} after #{duration.round(2)}s")

      # For failure analysis, capture the output separately
      stdout, stderr, _ = Open3.capture3(command) if @llm_service

      # Store error details for analysis
      @last_error = {
        command: command,
        exit_code: status_code,
        stdout: stdout || "",
        stderr: stderr || "",
        duration: duration,
        attempt: @current_attempt
      }

      return false
    end
  end

  def handle_failure(command)
    if @current_attempt <= @max_retries
      should_retry = should_retry_command?

      if should_retry
        log_info("Will retry in #{@retry_delay} seconds...")
        sleep(@retry_delay) if @retry_delay > 0
      else
        log_warning("LLM analysis suggests not to retry this error")
        exit 1
      end
    end
  end

  def should_retry_command?
    return true if @options[:no_analysis] || @llm_service.nil?

    log_progress("Analyzing error with LLM...")

    begin
      analysis_prompt = build_error_analysis_prompt
      response = @llm_service.complete(analysis_prompt)

      log_debug("LLM response: #{response}") if debug?

      # Parse the response to determine if we should retry
      should_retry = parse_retry_decision(response)

      if should_retry
        log_info("✅ LLM recommends retry: #{extract_reason(response)}")
      else
        log_warning("❌ LLM recommends not to retry: #{extract_reason(response)}")
      end

      should_retry
    rescue => e
      log_warning("Error during LLM analysis: #{e.message}")
      log_info("Falling back to simple retry")
      true # Default to retry on analysis failure
    end
  end

  def build_error_analysis_prompt
    error_details = @last_error

    prompt = <<~PROMPT
      Analyze this command failure and determine if it should be retried:

      Command: #{error_details[:command]}
      Exit Code: #{error_details[:exit_code]}
      Attempt: #{error_details[:attempt]}/#{@max_retries + 1}
      Duration: #{error_details[:duration].round(2)}s

      STDERR:
      #{error_details[:stderr].strip.empty? ? '(empty)' : error_details[:stderr]}

      STDOUT:
      #{error_details[:stdout].strip.empty? ? '(empty)' : error_details[:stdout]}

      Please analyze this error and respond with:
      1. DECISION: Either "RETRY" or "STOP"
      2. REASON: Brief explanation of why

      Consider these factors:
      - Network/connectivity issues → usually worth retrying
      - Rate limiting/throttling → usually worth retrying
      - Temporary resource unavailability → usually worth retrying
      - Invalid syntax/arguments → not worth retrying
      - Missing files/permissions → not worth retrying
      - Authentication failures → not worth retrying

      Format your response as:
      DECISION: [RETRY|STOP]
      REASON: [your explanation]
    PROMPT

    prompt
  end

  def parse_retry_decision(response)
    # Look for DECISION line
    decision_line = response.lines.find { |line| line.match?(/^DECISION:/i) }

    return true unless decision_line # Default to retry if we can't parse

    decision = decision_line.split(':', 2)[1]&.strip&.upcase
    decision == 'RETRY'
  end

  def extract_reason(response)
    # Look for REASON line
    reason_line = response.lines.find { |line| line.match?(/^REASON:/i) }

    return "Analysis completed" unless reason_line

    reason_line.split(':', 2)[1]&.strip || "No reason provided"
  end
end

AutoRetry.execute if __FILE__ == $0