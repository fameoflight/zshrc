# frozen_string_literal: true

require_relative 'base_service'

# Service for intelligently chunking large text documents
# Useful for processing large texts with LLMs that have context limits
class TextChunkingService < BaseService
  DEFAULT_CHUNK_SIZE = 12_000
  DEFAULT_OVERLAP_PERCENT = 20

  def initialize(options = {})
    super(options)
    @chunk_size = options[:chunk_size] || DEFAULT_CHUNK_SIZE
    @overlap_percent = options[:overlap_percent] || DEFAULT_OVERLAP_PERCENT
  end

  # Create overlapping chunks from text with intelligent sentence boundary detection
  def create_overlapping_chunks(text, chunk_size: nil, overlap_percent: nil)
    chunk_size ||= @chunk_size
    overlap_percent ||= @overlap_percent

    return [text] if text.length <= chunk_size

    chunks = []
    overlap_size = (chunk_size * overlap_percent / 100).to_i
    step_size = chunk_size - overlap_size

    start = 0
    while start < text.length
      # Find a good breaking point near sentence boundaries
      end_pos = [start + chunk_size, text.length].min

      # Try to break at sentence boundaries
      if end_pos < text.length
        sentence_end = text.rindex(/[.!?]\s+/, end_pos)
        if sentence_end && sentence_end > start + (chunk_size * 0.7) # At least 70% of chunk_size
          end_pos = sentence_end + 1
        end
      end

      chunk = text[start...end_pos].strip
      chunks << chunk unless chunk.empty?

      break if end_pos >= text.length

      start += step_size
    end

    log_debug("Created #{chunks.length} chunks with #{overlap_percent}% overlap") if @logger
    chunks
  end

  # Create non-overlapping chunks (simpler, faster)
  def create_simple_chunks(text, chunk_size: nil)
    chunk_size ||= @chunk_size
    return [text] if text.length <= chunk_size

    chunks = []
    start = 0

    while start < text.length
      end_pos = [start + chunk_size, text.length].min

      # Try to break at sentence boundaries for cleaner chunks
      if end_pos < text.length
        sentence_end = text.rindex(/[.!?]\s+/, end_pos)
        if sentence_end && sentence_end > start + (chunk_size * 0.5) # At least 50% of chunk_size
          end_pos = sentence_end + 1
        end
      end

      chunk = text[start...end_pos].strip
      chunks << chunk unless chunk.empty?

      break if end_pos >= text.length

      start = end_pos
    end

    log_debug("Created #{chunks.length} simple chunks") if @logger
    chunks
  end

  # Estimate token count (rough approximation: 4 chars per token)
  def estimate_tokens(text)
    (text.length / 4.0).ceil
  end

  # Check if text needs chunking
  def needs_chunking?(text, max_tokens: nil)
    if max_tokens
      estimate_tokens(text) > max_tokens
    else
      text.length > @chunk_size
    end
  end

  # Get chunk statistics
  def chunk_stats(chunks)
    {
      count: chunks.length,
      avg_size: chunks.map(&:length).sum / chunks.length,
      min_size: chunks.map(&:length).min,
      max_size: chunks.map(&:length).max,
      total_chars: chunks.map(&:length).sum,
      estimated_tokens: estimate_tokens(chunks.join)
    }
  end
end
