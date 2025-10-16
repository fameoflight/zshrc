# frozen_string_literal: true

# Utilities for displaying progress indicators during long-running operations
module ProgressUtils
  # Execute a block with a timeout-based progress bar
  def with_timeout_progress(message, timeout_seconds, &block)
    progress_bar = nil

    begin
      # Try to create a progress bar if tty-progressbar is available
      require 'tty-progressbar'
      progress_bar = TTY::ProgressBar.new(
        "#{message} [:bar] :percent (:elapsed/:total)",
        total: timeout_seconds,
        bar_format: :block,
        incomplete: '░',
        complete: '█',
        width: 40
      )
    rescue LoadError
      # Fallback if tty-progressbar not available
      log_progress(message) if respond_to?(:log_progress)
    end

    result = nil
    start_time = Time.now

    # Start progress updates in a separate thread
    progress_thread = nil
    if progress_bar
      progress_thread = Thread.new do
        loop do
          elapsed = Time.now - start_time
          break if elapsed >= timeout_seconds

          progress_bar.current = [elapsed, timeout_seconds].min.to_i
          sleep(0.5)
        end
      end
    end

    begin
      result = yield
    ensure
      # Clean up progress thread
      if progress_thread
        progress_thread.kill rescue nil
        progress_bar&.finish
        puts # New line after progress bar
      end
    end

    result
  end

  # Execute a block with a step-based progress bar
  def with_step_progress(message, total_steps, &block)
    progress_bar = nil

    begin
      require 'tty-progressbar'
      progress_bar = TTY::ProgressBar.new(
        "#{message} [:bar] :current/:total (:percent)",
        total: total_steps,
        bar_format: :block,
        incomplete: '░',
        complete: '█',
        width: 40
      )
    rescue LoadError
      # Fallback without progress bar
      log_progress(message) if respond_to?(:log_progress)
    end

    # Provide progress callback to the block
    progress_callback = lambda do |step|
      if progress_bar
        progress_bar.current = step
      elsif respond_to?(:log_progress)
        log_progress("#{message} (#{step}/#{total_steps})")
      end
    end

    result = nil
    begin
      result = yield(progress_callback)
    ensure
      progress_bar&.finish
      puts if progress_bar # New line after progress bar
    end

    result
  end

  # Multi-bar progress for parallel operations
  def with_multi_progress(operations, &block)
    multi_bar = nil

    begin
      require 'tty-progressbar'
      multi_bar = TTY::ProgressBar::Multi.new("Overall progress")
    rescue LoadError
      # Fallback - execute without progress bars
      return yield({})
    end

    progress_bars = {}

    # Create individual progress bars for each operation
    operations.each do |op_name, total_steps|
      progress_bars[op_name] = multi_bar.register(
        "#{op_name} [:bar] :current/:total",
        total: total_steps
      )
    end

    result = nil
    begin
      # Provide progress callbacks
      callbacks = progress_bars.transform_values do |bar|
        lambda { |step| bar.current = step }
      end

      result = yield(callbacks)
    ensure
      # Ensure all bars are completed
      progress_bars.values.each(&:finish)
    end

    result
  end

  # Simple spinner for indeterminate progress
  def with_spinner(message, &block)
    spinner = nil

    begin
      require 'tty-spinner'
      spinner = TTY::Spinner.new("#{message} :spinner", format: :bouncing_ball)
      spinner.auto_spin
    rescue LoadError
      # Fallback without spinner
      log_progress(message) if respond_to?(:log_progress)
    end

    result = nil
    begin
      result = yield
      spinner&.success('Done!')
    rescue => e
      spinner&.error('Failed!')
      raise e
    ensure
      spinner&.stop
    end

    result
  end
end