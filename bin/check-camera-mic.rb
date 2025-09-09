#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Description: Check which apps are using camera or microphone on macOS
class CheckCameraMic < ScriptBase
  def banner_text
    <<~BANNER
      📹🎤 Camera & Microphone Usage Checker

      Usage: #{script_name} [OPTIONS]

      Checks which applications are currently using the camera or microphone.
      Requires macOS and appropriate permissions.
    BANNER
  end

  def validate!
    # Check if running on macOS
    unless Gem::Platform.local.os == 'darwin'
      log_error('This script only works on macOS')
      exit 1
    end

    # Check for required commands
    %w[lsof sqlite3].each do |cmd|
      unless system("which #{cmd} >/dev/null 2>&1")
        log_error("Required command '#{cmd}' not found")
        exit 1
      end
    end

    super
  end

  def run
    log_banner('Camera & Microphone Usage Checker')

    check_camera_usage
    check_microphone_usage
    check_permissions

    show_tips
    show_completion('Camera & Microphone Check')
  end

  private

  def check_camera_usage
    log_section('Camera Usage')

    # Use lsof to find processes using the camera
    camera_processes = `lsof | grep -i "AppleCamera\\|AVCapture\\|Camera" | grep -v grep`.chomp

    if camera_processes.empty?
      log_success('No camera usage detected')
    else
      # Get unique processes with full names
      unique_processes = {}
      camera_processes.each_line do |line|
        parts = line.split
        next if parts.size < 2
        
        pid = parts[1]
        process_name = parts[0]
        
        # Get full process name using ps
        full_name = `ps -p #{pid} -o comm= 2>/dev/null`.chomp
        full_name = process_name if full_name.empty?
        
        # Get the actual command/app name
        app_info = `ps -p #{pid} -o args= 2>/dev/null`.chomp
        app_name = if app_info.include?('/Applications/')
                    app_info.match(%r{/Applications/([^/]+)\.app})&.captures&.first || full_name
                  else
                    full_name
                  end
        
        unique_processes[pid] = app_name unless unique_processes.value?(app_name)
      end
      
      if unique_processes.empty?
        log_success('No camera usage detected')
      else
        log_warning('Camera is in use by:')
        unique_processes.each do |pid, name|
          puts "  📹 #{name} (PID: #{pid})"
        end
      end
    end
  end

  def check_microphone_usage
    log_section('Microphone Usage')

    # Use lsof to find processes using audio input devices
    mic_processes = `lsof | grep -i "audio\\|microphone\\|input" | grep -v grep`.chomp

    # Also check for CoreAudio usage
    coreaudio_processes = `lsof | grep -i "coreaudio" | grep -v grep`.chomp

    # Filter out system processes that are always running
    system_processes = [
      'loginwindow', 'coreservicesd', 'controlcenter', 'corelocationd',
      'callservicesd', 'wifiagent', 'assistant', 'bird', 'sirittsd', 'siri',
      'appssoauthagent', 'siriinferenced', 'accessibilityd', 'avconferenced',
      'audiocomponentsd', 'audioaccessoryd', 'shortcuts', 'textinputmenuagent',
      'spotlight', 'heards', 'imklaunchagent', 'sizeup', 'lms', 'audiovisuald',
      'usernoted', 'universalaccess', 'finder', 'systemuiserver', 'notificationcenter',
      'applespell', 'safari', 'dockhelperd', 'nbagent'
    ]

    # Combine and deduplicate all audio processes
    all_processes = {}
    
    # Process microphone-related processes
    unless mic_processes.empty?
      mic_processes.each_line do |line|
        parts = line.split
        next if parts.size < 2
        
        pid = parts[1]
        process_name = parts[0].downcase
        
        # Skip if it's a system process
        next if system_processes.include?(process_name)
        
        # Get full process name
        full_name = get_process_name(pid, process_name)
        all_processes[pid] = full_name unless all_processes.value?(full_name)
      end
    end

    # Process CoreAudio processes (be more selective)
    unless coreaudio_processes.empty?
      coreaudio_processes.each_line do |line|
        parts = line.split
        next if parts.size < 2
        
        pid = parts[1]
        process_name = parts[0].downcase
        
        # Skip if it's a system process
        next if system_processes.include?(process_name)
        
        # Only include user applications for CoreAudio
        app_info = `ps -p #{pid} -o args= 2>/dev/null`.chomp
        next unless app_info.include?('/Applications/') || app_info.include?('/Users/')
        
        full_name = get_process_name(pid, process_name)
        all_processes[pid] = full_name unless all_processes.value?(full_name)
      end
    end

    if all_processes.empty?
      log_success('No microphone usage detected')
    else
      log_warning('Microphone may be in use by:')
      all_processes.each do |pid, name|
        puts "  🎤 #{name} (PID: #{pid})"
      end
    end
  end

  def get_process_name(pid, default_name)
    # Get full process name using ps
    full_name = `ps -p #{pid} -o comm= 2>/dev/null`.chomp
    full_name = default_name if full_name.empty?
    
    # Get the actual command/app name
    app_info = `ps -p #{pid} -o args= 2>/dev/null`.chomp
    if app_info.include?('/Applications/')
      app_name = app_info.match(%r{/Applications/([^/]+)\.app})&.captures&.first
      return app_name if app_name
    elsif app_info.include?('/Users/')
      # For user binaries, show the last part of the path
      user_app = app_info.match(%r{/([^/]+)$})&.captures&.first
      return user_app if user_app
    end
    
    full_name
  end

  def check_permissions
    log_section('Recent Camera & Microphone Access')

    tcc_db = '/Library/Application Support/com.apple.TCC/TCC.db'

    if File.exist?(tcc_db)
      log_info('Checking system privacy database...')

      # Check camera access (requires sudo)
      puts '📷 Recent camera access (last 24 hours):'
      begin
        camera_query = "SELECT client, last_modified FROM access WHERE service='kTCCServiceCamera' AND last_modified > datetime('now', '-1 day');"
        result = `sudo sqlite3 "#{tcc_db}" "#{camera_query}" 2>/dev/null`
        if result.empty?
          puts '  No recent camera access found'
        else
          puts result.lines.map { |line| "  #{line.chomp}" }.join("\n")
        end
      rescue => e
        log_warning("Unable to access camera permissions: #{e.message}")
      end

      # Check microphone access (requires sudo)
      puts '🎤 Recent microphone access (last 24 hours):'
      begin
        mic_query = "SELECT client, last_modified FROM access WHERE service='kTCCServiceMicrophone' AND last_modified > datetime('now', '-1 day');"
        result = `sudo sqlite3 "#{tcc_db}" "#{mic_query}" 2>/dev/null`
        if result.empty?
          puts '  No recent microphone access found'
        else
          puts result.lines.map { |line| "  #{line.chomp}" }.join("\n")
        end
      rescue => e
        log_warning("Unable to access microphone permissions: #{e.message}")
      end
    else
      log_warning('TCC database not found')
    end
  end

  def show_tips
    puts
    log_info('💡 Tip: Use Activity Monitor to monitor real-time camera/mic usage')
    log_info('💡 Tip: Check System Preferences > Security & Privacy > Privacy for app permissions')
    log_info('💡 Tip: Use Control Center to quickly see active camera/mic indicators')
  end
end

# Execute the script
CheckCameraMic.execute if __FILE__ == $0