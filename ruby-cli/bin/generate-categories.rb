#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: dev
# @description: Auto-generate categories.yml from script metadata headers
# @tags: automation, metadata, tooling

require_relative '../../bin/.common/script_base'
require 'yaml'

class GenerateCategories < ScriptBase
  def script_emoji; '📋'; end
  def script_title; 'Generate Categories'; end
  def script_description; 'Scan all scripts and generate categories.yml from metadata headers'; end
  def script_arguments; '[OPTIONS]'; end

  def add_custom_options(opts)
    opts.on('-o', '--output PATH', 'Output path for categories.yml (default: bin/categories.yml)') do |path|
      @options[:output] = path
    end
    opts.on('--validate', 'Validate existing headers without generating file') do
      @options[:validate_only] = true
    end
    opts.on('--missing', 'Show scripts missing metadata headers') do
      @options[:show_missing] = true
    end
  end

  def run
    log_banner(script_title)

    scripts = scan_all_scripts
    log_info "Found #{scripts.size} script files"

    metadata = parse_metadata(scripts)

    if @options[:show_missing]
      show_missing_metadata(scripts, metadata)
      return
    end

    if @options[:validate_only]
      validate_metadata(metadata)
      return
    end

    categories = build_categories(metadata)
    output_path = @options[:output] || File.join(PROJECT_ROOT, 'bin', 'categories.yml')

    write_categories_file(output_path, categories, metadata)
    show_statistics(categories, metadata)

    show_completion(script_title)
  end

  private

  def scan_all_scripts
    bin_dir = File.join(PROJECT_ROOT, 'bin')
    scripts = []

    # Scan ruby-cli/bin
    ruby_dir = File.join(bin_dir, 'ruby-cli', 'bin')
    scripts += Dir.glob(File.join(ruby_dir, '*.rb')) if Dir.exist?(ruby_dir)

    # Scan python scripts
    python_dir = File.join(bin_dir, 'python-cli')
    scripts += Dir.glob(File.join(python_dir, '*.py')) if Dir.exist?(python_dir)
    scripts += Dir.glob(File.join(bin_dir, '*.py'))

    # Scan shell scripts
    scripts += Dir.glob(File.join(bin_dir, '*.sh'))

    # Scan scripts without extensions (check if executable)
    Dir.glob(File.join(bin_dir, '*')).each do |file|
      next unless File.file?(file)
      next if File.extname(file) != ''
      next unless File.executable?(file)
      scripts << file
    end

    scripts.sort
  end

  def parse_metadata(scripts)
    metadata = {}

    scripts.each do |script_path|
      meta = extract_metadata(script_path)
      metadata[script_path] = meta if meta
    end

    metadata
  end

  def extract_metadata(script_path)
    meta = {
      category: nil,
      description: nil,
      tags: [],
      dependencies: [],
      language: detect_language(script_path)
    }

    File.open(script_path, 'r') do |file|
      line_count = 0
      file.each_line do |line|
        line_count += 1
        break if line_count > 20  # Only check first 20 lines

        # Parse metadata headers
        if line =~ /^#\s*@category:\s*(.+)$/
          meta[:category] = $1.strip
        elsif line =~ /^#\s*@description:\s*(.+)$/
          meta[:description] = $1.strip
        elsif line =~ /^#\s*@tags:\s*(.+)$/
          meta[:tags] = $1.split(',').map(&:strip)
        elsif line =~ /^#\s*@dependencies:\s*(.+)$/
          meta[:dependencies] = $1.split(',').map(&:strip)
        elsif line =~ /^#\s*@language:\s*(.+)$/
          meta[:language] = $1.strip
        end
      end
    end

    # Return nil if no category found (script doesn't have metadata)
    return nil unless meta[:category]

    meta
  rescue => e
    log_warning "Failed to parse #{File.basename(script_path)}: #{e.message}"
    nil
  end

  def detect_language(script_path)
    ext = File.extname(script_path)
    case ext
    when '.rb' then 'ruby'
    when '.py' then 'python'
    when '.sh' then 'shell'
    when '.rs' then 'rust'
    else
      # Try to detect from shebang
      first_line = File.open(script_path) { |f| f.readline rescue '' }
      if first_line =~ /ruby/
        'ruby'
      elsif first_line =~ /python/
        'python'
      elsif first_line =~ /(bash|sh|zsh)/
        'shell'
      else
        'unknown'
      end
    end
  end

  def build_categories(metadata)
    categories = Hash.new { |h, k| h[k] = [] }

    metadata.each do |script_path, meta|
      next unless meta[:category]

      rel_path = script_path.sub("#{PROJECT_ROOT}/", '')

      categories[meta[:category]] << {
        'path' => rel_path,
        'name' => File.basename(script_path, File.extname(script_path)),
        'description' => meta[:description],
        'language' => meta[:language],
        'tags' => meta[:tags],
        'dependencies' => meta[:dependencies]
      }
    end

    # Sort scripts within each category
    categories.each do |category, scripts|
      categories[category] = scripts.sort_by { |s| s['name'] }
    end

    categories.sort.to_h
  end

  def write_categories_file(output_path, categories, metadata)
    output = {
      'generated_at' => Time.now.iso8601,
      'total_scripts' => metadata.size,
      'categories' => categories
    }

    File.write(output_path, output.to_yaml)
    log_success "Generated #{output_path}"
  end

  def show_statistics(categories, metadata)
    puts ""
    log_section "Statistics"

    puts "#{Format.cyan('Total scripts')}: #{metadata.size}"
    puts "#{Format.cyan('Categories')}: #{categories.size}"
    puts ""

    categories.each do |category, scripts|
      emoji = category_emoji(category)
      puts "#{emoji} #{Format.bold(category.capitalize)}: #{Format.green(scripts.size.to_s)} scripts"
    end

    # Language breakdown
    puts ""
    log_section "By Language"
    langs = metadata.values.group_by { |m| m[:language] }
    langs.sort.each do |lang, metas|
      puts "#{Format.cyan(lang.capitalize)}: #{metas.size}"
    end
  end

  def show_missing_metadata(scripts, metadata)
    missing = scripts.reject { |s| metadata.key?(s) }

    if missing.empty?
      log_success "All #{scripts.size} scripts have metadata headers!"
      return
    end

    log_warning "#{missing.size} scripts missing metadata:"
    puts ""

    missing.each do |script|
      rel_path = script.sub("#{PROJECT_ROOT}/", '')
      puts "  #{Format.yellow('•')} #{rel_path}"
    end

    puts ""
    puts "Add headers in this format:"
    puts Format.dim("  # @category: <category>")
    puts Format.dim("  # @description: <one-line description>")
    puts Format.dim("  # @tags: <tag1, tag2>")
  end

  def validate_metadata(metadata)
    log_info "Validating metadata..."

    errors = []
    warnings = []

    metadata.each do |script_path, meta|
      rel_path = script_path.sub("#{PROJECT_ROOT}/", '')

      # Check required fields
      unless meta[:category]
        errors << "#{rel_path}: Missing @category"
      end

      unless meta[:description]
        warnings << "#{rel_path}: Missing @description"
      end

      # Validate category names
      valid_categories = %w[git media system setup backup dev files data communication]
      if meta[:category] && !valid_categories.include?(meta[:category])
        warnings << "#{rel_path}: Unknown category '#{meta[:category]}'"
      end
    end

    if errors.empty? && warnings.empty?
      log_success "All metadata is valid!"
      return
    end

    if errors.any?
      log_error "Found #{errors.size} errors:"
      errors.each { |e| puts "  #{Format.red('✗')} #{e}" }
    end

    if warnings.any?
      log_warning "Found #{warnings.size} warnings:"
      warnings.each { |w| puts "  #{Format.yellow('⚠')} #{w}" }
    end
  end

  def category_emoji(category)
    {
      'git' => '🐙',
      'media' => '🎬',
      'system' => '⚙️',
      'setup' => '🔧',
      'backup' => '💾',
      'dev' => '🛠️',
      'files' => '📁',
      'data' => '📊',
      'communication' => '💬'
    }[category] || '📦'
  end
end

GenerateCategories.execute if __FILE__ == $0
