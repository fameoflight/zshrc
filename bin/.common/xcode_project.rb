# frozen_string_literal: true

require 'pathname'
require 'json'

# Common module for Xcode project management
# Provides shared functionality for managing Xcode project files
module XcodeProject

  module_function

  # Auto-detect Xcode project in current directory
  def detect_project
    Dir.glob('*.xcodeproj').first&.then do |project_path|
      {
        name: File.basename(project_path, '.xcodeproj'),
        path: project_path,
        pbxproj: File.join(project_path, 'project.pbxproj')
      }
    end
  end

  # Get current project info or raise error
  def current_project
    @current_project ||= detect_project
    raise "No Xcode project found in current directory" unless @current_project
    @current_project
  end

  # File type mappings for Xcode
  FILE_TYPES = {
    '.swift' => 'sourcecode.swift',
    '.storyboard' => 'file.storyboard',
    '.plist' => 'text.plist.xml',
    '.md' => 'text.markdown',
    '.json' => 'text.json',
    '.png' => 'image.png',
    '.jpg' => 'image.jpeg',
    '.jpeg' => 'image.jpeg',
    '.pdf' => 'image.pdf',
    '.mlmodel' => 'file.mlmodel',
    '.xcassets' => 'folder.assetcatalog',
    '.entitlements' => 'text.plist.entitlements'
  }.freeze

  # Generic group mappings for any Xcode project structure
  GROUP_MAPPINGS = {
    'app' => {
      'group_name' => 'App',
      'path_match' => ['App', 'AppDelegate', 'SceneDelegate', '.entitlements', 'main.swift'],
      'build_phase' => 'Sources',
      'description' => 'App-level files (main app, delegates, entitlements)'
    },
    'ui' => {
      'group_name' => 'UI',
      'path_match' => ['UI/', 'View', 'ContentView', 'ViewController', 'Storyboard'],
      'build_phase' => 'Sources',
      'description' => 'User interface components and views'
    },
    'views' => {
      'group_name' => 'Views',
      'path_match' => ['Views/', 'View', 'SwiftUI'],
      'build_phase' => 'Sources',
      'description' => 'SwiftUI views and view components'
    },
    'controllers' => {
      'group_name' => 'Controllers',
      'path_match' => ['Controllers/', 'Controller', 'ViewController'],
      'build_phase' => 'Sources',
      'description' => 'View controllers and navigation'
    },
    'utils' => {
      'group_name' => 'Utils',
      'path_match' => ['Utils/', 'Extension', 'Helper'],
      'build_phase' => 'Sources',
      'description' => 'General utilities and extensions'
    },
    'models' => {
      'group_name' => 'Models',
      'path_match' => ['Models/', 'Model', 'Item.swift', '.mlmodel'],
      'build_phase' => 'Sources',
      'description' => 'Data models and Core ML models'
    },
    'resources' => {
      'group_name' => 'Resources',
      'path_match' => ['Assets.xcassets', '.png', '.jpg', '.pdf', 'Info.plist'],
      'build_phase' => 'Resources',
      'description' => 'Assets, storyboards, plists, images'
    }
  }.freeze

  # Check if we're in an Xcode project directory
  def project_exists?
    !detect_project.nil?
  end

  # Get project file content
  def read_project_file
    project_info = current_project
    File.read(project_info[:pbxproj])
  rescue => e
    raise "Error reading project file: #{e.message}"
  end

  # List all available categories
  def list_categories
    GROUP_MAPPINGS.map do |category, info|
      {
        name: category,
        group_name: info['group_name'],
        description: info['description'],
        build_phase: info['build_phase']
      }
    end
  end

  # Infer category from file path using project-specific logic
  def infer_category_from_path(file_path)
    path_str = file_path.to_s.downcase
    file_name = Pathname.new(file_path).basename.to_s

    # Check each category's path patterns
    GROUP_MAPPINGS.each do |category, info|
      info['path_match'].each do |pattern|
        if path_str.include?(pattern.downcase) || file_name.downcase.include?(pattern.downcase)
          return category
        end
      end
    end

    # Default fallback based on file extension
    ext = Pathname.new(file_path).extname.downcase
    case ext
    when '.png', '.jpg', '.jpeg', '.pdf', '.plist', '.xcassets'
      'resources'
    when '.swift'
      'app' # Default for Swift files
    else
      'utils' # Default fallback
    end
  end

  # Determine Xcode file type based on extension
  def get_file_type(file_path)
    ext = Pathname.new(file_path).extname.downcase
    FILE_TYPES[ext] || 'text'
  end

  # Determine build phase based on category and file type
  def get_build_phase(file_path, category)
    return GROUP_MAPPINGS[category]['build_phase'] if GROUP_MAPPINGS.key?(category)

    # Fallback based on file extension
    ext = Pathname.new(file_path).extname.downcase
    case ext
    when '.storyboard', '.plist', '.png', '.jpg', '.jpeg', '.pdf', '.mlmodel', '.xcassets'
      'Resources'
    else
      'Sources'
    end
  end

  # Check if file is a resource that needs special handling
  def is_resource_file?(file_path)
    ext = Pathname.new(file_path).extname.downcase
    resource_extensions = ['.png', '.jpg', '.jpeg', '.pdf', '.plist', '.xcassets', '.storyboard', '.xib', '.strings', '.mlmodel']
    resource_extensions.include?(ext)
  end

  # Check if file is an asset catalog
  def is_asset_catalog?(file_path)
    Pathname.new(file_path).extname.downcase == '.xcassets'
  end

  # Get special handling instructions for resource files
  def get_resource_handling_info(file_path, category)
    ext = Pathname.new(file_path).extname.downcase
    file_name = Pathname.new(file_path).basename.to_s
    project_name = current_project[:name]

    case ext
    when '.xcassets'
      {
        type: :asset_catalog,
        target_location: "#{project_name}/",
        instructions: [
          "Asset catalogs (.xcassets) are automatically managed by Xcode",
          "Place the entire .xcassets folder in the project root: #{project_name}/",
          "Xcode will automatically detect and include it in the project",
          "No manual project file editing required"
        ]
      }
    when '.png', '.jpg', '.jpeg', '.pdf'
      {
        type: :image_resource,
        target_location: "#{project_name}/Resources/Images/",
        instructions: [
          "Image files can be added to Assets.xcassets or as loose files",
          "For Assets.xcassets: Add to an existing .xcassets bundle",
          "For loose files: Place in #{project_name}/Resources/Images/",
          "Xcode will automatically detect and add to Resources build phase"
        ]
      }
    when '.plist'
      if file_name == 'Info.plist'
        {
          type: :info_plist,
          target_location: "#{project_name}/",
          instructions: [
            "Info.plist is a critical app configuration file",
            "Place directly in project root: #{project_name}/Info.plist",
            "Usually already exists - consider merging changes instead of replacing",
            "Xcode automatically includes this in the app bundle"
          ]
        }
      else
        {
          type: :plist_resource,
          target_location: "#{project_name}/Resources/",
          instructions: [
            "Property list files are configuration resources",
            "Place in: #{project_name}/Resources/",
            "Will be added to Resources build phase automatically",
            "Can be accessed via Bundle.main.path(forResource:ofType:)"
          ]
        }
      end
    when '.storyboard', '.xib'
      {
        type: :interface_builder,
        target_location: "#{project_name}/UI/",
        instructions: [
          "Interface Builder files define UI layouts",
          "Place in: #{project_name}/UI/ or #{project_name}/Views/",
          "Automatically added to Resources build phase",
          "Can be referenced in code via UIStoryboard or loadNibNamed"
        ]
      }
    when '.strings'
      {
        type: :localization,
        target_location: "#{project_name}/Resources/Localizable/",
        instructions: [
          "Strings files provide localized text",
          "Place in: #{project_name}/Resources/Localizable/",
          "Consider creating language-specific folders (en.lproj, es.lproj, etc.)",
          "Xcode will add to Resources build phase automatically"
        ]
      }
    when '.mlmodel'
      {
        type: :core_ml_model,
        target_location: "#{project_name}/Models/ML/",
        instructions: [
          "Core ML models for machine learning",
          "Place in: #{project_name}/Models/ML/",
          "Xcode automatically generates Swift classes for the model",
          "Added to Resources build phase and accessible via Bundle"
        ]
      }
    else
      {
        type: :generic_resource,
        target_location: "#{project_name}/Resources/",
        instructions: [
          "Generic resource file",
          "Place in: #{project_name}/Resources/",
          "Will be added to Resources build phase",
          "Accessible via Bundle.main.path(forResource:ofType:)"
        ]
      }
    end
  end

  # Get target directory for a category
  def get_target_directory(category)
    project_name = current_project[:name]

    case category
    when 'ui'
      "#{project_name}/UI"
    when 'views'
      "#{project_name}/Views"
    when 'controllers'
      "#{project_name}/Controllers"
    when 'utils'
      "#{project_name}/Utils"
    when 'models'
      "#{project_name}/Models"
    when 'resources'
      project_name
    else
      project_name
    end
  end

  # Check if a file exists in the project
  def file_exists_in_project?(file_name, content = nil)
    content ||= read_project_file
    return false unless content

    # Check for file reference in PBXFileSystemSynchronizedRootGroup or PBXFileReference
    file_pattern = Regexp.escape(file_name)
    content.match?(/\/#{file_pattern}/) || content.match?(/"#{file_pattern}"/)
  end

  # Get project root groups from project file
  def get_root_groups(content = nil)
    content ||= read_project_file
    return [] unless content

    # Extract file references from the modern Xcode project format
    # Look for PBXFileSystemSynchronizedRootGroup entries
    content.scan(/(\w+) \/\* (.+) \*\/ = \{\s*isa = PBXFileSystemSynchronizedRootGroup;.*?path = "(.+)";/m).map do |group_id, group_name, path|
      {
        id: group_id,
        name: group_name,
        path: path
      }
    end
  end

  # List files in a directory with metadata
  def list_directory_files(directory_path)
    return [] unless File.exist?(directory_path)
    return [] unless File.directory?(directory_path)

    Dir.entries(directory_path).reject { |f| f.start_with?('.') }.map do |file|
      file_path = File.join(directory_path, file)
      {
        name: file,
        path: file_path,
        type: File.directory?(file_path) ? :directory : :file,
        size: File.directory?(file_path) ? nil : File.size(file_path)
      }
    end.sort_by { |f| [f[:type] == :directory ? 0 : 1, f[:name]] }
  rescue => e
    raise "Error listing files in #{directory_path}: #{e.message}"
  end

  # Validate category
  def valid_category?(category)
    GROUP_MAPPINGS.key?(category)
  end

  # Get category info
  def get_category_info(category)
    GROUP_MAPPINGS[category]
  end

  # Find files matching a name in project directories
  def find_files_in_project(file_name)
    found_files = []
    project_name = current_project[:name]

    return found_files unless File.exist?(project_name)

    Dir.glob("#{project_name}/**/#{file_name}").each do |file_path|
      found_files << {
        path: file_path,
        exists: File.exist?(file_path),
        size: File.exist?(file_path) ? File.size(file_path) : nil
      }
    end

    found_files
  end

  # Ensure target directory exists
  def ensure_directory_exists(directory_path)
    return true if File.exist?(directory_path)

    FileUtils.mkdir_p(directory_path)
    true
  rescue => e
    raise "Error creating directory #{directory_path}: #{e.message}"
  end

  # Get project summary
  def project_summary
    return nil unless project_exists?

    project_info = current_project
    root_groups = get_root_groups
    {
      project_name: project_info[:name],
      project_file: project_info[:pbxproj],
      project_path: project_info[:path],
      root_groups_count: root_groups.size,
      categories_available: GROUP_MAPPINGS.keys.size
    }
  end
end