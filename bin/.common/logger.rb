# frozen_string_literal: true

require 'pastel'

# Centralized logging system for ZSH configuration scripts
# Provides consistent colored output and emoji indicators
class Logger
  def initialize
    @pastel = Pastel.new
    @color_enabled = true
  end

  # Core logging methods with emoji indicators
  def log_message(message)
    puts colorize("ℹ️  #{message}", :blue)
  end

  def success(message)
    puts colorize("✅ #{message}", :green)
  end

  def warning(message)
    puts colorize("⚠️  #{message}", :yellow)
  end

  def error(message)
    $stderr.puts colorize("❌ #{message}", :red)
  end

  def progress(message)
    puts colorize("🔄 #{message}", :cyan)
  end

  def section(message)
    puts colorize("🔧 #{message}", :magenta)
  end

  def debug(message)
    return unless ENV['DEBUG'] == '1'
    puts colorize("🐛 #{message}", :dim)
  end

  # Specialized logging methods
  def file_created(path)
    success("Created file: #{File.basename(path)}")
    debug("Path: #{path}")
  end

  def file_updated(path)
    log_message("📝 Updated: #{File.basename(path)}")
    debug("Path: #{path}")
  end

  def file_backed_up(path)
    log_message("💾 Backed up: #{File.basename(path)}")
    debug("Path: #{path}")
  end

  def install(package)
    success("📦 Installed: #{package}")
  end

  def clean(item)
    log_message("🧹 Cleaned: #{item}")
  end

  def update(item)
    log_message("🔄 Updated: #{item}")
  end

  # Platform-specific logging
  def brew(message)
    log_message("🍺 #{message}")
  end

  def git(message)
    log_message("🐙 #{message}")
  end

  def python(message)
    log_message("🐍 #{message}")
  end

  def ruby(message)
    log_message("💎 #{message}")
  end

  def macos(message)
    log_message("🍎 #{message}")
  end

  def linux(message)
    log_message("🐧 #{message}")
  end

  # Utility methods
  def separator
    puts colorize("━" * 50, :bright_black)
  end

  def complete(process_name)
    puts
    success("🎉 #{process_name} completed successfully!")
    puts
  end

  def banner(title)
    separator
    puts colorize("  #{title.upcase}", :bold)
    separator
  end

  # Configuration
  def verbose?
    ENV['VERBOSE'] == '1' || ENV['V'] == '1'
  end

  def disable_colors!
    @color_enabled = false
  end

  def enable_colors!
    @color_enabled = true
  end

  private

  def colorize(text, color)
    return text unless @color_enabled
    begin
      @pastel.send(color, text)
    rescue StandardError => e
      # Fallback if Pastel fails
      text
    end
  end
end

# Global logger instance
$logger = Logger.new

# Convenience methods for global access
def log_info(message)
  $logger.log_message(message)
end

def log_success(message)
  $logger.success(message)
end

def log_warning(message)
  $logger.warning(message)
end

def log_error(message)
  $logger.error(message)
end

def log_progress(message)
  $logger.progress(message)
end

def log_section(message)
  $logger.section(message)
end

def log_debug(message)
  $logger.debug(message)
end

def log_file_created(path)
  $logger.file_created(path)
end

def log_file_updated(path)
  $logger.file_updated(path)
end

def log_file_backed_up(path)
  $logger.file_backed_up(path)
end

def log_install(package)
  $logger.install(package)
end

def log_clean(item)
  $logger.clean(item)
end

def log_update(item)
  $logger.update(item)
end

def log_brew(message)
  $logger.brew(message)
end

def log_git(message)
  $logger.git(message)
end

def log_python(message)
  $logger.python(message)
end

def log_ruby(message)
  $logger.ruby(message)
end

def log_macos(message)
  $logger.macos(message)
end

def log_linux(message)
  $logger.linux(message)
end

def log_separator
  $logger.separator
end

def log_complete(process_name)
  $logger.complete(process_name)
end

def log_banner(title)
  $logger.banner(title)
end