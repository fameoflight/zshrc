# frozen_string_literal: true

# Concern for process-related utilities
module ProcessUtils
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

  def find_processes_using_lsof(grep_pattern, system_processes_to_ignore = [])
    processes = `lsof | grep -i "#{grep_pattern}" | grep -v grep`.chomp
    return {} if processes.empty?

    unique_processes = {}
    processes.each_line do |line|
      parts = line.split
      next if parts.size < 2
      
      pid = parts[1]
      process_name = parts[0].downcase
      
      next if system_processes_to_ignore.include?(process_name)
      
      full_name = get_process_name(pid, process_name)
      unique_processes[pid] = full_name unless unique_processes.value?(full_name)
    end
    unique_processes
  end
end
