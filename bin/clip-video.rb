#!/usr/bin/env ruby
require_relative '.common/script_base'
require 'optparse'

class ClipVideo < ScriptBase
  def script_emoji; '🎬'; end
  def script_title; 'Video Clipper'; end
  def script_description; 'Extract clips from videos using FFmpeg'; end
  def script_arguments; '[OPTIONS] <input_file>'; end

  def initialize
    super
    @start_time = '00:00:00'
    @duration = '30'
    @output_file = nil
    @preserve_quality = true
  end

  def add_custom_options(opts)
    opts.on('-sTIME', '--start TIME', 'Start time (default: 00:00:00, format: HH:MM:SS or MM:SS)') do |time|
      @start_time = time
    end

    opts.on('-dSECONDS', '--duration SECONDS', 'Duration in seconds (default: 30)') do |seconds|
      @duration = seconds
    end

    opts.on('-oFILE', '--output FILE', 'Output file path') do |file|
      @output_file = file
    end

    opts.on('-q', '--[no-]preserve-quality', 'Preserve original quality (default: true)') do |q|
      @preserve_quality = q
    end
  end

  def validate_dependencies
    unless system('which ffmpeg > /dev/null 2>&1')
      log_error "FFmpeg is not installed or not in PATH"
      log_info "Install with: brew install ffmpeg"
      exit 1
    end
  end

  def generate_output_filename(input_file)
    return @output_file if @output_file

    input_dir = File.dirname(input_file)
    input_ext = File.extname(input_file)
    input_basename = File.basename(input_file, input_ext)
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    File.join(input_dir, "#{input_basename}_clip_#{timestamp}#{input_ext}")
  end

  def validate_time_format(time_str)
    # Accept HH:MM:SS or MM:SS or just SS
    return true if time_str.match?(/^\d+$/) # Just seconds
    return true if time_str.match?(/^\d{1,2}:\d{2}:\d{2}$/) # HH:MM:SS
    return true if time_str.match?(/^\d{1,2}:\d{2}$/) # MM:SS
    false
  end

  def run
    if args.empty?
      log_error "Please specify an input video file"
      log_info "Usage: clip-video input.mp4 [-s 00:01:30] [-d 30] [-o output.mp4]"
      exit 1
    end

    input_file = File.expand_path(args[0])

    unless File.exist?(input_file)
      log_error "Input file does not exist: #{input_file}"
      exit 1
    end

    unless validate_time_format(@start_time)
      log_error "Invalid start time format: #{@start_time}"
      log_info "Use HH:MM:SS, MM:SS, or seconds format"
      exit 1
    end

    validate_dependencies

    output_file = generate_output_filename(input_file)

    log_section "Video Clipping"
    log_info "Input file: #{input_file}"
    log_info "Start time: #{@start_time}"
    log_info "Duration: #{@duration} seconds"
    log_info "Output file: #{output_file}"

    # Build FFmpeg command with proper quoting for spaces
    cmd = ['ffmpeg']
    cmd << '-i' << "\"#{input_file}\""
    cmd << '-ss' << @start_time
    cmd << '-t' << @duration

    if @preserve_quality
      cmd << '-c:v' << 'libx264' << '-crf' << '18'
      cmd << '-c:a' << 'aac' << '-b:a' << '192k'
    else
      cmd << '-c' << 'copy' # Faster, preserves original codecs
    end

    cmd << '-avoid_negative_ts' << '1'
    cmd << '-y' # Overwrite output file
    cmd << "\"#{output_file}\""

    log_progress "Clipping video..."

    unless system(cmd.join(' '))
      log_error "Failed to clip video"
      exit 1
    end

    if File.exist?(output_file)
      output_size = File.size(output_file) / (1024.0 * 1024.0)
      log_file_created output_file
      log_info "Output video: #{output_size.round(2)} MB"
      show_completion script_title
    else
      log_error "Output file was not created"
      exit 1
    end
  end

  def show_examples
    puts "Examples:"
    puts "  clip-video video.mp4                          # Clip 30 seconds from start"
    puts "  clip-video video.mp4 -s 01:30 -d 60           # Clip 60 seconds from 1:30"
    puts "  clip-video video.mp4 -s 30 -d 15 -o clip.mp4 # Clip 15 seconds from 30s mark"
  end
end

ClipVideo.execute if __FILE__ == $0