# frozen_string_literal: true

require 'thread'
require_relative 'device_utils'

# Utility for parallel processing with worker threads
# Based on existing patterns in gmail_service.rb and page_fetcher.rb
module ParallelUtils
  include DeviceUtils

  # Process items in parallel using worker threads
  # @param items [Array] Array of items to process
  # @param worker_count [Integer] Number of worker threads (default: auto-detect optimal count)
  # @param task_type [Symbol] Type of task: :cpu_intensive, :io_intensive, :mixed
  # @param memory_per_worker [Integer] Estimated memory per worker in MB
  # @param progress_message [String] Message for progress display
  # @param options [Hash] Additional options:
  #   - :progress [Boolean] Show progress bar (default: true)
  #   - :verbose [Boolean] Verbose logging (default: false)
  # @yield [item] Block that processes each item
  # @return [Array] Array of results in the same order as input items
  def process_in_parallel(items, worker_count: nil, task_type: :mixed, memory_per_worker: 100,
                         progress_message: "Processing", **options, &block)
    return [] if items.empty?

    # Determine optimal worker count using enhanced device detection
    if worker_count.nil?
      worker_count = optimal_worker_count(task_type: task_type, memory_per_worker: memory_per_worker)
    end
    worker_count = [worker_count, items.size].min

    if options[:verbose]
      memory_mb = available_memory ? (available_memory / 1024 / 1024).round : 0
      log_info "🚀 Processing #{items.size} items with #{worker_count} workers"
      log_info "📊 System: #{processor_count} cores, #{memory_mb}MB available RAM"
      log_info "🔧 Task type: #{task_type}, Load: #{system_load[:avg_1min].round(2)}"
    end

    # For small batches, single-threaded processing might be faster
    if items.size < 4 || worker_count == 1
      return process_sequentially(items, progress_message, options, &block)
    end

    # Thread-safe collections
    work_queue = Queue.new
    results = Array.new(items.size)
    results_mutex = Mutex.new
    completed_count = 0
    completed_mutex = Mutex.new

    # Enqueue all items with their indices
    items.each_with_index { |item, index| work_queue << [item, index] }

    # Progress bar setup
    progress_bar = nil
    if options[:progress] != false
      progress_bar = create_progress_bar(progress_message, items.size)
    end

    # Create worker threads
    threads = Array.new(worker_count) do
      Thread.new do
        while !work_queue.empty?
          begin
            item, index = work_queue.pop(true) # non-blocking pop
            result = yield(item)

            # Store result thread-safely
            results_mutex.synchronize do
              results[index] = result
            end

            # Update progress
            if progress_bar
              completed_mutex.synchronize do
                completed_count += 1
                progress_bar.current = completed_count
              end
            end

          rescue ThreadError
            # Queue is empty, exit thread
            break
          rescue => e
            # Log error but continue processing other items
            log_error "Error processing item: #{e.message}" if respond_to?(:log_error)

            # Store nil for failed items
            results_mutex.synchronize do
              results[index] = nil
            end

            if progress_bar
              completed_mutex.synchronize do
                completed_count += 1
                progress_bar.current = completed_count
              end
            end
          end
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)
    progress_bar&.finish
    puts if progress_bar # New line after progress bar

    results
  end

  # Process items in batches for better memory efficiency
  # @param items [Array] Array of items to process
  # @param batch_size [Integer] Size of each batch
  # @param worker_count [Integer] Number of worker threads per batch
  # @param progress_message [String] Message for progress display
  # @yield [item] Block that processes each item
  # @return [Array] Array of results
  def process_in_batches(items, batch_size: 10, worker_count: nil, progress_message: "Processing batches", **options, &block)
    return [] if items.empty?

    batches = items.each_slice(batch_size).to_a
    all_results = []

    with_step_progress("#{progress_message} (batches)", batches.size) do |progress|
      batches.each_with_index do |batch, index|
        batch_results = process_in_parallel(
          batch,
          worker_count: worker_count,
          progress_message: "Batch #{index + 1}/#{batches.size}",
          progress: false, # Don't show nested progress bars
          **options,
          &block
        )
        all_results.concat(batch_results)
        progress.call(index + 1)
      end
    end

    all_results
  end

  # Process items with a limited number of concurrent operations
  # Useful for rate-limited operations like API calls
  # @param items [Array] Array of items to process
  # @param max_concurrent [Integer] Maximum concurrent operations
  # @param progress_message [String] Message for progress display
  # @yield [item] Block that processes each item
  # @return [Array] Array of results
  def process_with_limit(items, max_concurrent: 4, progress_message: "Processing", **options, &block)
    return [] if items.empty?

    # Use a semaphore to limit concurrent operations
    semaphore = Mutex.new
    current_workers = 0
    max_workers = max_concurrent

    results = Array.new(items.size)
    results_mutex = Mutex.new
    completed_count = 0
    completed_mutex = Mutex.new

    progress_bar = create_progress_bar(progress_message, items.size)

    # Create threads that respect the concurrency limit
    threads = items.map.with_index do |item, index|
      Thread.new do
        # Wait until we have an available worker slot
        while true
          semaphore.synchronize do
            if current_workers < max_workers
              current_workers += 1
              break
            end
          end
          sleep(0.1) # Small delay to prevent busy waiting
        end

        begin
          result = yield(item)

          results_mutex.synchronize do
            results[index] = result
          end

        ensure
          # Free up the worker slot
          semaphore.synchronize do
            current_workers -= 1
          end

          # Update progress
          completed_mutex.synchronize do
            completed_count += 1
            progress_bar.current = completed_count
          end
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)
    progress_bar&.finish
    puts if progress_bar

    results
  end

  private

  # Create progress bar if TTY is available
  def create_progress_bar(message, total)
    begin
      require 'tty-progressbar'
      TTY::ProgressBar.new(
        "#{message} [:bar] :current/:total (:percent)",
        total: total,
        bar_format: :block,
        incomplete: '░',
        complete: '█',
        width: 40
      )
    rescue LoadError
      # Fallback - return nil if no progress bar available
      nil
    end
  end

  # Fallback sequential processing
  def process_sequentially(items, progress_message, options)
    results = []

    if options[:progress] != false
      with_step_progress(progress_message, items.size) do |progress|
        items.each_with_index do |item, index|
          begin
            results << yield(item)
          rescue => e
            log_error "Error processing item: #{e.message}" if respond_to?(:log_error)
            results << nil
          end
          progress.call(index + 1)
        end
      end
    else
      items.each do |item|
        begin
          results << yield(item)
        rescue => e
          log_error "Error processing item: #{e.message}" if respond_to?(:log_error)
          results << nil
        end
      end
    end

    results
  end
end