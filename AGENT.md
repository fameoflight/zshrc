# CLAUDE.md

_ZSH Configuration Repository - Documentation for Claude Code (claude.ai/code)_

## Repository Overview

Modular ZSH configuration system originated from Sebastian Tramp's configuration, customized by Hemant Verma. Features centralized logging, platform-specific configurations, and extensive custom scripts system.

## Quick Start

```bash
make install          # Full installation with symlinks
make mac             # Complete macOS setup
make github-setup    # Configure Git
make pytorch-setup   # Setup PyTorch models for image upscaling
make update          # Update repository and submodules
```

## Core Architecture

### Configuration Loading Order

1. **`logging.zsh`** - Centralized logging (loaded first for universal access)
2. **`environment.zsh`** - Environment variables and PATH management
3. **`options.zsh`** - Shell options and settings
4. **`prompt.zsh`** - Prompt configuration
5. **`functions.zsh`** - Custom functions and key bindings
6. **`aliases.zsh`** - Command aliases and suffix handlers
7. **Platform-specific** - `darwin.zsh` (macOS) or `linux.zsh`
8. **Application configs** - `git.zsh`, `rails.zsh`, `claude.zsh`, etc.
9. **`completion.zsh`** - Tab completion setup
10. **`private.zsh`** - User-specific private configurations

### Key Features

- **Modular Design** - Each feature area has dedicated `.zsh` file
- **Platform Detection** - Automatic OS-specific configuration loading
- **External Dependencies** - `zsh-syntax-highlighting` submodule
- **Path Management** - Automated setup for Python, Node, Conda, Ruby, etc.

## Development Utilities

### Navigation & File Operations

```bash
workspace              # cd ~/workspace
latest-dir            # Enter most recently created directory
path <pattern>        # Find files matching pattern
buf <file>            # Backup file with timestamp
massmove              # Batch rename files interactively
```

### Development Helpers

```bash
kill-port <port>      # Kill process on specific port
kill-grep <pattern>   # Kill processes matching pattern
clean-pyc             # Remove .pyc files recursively
fix-pep8              # Auto-fix Python PEP8 in staged files
```

## AI Tools Integration

### API Key Setup (Optional)

API keys enable enhanced functionality but aren't required.

**Claude (Anthropic):**

```bash
setup-claude-key "sk-ant-api03-your-key-here"
# Stores in ~/.claude/anthropic_api_key
```

**Gemini (Google):**

```bash
setup-gemini-key "AIzaSyYour-gemini-key-here"
# Stores in ~/.gemini/api_key
```

**Available Functions:**

- `claude` / `cc` - Claude Code CLI with auto-loaded API key
- `gemini-cli` / `gg` - Gemini CLI with auto-loaded API key

## Custom Scripts System

Three-tier Ruby-based scripts system with centralized dependency management and shared utilities.

**Architecture**: Executables in `bin/` directory, setup scripts in `scripts/` directory

⚠️ **BEFORE WRITING ANY NEW SCRIPT**: Always read `/Users/hemantv/zshrc/bin/SCRIPTS.md` first to understand:

- Available base classes (ScriptBase, InteractiveScriptBase, etc.)
- Existing utilities (Logger, System, ErrorUtils, etc.)
- Services you can reuse (LLMService, FileCache, etc.)
- Common patterns and best practices

### Script Categories

#### 🐚 Utility Scripts (ZSH Functions)

_Available immediately in shell - for frequent use_

```bash
calibre-update         # Update Calibre e-book manager
stack-monitors         # Configure stacked monitor setup
merge-pdf              # Merge multiple PDF files
dropbox-backup         # Move directories to Dropbox with symlinks
uninstall-app          # Comprehensive application uninstaller
xcode-icon-generator   # Generate app icons for Xcode projects
list-scripts           # Show all available scripts
```

#### 🛠️ Setup/Backup Scripts (Makefile Only)

_Controlled access for system configuration_

```bash
make macos-optimize    # Optimize macOS developer settings
make claude-setup      # Setup Claude Code configuration
make gemini-setup      # Setup Gemini CLI configuration
make xcode-backup      # Backup Xcode essential settings
make vscode-backup     # Backup VS Code settings
make iterm-backup      # Backup iTerm2 configuration
```

#### 🧹 Repository Maintenance (Makefile Only)

_Internal repository tools_

```bash
make find-orphans      # Find orphaned Makefile targets
```

### Ruby Script Development

⚠️ **MANDATORY FIRST STEP**: Read `/Users/hemantv/zshrc/bin/SCRIPTS.md` before writing any script. This comprehensive documentation covers:

- All available base classes and utilities
- Complete service catalog with usage examples
- Helper modules and mixins
- Common patterns and best practices
- Quick reference guide for "when you need to..."

**Install dependencies:**

```bash
make ruby-gems
```

**Available gems:** tty-prompt, tty-progressbar, pastel, sqlite3, rexml, chunky_png, oily_png

**Script template** (see SCRIPTS.md for complete patterns):

```ruby
#!/usr/bin/env ruby
require_relative '.common/script_base'

class MyUtilityScript < ScriptBase
  def script_emoji; '🔧'; end
  def script_title; 'My Utility Tool'; end
  def script_description; 'Does something useful'; end
  def script_arguments; '[OPTIONS] <arguments>'; end

  def run
    log_banner(script_title)
    # Implementation here
    show_completion(script_title)
  end
end

MyUtilityScript.execute if __FILE__ == $0
```

**For detailed patterns and examples**, consult `/Users/hemantv/zshrc/bin/SCRIPTS.md`

## Centralized Logging System

**Core Functions:**

```bash
log_success "Operation completed"     # Green + ✅
log_error "Failed to find file"      # Red + ❌ (stderr)
log_warning "Backup recommended"     # Yellow + ⚠️
log_info "Checking requirements"     # Blue + ℹ️
log_progress "Processing data"       # Cyan + 🔄
log_section "Configuration"         # Magenta + 🔧
```

**Specialized Functions:**

```bash
log_file_created "/path"            # 📄 File operations
log_install "package"               # 📦 Installation
log_brew "Installing tools"         # 🍺 Homebrew
log_git "Committing changes"        # 🐙 Git operations
```

**Usage in scripts:**

```bash
# Source logging in bash scripts
source "$ZSH_CONFIG/logging.zsh"
log_info "Script started"
```

**When to use Gemini:**

- Analyzing entire codebases (>100KB)
- Verifying implementations across multiple files
- Understanding project-wide patterns
- Context exceeds Claude's limits

## PyTorch Image Inference

### Overview

Modular PyTorch inference framework for image processing with support for multiple model types. Located in `bin/python-cli/` package with CLI script at `bin/pytorch_inference.py`.

### Model Setup

**PyTorch Models Setup Script:**

Automated setup for PyTorch models with Apple Silicon CoreML conversion. Uses external configuration files for easy maintenance.

```bash
make pytorch-setup    # Run PyTorch models setup script
```

**Configuration Files:**

- `scripts/requirements.txt` - Python dependencies for PyTorch environment
- `scripts/pytorch-models.json` - Model definitions with URLs and descriptions

**Setup Process:**

1. Creates isolated Python environment in `~/.config/zsh/.models/venv`
2. Installs dependencies from requirements.txt
3. Downloads PyTorch models from JSON configuration
4. Converts models to CoreML format for Apple Silicon optimization
5. Generates configuration file with available models

**Adding New Models:**
Update `scripts/pytorch-models.json`:

```json
{
  "ModelName": {
    "url": "https://example.com/model.pth",
    "filename": "model.pth",
    "description": "Model description"
  }
}
```

### Features

- **Smart Auto-Optimization**: Automatically determines optimal tile size, batch size, and worker count based on image size and device capabilities
- **Multi-Device Support**: CUDA GPU, Apple Silicon (MPS), and CPU with automatic device detection
- **Memory-Efficient Processing**: Tiled inference and streaming mode for large images
- **Extensible Architecture**: Easy to add new model types beyond ESRGAN

### Usage

**Basic Usage (Recommended - Auto-Optimized):**

```bash
python pytorch_inference.py --input image.jpg --output result.jpg --model model.pth
```

**Advanced Usage:**

```bash
# Override specific parameters
python pytorch_inference.py --input image.jpg --output result.jpg --model model.pth --tile 256

# Manual control
python pytorch_inference.py --input image.jpg --output result.jpg --model model.pth --tile 512 --batch-size 4 --workers 2

# Different scale factors
python pytorch_inference.py --input image.jpg --output result.jpg --model model.pth --scale 2
```

### Auto-Optimization Logic

The system analyzes image dimensions and available device memory to determine optimal parameters:

**CUDA GPU:**

- Larger tiles (256-1024px) for better parallelization
- Higher batch sizes (2-8)
- Multiple workers (2-4) based on image size

**Apple Silicon (MPS):**

- Moderate tiles (100-400px) due to memory constraints
- Smaller batches (1-4)
- Single worker to prevent memory issues

**CPU:**

- Smaller tiles (75-350px) to avoid memory pressure
- Small batches (1-4)
- Single worker to avoid oversubscription

### Architecture

**`python_cli/utils.py`** - Base inference framework:

- `BaseImageInference` class for generic PyTorch models
- Device detection and memory optimization
- Tiled and streaming inference methods
- Image preprocessing and postprocessing

**`python_cli/esrgan.py`** - ESRGAN-specific implementation:

- RRDBNet architecture definitions
- ESRGAN model loading logic
- Factory methods for easy instantiation

**`pytorch_inference.py`** - CLI interface:

- Command-line argument parsing
- Model type selection
- Error handling with helpful suggestions

### Adding New Model Types

To add support for new PyTorch models:

1. Create model class in `python_cli/my_model.py`
2. Inherit from `BaseImageInference`
3. Implement `load_model()` method
4. Update CLI script to support new model type

```python
from python_cli.utils import BaseImageInference

class MyModelInference(BaseImageInference):
    def load_model(self, model_path):
        # Custom model loading logic
        pass
```

### Memory Management

The framework includes automatic memory management:

- Estimates memory requirements based on image size and scale factor
- Falls back to streaming mode for very large images
- Provides helpful error messages with optimization suggestions
- Handles device-specific memory constraints

## Git Integration

**Custom aliases:** `lg` (log), `cp` (cherry-pick), `ri` (rebase interactive), `rc` (rebase continue), `pushf` (force push)

**Configuration includes:**

- Rebase editor setup
- SSH key management
- Push behavior defaults

## Environment Variables

- `ZSH_CONFIG` - Points to ~/.config/zsh
- `EDITOR` - Set to "vim"
- `PATH` - Extended for development tools (Python, Node, Ruby, etc.)

## Development Guidelines

### Style Conventions

- **Function naming:** Use kebab-case (`my-function` not `my_function`)
- **Logging:** Always use centralized logging functions, never raw `echo`
- **Colors:** Use logging functions for consistent emoji + color output
- **Error handling:** Use `set -euo pipefail` in bash scripts

### Adding New Scripts

**For utility scripts (Ruby preferred):**

1. Create `bin/my-script.rb` using ScriptBase template
2. Add wrapper function in `bin/scripts.zsh`
3. Update `list-scripts` function

**For setup/backup scripts (bash):**

1. Create `bin/my-script.sh`
2. Add Makefile target only (no wrapper function)
3. Source logging functions

## Directory Structure

```
├── zshrc                    # Main configuration entry
├── logging.zsh             # Centralized logging (loaded first)
├── environment.zsh         # Environment variables
├── [other core .zsh files]
├── bin/                    # Custom scripts system
│   ├── scripts.zsh         # Wrapper functions
│   ├── .common/            # Ruby utilities
│   └── [script files]
├── functions.d/            # Completion functions
├── Settings/               # Application backups
└── zsh-syntax-highlighting/ # External dependency
```

## Installation

The configuration uses symlinks to `~/.config/zsh/` allowing easy updates while maintaining customizations in `private.zsh`.

**Key installation targets:**

- `make install` - Full setup with symlinks
- `make mac` - macOS-specific setup with Homebrew
- `make github-setup` - Git configuration
- `make update` - Update repository and submodules
