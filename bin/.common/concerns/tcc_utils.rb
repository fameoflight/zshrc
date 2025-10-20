# frozen_string_literal: true

# Concern for TCC (Transparency, Consent, and Control) utilities
module TccUtils
  TCC_DB = '/Library/Application Support/com.apple.TCC/TCC.db'

  def check_tcc_permissions(service, service_name)
    log_section("Recent #{service_name} Access")

    if File.exist?(TCC_DB)
      log_info('Checking system privacy database...')

      puts "📷 Recent #{service_name.downcase} access (last 24 hours):"
      begin
        query = "SELECT client, last_modified FROM access WHERE service='#{service}' AND last_modified > datetime('now', '-1 day');"
        result = `sudo sqlite3 "#{TCC_DB}" "#{query}" 2>/dev/null`
        if result.empty?
          puts "  No recent #{service_name.downcase} access found"
        else
          puts result.lines.map { |line| "  #{line.chomp}" }.join("\n")
        end
      rescue => e
        log_warning("Unable to access #{service_name.downcase} permissions: #{e.message}")
      end
    else
      log_warning('TCC database not found')
    end
  end
end
