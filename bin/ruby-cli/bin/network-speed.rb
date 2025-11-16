#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: system
# @description: Test network speed and connectivity using command-line tools
# @tags: network, monitoring, performance

require_relative '../../.common/script_base'

# Network speed test script using common command-line tools
class NetworkSpeedTestScript < ScriptBase
  def script_emoji; '🌐'; end
  def script_title; 'Network Speed Test'; end
  def script_description; 'Test network speed and connectivity using various command-line tools'; end
  def script_arguments; '[OPTIONS]'; end

  def add_custom_options(opts)
    opts.on('-s', '--server SERVER', 'Speed test server (default: auto-select)') do |server|
      @options[:server] = server
    end
    opts.on('-t', '--timeout SECONDS', Integer, 'Timeout for operations (default: 30)') do |timeout|
      @options[:timeout] = timeout
    end
    opts.on('-n', '--no-download', 'Skip download speed test') do
      @options[:no_download] = true
    end
    opts.on('-u', '--no-upload', 'Skip upload speed test') do
      @options[:no_upload] = true
    end
    opts.on('-p', '--no-ping', 'Skip ping/latency test') do
      @options[:no_ping] = true
    end
    opts.on('-i', '--interface INTERFACE', 'Network interface to test') do |interface|
      @options[:interface] = interface
    end
    opts.on('--simple', 'Simple output format') do
      @options[:simple] = true
    end
    opts.on('--json', 'JSON output format') do
      @options[:json] = true
    end
    opts.on('--tool TOOL', 'Test tool to use (speedtest-cli, fast.com, iperf3)') do |tool|
      @options[:tool] = tool
    end
  end

  def validate!
    super
    @timeout = @options[:timeout] || 30
    @server = @options[:server]
    @interface = @options[:interface]
    @simple = @options[:simple] || false
    @json_format = @options[:json] || false
    @tool = @options[:tool]&.downcase
    @test_download = !@options[:no_download]
    @test_upload = !@options[:no_upload]
    @test_ping = !@options[:no_ping]

    # Validate tool choice
    if @tool && !%w[speedtest-cli fast.com iperf3].include?(@tool)
      log_error "Invalid tool: #{@tool}. Valid options: speedtest-cli, fast.com, iperf3"
      exit 1
    end

    # Check for required tools
    check_available_tools
  end

  def run
    log_banner("Network Speed Test")

    # Get initial network info
    network_info = get_network_info
    display_network_info(network_info) unless @json_format

    results = {}

    # Perform tests based on options
    if @test_ping
      log_progress "Testing ping/latency..."
      results[:ping] = test_ping
      display_ping_results(results[:ping]) unless @json_format
    end

    if @test_download || @test_upload
      log_progress "Testing bandwidth..."
      speed_results = test_bandwidth
      results.merge!(speed_results)
      display_speed_results(speed_results) unless @json_format
    end

    # Final summary
    if @json_format
      puts JSON.pretty_generate(results)
    else
      display_summary(results) unless @simple
    end

    show_completion("Network speed test")
  end

  private

  def check_available_tools
    @available_tools = {}

    # Check for speedtest-cli
    @available_tools[:speedtest_cli] = System.command?('speedtest-cli')
    # Check for fast.com CLI wrapper
    @available_tools[:fast] = System.command?('fast')
    # Check for iperf3
    @available_tools[:iperf3] = System.command?('iperf3')
    # Check for basic tools
    @available_tools[:ping] = System.command?('ping')
    @available_tools[:curl] = System.command?('curl')

    # Determine which tool to use
    if @tool
      case @tool
      when 'speedtest-cli'
        unless @available_tools[:speedtest_cli]
          log_error "speedtest-cli not found. Install with: brew install speedtest-cli"
          exit 1
        end
      when 'fast.com'
        unless @available_tools[:fast]
          log_error "fast CLI not found. Install with: npm install -g fast-cli"
          exit 1
        end
      when 'iperf3'
        unless @available_tools[:iperf3]
          log_error "iperf3 not found. Install with: brew install iperf3"
          exit 1
        end
      end
    else
      # Auto-select best available tool
      @selected_tool = if @available_tools[:speedtest_cli]
                         'speedtest-cli'
                       elsif @available_tools[:fast]
                         'fast'
                       else
                         'curl' # Fallback
                       end
    end

    log_debug "Available tools: #{@available_tools}" if debug?
    log_info "Using tool: #{@selected_tool}" if @selected_tool
  end

  def get_network_info
    info = {}

    # Get public IP
    if @available_tools[:curl]
      begin
        ip_response = System.execute("curl -s https://ipinfo.io/json", description: "Getting public IP info")
        if ip_response
          ip_data = JSON.parse(ip_response)
          info[:public_ip] = ip_data['ip']
          info[:location] = "#{ip_data['city']}, #{ip_data['region']}, #{ip_data['country']}"
          info[:isp] = ip_data['org']
          info[:hostname] = ip_data['hostname']
        end
      rescue => e
        log_debug "Failed to get IP info: #{e.message}" if debug?
      end
    end

    # Get local network interfaces
    if System.macos?
      ifconfig_output = System.execute("ifconfig", description: "Getting network interfaces")
      if ifconfig_output
        # Parse ifconfig output for active interfaces
        info[:interfaces] = parse_ifconfig(ifconfig_output)
      end
    end

    info
  end

  def parse_ifconfig(output)
    interfaces = []
    current_interface = nil

    output.each_line do |line|
      if line.match?(/^[a-z0-9]+:/)
        # New interface
        current_interface = {
          name: line.split(':')[0].strip,
          status: 'down'
        }
        interfaces << current_interface
      elsif current_interface && line.include?('inet ')
        # IPv4 address
        ip_match = line.match(/inet (\d+\.\d+\.\d+\.\d+)/)
        current_interface[:ip] = ip_match[1] if ip_match
      elsif current_interface && line.include?('status: ')
        # Interface status
        status_match = line.match(/status: (\w+)/)
        current_interface[:status] = status_match[1] if status_match
      end
    end

    interfaces.select { |iface| iface[:ip] && iface[:status] == 'active' }
  end

  def test_ping
    results = {}

    # Test to multiple hosts
    hosts = ['8.8.8.8', '1.1.1.1', 'google.com']
    if @server
      hosts.unshift(@server)
    end

    hosts.each do |host|
      begin
        log_debug "Pinging #{host}..." if debug?

        ping_cmd = System.macos? ? "ping -c 4 #{host}" : "ping -c 4 #{host}"
        ping_result = System.execute(ping_cmd, description: "Pinging #{host}")

        if ping_result
          ping_stats = parse_ping_output(ping_result)
          results[host] = ping_stats
        else
          results[host] = { error: "Ping failed", status: 'failed' }
        end
      rescue => e
        results[host] = { error: e.message, status: 'error' }
        log_debug "Ping to #{host} failed: #{e.message}" if debug?
      end
    end

    results
  end

  def parse_ping_output(output)
    stats = {}

    # Extract packet loss
    loss_match = output.match(/(\d+)% packet loss/)
    stats[:packet_loss] = loss_match[1].to_f if loss_match

    # Extract min/avg/max/stddev
    stats_match = output.match(/min\/avg\/max\/stddev = ([\d.]+)\/([\d.]+)\/([\d.]+)\/([\d.]+)/)
    if stats_match
      stats[:min_ms] = stats_match[1].to_f
      stats[:avg_ms] = stats_match[2].to_f
      stats[:max_ms] = stats_match[3].to_f
      stats[:stddev_ms] = stats_match[4].to_f
    end

    # Alternative format for some systems
    alt_match = output.match(/min\/avg\/max = ([\d.]+)\/([\d.]+)\/([\d.]+)/)
    if alt_match && !stats[:avg_ms]
      stats[:min_ms] = alt_match[1].to_f
      stats[:avg_ms] = alt_match[2].to_f
      stats[:max_ms] = alt_match[3].to_f
    end

    stats[:status] = 'success'
    stats
  end

  def test_bandwidth
    results = {}

    case @selected_tool
    when 'speedtest-cli'
      results = test_with_speedtest_cli
    when 'fast'
      results = test_with_fast
    else
      results = test_with_curl
    end

    results
  end

  def test_with_speedtest_cli
    results = {}
    cmd = "speedtest-cli --json --timeout #{@timeout}"
    cmd += " --server #{@server}" if @server
    cmd += " --single" if @test_download && !@test_upload # Simple download test

    begin
      log_debug "Running: #{cmd}" if debug?
      result = System.execute(cmd, description: "Running speed test with speedtest-cli")

      if result
        data = JSON.parse(result)

        results[:download_mbps] = data['download'] / 1_000_000.0 if data['download']
        results[:upload_mbps] = data['upload'] / 1_000_000.0 if data['upload']
        results[:ping_ms] = data['ping'] if data['ping']
        results[:server] = data['server'] if data['server']
        results[:client] = data['client'] if data['client']
        results[:timestamp] = data['timestamp'] if data['timestamp']
        results[:tool] = 'speedtest-cli'
        results[:status] = 'success'
      else
        results[:error] = "Speedtest failed"
        results[:status] = 'failed'
      end
    rescue => e
      results[:error] = e.message
      results[:status] = 'error'
    end

    results
  end

  def test_with_fast
    results = {}

    begin
      log_debug "Running fast speed test..." if debug?
      result = System.execute("fast", description: "Running fast speed test")

      if result
        # Parse fast output (e.g., "100 Mbps")
        speed_match = result.match(/(\d+(?:\.\d+)?)\s*(\w+)/)
        if speed_match
          speed = speed_match[1].to_f
          unit = speed_match[2].upcase

          if unit == 'MBPS' || unit == 'Mbps'
            results[:download_mbps] = speed
          elsif unit == 'GBPS' || unit == 'Gbps'
            results[:download_mbps] = speed * 1000
          end

          results[:tool] = 'fast'
          results[:status] = 'success'
        else
          results[:error] = "Could not parse fast output: #{result}"
          results[:status] = 'parse_error'
        end
      else
        results[:error] = "Fast test failed"
        results[:status] = 'failed'
      end
    rescue => e
      results[:error] = e.message
      results[:status] = 'error'
    end

    results
  end

  def test_with_curl
    results = {}

    if @test_download
      # Download test using curl to a large file
      test_url = "http://speedtest.tele2.net/10MB.zip"
      begin
        log_debug "Testing download with curl..." if debug?
        cmd = "curl -o /dev/null -r 0-10485760 -w '%{speed_download}' -s #{test_url}"
        result = System.execute(cmd, description: "Testing download speed with curl")

        if result && result.match?(/\d+/)
          bytes_per_sec = result.strip.to_f
          results[:download_mbps] = (bytes_per_sec * 8) / 1_000_000.0
          results[:download_method] = 'curl'
        end
      rescue => e
        log_debug "Download test failed: #{e.message}" if debug?
      end
    end

    results[:tool] = 'curl'
    results[:status] = results[:download_mbps] ? 'success' : 'failed'
    results
  end

  def display_network_info(info)
    log_section "Network Information"

    if info[:public_ip]
      puts "🌍 Public IP: #{info[:public_ip]}"
      puts "📍 Location: #{info[:location]}" if info[:location]
      puts "🏢 ISP: #{info[:isp]}" if info[:isp]
      puts "🖥️  Hostname: #{info[:hostname]}" if info[:hostname]
    else
      puts "🌍 Public IP: Unable to determine"
    end

    if info[:interfaces] && !info[:interfaces].empty?
      puts "\n📡 Network Interfaces:"
      info[:interfaces].each do |iface|
        puts "  #{iface[:name]}: #{iface[:ip]} (#{iface[:status]})"
      end
    end

    puts ""
  end

  def display_ping_results(ping_results)
    log_section "Ping/Latency Test"

    ping_results.each do |host, stats|
      if stats[:status] == 'success'
        puts "🏓 #{host}:"
        puts "   Average: #{'%.1f' % stats[:avg_ms]}ms"
        puts "   Min/Max: #{'%.1f' % stats[:min_ms]}ms / #{'%.1f' % stats[:max_ms]}ms"
        puts "   Loss: #{stats[:packet_loss]}%" if stats[:packet_loss]
      else
        puts "🏓 #{host}: ❌ #{stats[:error]}"
      end
    end
    puts ""
  end

  def display_speed_results(results)
    log_section "Bandwidth Test"

    if results[:status] == 'success'
      if results[:download_mbps]
        download_mb = results[:download_mbps] / 8
        puts "⬇️  Download: #{format_speed(results[:download_mbps] * 1_000_000)} (#{'%.2f' % download_mb} MB/s)"
      end

      if results[:upload_mbps]
        upload_mb = results[:upload_mbps] / 8
        puts "⬆️  Upload: #{format_speed(results[:upload_mbps] * 1_000_000)} (#{'%.2f' % upload_mb} MB/s)"
      end

      if results[:ping_ms]
        puts "🏓 Ping: #{'%.1f' % results[:ping_ms]}ms"
      end

      if results[:server]
        server = results[:server]
        puts "\n🌐 Test Server:"
        puts "   Name: #{server['name']}" if server['name']
        puts "   Location: #{server['country']}" if server['country']
        puts "   Sponsor: #{server['sponsor']}" if server['sponsor']
      end
    else
      puts "❌ Bandwidth test failed: #{results[:error]}"
    end
    puts ""
  end

  def display_summary(results)
    log_section "Summary"

    # Find best ping result
    if results[:ping] && !results[:ping].empty?
      best_ping = results[:ping].values.select { |p| p[:status] == 'success' }
                     .min_by { |p| p[:avg_ms] }
      if best_ping
        puts "🏓 Best Latency: #{'%.1f' % best_ping[:avg_ms]}ms"
      end
    end

    # Show speeds
    speed_results = results.select { |k, _| [:download_mbps, :upload_mbps].include?(k) }
    if !speed_results.empty?
      puts "🚀 Network Performance:"
      puts "   Download: #{format_speed(results[:download_mbps] * 1_000_000)}" if results[:download_mbps]
      puts "   Upload: #{format_speed(results[:upload_mbps] * 1_000_000)}" if results[:upload_mbps]
    end

    puts ""
    log_info "Test completed using #{results[:tool] || 'multiple tools'}"
  end

  def format_speed(bytes_per_sec)
    units = ['B/s', 'KB/s', 'MB/s', 'GB/s']
    speed = bytes_per_sec.to_f
    unit_index = 0

    while speed >= 1024 && unit_index < units.length - 1
      speed /= 1024
      unit_index += 1
    end

    if unit_index == 0
      "#{speed.to_i} #{units[unit_index]}"
    else
      "#{speed.round(2)} #{units[unit_index]}"
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name}                    # Full speed test with auto-selected tool"
    puts "  #{script_name} --simple           # Simple output format"
    puts "  #{script_name} --json             # JSON output format"
    puts "  #{script_name} -s 1234            # Use specific speedtest.net server"
    puts "  #{script_name} -n                 # Skip download test"
    puts "  #{script_name} -u                 # Skip upload test"
    puts "  #{script_name} -p                 # Skip ping test"
    puts "  #{script_name} -t 60              # Set timeout to 60 seconds"
    puts "  #{script_name} --tool fast.com    # Use fast.com for testing"
    puts "  #{script_name} --tool iperf3      # Use iperf3 for testing"
  end
end

NetworkSpeedTestScript.execute if __FILE__ == $0