#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'
require 'tmpdir'

class SetupPytorchModels
  attr_reader :models_dir, :pytorch_dir, :apple_silicon_dir, :rife_dir

  def initialize
    @zsh_config = File.expand_path('~/.config/zsh')
    @models_dir = File.join(@zsh_config, '.models')
    @pytorch_dir = File.join(@models_dir, 'pytorch')
    @apple_silicon_dir = File.join(@models_dir, 'apple-silicon')
    @rife_dir = File.join(@models_dir, 'rife')

    FileUtils.mkdir_p([@models_dir, @pytorch_dir, @apple_silicon_dir, @rife_dir])
  end

  def script_name
    File.basename($0)
  end

  # Logging functions
  def log_banner(message)
    puts "\n🤖 #{message}"
    puts "=" * 50
  end

  def log_success(message)
    puts "✅ #{message}"
  end

  def log_error(message)
    puts "❌ #{message}"
  end

  def log_info(message)
    puts "ℹ️  #{message}"
  end

  def log_warning(message)
    puts "⚠️  #{message}"
  end

  def log_progress(message)
    puts "🔄 #{message}"
  end

  def log_section(message)
    puts "\n🔧 #{message}"
    puts "-" * 30
  end

  def run
    log_banner("Setting up PyTorch models for Apple Silicon")

    setup_python_environment
    download_models
    convert_to_coreml
    create_config_file

    log_success("PyTorch models setup complete!")
    log_info("PyTorch models: #{@pytorch_dir}")
    log_info("CoreML models: #{@apple_silicon_dir}")
    log_info("RIFE models: #{@rife_dir}")
  end

  private

  def setup_python_environment
  log_section("Setting up Python environment")

  # Create standalone Python environment in models directory
  venv_path = File.join(@models_dir, 'venv')

  if File.directory?(venv_path)
    log_success("Using existing Python environment")
    @python_cmd = File.join(venv_path, 'bin/python')
    @pip_cmd = File.join(venv_path, 'bin/pip')
  else
    log_progress("Creating Python virtual environment...")
    system("python3 -m venv '#{venv_path}'")

    if File.directory?(venv_path)
      log_success("Created Python virtual environment")
      @python_cmd = File.join(venv_path, 'bin/python')
      @pip_cmd = File.join(venv_path, 'bin/pip')
    else
      log_error("Failed to create Python virtual environment")
      exit(1)
    end
  end

  # Install required packages
  install_dependencies
end

def install_dependencies
  log_progress("Installing Python dependencies...")

  # Get requirements file path - check in scripts directory first
  requirements_path = File.join(File.dirname(__FILE__), 'requirements.txt')

  if File.exist?(requirements_path)
    log_info("Installing from requirements file: #{requirements_path}")
    system("#{@pip_cmd} install -r '#{requirements_path}'")
  else
    log_error("Requirements file not found: #{requirements_path}")
    exit(1)
  end

  # Verify critical installations
  dependencies_to_check = [
    { name: 'CoreML tools', import: 'coremltools', message: 'CoreML tools available' },
    { name: 'OpenCV', import: 'cv2', message: 'OpenCV available' },
    { name: 'MoviePy', import: 'moviepy', message: 'MoviePy available for video processing' },
    { name: 'tqdm', import: 'tqdm', message: 'tqdm available for progress bars' }
  ]

  all_good = true
  dependencies_to_check.each do |dep|
    result = system("#{@python_cmd} -c \"import #{dep[:import]}; print('#{dep[:message]}')\"")
    if result
      log_success("✅ #{dep[:name]} installed")
    else
      log_error("❌ #{dep[:name]} failed to install")
      all_good = false
    end
  end

  if all_good
    log_success("All dependencies installed successfully")
  else
    log_error("Some dependencies failed to install")
    log_info("💡 Video processing may not work without moviepy")
    exit(1)
  end
end

  def download_models
    log_section("Downloading PyTorch models")

    # Load model definitions from JSON file
    models_file = File.join(File.dirname(__FILE__), 'pytorch-models.json')

    if !File.exist?(models_file)
      log_error("Models configuration file not found: #{models_file}")
      return
    end

    begin
      models_data = JSON.parse(File.read(models_file))
      log_info("Loaded #{models_data.size} model definitions from #{models_file}")
    rescue JSON::ParserError => e
      log_error("Failed to parse models JSON file: #{e.message}")
      return
    end

    models_data.each do |model_name, config|
      download_model(model_name, config)
    end
  end

  def download_model(name, config)
    # Determine target directory based on model type
    if name.start_with?('RIFE')
      target_dir = @rife_dir
      log_info("RIFE model detected, placing in rife/ directory")
    else
      target_dir = @pytorch_dir
    end

    model_path = File.join(target_dir, config['filename'])

    if File.exist?(model_path) && File.size(model_path) > 1_000_000
      log_success("#{name} already exists (#{format_file_size(File.size(model_path))})")
      return
    end

    # Check if URL is provided (some models require manual download)
    if config['url'].nil? || config['url'].empty?
      log_warning("#{name} requires manual download")
      log_info("   • Download from: https://drive.google.com/file/d/1APIzVeI-4ZZCEuIRE1m6WYfSCaOsi_7_/view?usp=sharing")
      log_info("   • Place in: #{target_dir}")
      return
    end

    log_progress("Downloading #{name}...")

    begin
      # Use curl with redirect following for better download handling
      cmd = [
        'curl', '-L', '--fail', '--silent', '--show-error',
        '-o', model_path,
        config['url']
      ].join(' ')

      if system(cmd)
        # Verify file size
        if File.size(model_path) > 1_000_000
          log_success("Downloaded #{name} (#{format_file_size(File.size(model_path))})")
        else
          log_error("Downloaded file too small, removing...")
          File.delete(model_path)
        end
      else
        log_error("Failed to download #{name}")
      end
    rescue => e
      log_error("Error downloading #{name}: #{e.message}")
    end
  end

  def convert_to_coreml
    log_section("Converting models to CoreML")

    # Get Python conversion script path - resolve from zshrc directory
    conversion_script = File.join(File.dirname(__FILE__), '..', 'bin', 'python-cli', 'convert_to_coreml.py')
    conversion_script = File.expand_path(conversion_script)

    log_info("Looking for conversion script at: #{conversion_script}")

    if !File.exist?(conversion_script)
      log_error("Conversion script not found: #{conversion_script}")
      return
    end

    log_success("Found conversion script")

    # Convert each model
    Dir.glob(File.join(@pytorch_dir, '*.pth')).each do |model_path|
      model_name = File.basename(model_path, '.pth')
      convert_model_to_coreml(model_name, model_path, conversion_script)
    end
  end

  
  def convert_model_to_coreml(name, pytorch_path, conversion_script)
    # Check for existing MLPackage (more complete than just .mlmodel)
    mlpackage_path = File.join(@apple_silicon_dir, "#{name}.mlpackage")
    coreml_path = File.join(@apple_silicon_dir, "#{name}.mlmodel")

    if File.exist?(mlpackage_path)
      log_success("#{name} CoreML MLPackage already exists")
      return
    end

    log_progress("Converting #{name} to CoreML...")

    begin
      # Use the copied conversion script with correct argument order
      cmd = [
        @python_cmd,
        conversion_script,
        pytorch_path,
        name,
        "4"  # scale factor as positional argument
      ].join(' ')

      if system("cd #{@apple_silicon_dir} && #{cmd}")
        log_success("Converted #{name} to CoreML")
      else
        log_warning("Failed to convert #{name} to CoreML")
      end
    rescue => e
      log_error("Error converting #{name}: #{e.message}")
    end
  end

  def create_config_file
    log_section("Creating configuration")

    config = {
      'models' => {},
      'default_model' => 'RealESRGAN_x4plus',
      'paths' => {
        'pytorch' => @pytorch_dir,
        'apple_silicon' => @apple_silicon_dir
      },
      'updated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
    }

    # Add available models - check both direct .mlmodel files and .mlpackage directories
    models_found = []

    # Check for .mlmodel files
    Dir.glob(File.join(@apple_silicon_dir, '**', '*.mlmodel')).each do |model_path|
      model_name = File.basename(model_path, '.mlmodel')
      models_found << model_name
      config['models'][model_name] = {
        'coreml_path' => model_path,
        'pytorch_path' => File.join(@pytorch_dir, "#{model_name}.pth")
      }
    end

    # Check for .mlpackage directories
    Dir.glob(File.join(@apple_silicon_dir, '**', '*.mlpackage')).each do |package_path|
      model_name = File.basename(package_path, '.mlpackage')
      next if models_found.include?(model_name) # Skip if already found as .mlmodel

      mlmodel_path = File.join(package_path, 'Data', 'com.apple.CoreML', 'model.mlmodel')
      if File.exist?(mlmodel_path)
        models_found << model_name
        config['models'][model_name] = {
          'coreml_path' => mlmodel_path,
          'pytorch_path' => File.join(@pytorch_dir, "#{model_name}.pth")
        }
      end
    end

    config_file = File.join(@models_dir, 'config.json')
    File.write(config_file, JSON.pretty_generate(config))

    if models_found.empty?
      log_warning("No models found for configuration")
    else
      log_success("Configuration saved to #{config_file}")
      log_info("Available models: #{models_found.join(', ')}")
    end
  end

  def format_file_size(bytes)
    units = ['B', 'KB', 'MB', 'GB']
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)}#{units[unit_index]}"
  end
end

if __FILE__ == $0
  SetupPytorchModels.new.run
end