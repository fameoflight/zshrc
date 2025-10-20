#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../.common/script_base'
require_relative '../lib/archive/concerns/macos_utils'
require_relative '../lib/archive/concerns/process_utils'
require_relative '../lib/archive/concerns/tcc_utils'

# Description: Check which apps are using camera or microphone on macOS
class CheckCameraMic < ScriptBase
  include MacosUtils
  include ProcessUtils
  include TccUtils

  def banner_text
    <<~BANNER
      📹🎤 Camera & Microphone Usage Checker

      Usage: #{script_name} [OPTIONS]

      Checks which applications are currently using the camera or microphone.
      Requires macOS and appropriate permissions.
    BANNER
  end

  def validate!
    self.class.require_macos
    self.class.require_commands('lsof', 'sqlite3')
    super
  end

  def run
    log_banner('Camera & Microphone Usage Checker')

    check_camera_usage
    check_microphone_usage
    check_tcc_permissions('kTCCServiceCamera', 'Camera')
    check_tcc_permissions('kTCCServiceMicrophone', 'Microphone')

    show_tips
    show_completion('Camera & Microphone Check')
  end

  private

  def check_camera_usage
    log_section('Camera Usage')
    processes = find_processes_using_lsof('AppleCamera\|AVCapture\|Camera')

    if processes.empty?
      log_success('No camera usage detected')
    else
      log_warning('Camera is in use by:')
      processes.each do |pid, name|
        puts "  📹 #{name} (PID: #{pid})"
      end
    end
  end

  def check_microphone_usage
    log_section('Microphone Usage')

    system_processes_to_ignore = [
      'loginwindow', 'coreservicesd', 'controlcenter', 'corelocationd',
      'callservicesd', 'wifiagent', 'assistant', 'bird', 'sirittsd', 'siri',
      'appssoauthagent', 'siriinferenced', 'accessibilityd', 'avconferenced',
      'audiocomponentsd', 'audioaccessoryd', 'shortcuts', 'textinputmenuagent',
      'spotlight', 'heards', 'imklaunchagent', 'sizeup', 'lms', 'audiovisuald',
      'usernoted', 'universalaccess', 'finder', 'systemuiserver', 'notificationcenter',
      'applespell', 'safari', 'dockhelperd', 'nbagent'
    ]

    mic_processes = find_processes_using_lsof('audio\|microphone\|input', system_processes_to_ignore)
    coreaudio_processes = find_processes_using_lsof('coreaudio', system_processes_to_ignore)

    all_processes = mic_processes.merge(coreaudio_processes)

    if all_processes.empty?
      log_success('No microphone usage detected')
    else
      log_warning('Microphone may be in use by:')
      all_processes.each do |pid, name|
        puts "  🎤 #{name} (PID: #{pid})"
      end
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
