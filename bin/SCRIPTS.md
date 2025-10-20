# Scripts System Documentation

This document provides comprehensive documentation for the Ruby-based scripts system in the ZSH configuration repository.

⚠️ **IMPORTANT: ALWAYS read this documentation BEFORE writing any new scripts or commands** to understand:
- Available base classes and utilities
- Existing services and helpers
- Common patterns and best practices
- How to avoid duplicating existing functionality

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Base Classes](#base-classes)
3. [Core Utilities (Stateless)](#core-utilities-stateless)
4. [Services (Stateful)](#services-stateful)
5. [Utils (Helper Modules)](#utils-helper-modules)
6. [Concerns (Mixins)](#concerns-mixins)
7. [Development Patterns](#development-patterns)
8. [Usage Examples](#usage-examples)
9. [Testing and Quality](#testing-and-quality)

## Architecture Overview

The scripts system follows a **modular CLI design** with separate language-specific directories and shared utilities:

- **Ruby CLI** - Ruby-based scripts with advanced functionality and interactive features
- **Python CLI** - Python-based scripts focused on AI/ML and data processing
- **Rust CLI** - Rust-based high-performance utilities
- **.common/** - Shared utilities, base classes, and services available to all CLI systems

### Directory Structure

```
bin/
├── ruby-cli/
│   ├── bin/                       # Ruby executable scripts
│   │   ├── largest-files.rb       # Find largest files respecting .gitignore
│   │   ├── game-mode.rb           # System optimization for gaming
│   │   ├── gmail-inbox.rb         # Gmail management and automation
│   │   ├── youtube-transcript-chat.rb # YouTube transcript processing
│   │   └── ... (other Ruby scripts)
│   ├── scripts.zsh                # ZSH wrapper functions for Ruby scripts
│   └── Gemfile                    # Ruby dependencies
├── python-cli/
│   ├── bin/                       # Python executable scripts
│   ├── scripts.zsh                # ZSH wrapper functions for Python scripts
│   └── requirements.txt           # Python dependencies
├── rust-cli/
│   ├── src/                       # Rust source code
│   ├── target/                    # Compiled binaries
│   └── scripts.zsh                # ZSH wrapper functions for Rust scripts
├── .common/                       # Shared utilities and services
│   ├── Base Classes
│   ├── script_base.rb              # Universal script foundation
│   ├── interactive_script_base.rb  # Interactive menu systems
│   ├── git_commit_script_base.rb   # Git workflow automation
│   └── file_merger_base.rb         # File merging operations
│
├── Core Utilities (Stateless)
│   ├── logger.rb                   # Centralized logging system
│   ├── system.rb                   # System command execution
│   ├── format.rb                   # Text formatting utilities
│   ├── view.rb                     # UI display utilities
│   └── database.rb                 # Database operations
│
├── Gmail Integration
│   ├── gmail_service.rb            # Gmail API integration
│   ├── gmail_database.rb           # Gmail data persistence
│   └── gmail_archive_handler.rb    # Email archiving
│
├── services/ (Stateful Classes)
│   ├── base_service.rb             # Service foundation class
│   ├── settings_service.rb         # Settings persistence
│   ├── interactive_menu_service.rb # Menu UI systems
│   ├── llm_service.rb             # AI/LLM integrations
│   ├── unified_llm_service.rb     # Multi-provider LLM
│   ├── browser_service.rb         # Browser automation
│   ├── file_cache_service.rb      # File caching system
│   ├── markdown_renderer.rb       # Markdown processing
│   ├── text_chunking_service.rb   # Text processing
│   ├── video_info_service.rb      # Video metadata
│   ├── media_transcript_service.rb # Media transcription
│   ├── configuration_display_service.rb # Configuration display
│   ├── conversation_service.rb     # Chat and conversation management
│   ├── element_analyzer.rb         # Web element analysis
│   ├── element_detector_service.rb # DOM element detection
│   ├── epub_generator.rb           # EPUB e-book generation
│   ├── image_processor.rb          # Image processing
│   ├── interactive_chat_service.rb # Interactive chat interfaces
│   ├── llm_chain_processor.rb      # LLM request chaining
│   ├── lm_studio_service.rb        # LM Studio AI integration
│   ├── ollama_service.rb           # Ollama AI integration
│   ├── page_fetcher.rb             # Web page fetching
│   ├── summary_generation_service.rb # Content summarization
│   ├── transcript_parsing_service.rb # Transcript processing
│   ├── url_collector.rb            # URL collection
│   └── url_validation_service.rb   # URL validation
│
├── utils/ (Helper Modules)
│   ├── error_utils.rb             # Error handling patterns
│   ├── progress_utils.rb          # Progress indicators
│   ├── time_utils.rb              # Time calculations
│   └── interactive_settings_utils.rb # Settings UI helpers
│
└── concerns/ (Mixins)
    ├── macos_utils.rb             # macOS system integration
    ├── tcc_utils.rb               # macOS privacy permissions
    ├── process_utils.rb           # Process management
    ├── cacheable.rb               # Caching behavior
    ├── account_manager.rb         # Account management
    ├── icloud_storage.rb          # iCloud integration
    ├── article_detector.rb        # Article content detection
    └── gmail_view.rb              # Gmail UI display helpers
```

## Base Classes

### ScriptBase (`script_base.rb`)

**Purpose**: Universal foundation class for all Ruby scripts in the system.

**Key Features**:
- Standardized command-line argument parsing with `--help`, `--verbose`, `--debug`, `--dry-run`, `--force`
- Automatic bundler setup with fallback gem installation
- Settings persistence and loading via `SettingsService`
- Session logging with timestamps and performance tracking
- Interactive menu integration via `InteractiveMenuService`
- Comprehensive error handling with graceful exits
- Platform-specific directory helpers (Library, Applications, Launch dirs)

**Usage Pattern**:
```ruby
#!/usr/bin/env ruby
require_relative '.common/script_base'

class MyScript < ScriptBase
  def script_emoji; '🔧'; end
  def script_title; 'My Custom Tool'; end
  def script_description; 'Does something useful'; end
  def script_arguments; '[OPTIONS] <file>'; end

  def validate!
    # Custom validation logic
    super
  end

  def add_custom_options(opts)
    opts.on('-c', '--custom', 'Custom option') do
      @options[:custom] = true
    end
  end

  def run
    log_banner(script_title)
    # Main script logic here
    show_completion(script_title)
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} file.txt    # Process file"
    puts "  #{script_name} --verbose   # Verbose mode"
  end
end

MyScript.execute if __FILE__ == $0
```

**Available Methods**:
- `dry_run?`, `force?`, `verbose?`, `debug?` - Option checking
- `confirm_action(message)` - Interactive confirmation with force override
- `execute_cmd(command, description:)` - System command execution
- `remove_file(path)`, `remove_files(paths)` - File operations with logging
- `find_in_directories(dirs, pattern)` - File searching
- `show_completion(name)` - Completion message with restart notice

### InteractiveScriptBase (`interactive_script_base.rb`)

**Purpose**: Foundation for scripts that need menu-driven interactive interfaces.

**Key Features**:
- Built-in TTY::Prompt integration
- Menu system with continue/exit flow
- Setup and cleanup lifecycle hooks
- Header display and user interaction patterns

**Usage Pattern**:
```ruby
class MyInteractiveScript < InteractiveScriptBase
  def menu_options
    {
      'process' => '📄 Process Files',
      'settings' => '⚙️  Settings',
      'exit' => '🚪 Exit'
    }
  end

  def handle_menu_choice(choice)
    case choice
    when 'process'
      process_files
    when 'settings'
      show_settings_menu
    end
  end

  def setup_interactive_mode
    log_info("Starting interactive mode...")
  end
end
```

### GitCommitScriptBase (`git_commit_script_base.rb`)

**Purpose**: Specialized base for scripts that automate git commit workflows.

**Key Features**:
- Git repository detection and validation
- Automated staging and commit message generation
- Branch management and push operations
- Conflict resolution helpers

## Core Utilities (Stateless)

### Logger (`logger.rb`)

**Purpose**: Centralized logging system with consistent emoji indicators and colors.

**Key Features**:
- Color-coded output using Pastel gem
- Emoji indicators for different message types
- Automatic stderr routing for errors
- Debug mode support via `DEBUG=1` environment variable
- Platform-specific logging methods

**Available Functions**:
```ruby
# Core logging (global functions available everywhere)
log_info("Processing request")        # ℹ️  Blue
log_success("Operation completed")    # ✅ Green
log_warning("Potential issue")        # ⚠️  Yellow
log_error("Critical error")          # ❌ Red (stderr)
log_progress("Working on task")       # 🔄 Cyan
log_section("Section Header")        # 🔧 Magenta
log_debug("Debug info")              # 🐛 Dim (only if DEBUG=1)

# File operations
log_file_created("/path/to/file")    # 📄 Green
log_file_updated("/path/to/file")    # 📝 Blue
log_file_backed_up("/path/to/file")  # 💾 Cyan

# System operations
log_install("package-name")          # 📦 Green
log_clean("cache files")             # 🧹 Cyan
log_update("system packages")        # 🔄 Blue

# Platform-specific
log_brew("Installing packages")      # 🍺 Yellow
log_git("Committing changes")        # 🐙 Magenta
log_python("Running script")         # 🐍 Blue
log_ruby("Installing gems")          # 💎 Red
log_macos("System config")           # 🍎 Blue
log_linux("Package install")        # 🐧 Blue

# Utility
log_separator                        # Print separator line
log_complete("Process name")         # 🎉 Celebration
log_banner("Title")                  # Header with separators
```

**Class Methods** (when using Logger class directly):
```ruby
logger = Logger.new
logger.disable_colors!  # Disable color output
logger.enable_colors!   # Re-enable color output
logger.verbose?         # Check if verbose mode enabled
```

### System (`system.rb`)

**Purpose**: System command execution and platform utilities.

**Key Features**:
- Safe command execution with proper error handling
- Platform detection (macOS/Linux)
- Process management and killing
- File finding across directories
- Homebrew and Mac App Store integration
- Interactive prompt utilities

**Core Methods**:
```ruby
# Command execution
result = System.execute("ls -la", description: "List files", dry_run: false, verbose: false)
success = System.execute?("which brew", description: "Check Homebrew")

# Command availability
System.command?("brew")  # Check if command exists in PATH

# Process management
System.kill_processes("Chrome", signal: 'TERM', verbose: true)

# File operations
files = System.find_files(["/Applications", "~/Applications"], "Chrome", type: 'f')

# Platform detection
System.macos?       # true on macOS
System.linux?       # true on Linux
System.admin?       # true if running as root/admin
System.current_user # Current username
System.home_dir     # Home directory path

# Homebrew utilities
System::Homebrew.installed?           # Check if Homebrew available
System::Homebrew.list_formulae        # List installed formulae
System::Homebrew.list_casks           # List installed casks
System::Homebrew.running_services     # List running services
System::Homebrew.stop_service("nginx")
System::Homebrew.uninstall_formula("wget")
System::Homebrew.uninstall_cask("chrome")

# Mac App Store utilities
System::MacAppStore.installed?        # Check if 'mas' available
System::MacAppStore.list_installed    # List installed apps
System::MacAppStore.uninstall("12345") # Uninstall by app ID
```

**Interactive Prompts**:
```ruby
# Global prompt functions
confirmed = confirm_action("Proceed with operation?", force: false)
choice = prompt_select("Choose option:", ["Option 1", "Option 2", "Exit"])
choices = prompt_multiselect("Select multiple:", ["A", "B", "C"])
```

### Format (`format.rb`)

**Purpose**: Text formatting and display utilities.

**Key Features**:
- Consistent text formatting across scripts
- Table generation and alignment
- Text wrapping and truncation
- Size and duration formatting

### View (`view.rb`)

**Purpose**: UI display and presentation utilities.

**Key Features**:
- Consistent UI layouts and headers
- Progress indicators and status displays
- Menu formatting and presentation
- Terminal width detection and responsive layout

### Database (`database.rb`)

**Purpose**: Database operations and management utilities.

**Key Features**:
- SQLite database initialization and management
- Schema migrations and versioning
- Query execution with error handling
- Connection pooling and cleanup

### FileFilter (`file_filter.rb`)

**Purpose**: Common file filtering utilities for dimensions, extensions, and custom criteria.

**Key Features**:
- Filter files by extensions (case-insensitive)
- Filter images by dimensions with min/max constraints
- Chain multiple filters together
- Handle filtering errors gracefully
- Return structured results with accepted/rejected files

**Usage Pattern**:
```ruby
require_relative '.common/file_filter'

# Filter by extensions
image_files = FileFilter.filter_by_extensions(all_files, %w[.jpg .jpeg .png .webp])

# Filter images by dimensions
filtered = FileFilter.filter_images_by_dimensions(
  image_files,
  min_width: 200,
  min_height: 200,
  max_width: 8000,
  max_height: 6000
)
# => { accepted: [...], rejected: [...], errors: [...] }

# Chain multiple filters
result = FileFilter.filter_chain(
  files,
  { type: :extensions, extensions: %w[.jpg .png] },
  { type: :dimensions, min_width: 1024, min_height: 768 },
  { type: :custom, criteria: ->(path) { !path.include?('temp') } }
)
```

### WorkflowProcessor (`workflow_processor.rb`)

**Purpose**: Multi-pass workflow processing with intelligent caching and progress reporting.

**Key Features**:
- Process files through multiple passes with different operations
- Automatic caching for each pass with FileProcessingTracker integration
- Filter files between passes
- Progress reporting that accounts for cached vs new files
- Error handling and recovery
- Workflow summary and statistics

**Usage Pattern**:
```ruby
require_relative '.common/workflow_processor'

processor = WorkflowProcessor.new(
  tracker: FileProcessingTracker.new,
  logger: self
)

passes = [
  {
    name: "Human Detection",
    operation_name: "detect_humans",
    enable_cache: true,
    cache_description: "human detection results",
    show_progress: true,
    filter_proc: ->(path) { image_is_large_enough?(path) },
    process_proc: ->(path) { detect_humans_in_image(path) },
    filter_remaining: true
  },
  {
    name: "Resolution Analysis",
    operation_name: "check_resolution",
    enable_cache: true,
    process_proc: ->(path) { analyze_image_resolution(path) }
  }
]

result = processor.process_workflow(image_files, passes)
```

### ImageWorkflow (`image_workflow.rb`)

**Purpose**: Specialized workflow processor for common image processing operations.

**Key Features**:
- Pre-built image analysis workflows
- Human detection integration
- Resolution analysis and upscaling
- Image dimension filtering
- Image-specific statistics and reporting
- Configurable processing pipelines

**Usage Pattern**:
```ruby
require_relative '.common/image_workflow'

# Create image workflow processor
workflow = ImageWorkflow.new(tracker: FileProcessingTracker.new)

# Process images with standard workflow
result = workflow.process_images(
  image_files,
  human_detection: true,
  human_threshold: 60.0,
  upscaling: true,
  min_resolution: 3840,
  min_height: 2160,
  dry_run: false
)

# Or build custom workflow
config = workflow.build_image_workflow_config(
  human_detection: true,
  min_width: 200,
  min_height: 200,
  upscaling: true
)
result = workflow.process_workflow(image_files, config)
```

### FileProcessingTracker (`file_processing_tracker.rb`)

**Purpose**: Track file processing status across multiple runs to prevent duplicate processing.

**Key Features**:
- SQLite-based file processing state tracking
- Track files by path, hash, and processing status
- Prevent reprocessing of already completed files
- Resume interrupted batch operations
- Track processing errors and retry counts
- Analyze files to separate cached vs new processing needs

**Usage Pattern**:
```ruby
require_relative '.common/file_processing_tracker'

tracker = FileProcessingTracker.new(db_path: 'my_script.db')

# Mark file as being processed
tracker.mark_processing(file_path)

# Mark file as completed
tracker.mark_completed(file_path)

# Mark file as failed with error
tracker.mark_failed(file_path, error_message)

# Check if file needs processing
if tracker.needs_processing?(file_path)
  process_file(file_path)
end

# Analyze multiple files to separate cached from new processing
# Returns: { cached: [...], needs_processing: [...], total: N }
analysis = tracker.analyze_files(file_paths, 'detect_humans', params: { threshold: 60.0 })
puts "Using cached results for #{analysis[:cached].length} files"
puts "Processing #{analysis[:needs_processing].length} new files"

# Or use the convenience methods for reporting
summary = tracker.get_processing_summary(file_paths, 'detect_humans', params: { threshold: 60.0 })
tracker.print_processing_summary(summary, "human detection results")

# Get all pending files
pending = tracker.pending_files

# Get statistics
stats = tracker.stats
# => { total: 100, pending: 20, processing: 5, completed: 70, failed: 5 }
```

**Progress Tracking Best Practices**:
For scripts that process many files with caching support, use the FileProcessingTracker's built-in reporting methods:

```ruby
# Before processing, analyze and report file status
file_paths = Dir.glob('*.jpg')
operation_params = { threshold: 70.0 }

# Get processing summary and print standardized report
summary = tracker.get_processing_summary(file_paths, 'detect_objects', params: operation_params)
tracker.print_processing_summary(summary, "object detection results")

# Process only the files that actually need work
if summary[:new_files] > 0
  analysis = tracker.analyze_files(file_paths, 'detect_objects',
                                  params: operation_params,
                                  show_progress: true)

  process_in_parallel(analysis[:needs_processing]) do |file|
    # Process file
  end
end
```

**Standardized Output Format**:
The `print_processing_summary()` method provides consistent, user-friendly output:
- With cache: `📋 Using cached object detection results for 823 files` and `🔍 Will analyze 176 new files`
- Without cache: `🔍 Will analyze 999 files`

### ImageUtils (`image_utils.rb`)

**Purpose**: Image manipulation and information utilities using ChunkyPNG.

**Key Features**:
- PNG image reading and writing
- Image dimensions and metadata
- Pixel manipulation
- Color analysis
- Alpha channel handling

**Usage Pattern**:
```ruby
require_relative '.common/image_utils'

# Read image dimensions
width, height = ImageUtils.dimensions(image_path)

# Check if image has transparency
has_alpha = ImageUtils.has_alpha?(image_path)

# Get dominant colors
colors = ImageUtils.dominant_colors(image_path, count: 5)

# Resize image
ImageUtils.resize(image_path, output_path, width: 800, height: 600)
```

### XcodeProject (`xcode_project.rb`)

**Purpose**: Xcode project file (.xcodeproj) manipulation and management.

**Key Features**:
- Parse and modify Xcode project files
- Add/remove files and groups
- Manage build phases and targets
- Update project settings
- Handle file references and build configurations

**Usage Pattern**:
```ruby
require_relative '.common/xcode_project'

project = XcodeProject.new('MyApp.xcodeproj')

# Add file to project
project.add_file('Source/NewFile.swift', target: 'MyApp')

# Create group
project.create_group('Features/NewFeature')

# Get all source files
sources = project.source_files

# Save changes
project.save
```

## Services (Stateful)

### BaseService (`services/base_service.rb`)

**Purpose**: Foundation class for all stateful services.

**Key Features**:
- Logger integration with optional debug mode
- Consistent initialization patterns
- Error handling integration via ErrorUtils

**Usage Pattern**:
```ruby
class MyService < BaseService
  def initialize(options = {})
    super(options)  # Sets up @logger and @debug
    @custom_state = options[:custom_state]
  end

  def perform_operation
    log_info("Starting operation")
    # Service logic here
    log_success("Operation completed")
  end

  private

  def some_helper
    log_debug("Helper method called") if debug_enabled?
  end
end

# Usage
service = MyService.new(logger: script_logger, debug: true)
service.perform_operation
```

### SettingsService (`services/settings_service.rb`)

**Purpose**: Manages script settings persistence and loading.

**Key Features**:
- JSON-based settings storage in `~/.config/zsh/settings/`
- Automatic filtering of persistent vs. transient settings
- Settings validation and error recovery
- Metadata tracking (timestamps, script versions)

**Usage Pattern**:
```ruby
# Automatic integration via ScriptBase
class MyScript < ScriptBase
  def run
    # Settings automatically loaded into @options during initialization
    puts "Current setting: #{get_setting(:my_option, 'default_value')}"

    # Update a setting
    set_setting(:my_option, 'new_value')

    # Save all current options as persistent settings
    save_current_settings

    # Show settings summary
    show_settings_summary if verbose?
  end
end
```

**Direct Usage**:
```ruby
settings_service = SettingsService.new("my-script")
settings = settings_service.load_settings
settings_service.save_settings(new_options)
settings_service.update_settings(debug: true, verbose: false)
```

### InteractiveMenuService (`services/interactive_menu_service.rb`)

**Purpose**: Universal interactive menu systems for scripts.

**Key Features**:
- Standardized "Use It | Cancel | Settings" action menus
- Settings management interfaces
- Progress indicators with spinners
- Task description prompts

**Usage Pattern**:
```ruby
# Integrated via ScriptBase
class MyScript < ScriptBase
  def run
    action = show_action_menu("Ready to process files")

    case action
    when :use_it
      process_files
    when :settings
      show_settings_menu
    when :cancel
      log_info("Operation cancelled")
      return
    end
  end

  # Override to provide script-specific settings
  def interactive_settings_menu
    [
      {
        key: :output_format,
        label: "Output Format",
        icon: "📄",
        current_value: get_setting(:output_format, 'json')
      }
    ]
  end

  def handle_setting_change(setting_key, menu_service)
    case setting_key
    when :output_format
      new_format = interactive_select("Choose format:", ['json', 'yaml', 'csv'])
      set_setting(:output_format, new_format)
    end
  end
end
```

### LLMService (`services/llm_service.rb`)

**Purpose**: Integration with Large Language Models (AI services).

**Key Features**:
- Multiple provider support (OpenAI, Anthropic, etc.)
- Token counting and rate limiting
- Conversation context management
- Error handling and retries

### UnifiedLLMService (`services/unified_llm_service.rb`)

**Purpose**: Multi-provider LLM management with fallbacks.

**Key Features**:
- Provider switching and fallback strategies
- Cost optimization across providers
- Unified API regardless of underlying provider
- Response caching and deduplication

### BrowserService (`services/browser_service.rb`)

**Purpose**: Browser automation and interaction utilities.

**Key Features**:
- Headless browser automation (Chrome, Firefox)
- Page interaction and form filling
- Screenshot capture and PDF generation
- Cookie and session management
- JavaScript execution and DOM manipulation
- Mobile browser emulation

### Gmail Integration Services

#### GmailService (`gmail_service.rb`)

**Purpose**: Gmail API integration for email operations and automation.

**Key Features**:
- Gmail API authentication and authorization
- Email reading, sending, and modification
- Label management and organization
- Batch operations for efficiency
- Rate limiting and quota management

#### GmailDatabase (`gmail_database.rb`)

**Purpose**: Gmail data persistence and caching for offline operations.

**Key Features**:
- Local SQLite database for Gmail data
- Message and thread caching
- Metadata indexing and search
- Sync status tracking
- Data export and import utilities

#### GmailArchiveHandler (`gmail_archive_handler.rb`)

**Purpose**: Email archiving and organization workflows.

**Key Features**:
- Intelligent email archiving rules
- Bulk archiving operations
- Archive restoration capabilities
- Category-based organization
- Archive analytics and reporting

### Additional Specialized Services

#### ConfigurationDisplayService (`services/configuration_display_service.rb`)

**Purpose**: Configuration display and formatting utilities.

**Key Features**:
- Structured configuration presentation
- Multi-format output (table, JSON, YAML)
- Configuration validation display
- Diff visualization for config changes
- Interactive configuration browsers

#### ConversationService (`services/conversation_service.rb`)

**Purpose**: Chat and conversation management for interactive applications.

**Key Features**:
- Conversation state management
- Message history persistence
- Context tracking and management
- Multi-participant conversation support
- Conversation export and analysis

#### ElementAnalyzer (`services/element_analyzer.rb`)

**Purpose**: Web element analysis and detection utilities.

**Key Features**:
- DOM element inspection and analysis
- Element attribute extraction
- Accessibility analysis
- Performance impact assessment
- Element similarity detection

#### ElementDetectorService (`services/element_detector_service.rb`)

**Purpose**: Advanced DOM element detection and selection.

**Key Features**:
- Smart element selection strategies
- XPath and CSS selector generation
- Element stability monitoring
- Dynamic content detection
- Selector optimization and validation

#### EpubGenerator (`services/epub_generator.rb`)

**Purpose**: EPUB e-book generation service.

**Key Features**:
- EPUB 3.0 standard compliance
- Multi-chapter book generation
- Table of contents automation
- Metadata management
- Cover image integration
- CSS styling and formatting

#### ImageProcessor (`services/image_processor.rb`)

**Purpose**: Image processing and manipulation utilities.

**Key Features**:
- Image resize, crop, and format conversion
- Batch image processing
- Metadata extraction and manipulation
- Thumbnail generation
- Image optimization for web
- Watermarking and annotation

#### InteractiveChatService (`services/interactive_chat_service.rb`)

**Purpose**: Interactive chat interfaces for command-line applications.

**Key Features**:
- Real-time chat interface
- Command parsing within chat
- Chat history and search
- Multi-session support
- Plugin system for chat commands

#### LLMChainProcessor (`services/llm_chain_processor.rb`)

**Purpose**: LLM request chaining and complex workflow processing.

**Key Features**:
- Sequential prompt chaining
- Conditional workflow branching
- Result aggregation and synthesis
- Error handling and retry logic
- Performance optimization for chains

#### LMStudioService (`services/lm_studio_service.rb`)

**Purpose**: LM Studio local AI integration for privacy-focused AI operations.

**Key Features**:
- Local LM Studio server integration
- Model management and switching
- Offline AI processing capabilities
- Performance monitoring
- Custom model configuration

#### OllamaService (`services/ollama_service.rb`)

**Purpose**: Ollama local AI integration for self-hosted language models.

**Key Features**:
- Ollama server communication
- Model downloading and management
- Local inference processing
- Memory and resource optimization
- Custom model deployment

#### PageFetcher (`services/page_fetcher.rb`)

**Purpose**: Web page fetching and parsing with advanced capabilities.

**Key Features**:
- Intelligent page content extraction
- JavaScript rendering support
- Rate limiting and politeness
- Cookie and session management
- Content caching and deduplication
- Mobile and desktop user agents

#### SummaryGenerationService (`services/summary_generation_service.rb`)

**Purpose**: Content summarization using various AI providers and techniques.

**Key Features**:
- Multiple summarization algorithms
- Length and style control
- Key point extraction
- Multi-document summarization
- Summary quality assessment
- Custom summarization templates

#### TranscriptParsingService (`services/transcript_parsing_service.rb`)

**Purpose**: Transcript processing and analysis utilities.

**Key Features**:
- Multiple transcript format support
- Speaker identification and labeling
- Timestamp parsing and validation
- Transcript segmentation
- Search and indexing capabilities
- Export to multiple formats

#### URLCollector (`services/url_collector.rb`)

**Purpose**: URL collection and management for batch processing.

**Key Features**:
- URL discovery from multiple sources
- Duplicate URL detection and removal
- URL categorization and tagging
- Batch URL processing
- Progress tracking for large collections
- URL accessibility validation

#### URLValidationService (`services/url_validation_service.rb`)

**Purpose**: Comprehensive URL validation and sanitization.

**Key Features**:
- URL format validation
- Domain and subdomain verification
- Protocol security checking
- Redirect chain following
- Malicious URL detection
- URL canonicalization

## Utils (Helper Modules)

### ErrorUtils (`utils/error_utils.rb`)

**Purpose**: Comprehensive error handling patterns and utilities.

**Key Features**:
- Enhanced error logging with context and backtraces
- Automatic retry mechanisms with exponential backoff
- Parameter validation helpers
- File access checking
- Safe system command execution
- HTTP request error handling
- Memory usage monitoring
- Performance timing

**Usage Pattern**:
```ruby
class MyScript < ScriptBase
  include ErrorUtils  # Included automatically via ScriptBase

  def process_file(file_path)
    # Enhanced error logging
    with_error_handling("File processing", file: file_path) do
      content = safe_file_read(file_path, "Reading input file")
      processed = process_content(content)
      safe_file_write("output.txt", processed, "Writing output file")
    end
  end

  def network_operation
    # Retry with exponential backoff
    with_retry(max_retries: 3, base_delay: 1, "API request") do
      api_call()
    end
  end

  def validate_inputs(params)
    # Parameter validation
    validate_required(params, [:input_file, :output_dir], "File processing")
  end

  def system_command
    # Safe command execution with timeout
    result = safe_system_execute("long_running_command", "Processing data", timeout: 60)
    puts result[:stdout] if result
  end

  def timed_operation
    # Performance measurement
    result = measure_time("Database query") do
      expensive_database_operation()
    end
    result
  end
end
```

**Available Methods**:
```ruby
# Error handling
with_error_handling(operation_name, context = {}, &block)
log_error_with_context(error, context = {})

# Retry mechanisms
with_retry(max_retries = 3, base_delay = 1, operation_name, context = {}, &block)

# Validation
validate_required(params, required_keys, operation_name)
check_file_access(file_path, operation = :read, operation_name)

# Safe operations
safe_file_read(file_path, operation_name)
safe_file_write(file_path, content, operation_name)
safe_system_execute(command, operation_name, timeout: 30)
safe_http_request(uri, request_class, operation_name, timeout: 30, &block)

# Monitoring
log_memory_usage(context = "")
measure_time(operation_name, &block)
```

### ProgressUtils (`utils/progress_utils.rb`)

**Purpose**: Progress indicators, timing, and user feedback utilities.

**Key Features**:
- Progress bars for long-running operations
- Spinner indicators for indeterminate progress
- Time estimation and remaining time calculation
- Throughput measurement

### TimeUtils (`utils/time_utils.rb`)

**Purpose**: Time formatting and calculation utilities.

**Key Features**:
- Human-readable duration formatting
- Timestamp generation and parsing
- Time zone handling
- Relative time calculations ("2 minutes ago")

### ParallelUtils (`utils/parallel_utils.rb`)

**Purpose**: Parallel processing and concurrent execution utilities.

**Key Features**:
- Thread-safe parallel processing of collections
- Worker pool management
- Progress tracking for parallel operations
- Error handling in concurrent contexts
- Automatic CPU core detection and optimal worker count

**Usage Pattern**:
```ruby
require_relative '.common/utils/parallel_utils'

# Process items in parallel
results = ParallelUtils.parallel_map(items, workers: 4) do |item|
  process_item(item)
end

# Parallel each with error handling
ParallelUtils.parallel_each(files, workers: 8) do |file|
  process_file(file)
end

# Get optimal worker count
workers = ParallelUtils.optimal_workers
```

### DeviceUtils (`utils/device_utils.rb`)

**Purpose**: Device detection and capability utilities for Apple Silicon and other platforms.

**Key Features**:
- Apple Silicon (M1/M2/M3) detection
- GPU availability detection
- Memory and core count queries
- CoreML availability detection
- Metal support detection

**Usage Pattern**:
```ruby
require_relative '.common/utils/device_utils'

# Check if running on Apple Silicon
if DeviceUtils.apple_silicon?
  log_info("Running on Apple Silicon")
end

# Get device capabilities
cores = DeviceUtils.cpu_cores
memory = DeviceUtils.total_memory_gb

# Check ML framework availability
if DeviceUtils.coreml_available?
  log_info("CoreML available for inference")
end
```

### InteractiveSettingsUtils (`utils/interactive_settings_utils.rb`)

**Purpose**: Helper utilities for settings user interfaces.

**Key Features**:
- Settings menu generation
- Input validation for settings
- Default value handling
- Settings export/import utilities

## Concerns (Mixins)

### MacOSUtils (`concerns/macos_utils.rb`)

**Purpose**: macOS-specific system integration utilities.

**Key Features**:
- System Preferences automation
- Dock and Finder configuration
- Launch Services integration
- Spotlight and metadata utilities

### TCCUtils (`concerns/tcc_utils.rb`)

**Purpose**: macOS privacy permissions (Transparency, Consent, and Control) management.

**Key Features**:
- Privacy permission checking
- TCC database queries
- Permission request automation
- Privacy-sensitive operation detection

### ProcessUtils (`concerns/process_utils.rb`)

**Purpose**: Process management and control utilities.

**Key Features**:
- Process discovery and filtering
- Graceful process termination
- Process monitoring and health checks
- Resource usage tracking

### Cacheable (`concerns/cacheable.rb`)

**Purpose**: Caching behavior mixin for classes.

**Key Features**:
- Method result caching
- Cache invalidation strategies
- Memory and disk-based caching
- Cache statistics and monitoring

### AccountManager (`concerns/account_manager.rb`)

**Purpose**: Account and credential management utilities.

**Key Features**:
- Secure credential storage
- Multi-account management
- Authentication workflows
- Session management

### ICloudStorage (`concerns/icloud_storage.rb`)

**Purpose**: iCloud integration utilities.

**Key Features**:
- iCloud Drive file operations
- Sync status monitoring
- Conflict resolution
- Mobile Documents access

### ArticleDetector (`concerns/article_detector.rb`)

**Purpose**: Article content detection and extraction from web pages.

**Key Features**:
- Intelligent article content identification
- Noise removal (ads, navigation, sidebars)
- Title and metadata extraction
- Reading time estimation
- Content quality assessment
- Multiple extraction algorithms

### GmailView (`concerns/gmail_view.rb`)

**Purpose**: Gmail UI display helpers and formatting utilities.

**Key Features**:
- Email message formatting for terminal display
- Thread conversation rendering
- Label and category visualization
- Search result presentation
- Interactive email browsing
- Message preview and summary

## Development Patterns

### 1. Script Creation Pattern

**⚠️ IMPORTANT: Working Directory Handling**
All Ruby CLI scripts should use `original_working_dir` instead of `Dir.pwd` to ensure they run in the user's original working directory, not the ruby-cli directory.

**Always start with this template**:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '.common/script_base'

# Brief description of what this script does
class MyUtilityScript < ScriptBase
  def script_emoji; '🔧'; end
  def script_title; 'My Utility Script'; end
  def script_description; 'Does something useful'; end
  def script_arguments; '[OPTIONS] <arguments>'; end

  def add_custom_options(opts)
    opts.on('-c', '--custom', 'Custom option') do
      @options[:custom] = true
    end
  end

  def validate!
    # Add validation logic
    # Use original_working_dir instead of Dir.pwd to run in user's directory
    @target_dir = args.empty? ? original_working_dir : File.expand_path(args[0])
    super
  end

  def run
    log_banner(script_title)
    # Main script logic
    show_completion(script_title)
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} file.txt    # Process file"
  end
end

MyUtilityScript.execute if __FILE__ == $0
```

### 2. Service Creation Pattern

**For stateful services**:
```ruby
# frozen_string_literal: true

require_relative '../base_service'

class MyService < BaseService
  def initialize(options = {})
    super(options)
    @custom_config = options[:config] || {}
    @state = initialize_state
  end

  def perform_operation(params)
    log_info("Starting #{self.class.name.downcase}")

    with_error_handling("Operation", params) do
      validate_inputs(params)
      result = process_data(params)
      update_state(result)
      result
    end
  end

  private

  def initialize_state
    # Initialize service state
  end

  def validate_inputs(params)
    validate_required(params, [:required_param], "My operation")
  end

  def process_data(params)
    # Main processing logic
  end

  def update_state(result)
    # Update internal state
  end
end
```

### 3. Utility Module Pattern

**For stateless utilities**:
```ruby
# frozen_string_literal: true

# Utility module for specific functionality
module MyUtils
  module_function

  def helper_method(input, options = {})
    # Pure function - no side effects
    process_input(input, options)
  end

  def another_helper(data)
    # Another pure function
    transform_data(data)
  end

  private

  def process_input(input, options)
    # Implementation
  end

  def transform_data(data)
    # Implementation
  end
end
```

### 4. Mixin/Concern Pattern

**For reusable behavior**:
```ruby
# frozen_string_literal: true

# Mixin providing specialized functionality
module MyBehavior
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Instance methods
  def instance_behavior
    # Behavior available to instances
  end

  module ClassMethods
    # Class methods
    def class_behavior
      # Behavior available to class
    end
  end

  private

  def private_helper
    # Private helper methods
  end
end
```

## Usage Examples

### Example 1: Simple File Processing Script

```ruby
#!/usr/bin/env ruby
require_relative '.common/script_base'

class FileProcessor < ScriptBase
  def script_emoji; '📄'; end
  def script_title; 'File Processor'; end
  def script_description; 'Processes text files with various operations'; end
  def script_arguments; '[OPTIONS] <input_file> <output_file>'; end

  def add_custom_options(opts)
    opts.on('-u', '--uppercase', 'Convert to uppercase') do
      @options[:uppercase] = true
    end
    opts.on('-c', '--count-words', 'Count words') do
      @options[:count_words] = true
    end
  end

  def validate!
    super

    if args.length < 2
      log_error("Missing required arguments: input_file output_file")
      exit 1
    end

    @input_file = args[0]
    @output_file = args[1]

    check_file_access(@input_file, :read, "File processing")
    check_file_access(@output_file, :write, "File processing")
  end

  def run
    log_banner("File Processing")

    content = safe_file_read(@input_file, "Reading input file")
    return unless content

    processed_content = process_content(content)
    safe_file_write(@output_file, processed_content, "Writing output file")

    show_completion("File processing")
  end

  private

  def process_content(content)
    result = content

    if @options[:uppercase]
      log_progress("Converting to uppercase")
      result = result.upcase
    end

    if @options[:count_words]
      word_count = result.split.length
      log_info("Word count: #{word_count}")
    end

    result
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} input.txt output.txt                    # Basic processing"
    puts "  #{script_name} --uppercase input.txt output.txt       # Convert to uppercase"
    puts "  #{script_name} --count-words --verbose input.txt out.txt  # Count words verbosely"
  end
end

FileProcessor.execute if __FILE__ == $0
```

### Example 2: Interactive Menu Script

```ruby
#!/usr/bin/env ruby
require_relative '.common/interactive_script_base'
require_relative '.common/services/file_cache_service'

class FileManager < InteractiveScriptBase
  def script_emoji; '📁'; end
  def script_title; 'File Manager'; end
  def script_description; 'Interactive file management utility'; end

  def initialize
    super
    @cache_service = FileCacheService.new(logger: self, debug: debug?)
    @current_directory = Dir.pwd
  end

  def menu_options
    {
      'list' => '📋 List Files',
      'search' => '🔍 Search Files',
      'clean' => '🧹 Clean Cache',
      'settings' => '⚙️  Settings',
      'exit' => '🚪 Exit'
    }
  end

  def handle_menu_choice(choice)
    case choice
    when 'list'
      list_files
    when 'search'
      search_files
    when 'clean'
      clean_cache
    when 'settings'
      show_settings_menu
    end
  end

  def setup_interactive_mode
    log_info("File Manager starting in: #{@current_directory}")
    @cache_service.initialize_cache
  end

  private

  def list_files
    log_progress("Listing files in #{@current_directory}")

    files = Dir.glob("*").select { |f| File.file?(f) }

    if files.empty?
      log_warning("No files found in current directory")
      return
    end

    log_info("Found #{files.length} files:")
    files.each { |file| puts "  📄 #{file}" }
  end

  def search_files
    pattern = @prompt.ask("Search pattern:", default: "*.txt")

    with_progress("Searching for files matching #{pattern}") do
      matches = Dir.glob("**/#{pattern}")

      if matches.empty?
        log_warning("No files found matching '#{pattern}'")
      else
        log_success("Found #{matches.length} matches:")
        matches.each { |match| puts "  📄 #{match}" }
      end
    end
  end

  def clean_cache
    if confirm_action("Clear file cache?")
      @cache_service.clear_cache
      log_success("Cache cleared")
    end
  end
end

FileManager.execute if __FILE__ == $0
```

### Example 3: Service Integration

```ruby
#!/usr/bin/env ruby
require_relative '.common/script_base'
require_relative '.common/services/llm_service'
require_relative '.common/services/file_cache_service'

class ContentAnalyzer < ScriptBase
  def script_emoji; '📊'; end
  def script_title; 'Content Analyzer'; end
  def script_description; 'Analyzes text content using AI'; end
  def script_arguments; '[OPTIONS] <content_file>'; end

  def initialize
    super
    @llm_service = LLMService.new(logger: self, debug: debug?)
    @cache_service = FileCacheService.new(logger: self)
  end

  def add_custom_options(opts)
    opts.on('-m', '--model MODEL', 'AI model to use') do |model|
      @options[:model] = model
    end
    opts.on('--no-cache', 'Disable result caching') do
      @options[:no_cache] = true
    end
  end

  def validate!
    super

    if args.empty?
      log_error("Missing required argument: content_file")
      exit 1
    end

    @content_file = args[0]
    check_file_access(@content_file, :read, "Content analysis")
  end

  def run
    log_banner("Content Analysis")

    content = safe_file_read(@content_file, "Reading content")
    return unless content

    # Check cache first (unless disabled)
    cache_key = "analysis_#{File.basename(@content_file)}"

    analysis = nil
    unless @options[:no_cache]
      analysis = @cache_service.get(cache_key)
      log_info("Using cached analysis") if analysis
    end

    # Perform analysis if not cached
    unless analysis
      log_progress("Analyzing content with AI")
      analysis = @llm_service.analyze_content(content, model: @options[:model])

      # Cache the result
      @cache_service.set(cache_key, analysis) unless @options[:no_cache]
    end

    display_analysis(analysis)
    show_completion("Content analysis")
  end

  private

  def display_analysis(analysis)
    log_section("Analysis Results")

    analysis.each do |key, value|
      puts "#{key.to_s.capitalize}: #{value}"
    end
  end

  def show_examples
    puts "Examples:"
    puts "  #{script_name} document.txt                          # Basic analysis"
    puts "  #{script_name} --model gpt-4 document.txt           # Use specific model"
    puts "  #{script_name} --no-cache --verbose document.txt    # Skip cache, verbose output"
  end
end

ContentAnalyzer.execute if __FILE__ == $0
```

## Testing and Quality

### RuboCop Configuration

All scripts should pass RuboCop checks:
```bash
bundle exec rubocop bin/ --config .rubocop.yml
```

### RSpec Testing

Test your services and utilities:
```ruby
# spec/services/my_service_spec.rb
require_relative '../../bin/.common/services/my_service'

RSpec.describe MyService do
  let(:service) { MyService.new(logger: double('logger').as_null_object) }

  describe '#perform_operation' do
    it 'processes data correctly' do
      result = service.perform_operation(input: 'test')
      expect(result).to be_truthy
    end
  end
end
```

### Debug Mode

Enable debug mode for detailed logging:
```bash
DEBUG=1 bundle exec ruby bin/my-script.rb --verbose
```

### Session Logging

Enable session logging for troubleshooting:
```bash
LOG_SESSIONS=1 bundle exec ruby bin/my-script.rb
# Or use the flag
bundle exec ruby bin/my-script.rb --log-session
```

---

## Complete Reference: All .common Utilities

This section provides a complete inventory of all utilities available in `bin/.common/` for quick reference.

### Base Classes
- **script_base.rb** - Universal script foundation with CLI parsing, settings, logging
- **interactive_script_base.rb** - Interactive menu-driven script foundation
- **git_commit_script_base.rb** - Git workflow automation base
- **file_merger_base.rb** - File merging operations base

### Core Utilities (Stateless)
- **logger.rb** - Centralized logging with emoji indicators and colors
- **system.rb** - System command execution, platform detection, process management
- **format.rb** - Text formatting, table generation, size/duration formatting
- **view.rb** - UI display utilities, progress indicators, menu formatting
- **database.rb** - SQLite database operations and management
- **file_processing_tracker.rb** - Track file processing status across runs
- **file_filter.rb** - File filtering utilities for dimensions, extensions, custom criteria
- **workflow_processor.rb** - Multi-pass workflow processing with caching support
- **image_workflow.rb** - Specialized image processing workflows with common patterns
- **image_utils.rb** - Image manipulation using ChunkyPNG
- **xcode_project.rb** - Xcode project file manipulation

### Gmail Integration
- **gmail_service.rb** - Gmail API integration for email operations
- **gmail_database.rb** - Gmail data persistence and caching
- **gmail_archive_handler.rb** - Email archiving workflows

### Services (Stateful - in services/)
- **base_service.rb** - Foundation for all stateful services
- **settings_service.rb** - Settings persistence and loading
- **interactive_menu_service.rb** - Interactive menu UI systems
- **llm_service.rb** - AI/LLM integration (OpenAI, Anthropic)
- **unified_llm_service.rb** - Multi-provider LLM with fallbacks
- **lm_studio_service.rb** - LM Studio local AI integration
- **ollama_service.rb** - Ollama local AI integration
- **browser_service.rb** - Browser automation (Chrome, Firefox)
- **file_cache_service.rb** - File caching system
- **markdown_renderer.rb** - Markdown processing
- **text_chunking_service.rb** - Text processing and chunking
- **video_info_service.rb** - Video metadata extraction
- **media_transcript_service.rb** - Media transcription
- **configuration_display_service.rb** - Configuration display formatting
- **conversation_service.rb** - Chat and conversation management
- **element_analyzer.rb** - Web element analysis
- **element_detector_service.rb** - DOM element detection
- **epub_generator.rb** - EPUB e-book generation
- **image_processor.rb** - Image processing and manipulation
- **interactive_chat_service.rb** - Interactive chat interfaces
- **llm_chain_processor.rb** - LLM request chaining
- **page_fetcher.rb** - Web page fetching and parsing
- **summary_generation_service.rb** - Content summarization
- **transcript_parsing_service.rb** - Transcript processing
- **url_collector.rb** - URL collection and management
- **url_validation_service.rb** - URL validation and sanitization

### Utils (Helper Modules - in utils/)
- **error_utils.rb** - Error handling patterns, retries, validation
- **progress_utils.rb** - Progress indicators, timing, feedback
- **time_utils.rb** - Time formatting and calculations
- **interactive_settings_utils.rb** - Settings UI helpers
- **parallel_utils.rb** - Parallel processing and threading
- **device_utils.rb** - Device detection (Apple Silicon, GPU, etc.)

### Concerns (Mixins - in concerns/)
- **macos_utils.rb** - macOS system integration
- **tcc_utils.rb** - macOS privacy permissions (TCC)
- **process_utils.rb** - Process management and control
- **cacheable.rb** - Caching behavior mixin
- **account_manager.rb** - Account and credential management
- **icloud_storage.rb** - iCloud integration
- **article_detector.rb** - Article content detection from web pages
- **gmail_view.rb** - Gmail UI display helpers

### Quick Reference Guide

**When you need to...**

- **Parse CLI arguments** → Use `ScriptBase`
- **Create interactive menus** → Use `InteractiveScriptBase` + `InteractiveMenuService`
- **Log messages** → Use global functions from `logger.rb` (`log_info`, `log_success`, etc.)
- **Execute commands** → Use `System.execute` from `system.rb`
- **Handle errors** → Include `ErrorUtils` mixin
- **Process files in parallel** → Use `ParallelUtils`
- **Track file processing** → Use `FileProcessingTracker`
- **Filter files by criteria** → Use `FileFilter` for dimensions, extensions, custom filters
- **Process multi-pass workflows** → Use `WorkflowProcessor` for complex file processing pipelines
- **Process images with common patterns** → Use `ImageWorkflow` for human detection, upscaling, etc.
- **Work with images** → Use `ImageUtils` or `ImageProcessor`
- **Call AI/LLM APIs** → Use `LLMService` or `UnifiedLLMService`
- **Cache results** → Use `FileCacheService` or `Cacheable` concern
- **Process web pages** → Use `PageFetcher` or `BrowserService`
- **Create EPUBs** → Use `EpubGenerator`
- **Work with Xcode** → Use `XcodeProject`
- **Manage settings** → Use `SettingsService` (auto-included in `ScriptBase`)
- **Show progress** → Use `ProgressUtils` or `with_progress` from `InteractiveMenuService`
- **Work with Gmail** → Use `GmailService`, `GmailDatabase`, `GmailArchiveHandler`
- **Detect device capabilities** → Use `DeviceUtils`

---

This documentation should be your **first reference** when developing scripts. The patterns and utilities documented here provide the foundation for all script development in this system.