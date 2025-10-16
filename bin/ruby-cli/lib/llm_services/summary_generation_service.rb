#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'base_service'
require_relative 'llm_chain_processor'

# Service for generating summaries from text content using LLM
class SummaryGenerationService < BaseService
  def initialize(llm_service, options = {})
    super(options)
    @llm = llm_service
    @default_chunk_size = options[:chunk_size] || 12000
    @default_overlap = options[:overlap_percent] || 20
    @default_temperature = options[:temperature] || 0.3
    @default_max_tokens = options[:max_tokens] || 1000
  end

  # Generate summary from text with automatic chunking for large content
  def generate_summary(text, video_info = nil, options = {})
    return nil unless text && !text.empty?

    # Merge options with defaults
    opts = {
      chunk_size: @default_chunk_size,
      no_chunking: false,
      temperature: @default_temperature,
      max_tokens: @default_max_tokens,
      auto_reload: true,
      min_context: nil
    }.merge(options)

    # Determine if chunking is needed
    if text.length > opts[:chunk_size] && !opts[:no_chunking]
      log_info("Large content detected (#{text.length} chars), using chunked summarization")
      log_info("Chunk size: #{opts[:chunk_size]} characters")
      generate_chunked_summary(text, video_info, opts)
    else
      log_info("Using single-pass summarization: #{text.length} characters")
      generate_single_summary(text, video_info, opts)
    end
  end

  # Generate summary from a single piece of text
  def generate_single_summary(text, video_info = nil, options = {})
    system_prompt = build_summary_system_prompt(options[:summary_type] || :general)
    user_prompt = build_summary_user_prompt(text, video_info, options[:summary_type] || :general)

    log_progress("Generating summary with LLM")

    # Check context before making request
    if options[:auto_reload]
      total_content = "#{system_prompt}\n#{user_prompt}"
      unless @llm.ensure_sufficient_context(total_content.length, options[:min_context], options[:auto_reload])
        log_error("Insufficient context for summary generation")
        return nil
      end
    end

    measure_time("Summary generation") do
      with_error_handling("Summary generation", {
        content_length: user_prompt.length,
        temperature: options[:temperature],
        max_tokens: options[:max_tokens],
        model: @llm.instance_variable_get(:@model)
      }) do
        log_debug("Sending summary request to LLM...")

        summary = @llm.complete(
          user_prompt,
          system: system_prompt,
          max_tokens: options[:max_tokens],
          temperature: options[:temperature],
          auto_reload: options[:auto_reload],
          min_context: options[:min_context]
        )

        if summary && !summary.empty?
          log_success("Summary generated successfully (#{summary.length} characters)")
          summary
        else
          log_error("Failed to generate summary - LLM returned empty response")
          nil
        end
      end
    end
  end

  # Generate summary by chunking large text and synthesizing results
  def generate_chunked_summary(text, video_info = nil, options = {})
    # Initialize chain processor
    processor = LLMChainProcessor.new(@llm, {
      chunk_size: options[:chunk_size],
      overlap_percent: @default_overlap,
      logger: self,
      timeout: options[:timeout] || 300
    })

    # Process and synthesize using the chain processor
    processor.process_and_synthesize(
      text,
      process_context: { video_info: video_info, options: options },
      synthesis_context: { video_info: video_info, options: options }
    ) do |chunk_text, context, synthesis_results = nil|
      if synthesis_results
        # This is the synthesis step
        synthesize_chunk_summaries(synthesis_results, context[:video_info], context[:options])
      else
        # This is the chunk processing step
        chunk_info = context[:chunk_info]
        generate_chunk_summary(chunk_text, context[:video_info], chunk_info[:current], chunk_info[:total], context[:options])
      end
    end
  end

  # Generate summary for a single chunk
  def generate_chunk_summary(chunk_text, video_info = nil, chunk_num = 1, total_chunks = 1, options = {})
    begin
      log_debug("Processing chunk #{chunk_num}/#{total_chunks} (#{chunk_text.length} characters)")

      system_prompt = build_chunk_summary_system_prompt(chunk_num, total_chunks)
      user_prompt = build_chunk_summary_user_prompt(chunk_text, video_info, chunk_num, total_chunks)

      result = @llm.complete(
        user_prompt,
        system: system_prompt,
        max_tokens: [options[:max_tokens] / 2, 500].max, # Use half tokens per chunk
        temperature: options[:temperature],
        auto_reload: options[:auto_reload],
        min_context: options[:min_context]
      )

      if result && !result.empty?
        log_debug("Chunk #{chunk_num} summary generated successfully (#{result.length} characters)")
        result
      else
        log_error("Failed to generate summary for chunk #{chunk_num} - LLM returned empty response")
        nil
      end
    rescue => e
      log_error("Failed to generate summary for chunk #{chunk_num}: #{e.class.name} - #{e.message}")
      nil
    end
  end

  # Synthesize multiple chunk summaries into a final summary
  def synthesize_chunk_summaries(chunk_summaries, video_info = nil, options = {})
    begin
      log_debug("Synthesizing #{chunk_summaries.length} chunk summaries")

      system_prompt = build_synthesis_system_prompt(chunk_summaries.length)
      user_prompt = build_synthesis_user_prompt(chunk_summaries, video_info)

      result = @llm.complete(
        user_prompt,
        system: system_prompt,
        max_tokens: options[:max_tokens],
        temperature: options[:temperature],
        auto_reload: options[:auto_reload],
        min_context: options[:min_context]
      )

      if result && !result.empty?
        log_debug("Summary synthesis completed successfully (#{result.length} characters)")
        result
      else
        log_error("Failed to synthesize chunk summaries - LLM returned empty response")
        nil
      end
    rescue => e
      log_error("Failed to synthesize chunk summaries: #{e.class.name} - #{e.message}")
      nil
    end
  end

  # Generate different types of summaries
  def generate_typed_summary(text, summary_type, video_info = nil, options = {})
    case summary_type
    when :brief
      generate_brief_summary(text, video_info, options)
    when :detailed
      generate_detailed_summary(text, video_info, options)
    when :bullets
      generate_bullet_summary(text, video_info, options)
    when :key_points
      generate_key_points_summary(text, video_info, options)
    else
      generate_summary(text, video_info, options)
    end
  end

  # Generate brief summary (1-2 sentences)
  def generate_brief_summary(text, video_info = nil, options = {})
    opts = options.merge(summary_type: :brief, max_tokens: 200)
    generate_single_summary(text, video_info, opts)
  end

  # Generate detailed summary with more depth
  def generate_detailed_summary(text, video_info = nil, options = {})
    opts = options.merge(summary_type: :detailed, max_tokens: 2000)
    generate_single_summary(text, video_info, opts)
  end

  # Generate bullet-point summary
  def generate_bullet_summary(text, video_info = nil, options = {})
    opts = options.merge(summary_type: :bullets)
    generate_single_summary(text, video_info, opts)
  end

  # Generate key points summary
  def generate_key_points_summary(text, video_info = nil, options = {})
    opts = options.merge(summary_type: :key_points)
    generate_single_summary(text, video_info, opts)
  end

  # Extract key information from text
  def extract_key_information(text)
    system_prompt = <<~PROMPT
      Extract key information from the following text. Focus on:
      - Main topics discussed
      - Important facts or figures
      - Key decisions or conclusions
      - Action items or next steps

      Return the information in a structured format.
    PROMPT

    @llm.complete(text, system: system_prompt, max_tokens: 800, temperature: 0.2)
  end

  private

  def build_summary_system_prompt(summary_type = :general)
    case summary_type
    when :brief
      <<~PROMPT
        You are an AI assistant that creates very brief, concise summaries of content.
        Create a 1-2 sentence summary that captures the main point.
      PROMPT
    when :detailed
      <<~PROMPT
        You are an AI assistant that creates comprehensive, detailed summaries.
        Create a thorough summary that covers all important aspects of the content.
      PROMPT
    when :bullets
      <<~PROMPT
        You are an AI assistant that creates bullet-point summaries.
        Create a well-structured summary using bullet points for key information.
      PROMPT
    when :key_points
      <<~PROMPT
        You are an AI assistant that extracts key points from content.
        Focus on the most important points, decisions, and takeaways.
      PROMPT
    else
      <<~PROMPT
        You are an AI assistant that creates concise, helpful summaries of content.

        Create a structured summary with:
        1. Brief overview (2-3 sentences)
        2. Key points (3-5 bullet points)
        3. Main topics covered
        4. Any actionable insights or conclusions

        Be concise but comprehensive. Focus on the most valuable information.
      PROMPT
    end
  end

  def build_summary_user_prompt(text, video_info = nil, summary_type = :general)
    video_context = build_video_context(video_info) if video_info

    <<~PROMPT
      #{video_context}

      Please summarize this content:

      <content>
      #{text}
      </content>
    PROMPT
  end

  def build_chunk_summary_system_prompt(chunk_num, total_chunks)
    <<~PROMPT
      You are an AI assistant summarizing part #{chunk_num} of #{total_chunks} from a larger piece of content.

      Create a concise summary focusing on:
      - Key points discussed in this section
      - Important concepts or topics introduced
      - Any specific examples, numbers, or actionable items

      Keep it focused and avoid repeating information from other chunks.
    PROMPT
  end

  def build_chunk_summary_user_prompt(chunk_text, video_info = nil, chunk_num = 1, total_chunks = 1)
    video_context = build_video_context(video_info) if video_info

    <<~PROMPT
      #{video_context}

      Summarize this section (part #{chunk_num}/#{total_chunks}):

      <content_section>
      #{chunk_text}
      </content_section>
    PROMPT
  end

  def build_synthesis_system_prompt(num_chunks)
    <<~PROMPT
      You are an AI assistant that creates comprehensive summaries from multiple partial summaries.

      You will receive #{num_chunks} section summaries. Create a unified, well-structured final summary with:

      1. Brief overview (2-3 sentences)
      2. Key points (4-6 bullet points covering the main themes)
      3. Main topics covered (organized logically)
      4. Important insights or conclusions
      5. Any actionable takeaways

      Eliminate redundancy between sections and present a coherent narrative.
      Be comprehensive but concise.
    PROMPT
  end

  def build_synthesis_user_prompt(chunk_summaries, video_info = nil)
    video_context = build_video_context(video_info) if video_info

    combined_summaries = chunk_summaries.map.with_index do |summary, index|
      "**Section #{index + 1} Summary:**\n#{summary}"
    end.join("\n\n")

    <<~PROMPT
      #{video_context}

      Create a comprehensive final summary from the section summaries below:

      #{combined_summaries}
    PROMPT
  end

  def build_video_context(video_info)
    <<~CONTEXT
      **Video Information:**
      - Title: #{video_info[:title]}
      - Duration: #{video_info[:duration]}
      - Uploader: #{video_info[:uploader]}
    CONTEXT
  end
end