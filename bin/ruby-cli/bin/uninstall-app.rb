#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/archive/script_base'
require 'sqlite3'
require 'find'
require 'rexml/document'

# Comprehensive Application Uninstaller
# Removes applications from multiple sources with complete cleanup
class UninstallApp < ScriptBase
  def initialize
    super
    @app_name = nil
    @discovery_results = {}
  end

  # Script metadata for standardized help text
  def script_emoji
    '🗑️'
  end

  def script_title
    'Comprehensive Application Uninstaller'
  end

  def script_description
    'Removes applications from multiple sources with complete cleanup including
Homebrew packages, Mac App Store apps, processes, and associated files.'
  end

  def script_arguments
    '<application-name>'
  end

  def add_custom_options(opts)
    # No custom options for this script
  end

  def show_examples
    puts 'Examples:'
    puts "  #{script_name} \"Visual Studio Code\"    # Remove Visual Studio Code"
    puts "  #{script_name} --force docker           # Force remove Docker"
    puts "  #{script_name} --dry-run slack          # Preview what would be removed"
    puts "  #{script_name} -v \"Adobe Photoshop\"     # Verbose removal"
    puts ''
    puts 'Features:'
    puts '  🍺 Homebrew packages & services'
    puts '  🏪 Mac App Store applications'
    puts '  🖥️  Application bundles'
    puts '  ⚡ Running process termination'
    puts '  🚀 Startup items cleanup'
    puts '  🌐 Browser extensions & data'
    puts '  🔧 Kernel extensions & drivers'
    puts '  🔒 Security & privacy entries'
    puts '  📦 Package managers (npm, yarn, pip, gems)'
    puts '  🌐 Network & system integration'
    puts '  🔍 Advanced cleanup features'
    puts '  🧹 Associated files & preferences'
  end

  def validate!
    if args.empty?
      log_error('Application name is required')
      puts banner_text
      exit 1
    end

    @app_name = args.join(' ')
    log_debug("Target application: #{@app_name}")
  end

  def run
    log_banner("#{script_title}: #{@app_name}")

    # Phase 1: Discovery
    log_section('🔍 DISCOVERY PHASE')
    discover_all_components
    show_discovery_summary

    return if dry_run?
    return unless confirm_overall_removal

    # Phase 2: Removal
    log_section('🗑️  REMOVAL PHASE')
    perform_removal

    show_completion("#{script_title} for #{@app_name}")
  end

  private

  # Discovery phase - find everything without removing
  def discover_all_components
    @discovery_results = {
      processes: discover_processes,
      homebrew_formulae: discover_homebrew_formulae,
      homebrew_casks: discover_homebrew_casks,
      homebrew_services: discover_homebrew_services,
      mas_apps: discover_mas_apps,
      app_bundles: discover_app_bundles,
      startup_items: discover_startup_items,
      browser_items: discover_browser_items,
      kernel_extensions: discover_kernel_extensions,
      security_entries: discover_security_entries,
      package_managers: discover_package_managers,
      network_items: discover_network_items,
      advanced_items: discover_advanced_items,
      associated_files: discover_associated_files
    }
  end

  def discover_processes
    pids = `pgrep -i "#{@app_name}"`.split.map(&:to_i)
    return [] if pids.empty?

    processes = pids.map do |pid|
      cmd = `ps -p #{pid} -o comm= 2>/dev/null`.strip
      { pid: pid, command: cmd }
    end.reject { |p| p[:command].empty? }

    log_info("Found #{processes.length} running process(es)")
    processes
  end

  def discover_homebrew_formulae
    return [] unless System::Homebrew.installed?

    formulae = System::Homebrew.list_formulae.select { |f| f.downcase.include?(@app_name.downcase) }
    log_info("Found #{formulae.length} Homebrew formula(e)")
    formulae
  end

  def discover_homebrew_casks
    return [] unless System::Homebrew.installed?

    casks = System::Homebrew.list_casks.select { |c| c.downcase.include?(@app_name.downcase) }
    log_info("Found #{casks.length} Homebrew cask(s)")
    casks
  end

  def discover_homebrew_services
    return [] unless System::Homebrew.installed?

    services = System::Homebrew.running_services.select { |s| s.downcase.include?(@app_name.downcase) }
    log_info("Found #{services.length} running Homebrew service(s)")
    services
  end

  def discover_mas_apps
    return [] unless System::MacAppStore.installed?

    apps = System::MacAppStore.list_installed.select do |app|
      app[:name].downcase.include?(@app_name.downcase)
    end
    log_info("Found #{apps.length} Mac App Store application(s)")
    apps
  end

  def discover_app_bundles
    bundles = find_in_directories(application_dirs, @app_name).select { |f| f.end_with?('.app') }
    log_info("Found #{bundles.length} application bundle(s)")
    bundles
  end

  def discover_startup_items
    plists = find_in_directories(launch_dirs, @app_name).select { |f| f.end_with?('.plist') }
    log_info("Found #{plists.length} startup item(s)")
    plists
  end

  def discover_browser_items
    browser_dirs = [
      "#{System.home_dir}/Library/Application Support/Google/Chrome/Default/Extensions",
      "#{System.home_dir}/Library/Application Support/Google/Chrome/Profile */Extensions",
      "#{System.home_dir}/Library/Safari/Extensions",
      "#{System.home_dir}/Library/Containers/com.apple.Safari/Data/Library/Safari/Extensions",
      "#{System.home_dir}/Library/Application Support/Firefox/Profiles/*/extensions"
    ]

    items = find_in_directories(browser_dirs, @app_name)
    log_info("Found #{items.length} browser item(s)")
    items
  end

  def discover_kernel_extensions
    kext_dirs = [
      '/System/Library/Extensions',
      '/Library/Extensions',
      '/System/Library/DriverExtensions',
      '/Library/DriverExtensions'
    ]

    kexts = find_in_directories(kext_dirs, @app_name).select { |f| f.match?(/\.(kext|dext)$/) }
    log_info("Found #{kexts.length} kernel extension(s)")
    kexts
  end

  def discover_security_entries
    entries = {}

    # Keychain entries
    keychain_items = `security dump-keychain 2>/dev/null | grep -i "#{@app_name}" || true`.split("\n")
    entries[:keychain] = keychain_items.first(5) # Limit display

    # Privacy database
    privacy_db = '/Library/Application Support/com.apple.TCC/TCC.db'
    entries[:privacy] = []

    if File.exist?(privacy_db) && System.command?('sqlite3')
      begin
        privacy_entries = `sudo sqlite3 "#{privacy_db}" "SELECT client FROM access WHERE client LIKE '%#{@app_name}%';" 2>/dev/null`.split("\n")
        entries[:privacy] = privacy_entries
      rescue StandardError
        # Ignore permission errors
      end
    end

    total = entries[:keychain].length + entries[:privacy].length
    log_info("Found #{total} security/privacy entry(ies)")
    entries
  end

  def discover_package_managers
    packages = {}

    # NPM global packages
    if System.command?('npm')
      npm_packages = `npm list -g --depth=0 2>/dev/null | grep -i "#{@app_name}" || true`.split("\n")
      packages[:npm] = npm_packages
    end

    # Yarn global packages
    if System.command?('yarn')
      yarn_packages = `yarn global list 2>/dev/null | grep -i "#{@app_name}" || true`.split("\n")
      packages[:yarn] = yarn_packages
    end

    # Python packages
    if System.command?('pip3')
      pip_packages = `pip3 list | grep -i "#{@app_name}" || true`.split("\n")
      packages[:pip] = pip_packages
    end

    # Ruby gems
    if System.command?('gem')
      gem_packages = `gem list | grep -i "#{@app_name}" || true`.split("\n")
      packages[:gems] = gem_packages
    end

    total = packages.values.sum(&:length)
    log_info("Found #{total} package manager entry(ies)")
    packages
  end

  def discover_network_items
    items = {}

    # System extensions
    if System.command?('systemextensionsctl')
      sys_exts = `systemextensionsctl list 2>/dev/null | grep -i "#{@app_name}" || true`.split("\n")
      items[:system_extensions] = sys_exts
    end

    # DNS resolver files
    dns_dir = '/etc/resolver'
    items[:dns_files] = []
    items[:dns_files] = find_in_directories([dns_dir], @app_name) if Dir.exist?(dns_dir)

    total = items.values.sum(&:length)
    log_info("Found #{total} network/system entry(ies)")
    items
  end

  def discover_advanced_items
    items = {}

    # QuickLook plugins
    ql_dirs = [
      "#{System.home_dir}/Library/QuickLook",
      '/Library/QuickLook',
      '/System/Library/QuickLook'
    ]
    items[:quicklook] = find_in_directories(ql_dirs, @app_name).select { |f| f.end_with?('.qlgenerator') }

    # Time Machine exclusions
    if System.command?('tmutil')
      tm_exclusions = `tmutil listexclusions 2>/dev/null | grep -i "#{@app_name}" || true`.split("\n")
      items[:time_machine] = tm_exclusions
    end

    # Dock entries (check plist)
    dock_plist = "#{System.home_dir}/Library/Preferences/com.apple.dock.plist"
    items[:dock_entries] = []
    if File.exist?(dock_plist)
      begin
        require 'plist'
        dock_data = Plist.parse_xml(dock_plist)
        if dock_data && dock_data['persistent-apps']
          dock_entries = dock_data['persistent-apps'].select do |app|
            app.dig('tile-data', 'file-label')&.downcase&.include?(@app_name.downcase) ||
              app.dig('tile-data', 'bundle-identifier')&.downcase&.include?(@app_name.downcase)
          end
          items[:dock_entries] = dock_entries.empty? ? [] : ["Found #{dock_entries.size} Dock entry(ies)"]
        end
      rescue StandardError => e
        log_debug("Failed to parse Dock plist: #{e.message}")
        # Fallback to plutil if plist gem fails
        if System.command?('plutil')
          dock_check = `plutil -convert xml1 -o - "#{dock_plist}" | grep -i "#{@app_name}" || true`
          items[:dock_entries] = dock_check.empty? ? [] : ['Found in Dock preferences']
        end
      end
    end

    total = items.values.sum(&:length)
    log_info("Found #{total} advanced cleanup item(s)")
    items
  end

  def discover_associated_files
    all_dirs = user_library_dirs + system_library_dirs
    files = find_in_directories(all_dirs, @app_name)
    log_info("Found #{files.length} associated file(s)")
    files
  end

  # Show comprehensive discovery summary
  def show_discovery_summary
    puts
    log_section('📋 DISCOVERY SUMMARY')
    puts

    total_items = 0

    # Running processes
    if @discovery_results[:processes].any?
      log_warning("⚡ Running Processes (#{@discovery_results[:processes].length}):")
      @discovery_results[:processes].each do |proc|
        puts "  • PID #{proc[:pid]}: #{proc[:command]}"
      end
      total_items += @discovery_results[:processes].length
      puts
    end

    # Homebrew items
    homebrew_total = @discovery_results[:homebrew_formulae].length +
                     @discovery_results[:homebrew_casks].length +
                     @discovery_results[:homebrew_services].length

    if homebrew_total > 0
      log_warning("🍺 Homebrew Items (#{homebrew_total}):")
      @discovery_results[:homebrew_services].each { |s| puts "  • Service: #{s}" }
      @discovery_results[:homebrew_formulae].each { |f| puts "  • Formula: #{f}" }
      @discovery_results[:homebrew_casks].each { |c| puts "  • Cask: #{c}" }
      total_items += homebrew_total
      puts
    end

    # Mac App Store
    if @discovery_results[:mas_apps].any?
      log_warning("🏪 Mac App Store Apps (#{@discovery_results[:mas_apps].length}):")
      @discovery_results[:mas_apps].each { |app| puts "  • #{app[:name]} (#{app[:id]})" }
      total_items += @discovery_results[:mas_apps].length
      puts
    end

    # Application bundles
    if @discovery_results[:app_bundles].any?
      log_warning("🖥️  Application Bundles (#{@discovery_results[:app_bundles].length}):")
      @discovery_results[:app_bundles].each { |app| puts "  • #{File.basename(app)}" }
      total_items += @discovery_results[:app_bundles].length
      puts
    end

    # Startup items
    if @discovery_results[:startup_items].any?
      log_warning("🚀 Startup Items (#{@discovery_results[:startup_items].length}):")
      @discovery_results[:startup_items].each { |item| puts "  • #{File.basename(item)}" }
      total_items += @discovery_results[:startup_items].length
      puts
    end

    # Browser items
    if @discovery_results[:browser_items].any?
      log_warning("🌐 Browser Extensions/Data (#{@discovery_results[:browser_items].length}):")
      @discovery_results[:browser_items].each { |item| puts "  • #{File.basename(item)}" }
      total_items += @discovery_results[:browser_items].length
      puts
    end

    # Kernel extensions
    if @discovery_results[:kernel_extensions].any?
      log_warning("🔧 Kernel Extensions (#{@discovery_results[:kernel_extensions].length}):")
      @discovery_results[:kernel_extensions].each { |kext| puts "  • #{File.basename(kext)}" }
      total_items += @discovery_results[:kernel_extensions].length
      puts
    end

    # Security entries
    security_total = @discovery_results[:security_entries][:keychain].length +
                     @discovery_results[:security_entries][:privacy].length

    if security_total > 0
      log_warning("🔒 Security/Privacy Entries (#{security_total}):")
      @discovery_results[:security_entries][:keychain].each { |item| puts "  • Keychain: #{item}" }
      @discovery_results[:security_entries][:privacy].each { |item| puts "  • Privacy DB: #{item}" }
      total_items += security_total
      puts
    end

    # Package managers
    pkg_total = @discovery_results[:package_managers].values.sum(&:length)
    if pkg_total > 0
      log_warning("📦 Package Manager Items (#{pkg_total}):")
      @discovery_results[:package_managers].each do |mgr, items|
        items.each { |item| puts "  • #{mgr.upcase}: #{item}" }
      end
      total_items += pkg_total
      puts
    end

    # Network items
    net_total = @discovery_results[:network_items].values.sum(&:length)
    if net_total > 0
      log_warning("🌐 Network/System Items (#{net_total}):")
      @discovery_results[:network_items].each do |type, items|
        items.each { |item| puts "  • #{type}: #{item}" }
      end
      total_items += net_total
      puts
    end

    # Advanced items
    adv_total = @discovery_results[:advanced_items].values.sum(&:length)
    if adv_total > 0
      log_warning("🔍 Advanced Items (#{adv_total}):")
      @discovery_results[:advanced_items].each do |type, items|
        items.each { |item| puts "  • #{type}: #{item}" }
      end
      total_items += adv_total
      puts
    end

    # Associated files
    if @discovery_results[:associated_files].any?
      log_warning("🧹 Associated Files (#{@discovery_results[:associated_files].length}):")
      @discovery_results[:associated_files].first(10).each { |file| puts "  • #{File.basename(file)}" }
      if @discovery_results[:associated_files].length > 10
        puts "  • ... and #{@discovery_results[:associated_files].length - 10} more"
      end
      total_items += @discovery_results[:associated_files].length
      puts
    end

    if total_items == 0
      log_info("No items found for '#{@app_name}'")
      log_info('The application may not be installed or may use a different name')
      exit 0
    end

    log_warning("📊 TOTAL ITEMS TO REMOVE: #{total_items}")
    puts
  end

  def confirm_overall_removal
    log_warning("⚠️  This will COMPLETELY REMOVE '#{@app_name}' from your system!")
    log_warning('This includes ALL items listed above.')
    puts

    confirm_action('❓ Proceed with complete removal?')
  end

  # Removal phase
  def perform_removal
    # Step 1: Kill processes
    remove_processes if @discovery_results[:processes].any?

    # Step 2: Stop and remove Homebrew services
    remove_homebrew_services if @discovery_results[:homebrew_services].any?

    # Step 3: Remove Homebrew packages
    remove_homebrew_packages if @discovery_results[:homebrew_formulae].any? || @discovery_results[:homebrew_casks].any?

    # Step 4: Remove Mac App Store apps
    remove_mas_apps if @discovery_results[:mas_apps].any?

    # Step 5: Remove application bundles
    remove_app_bundles if @discovery_results[:app_bundles].any?

    # Step 6: Remove startup items
    remove_startup_items if @discovery_results[:startup_items].any?

    # Step 7: Remove browser items
    remove_browser_items if @discovery_results[:browser_items].any?

    # Step 8: Remove kernel extensions
    remove_kernel_extensions if @discovery_results[:kernel_extensions].any?

    # Step 9: Remove security entries
    if @discovery_results[:security_entries][:keychain].any? || @discovery_results[:security_entries][:privacy].any?
      remove_security_entries
    end

    # Step 10: Remove package manager items
    remove_package_managers if @discovery_results[:package_managers].values.any?(&:any?)

    # Step 11: Remove network items
    remove_network_items if @discovery_results[:network_items].values.any?(&:any?)

    # Step 12: Remove advanced items
    remove_advanced_items if @discovery_results[:advanced_items].values.any?(&:any?)

    # Step 13: Remove associated files
    remove_associated_files if @discovery_results[:associated_files].any?

    # Step 14: Cleanup
    cleanup_homebrew
  end

  def remove_processes
    log_progress('⚡ Removing running processes...')

    pids = `pgrep -i "#{@app_name}"`.split.map(&:to_i)
    return if pids.empty?

    log_warning("Found #{pids.length} running process(es) for '#{@app_name}'")
    pids.each { |pid| log_debug("PID: #{pid}") } if verbose?

    pids.each do |pid|
      log_progress("Terminating process #{pid}")
      system("kill -TERM #{pid}")
      sleep 1

      # Force kill if still running
      if system("kill -0 #{pid} 2>/dev/null")
        log_progress("Force killing process #{pid}")
        system("kill -KILL #{pid}")
      end
    end

    log_success('Stopped running processes')
    puts
  end

  def remove_homebrew_services
    log_progress('🍺 Stopping Homebrew services...')
    @discovery_results[:homebrew_services].each do |service|
      System::Homebrew.stop_service(service)
    end
    puts
  end

  def remove_homebrew_packages
    log_progress('🍺 Removing Homebrew packages...')
    @discovery_results[:homebrew_formulae].each do |formula|
      System::Homebrew.uninstall_formula(formula)
    end
    @discovery_results[:homebrew_casks].each do |cask|
      System::Homebrew.uninstall_cask(cask)
    end
    puts
  end

  def remove_mas_apps
    log_progress('🏪 Removing Mac App Store applications...')

    @discovery_results[:mas_apps].each do |app|
      success = System::MacAppStore.uninstall(app[:id])

      unless success
        log_warning("⚠️  Failed to uninstall '#{app[:name]}' via Mac App Store")
        log_warning("   This may require manual uninstallation via Launchpad or Finder")
        log_warning("   Some apps don't support command-line uninstallation")

        # Fallback: Check if the app bundle still exists and remove it
        app_path = "/Applications/#{app[:name]}.app"
        if File.exist?(app_path)
          log_progress("🔄 Attempting manual removal of app bundle...")
          remove_file(app_path, skip_confirmation: true)
        end
      end
    end
    puts
  end

  def remove_app_bundles
    log_progress('🖥️  Removing application bundles...')

    @discovery_results[:app_bundles].each do |app_bundle|
      # Check if the app bundle exists and get its ownership
      if File.exist?(app_bundle)
        stat = File.stat(app_bundle)

        # If owned by root, use sudo for removal
        if stat.uid == 0
          log_warning("🔧 System-owned application detected: #{File.basename(app_bundle)}")
          log_progress("🔄 Using sudo to remove system application...")
          execute_cmd("sudo rm -rf '#{app_bundle}'", description: "Removing system app: #{File.basename(app_bundle)}")
        else
          # Regular user-owned app, use standard removal
          remove_file(app_bundle, skip_confirmation: true)
        end
      else
        log_info("App bundle not found: #{app_bundle}")
      end
    end

    log_success("Removed #{@discovery_results[:app_bundles].length} app bundles") if @discovery_results[:app_bundles].any?
    puts
  end

  def remove_startup_items
    log_progress('🚀 Removing startup items...')
    @discovery_results[:startup_items].each do |plist|
      plist_name = File.basename(plist, '.plist')
      execute_cmd("launchctl unload '#{plist}'", description: "Unloading #{plist_name}")
      remove_file(plist)
    end
    puts
  end

  def remove_browser_items
    log_progress('🌐 Removing browser extensions and data...')
    remove_files(@discovery_results[:browser_items], skip_confirmation: true)
    puts
  end

  def remove_kernel_extensions
    return unless confirm_action('🔧 Remove kernel extensions? (requires admin privileges)')

    log_progress('🔧 Removing kernel extensions...')
    log_warning('⚠️  This requires admin privileges and system restart!')

    @discovery_results[:kernel_extensions].each do |kext|
      kext_name = File.basename(kext)
      execute_cmd("sudo kextunload '#{kext}'", description: "Unloading #{kext_name}")
      log_warning "System-level deletion required for kernel extension: #{kext_name}"
      execute_cmd("sudo rm -rf '#{kext}'", description: "Removing #{kext_name} (SYSTEM FILE)")
    end

    execute_cmd('sudo kextcache -system-prelinked-kernel', description: 'Rebuilding kernel cache')
    execute_cmd('sudo kextcache -system-caches', description: 'Updating system caches')

    log_warning('System restart recommended for changes to take effect')
    puts
  end

  def remove_security_entries
    log_progress('🔒 Handling security and privacy entries...')

    if @discovery_results[:security_entries][:keychain].any?
      log_warning('Found keychain entries - manual review recommended in Keychain Access.app')
    end

    if @discovery_results[:security_entries][:privacy].any?
      log_warning('Removing privacy permissions (requires sudo)')
      privacy_db = '/Library/Application Support/com.apple.TCC/TCC.db'
      execute_cmd("sudo sqlite3 '#{privacy_db}' \"DELETE FROM access WHERE client LIKE '%#{@app_name}%';\"",
                  description: 'Removing privacy permissions')
    end
    puts
  end

  def remove_package_managers
    log_progress('📦 Removing package manager installations...')

    @discovery_results[:package_managers].each do |manager, packages|
      next if packages.empty?

      packages.each do |package|
        case manager
        when :npm
          package_name = package.split('── ').last.split('@').first
          execute_cmd("npm uninstall -g '#{package_name}'", description: "Removing npm package: #{package_name}")
        when :yarn
          package_name = package.split('@').first.gsub(/^info "/, '').gsub(/".*$/, '')
          execute_cmd("yarn global remove '#{package_name}'", description: "Removing yarn package: #{package_name}")
        when :pip
          package_name = package.split.first
          execute_cmd("pip3 uninstall -y '#{package_name}'", description: "Removing pip package: #{package_name}")
        when :gems
          gem_name = package.split.first
          execute_cmd("gem uninstall '#{gem_name}'", description: "Removing gem: #{gem_name}")
        end
      end
    end
    puts
  end

  def remove_network_items
    log_progress('🌐 Removing network and system integration...')

    @discovery_results[:network_items][:system_extensions].each do |ext_line|
      bundle_id = ext_line.split[1]
      execute_cmd("sudo systemextensionsctl uninstall '#{bundle_id}'",
                  description: "Removing system extension: #{bundle_id}")
    end

    if @discovery_results[:network_items][:dns_files].any?
      log_warning('Removing DNS resolver files (requires sudo)')
      @discovery_results[:network_items][:dns_files].each do |file|
        log_warning "System-level deletion required for DNS resolver: #{File.basename(file)}"
        execute_cmd("sudo rm -f '#{file}'", description: "Removing DNS resolver: #{File.basename(file)} (SYSTEM FILE)")
      end
    end
    puts
  end

  def remove_advanced_items
    log_progress('🔍 Performing advanced cleanup...')

    if @discovery_results[:advanced_items][:quicklook].any?
      remove_files(@discovery_results[:advanced_items][:quicklook], skip_confirmation: true)
      execute_cmd('qlmanage -r', description: 'Reloading QuickLook plugins')
    end

    if @discovery_results[:advanced_items][:time_machine].any?
      @discovery_results[:advanced_items][:time_machine].each do |exclusion|
        execute_cmd("tmutil removeexclusion '#{exclusion}'", description: 'Removing Time Machine exclusion')
      end
    end

    if @discovery_results[:advanced_items][:dock_entries].any?
      log_warning('Restarting Dock to remove entries')
      execute_cmd('killall Dock', description: 'Restarting Dock')
    end
    puts
  end

  def remove_associated_files
    log_progress('🧹 Removing associated files...')
    remove_files(@discovery_results[:associated_files], skip_confirmation: true)
    puts
  end

  def cleanup_homebrew
    return unless System::Homebrew.installed?

    log_progress('🍺 Cleaning up Homebrew...')
    execute_cmd('brew cleanup', description: 'Running Homebrew cleanup')
    execute_cmd('brew autoremove', description: 'Removing unused dependencies')
  end

  def show_restart_notice
    log_info('You may need to restart your system for all changes to take effect')
  end
end

# Execute the script
UninstallApp.execute if __FILE__ == $0
