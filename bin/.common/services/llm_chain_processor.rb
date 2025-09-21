# frozen_string_literal: true

require_relative 'base_service'
require_relative 'text_chunking_service'
require_relative '../utils/progress_utils'

# Service for processing large content through LLMs using chunking and synthesis
class LLMChainProcessor < BaseService
  include ProgressUtils

  def initialize(llm_service, options = {})
    super(options)
    @llm = llm_service
    @chunk_service = TextChunkingService.new(
      chunk_size: options[:chunk_size] || 12000,
      overlap_percent: options[:overlap_percent] || 20,
      logger: @logger
    )
    @max_retries = options[:max_retries] || 2
    @timeout = options[:timeout] || 300
  end

  # Process large text by chunking, processing each chunk, then synthesizing results
  def process_chunked_text(text, context: {}, &block)
    # Check if chunking is needed
    unless @chunk_service.needs_chunking?(text)
      log_info("Text fits in single request, processing directly") if @logger
      return yield(text, context.merge(chunk_info: { current: 1, total: 1 }))
    end

    # Create chunks
    chunks = @chunk_service.create_overlapping_chunks(text)
    log_info("Processing #{chunks.length} chunks") if @logger

    # Process each chunk
    chunk_results = []
    failed_chunks = []

    with_step_progress("Processing chunks", chunks.length) do |progress|
      chunks.each_with_index do |chunk, index|
        chunk_num = index + 1
        chunk_context = context.merge(
          chunk_info: {
            current: chunk_num,
            total: chunks.length,
            text: chunk
          }
        )

        begin
          result = with_retries(@max_retries) do
            with_timeout_progress("Chunk #{chunk_num}/#{chunks.length}", @timeout) do
              yield(chunk, chunk_context)
            end
          end

          if result && !result.empty?
            chunk_results << { chunk: chunk_num, result: result }
            log_success("✅ Chunk #{chunk_num} processed") if @logger
          else
            failed_chunks << chunk_num
            log_warning("⚠️  Empty result for chunk #{chunk_num}") if @logger
          end
        rescue => e
          failed_chunks << chunk_num
          log_error("❌ Error processing chunk #{chunk_num}: #{e.message}") if @logger
        end

        progress.call(chunk_num)
      end
    end

    # Check if we have any results
    if chunk_results.empty?
      log_error("No chunks processed successfully") if @logger
      return nil
    end

    if failed_chunks.any?
      log_warning("#{failed_chunks.length} chunks failed: #{failed_chunks.join(', ')}") if @logger
    end

    # Return results for synthesis
    {
      chunk_results: chunk_results.map { |r| r[:result] },
      failed_chunks: failed_chunks,
      total_chunks: chunks.length,
      success_rate: (chunk_results.length.to_f / chunks.length * 100).round(1)
    }
  end

  # Synthesize multiple results into a final output
  def synthesize_results(results, synthesis_context: {}, &synthesis_block)
    return nil if results.nil? || results[:chunk_results].empty?

    log_info("Synthesizing #{results[:chunk_results].length} chunk results") if @logger

    with_timeout_progress("Synthesizing final result", @timeout * 1.5) do
      with_retries(@max_retries) do
        synthesis_block.call(results[:chunk_results], synthesis_context)
      end
    end
  end

  # Complete workflow: chunk -> process -> synthesize
  def process_and_synthesize(text, process_context: {}, synthesis_context: {}, &process_block)
    # Step 1: Process chunks
    chunk_results = process_chunked_text(text, context: process_context, &process_block)
    return nil unless chunk_results

    # Step 2: Synthesize results
    synthesize_results(chunk_results, synthesis_context: synthesis_context) do |results, context|
      yield(results, context, chunk_results)
    end
  end

  # Get statistics about the last processing run
  def processing_stats
    {
      chunk_service: @chunk_service,
      last_run: @last_stats
    }
  end

  private

  def with_retries(max_retries, &block)
    retries = 0
    begin
      yield
    rescue => e
      retries += 1
      if retries <= max_retries
        log_warning("Retry #{retries}/#{max_retries} after error: #{e.message}") if @logger
        sleep(retries * 2) # Exponential backoff
        retry
      else
        log_error("Failed after #{max_retries} retries: #{e.message}") if @logger
        raise e
      end
    end
  end

end