# frozen_string_literal: true

require_relative '../utils/error_utils'

# Base service class providing common logger functionality
class BaseService
  include ErrorUtils

  def initialize(options = {})
    @logger = options[:logger]
    @debug = options[:debug] || false
  end

  protected

  def log_info(message)
    @logger&.log_info(message)
  end

  def log_debug(message)
    @logger&.log_debug(message) if @debug || debug_enabled?
  end

  def log_warning(message)
    @logger&.log_warning(message)
  end

  def log_error(message)
    @logger&.log_error(message)
  end

  def log_success(message)
    @logger&.log_success(message)
  end

  def log_progress(message)
    @logger&.log_progress(message)
  end

  def debug_enabled?
    ENV['DEBUG'] == '1' || @debug
  end
end