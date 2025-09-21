#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'
require_relative '.common/services/media_transcript_service'

# Simple test to debug transcript data
class TranscriptDebugTest < ScriptBase
  def banner_text
    "Transcript Debug Test"
  end

  def run
    log_banner("Transcript Debug Test")

    # Test transcript download
    service = MediaTranscriptService.new({ logger: self })
    transcript_data = service.download_transcript("https://www.youtube.com/watch?v=3Up-x7nMbYE")

    if transcript_data
      log_success("Transcript downloaded successfully")
      log_info("Transcript keys: #{transcript_data.keys.join(', ')}")

      full_text = transcript_data[:full_text]
      if full_text
        log_info("Full text length: #{full_text.length} characters")
        log_info("Full text preview: #{full_text[0..100]}...")
      else
        log_error("Full text is nil")
      end

      log_info("Video info: #{transcript_data[:video_info]}")
    else
      log_error("Failed to download transcript")
    end
  end
end

TranscriptDebugTest.execute if __FILE__ == $0