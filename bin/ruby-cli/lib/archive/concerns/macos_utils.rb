# frozen_string_literal: true

# Concern for macOS specific utilities
module MacosUtils
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def require_macos
      unless Gem::Platform.local.os == 'darwin'
        log_error('This script only works on macOS')
        exit 1
      end
    end

    def require_commands(*cmds)
      cmds.each do |cmd|
        unless system("which #{cmd} >/dev/null 2>&1")
          log_error("Required command '#{cmd}' not found")
          exit 1
        end
      end
    end
  end

  def macos?
    Gem::Platform.local.os == 'darwin'
  end
end
