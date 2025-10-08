# frozen_string_literal: true

require_relative 'file_processing_tracker'
require_relative 'utils/progress_utils'
require_relative 'utils/parallel_utils'

# Common workflow processor for multi-pass file operations with caching
class WorkflowProcessor
  include ProgressUtils
  include ParallelUtils

  attr_reader :tracker, :logger

  def initialize(tracker = nil, logger: nil, options: {})
    @tracker = tracker || FileProcessingTracker.new
    @logger = logger
    @options = options
  end

  # Process files through multiple passes with caching support
  # Each pass can filter files and generate results
  def process_workflow(file_paths, passes, options = {})
    workflow_result = {
      initial_files: file_paths.dup,
      final_files: file_paths.dup,
      pass_results: [],
      summary: {}
    }

    log_info "Starting workflow with #{file_paths.length} files through #{passes.length} passes"

    passes.each_with_index do |pass_config, pass_index|
      pass_number = pass_index + 1
      pass_name = pass_config[:name] || "Pass #{pass_number}"

      log_section "#{pass_name} (#{pass_number}/#{passes.length})"

      # Process this pass
      pass_result = process_single_pass(
        workflow_result[:final_files],
        pass_config,
        pass_number: pass_number
      )

      workflow_result[:pass_results] << pass_result

      # Update remaining files for next pass
      if pass_config[:filter_remaining]
        excluded_files = pass_result[:results].select { |r| r[:exclude_from_next_pass] }
                                           .map { |r| r[:path] }
        workflow_result[:final_files] -= excluded_files

        log_info "Excluding #{excluded_files.length} files from remaining passes" if excluded_files.any?
      end

      log_info "#{pass_name} completed"
    end

    # Generate summary
    workflow_result[:summary] = generate_workflow_summary(workflow_result)

    log_section "Workflow Summary"
    workflow_result[:summary].each do |key, value|
      log_info "#{key.to_s.gsub('_', ' ').capitalize}: #{value}"
    end

    workflow_result
  end

  # Process a single pass with caching support
  def process_single_pass(file_paths, pass_config, options = {})
    pass_number = options[:pass_number] || 1

    result = {
      pass_name: pass_config[:name],
      pass_number: pass_number,
      input_files: file_paths.dup,
      processed_files: [],
      cached_files: [],
      results: [],
      errors: []
    }

    # Early exit if no files
    if file_paths.empty?
      log_info "No files to process in this pass"
      return result
    end

    # Show processing summary if caching is enabled
    if pass_config[:enable_cache] && !@options[:disable_tracking] && !@options[:force_reprocess]
      summary = @tracker.get_processing_summary(
        file_paths,
        pass_config[:operation_name],
        params: pass_config[:operation_params] || {}
      )
      @tracker.print_processing_summary(summary, pass_config[:cache_description] || "results")
    end

    # Filter files if filter proc is provided
    if pass_config[:filter_proc]
      filtered_result = apply_file_filter(file_paths, pass_config[:filter_proc])
      result[:filtered_files] = filtered_result

      if filtered_result[:rejected].any?
        log_info "Filtered out #{filtered_result[:rejected].length} files"
      end

      files_to_process = filtered_result[:accepted]
    else
      files_to_process = file_paths
    end

    # Analyze and process files
    if pass_config[:enable_cache] && !@options[:disable_tracking] && !@options[:force_reprocess]
      analysis = @tracker.analyze_files(
        files_to_process,
        pass_config[:operation_name],
        params: pass_config[:operation_params] || {},
        show_progress: pass_config[:show_progress] != false
      )

      result[:cached_files] = analysis[:cached]
      result[:processed_files] = analysis[:needs_processing]

      # Load cached results
      load_cached_results(analysis[:cached], pass_config, result)

      # Process new files
      process_new_files(analysis[:needs_processing], pass_config, result)
    else
      # Process all files without caching
      result[:processed_files] = files_to_process
      process_new_files(files_to_process, pass_config, result)
    end

    result
  end

  private

  def apply_file_filter(file_paths, filter_proc)
    filtered = {
      accepted: [],
      rejected: [],
      errors: []
    }

    file_paths.each do |file_path|
      begin
        if filter_proc.call(file_path)
          filtered[:accepted] << file_path
        else
          filtered[:rejected] << file_path
        end
      rescue => e
        filtered[:errors] << {
          path: file_path,
          error: e.message
        }
      end
    end

    filtered
  end

  def load_cached_results(cached_files, pass_config, result)
    return if cached_files.empty?

    log_progress "Loading cached results..." if cached_files.length > 10

    cached_files.each do |file_path|
      begin
        record = @tracker.get_processing_record(file_path, pass_config[:operation_name])
        if record && record['result']
          cached_result = if pass_config[:result_parser]
                           pass_config[:result_parser].call(JSON.parse(record['result']))
                         else
                           JSON.parse(record['result'])
                         end

          result[:results] << {
            path: file_path,
            cached: true,
            data: cached_result
          }
        end
      rescue => e
        result[:errors] << {
          path: file_path,
          error: "Failed to load cached result: #{e.message}"
        }
      end
    end

    log_info "Loaded #{cached_files.length} cached results"
  end

  def process_new_files(files_to_process, pass_config, result)
    return if files_to_process.empty?

    puts "🔧 Processing #{files_to_process.length} files, parallel=#{pass_config[:parallel_processing]}" if @options[:debug]

    if pass_config[:parallel_processing]
      process_files_in_parallel(files_to_process, pass_config, result)
    else
      process_files_sequentially(files_to_process, pass_config, result)
    end
  end

  def process_files_sequentially(files_to_process, pass_config, result)
    with_step_progress("Processing #{pass_config[:progress_description] || 'files'}", files_to_process.length) do |progress|
      files_to_process.each_with_index do |file_path, index|
        begin
          process_result = pass_config[:process_proc].call(file_path)

          # Record result in tracker
          if pass_config[:enable_cache] && !@options[:disable_tracking]
            @tracker.record_processed(
              file_path,
              pass_config[:operation_name],
              process_result.to_json,
              { params: pass_config[:operation_params] || {} }
            )
          end

          result[:results] << {
            path: file_path,
            cached: false,
            data: process_result
          }
        rescue => e
          result[:errors] << {
            path: file_path,
            error: e.message
          }
        end

        progress.call(index + 1)
      end
    end
  end

  def process_files_in_parallel(files_to_process, pass_config, result)
    return if files_to_process.empty?

    # Determine worker count from options or use auto-detection
    worker_count = @options[:worker_count] || optimal_worker_count(
      task_type: :io_intensive,  # Human detection is I/O intensive (calls external script)
      memory_per_worker: 50      # Low memory usage for human detection
    )

    # Process files in parallel using ParallelUtils
    process_results = process_in_parallel(
      files_to_process,
      worker_count: worker_count,
      task_type: :io_intensive,
      memory_per_worker: 50,
      progress_message: "Analyzing #{pass_config[:progress_description] || 'files'}",
      verbose: @options[:debug]
    ) do |file_path|
      begin
        # Debug: log that we're processing this file
        puts "🔍 Processing: #{File.basename(file_path)}" if @options[:debug]

        # Validate file exists before processing
        unless File.exist?(file_path)
          raise "File does not exist: #{file_path}"
        end

        process_result = pass_config[:process_proc].call(file_path)

        # Validate result
        if process_result.nil?
          raise "Process returned nil result for #{file_path}"
        end

        # Debug: log the result
        puts "✅ Success: #{File.basename(file_path)} -> #{process_result.class}" if @options[:debug]

        # Record result in tracker (needs to be thread-safe)
        if pass_config[:enable_cache] && !@options[:disable_tracking]
          @tracker.record_processed(
            file_path,
            pass_config[:operation_name],
            process_result.to_json,
            { params: pass_config[:operation_params] || {} }
          )
        end

        {
          path: file_path,
          cached: false,
          data: process_result,
          error: nil
        }
      rescue => e
        puts "❌ ERROR: #{File.basename(file_path)} - #{e.message}"
        puts "   Backtrace: #{e.backtrace.first(3).join(', ')}" if @options[:debug]
        {
          path: file_path,
          cached: false,
          data: nil,
          error: e.message
        }
      end
    end

    # Separate successful results from errors
    process_results.compact.each do |process_result|
      if process_result[:error]
        result[:errors] << {
          path: process_result[:path],
          error: process_result[:error]
        }
        # Log the error for debugging
        puts "❌ ERROR: #{File.basename(process_result[:path])} - #{process_result[:error]}"
      else
        result[:results] << {
          path: process_result[:path],
          cached: false,
          data: process_result[:data]
        }
        puts "✅ SUCCESS: #{File.basename(process_result[:path])}" if @options[:debug]
      end
    end

    # Handle nil results (shouldn't happen but let's be safe)
    nil_count = process_results.count(&:nil?)
    if nil_count > 0
      puts "⚠️  WARNING: #{nil_count} nil results returned from parallel processing"
      result[:errors] << {
        path: "unknown",
        error: "#{nil_count} nil results from parallel processing"
      }
    end
  end

  def generate_workflow_summary(workflow_result)
    total_initial = workflow_result[:initial_files].length
    total_final = workflow_result[:final_files].length
    total_processed = workflow_result[:pass_results].sum { |p| p[:processed_files].length }
    total_cached = workflow_result[:pass_results].sum { |p| p[:cached_files].length }
    total_errors = workflow_result[:pass_results].sum { |p| p[:errors].length }
    total_results = workflow_result[:pass_results].sum { |p| p[:results].length }

    {
      initial_files: total_initial,
      final_files: total_final,
      total_processed: total_processed,
      total_cached: total_cached,
      total_errors: total_errors,
      total_results: total_results,
      cache_hit_rate: total_processed + total_cached > 0 ?
                      (total_cached.to_f / (total_processed + total_cached) * 100).round(1) : 0
    }
  end

  # Logging methods that can work with or without a logger
  def log_info(message)
    @logger ? @logger.log_info(message) : puts("ℹ️  #{message}")
  end

  def log_section(message)
    @logger ? @logger.log_section(message) : puts("🔧 #{message}")
  end

  def log_progress(message)
    @logger ? @logger.log_progress(message) : puts("🔄 #{message}")
  end

  def log_error(message)
    @logger ? @logger.log_error(message) : puts("❌ #{message}")
  end
end