#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: Auto-generate categories.yml from script metadata headers
# @tags: automation, metadata, organization

require 'yaml'
require 'fileutils'

class GenerateCategoriesScript
  # ANSI color codes
  BLUE = "\033[0;34m"
  GREEN = "\033[0;32m"
  YELLOW = "\033[1;33m"
  RED = "\033[0;31m"
  MAGENTA = "\033[0;35m"
  NC = "\033[0m"

  attr_reader :validate_only, :show_missing, :output_path, :working_dir

  def initialize
    @working_dir = ENV['ORIGINAL_WORKING_DIR'] || Dir.pwd
    # Navigate up to zshrc root if we're in a subdirectory
    @working_dir = File.expand_path('../../../..', __FILE__) if @working_dir.include?('bin/ruby-cli')
    parse_options
  end

  def parse_options
    @validate_only = ARGV.include?('--validate')
    @show_missing = ARGV.include?('--missing')
    @output_path = if ARGV.include?('--output')
                     idx = ARGV.index('--output')
                     ARGV[idx + 1]
                   else
                     File.join(@working_dir, 'bin', 'categories.yml')
                   end
  end

  def run
    unless validate_only || show_missing
      log_banner('Generate Categories')
    end

    scripts = scan_scripts

    if show_missing
      show_missing_headers(scripts)
      return
    end

    if validate_only
      validate_scripts(scripts)
      return
    end

    categories = organize_by_category(scripts)
    write_yaml(categories)
    log_success("Category generation complete!")
  end

  private

  def log_info(msg)
    puts "#{BLUE}ℹ️  #{msg}#{NC}"
  end

  def log_success(msg)
    puts "#{GREEN}✅ #{msg}#{NC}"
  end

  def log_warning(msg)
    puts "#{YELLOW}⚠️  #{msg}#{NC}"
  end

  def log_error(msg)
    puts "#{RED}❌ #{msg}#{NC}"
  end

  def log_section(msg)
    puts "#{MAGENTA}🔧 #{msg}#{NC}"
  end

  def log_banner(title)
    puts ""
    puts "📋 #{title}"
    puts "=" * 60
  end

  def scan_scripts
    scripts = []
    bin_dir = File.join(@working_dir, 'bin')

    log_info "Scanning #{bin_dir} for scripts..."

    # Ruby scripts
    Dir.glob("#{bin_dir}/ruby-cli/bin/*.rb").each do |path|
      scripts << parse_script(path, 'Ruby')
    end

    # Python scripts
    Dir.glob("#{bin_dir}/python-cli/*.py").each do |path|
      scripts << parse_script(path, 'Python')
    end

    # Shell scripts
    Dir.glob("#{bin_dir}/*.sh").each do |path|
      scripts << parse_script(path, 'Shell')
    end

    # Scripts without extensions (likely Ruby or Shell)
    Dir.glob("#{bin_dir}/*").select { |f| File.file?(f) && File.executable?(f) && !f.match?(/\.(rb|py|sh)$/) }.each do |path|
      # Detect language from shebang
      first_line = File.readlines(path).first
      language = if first_line&.include?('ruby')
                   'Ruby'
                 elsif first_line&.include?('python')
                   'Python'
                 elsif first_line&.include?('bash') || first_line&.include?('sh')
                   'Shell'
                 else
                   'Unknown'
                 end
      scripts << parse_script(path, language)
    end

    log_success "Found #{scripts.size} scripts"
    scripts.compact
  end

  def parse_script(path, language)
    content = File.read(path, encoding: 'UTF-8', invalid: :replace, undef: :replace, replace: '')
    lines = content.lines.first(20) # Only read first 20 lines for metadata

    category = extract_metadata(lines, 'category')
    description = extract_metadata(lines, 'description')
    tags = extract_metadata(lines, 'tags')

    # Skip if no metadata
    return nil unless category || description || tags

    {
      name: File.basename(path),
      path: path.sub(@working_dir + '/', ''),
      language: language,
      category: category,
      description: description,
      tags: tags ? tags.split(',').map(&:strip) : []
    }
  end

  def extract_metadata(lines, field)
    pattern = /^#\s*@#{field}:\s*(.+)$/
    match = lines.find { |line| line.match?(pattern) }
    match ? match.match(pattern)[1].strip : nil
  end

  def organize_by_category(scripts)
    categories = {}

    scripts.each do |script|
      next unless script[:category]

      category = script[:category]
      categories[category] ||= []
      categories[category] << {
        'name' => script[:name],
        'path' => script[:path],
        'language' => script[:language],
        'description' => script[:description] || 'No description',
        'tags' => script[:tags]
      }
    end

    # Sort categories alphabetically
    Hash[categories.sort]
  end

  def write_yaml(categories)
    log_info "Writing to #{output_path}..."

    yaml_content = {
      'version' => '1.0',
      'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'categories' => categories,
      'statistics' => generate_statistics(categories)
    }

    File.write(output_path, yaml_content.to_yaml)
    log_success "Created: #{output_path}"

    # Show summary
    puts ""
    log_section "Category Summary"
    categories.each do |category, scripts|
      puts "  #{category.ljust(15)} #{scripts.size} scripts"
    end
  end

  def generate_statistics(categories)
    total_scripts = categories.values.sum(&:size)
    languages = {}

    categories.values.flatten.each do |script|
      lang = script['language']
      languages[lang] ||= 0
      languages[lang] += 1
    end

    {
      'total_scripts' => total_scripts,
      'total_categories' => categories.size,
      'by_language' => languages
    }
  end

  def show_missing_headers(scripts)
    log_banner("Scripts Missing Metadata")

    bin_dir = File.join(@working_dir, 'bin')
    all_scripts = Dir.glob("#{bin_dir}/**/*.{rb,py,sh}") +
                  Dir.glob("#{bin_dir}/*").select { |f| File.file?(f) && File.executable?(f) }

    all_scripts = all_scripts.map { |p| File.basename(p) }.uniq
    scripts_with_metadata = scripts.map { |s| s[:name] }

    missing = all_scripts - scripts_with_metadata

    if missing.empty?
      log_success "All scripts have metadata headers!"
    else
      log_warning "#{missing.size} scripts missing headers:"
      missing.sort.each do |name|
        puts "  • #{name}"
      end
    end
  end

  def validate_scripts(scripts)
    log_banner("Validating Script Metadata")

    errors = []
    warnings = []

    scripts.each do |script|
      name = script[:name]

      # Check for required fields
      unless script[:category]
        errors << "#{name}: Missing @category"
      end

      unless script[:description]
        warnings << "#{name}: Missing @description"
      end

      unless script[:tags] && !script[:tags].empty?
        warnings << "#{name}: Missing @tags"
      end

      # Validate category is known
      known_categories = %w[git media system setup backup dev files data communication]
      if script[:category] && !known_categories.include?(script[:category])
        warnings << "#{name}: Unknown category '#{script[:category]}'"
      end
    end

    if errors.empty? && warnings.empty?
      log_success "All metadata is valid!"
    else
      if errors.any?
        log_error "Found #{errors.size} errors:"
        errors.each { |e| puts "  ❌ #{e}" }
      end

      if warnings.any?
        log_warning "Found #{warnings.size} warnings:"
        warnings.each { |w| puts "  ⚠️  #{w}" }
      end

      exit 1 if errors.any?
    end
  end
end

if __FILE__ == $0
  begin
    script = GenerateCategoriesScript.new
    script.run
  rescue StandardError => e
    puts "\033[0;31m❌ Error: #{e.message}\033[0m"
    puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    exit 1
  end
end
