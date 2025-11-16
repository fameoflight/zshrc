# Script Development Rules - Readable, DRY, Encapsulated Code

You are an expert at writing simple, readable, DRY scripts with excellent encapsulation. Follow these patterns strictly for all scripts (Ruby, Python, Shell).

## Core Principles

1. **Maximum 5 parameters - EVER** (functions, methods, scripts)
2. **Prefer options hash/dict pattern** - Makes parameters explicit and extensible
3. **Small helper methods** - Remove friction, encapsulate complexity
4. **DRY** - Don't Repeat Yourself
5. **Simple over clever** - Boring code is good code
6. **Encapsulation** - Hide complexity behind clean interfaces
7. **Inheritance is good when done right** - Use base classes (ScriptBase, BaseImageInference)
8. **Metadata headers** - All scripts must have category headers

---

## Pattern 1: Script Headers (MANDATORY)

**ALL scripts must include metadata headers**

### Ruby Scripts

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Split large commits into smaller logical commits
# @tags: automation, interactive

require_relative '../../bin/.common/script_base'

class GitCommitSplitter < ScriptBase
  # ...
end

GitCommitSplitter.execute if __FILE__ == $0
```

### Python Scripts

```python
#!/usr/bin/env python3
# @category: media
# @description: Upscale images using PyTorch ESRGAN models
# @tags: ml, image-processing

import sys
from python_cli.esrgan import ESRGANInference

def main():
    # ...
```

### Shell Scripts

```bash
#!/bin/bash
# @category: setup
# @description: Configure Claude Code CLI with API keys
# @tags: configuration, ai

set -euo pipefail
source "$ZSH_CONFIG/logging.zsh"
```

**Required Fields:**
- `@category`: git, media, system, setup, backup, dev, files, data, communication
- `@description`: One-line description of what the script does

**Optional Fields:**
- `@tags`: Comma-separated tags for additional filtering
- `@dependencies`: External tools required (e.g., `ffmpeg, imagemagick`)

---

## Pattern 2: Options Hash/Dict (The `opts` Pattern)

**When to use:** Any method/function with 3+ parameters OR parameters that might grow

### ✅ GOOD - Ruby Options Pattern

```ruby
# Example: ScriptBase initialization
class ScriptBase
  def initialize(opts = {})
    @options = default_options.merge(opts)
    @args = []
    @original_working_dir = ENV['ORIGINAL_WORKING_DIR'] || Dir.pwd
  end

  def default_options
    {
      dry_run: false,
      force: false,
      verbose: false,
      quiet: false
    }
  end
end

# Usage
script = MyScript.new(dry_run: true, verbose: true)
```

### ✅ GOOD - Python Options Pattern

```python
# Example: BaseImageInference
class BaseImageInference:
    def __init__(self, model_path: str, opts: Optional[Dict] = None):
        self.model_path = model_path
        self.opts = opts or {}
        self.device = self.opts.get('device', 'cuda')
        self.tile_size = self.opts.get('tile_size', 512)
        self.batch_size = self.opts.get('batch_size', 1)

# Usage
inference = ESRGANInference(
    'model.pth',
    opts={'device': 'mps', 'tile_size': 256}
)
```

### ✅ GOOD - Shell Options Pattern

```bash
# Example: Function with options
backup_xcode() {
    local dry_run=false
    local force=false
    local output_dir="$HOME/Settings/Xcode"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            --force) force=true; shift ;;
            --output) output_dir="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    # Use options
    [[ "$dry_run" = true ]] && log_info "Dry run mode"
}

# Usage
backup_xcode --dry-run --output /tmp/backup
```

### ❌ BAD - Too Many Positional Parameters

```ruby
# ❌ BAD - Hard to read, hard to extend
def process_image(input_path, output_path, scale, device, tile_size, batch_size)
  # What do all these mean?
end

# Usage - unclear!
process_image('in.jpg', 'out.jpg', 4, 'cuda', 512, 2)
```

```python
# ❌ BAD - Positional parameter hell
def upscale_image(input_path, output_path, model_path, scale,
                  device, tile_size, batch_size, workers):
    # Too many parameters!
    pass

# Usage - what is what?
upscale_image('in.jpg', 'out.jpg', 'model.pth', 4, 'cuda', 512, 2, 4)
```

**Problems:**
- Unclear what each parameter means
- Hard to add new parameters
- Must remember parameter order
- No type hints at call site

---

## Pattern 3: Helper Methods (Friction Removal)

**When to use:** When you find yourself repeating code or complex logic

### ✅ GOOD - Ruby Helper Methods

```ruby
# Example: GitCommitScriptBase helpers
class GitCommitScriptBase < ScriptBase
  # Helper: Get staged files by type
  def get_staged_files
    System.safe_execute("git diff --cached --name-only --diff-filter=ACMR")
      .split("\n")
      .reject(&:empty?)
  end

  # Helper: Create commit
  def create_commit(message)
    return if @options[:dry_run]

    log_info "Creating commit"
    System.safe_execute("git commit -m #{message.shellescape}")
    log_success "Commit created"
  end

  # Helper: Check if changes are staged
  def has_staged_changes?
    !System.safe_execute("git diff --cached --name-only").strip.empty?
  end
end

# Usage - clean and DRY!
class GitCommitDeletes < GitCommitScriptBase
  def run
    return unless has_staged_changes?  # ✅ Helper method

    files = get_staged_files           # ✅ Helper method
    create_commit("Delete #{files.size} files")  # ✅ Helper method
  end
end
```

### ✅ GOOD - Python Helper Functions

```python
# Example: pytorch_inference.py helpers
def detect_device() -> str:
    """Helper: Auto-detect best available device"""
    if torch.cuda.is_available():
        return 'cuda'
    elif torch.backends.mps.is_available():
        return 'mps'
    return 'cpu'

def calculate_optimal_tile_size(image_size: Tuple[int, int],
                                device: str) -> int:
    """Helper: Calculate optimal tile size based on image and device"""
    width, height = image_size
    total_pixels = width * height

    if device == 'cuda':
        return min(1024, max(256, total_pixels // 1000))
    elif device == 'mps':
        return min(400, max(100, total_pixels // 2000))
    return min(350, max(75, total_pixels // 3000))

# Usage - clear what's happening!
device = detect_device()
tile_size = calculate_optimal_tile_size((1920, 1080), device)
```

### ✅ GOOD - Shell Helper Functions

```bash
# Example: logging.zsh helpers
log_with_color() {
    local color=$1
    local emoji=$2
    local message=$3
    echo "${color}${emoji} ${message}${RESET_COLOR}"
}

log_success() {
    log_with_color "$GREEN" "✅" "$1"
}

log_error() {
    log_with_color "$RED" "❌" "$1" >&2
}

# Usage - consistent and DRY!
log_success "Installation complete"
log_error "File not found"
```

### ❌ BAD - Repeated Logic

```ruby
# ❌ BAD - Same code repeated everywhere
class GitCommitDeletes < ScriptBase
  def run
    staged = `git diff --cached --name-only --diff-filter=ACMR`.split("\n")
    if staged.empty?
      puts "No staged files"
      return
    end

    `git commit -m "Delete files"`
  end
end

class GitCommitRenames < ScriptBase
  def run
    staged = `git diff --cached --name-only --diff-filter=ACMR`.split("\n")  # ❌ Duplicate!
    if staged.empty?  # ❌ Duplicate!
      puts "No staged files"
      return
    end

    `git commit -m "Rename files"`
  end
end
```

**Problems:**
- Code duplication (DRY violation)
- Inconsistent error handling
- Hard to maintain
- No logging

---

## Pattern 4: Base Class Inheritance

**When to use:** Shared functionality across multiple scripts

### ✅ GOOD - Ruby Base Classes

```ruby
# Example: ScriptBase provides common functionality
class ScriptBase
  include ErrorUtils

  PROJECT_ROOT = ENV['ZSH_CONFIG'] || File.expand_path('../..', __dir__)

  attr_reader :options, :args

  def initialize
    @options = default_options
    @args = []
    @original_working_dir = ENV['ORIGINAL_WORKING_DIR'] || Dir.pwd
    setup_bundler
    parse_arguments
  end

  # Common method: Banner logging
  def log_banner(title)
    Logger.log_section("#{script_emoji} #{title}")
  end

  # Common method: Completion message
  def show_completion(title)
    Logger.log_success("#{title} completed successfully")
  end

  # Abstract methods (override in subclass)
  def run
    raise NotImplementedError, "#{self.class} must implement #run"
  end

  def script_title
    self.class.name
  end
end

# Subclass inherits all functionality!
class MyScript < ScriptBase
  def script_emoji; '🔧'; end
  def script_title; 'My Utility'; end

  def run
    log_banner(script_title)  # ✅ From base class
    # ... custom logic ...
    show_completion(script_title)  # ✅ From base class
  end
end
```

### ✅ GOOD - Python Base Classes

```python
# Example: BaseImageInference provides common ML functionality
class BaseImageInference:
    """Base class for PyTorch image inference models"""

    def __init__(self, model_path: str, opts: Optional[Dict] = None):
        self.model_path = model_path
        self.opts = opts or {}
        self.device = self._detect_device()
        self.model = None

    def _detect_device(self) -> str:
        """Helper: Auto-detect device"""
        device = self.opts.get('device')
        if device:
            return device

        if torch.cuda.is_available():
            return 'cuda'
        elif torch.backends.mps.is_available():
            return 'mps'
        return 'cpu'

    def load_model(self, model_path: str):
        """Abstract method - override in subclass"""
        raise NotImplementedError("Subclass must implement load_model()")

    def process_image(self, image_path: str, output_path: str):
        """Common method - uses subclass model"""
        if not self.model:
            self.model = self.load_model(self.model_path)

        # Common processing logic
        img = Image.open(image_path)
        result = self._run_inference(img)
        result.save(output_path)

# Subclass inherits common functionality!
class ESRGANInference(BaseImageInference):
    def load_model(self, model_path: str):
        # ✅ Custom model loading
        model = RRDBNet(...)
        model.load_state_dict(torch.load(model_path))
        return model
```

### ✅ GOOD - Shell Base Pattern

```bash
# Example: Common functions in scripts.zsh
script_wrapper() {
    local script_name=$1
    local script_path=$2
    shift 2

    # Common wrapper functionality
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_name"
        return 1
    fi

    # Execute with proper environment
    ORIGINAL_WORKING_DIR="$PWD" "$script_path" "$@"
}

# All Ruby scripts use same wrapper!
git-commit-deletes() {
    script_wrapper "git-commit-deletes" \
        "$BIN_DIR/ruby-cli/bin/git-commit-deletes.rb" "$@"
}

git-smart-rebase() {
    script_wrapper "git-smart-rebase" \
        "$BIN_DIR/ruby-cli/bin/git-smart-rebase.rb" "$@"
}
```

**Benefits of base classes:**
- DRY - shared code in one place
- Consistent behavior across scripts
- Easy to add new scripts
- Centralized error handling
- Single place to improve functionality

---

## Pattern 5: The 5-Parameter Rule

**NEVER exceed 5 parameters** - If you need more, you're doing too much

### Solutions When You Hit 5 Parameters

**1. Options Hash/Dict**

```ruby
# ❌ BAD - 7 parameters
def process_video(input, output, codec, bitrate, resolution, fps, audio_codec)
end

# ✅ GOOD - 2 required + 1 options
def process_video(input_path, output_path, opts = {})
  codec = opts.fetch(:codec, 'h264')
  bitrate = opts.fetch(:bitrate, '5M')
  resolution = opts.fetch(:resolution, '1920x1080')
  fps = opts.fetch(:fps, 30)
  audio_codec = opts.fetch(:audio_codec, 'aac')
end

# Usage - self-documenting!
process_video('in.mp4', 'out.mp4',
  codec: 'h265',
  bitrate: '10M',
  resolution: '3840x2160'
)
```

**2. Extract to Class/Module**

```python
# ❌ BAD - Too many parameters
def upscale_image(input_path, output_path, model_path, scale,
                  device, tile_size, batch_size, workers):
    pass

# ✅ GOOD - Class encapsulates config
class ImageUpscaler:
    def __init__(self, model_path: str, opts: Dict = None):
        self.model_path = model_path
        self.opts = opts or {}
        self.scale = self.opts.get('scale', 4)
        self.device = self.opts.get('device', 'cuda')
        self.tile_size = self.opts.get('tile_size', 512)
        self.batch_size = self.opts.get('batch_size', 1)

    def upscale(self, input_path: str, output_path: str):
        # Clean interface - only 2 parameters!
        pass

# Usage
upscaler = ImageUpscaler('model.pth', {'scale': 4, 'device': 'mps'})
upscaler.upscale('input.jpg', 'output.jpg')
```

**3. Group Related Parameters**

```bash
# ❌ BAD - 8 parameters
backup_files() {
    local src=$1
    local dest=$2
    local include_hidden=$3
    local exclude_pattern=$4
    local dry_run=$5
    local verbose=$6
    local compress=$7
    local encrypt=$8
}

# ✅ GOOD - Grouped into logical sets
backup_files() {
    local src=$1
    local dest=$2

    # Parse options
    local -A opts=(
        [include_hidden]=false
        [exclude_pattern]=""
        [dry_run]=false
        [verbose]=false
        [compress]=false
        [encrypt]=false
    )

    # Process options...
}
```

---

## Pattern 6: Logging Standards

**ALWAYS use centralized logging functions**

### ✅ GOOD - Ruby Logging

```ruby
# Use Logger module
Logger.log_success("Operation completed")
Logger.log_error("Failed to find file")
Logger.log_warning("Backup recommended")
Logger.log_info("Checking requirements")

# Script-specific logging
log_banner(script_title)
show_completion(script_title)
```

### ✅ GOOD - Shell Logging

```bash
# Use logging.zsh functions
log_success "Installation complete"
log_error "File not found"
log_warning "Deprecated feature"
log_info "Processing files"
log_progress "Downloading..."
log_section "Configuration"
log_file_created "/path/to/file"
```

### ❌ BAD - Raw Output

```ruby
# ❌ BAD - No color, no emoji, inconsistent
puts "Success!"
puts "ERROR: Failed"
puts "Warning: Something wrong"
```

```bash
# ❌ BAD - Raw echo
echo "Done"
echo "ERROR: Failed" >&2
```

**Why logging matters:**
- Consistent output format
- Color-coded for quick scanning
- Emoji for visual identification
- Proper stderr for errors
- Easy to grep logs

---

## Pattern 7: Working Directory Handling

**Scripts must respect user's original working directory**

### ✅ GOOD - Ruby Scripts

```ruby
class ScriptBase
  def initialize
    @original_working_dir = ENV['ORIGINAL_WORKING_DIR'] || Dir.pwd
  end

  # Use this instead of Dir.pwd
  def original_working_dir
    @original_working_dir
  end
end

# Usage in subclass
class FileProcessor < ScriptBase
  def run
    # ✅ Use original directory
    files = Dir.glob(File.join(original_working_dir, '*.txt'))
  end
end
```

### ✅ GOOD - Shell Scripts

```bash
# Wrapper sets ORIGINAL_WORKING_DIR
script_wrapper() {
    local script_path=$1
    shift
    ORIGINAL_WORKING_DIR="$PWD" "$script_path" "$@"
}

# Script uses it
process_files() {
    cd "$ZSH_CONFIG" || return 1
    # Do work in ZSH_CONFIG...

    # Reference files relative to user's directory
    local user_file="${ORIGINAL_WORKING_DIR}/file.txt"
}
```

### ❌ BAD - Using Current Directory

```ruby
# ❌ BAD - Assumes current directory
def process_files
  Dir.glob('*.txt').each do |file|
    # ❌ Will fail if script changed directory
  end
end
```

---

## Anti-Patterns to Avoid

### ❌ God Scripts

```ruby
# ❌ BAD - Doing everything in one script
class SystemManager
  def backup_xcode; end
  def backup_vscode; end
  def optimize_macos; end
  def setup_homebrew; end
  def configure_git; end
  def install_gems; end
  def setup_python; end
  # 50 more methods...
end
```

**Fix:** Split into focused scripts:
- `xcode-backup.sh` - Xcode only
- `vscode-backup.sh` - VSCode only
- `macos-optimize.sh` - macOS optimization
- etc.

### ❌ Hardcoded Paths

```bash
# ❌ BAD - Hardcoded paths
backup_dir="/Users/hemantv/Backups"
config_file="/Users/hemantv/.config/app/settings.json"
```

**Fix:** Use environment variables and relative paths:

```bash
# ✅ GOOD - Dynamic paths
backup_dir="${HOME}/Backups"
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/app/settings.json"
```

### ❌ No Error Handling

```bash
# ❌ BAD - No error handling
cp /source/file /dest/file
rm /important/file
```

**Fix:** Always check exit codes:

```bash
# ✅ GOOD - Error handling
set -euo pipefail

if ! cp /source/file /dest/file; then
    log_error "Failed to copy file"
    return 1
fi
```

### ❌ Missing Dry Run

```ruby
# ❌ BAD - No dry run option
def delete_files(files)
  files.each { |f| File.delete(f) }  # Irreversible!
end
```

**Fix:** Always support dry run:

```ruby
# ✅ GOOD - Dry run support
def delete_files(files)
  files.each do |f|
    if @options[:dry_run]
      log_info "Would delete: #{f}"
    else
      File.delete(f)
      log_success "Deleted: #{f}"
    end
  end
end
```

---

## Decision Tree: How to Structure Code

```
Start: I need to write a new script
│
├─ Is there a base class for this type?
│  ├─ YES → Inherit from it (ScriptBase, BaseImageInference, etc.)
│  │   └─ Override only what's needed
│  │
│  └─ NO → Create standalone script (but consider if base class is needed)
│
├─ How many parameters?
│  ├─ 0-2 → Direct parameters OK
│  ├─ 3-5 → Options hash/dict recommended
│  └─ 6+ → Refactor! (options pattern or extract class)
│
├─ Is logic repeated in other scripts?
│  ├─ YES → Extract to helper method or base class
│  │   └─ Put in .common/ or base class
│  │
│  └─ NO → Keep inline (but watch for future duplication)
│
├─ Does it modify files/system?
│  ├─ YES → MUST support --dry-run flag
│  │   └─ Show what would happen
│  │
│  └─ NO → Optional
│
└─ Did I add metadata headers?
   ├─ YES → Good! ✅
   └─ NO → Add @category and @description NOW
```

---

## Refactoring Checklist

When writing or refactoring scripts, check these:

### All Scripts

- [ ] Metadata headers present (@category, @description)
- [ ] Shebang line correct (#!/usr/bin/env ruby|python3|bash)
- [ ] ≤ 5 parameters per method/function
- [ ] Options hash/dict for 3+ parameters
- [ ] Uses centralized logging (no raw echo/puts)
- [ ] Respects original_working_dir
- [ ] Supports --dry-run for destructive operations
- [ ] Supports --help flag
- [ ] Error handling (exit codes, try/catch)
- [ ] No hardcoded paths (use env vars)

### Ruby Scripts

- [ ] Inherits from ScriptBase (if applicable)
- [ ] Uses frozen_string_literal: true
- [ ] Helper methods for repeated logic
- [ ] Executes with .execute if __FILE__ == $0
- [ ] Uses System.safe_execute for shell commands
- [ ] Uses Logger for all output

### Python Scripts

- [ ] Uses type hints
- [ ] Inherits from base class (if applicable)
- [ ] Options dict for configuration
- [ ] Helper functions extracted
- [ ] Proper main() function
- [ ] if __name__ == '__main__': guard

### Shell Scripts

- [ ] Uses set -euo pipefail
- [ ] Sources logging.zsh
- [ ] Functions instead of long scripts
- [ ] Quotes all variables ("$var")
- [ ] Uses local for function variables
- [ ] Returns proper exit codes

---

## Quick Reference

### Ruby Script Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: <category>
# @description: <one-line description>
# @tags: <tag1, tag2>

require_relative '../../bin/.common/script_base'

class MyScript < ScriptBase
  def script_emoji; '🔧'; end
  def script_title; 'My Script'; end
  def script_description; 'Does something useful'; end

  def add_custom_options(opts)
    opts.on('--custom', 'Custom option') do
      @options[:custom] = true
    end
  end

  def run
    log_banner(script_title)
    # Implementation here
    show_completion(script_title)
  end
end

MyScript.execute if __FILE__ == $0
```

### Python Script Template

```python
#!/usr/bin/env python3
# @category: <category>
# @description: <one-line description>
# @tags: <tag1, tag2>

import sys
from typing import Dict, Optional

class MyScript:
    def __init__(self, opts: Optional[Dict] = None):
        self.opts = opts or {}
        self.verbose = self.opts.get('verbose', False)

    def run(self):
        # Implementation here
        pass

def main():
    import argparse
    parser = argparse.ArgumentParser(description='My script')
    parser.add_argument('--verbose', action='store_true')
    args = parser.parse_args()

    script = MyScript(opts=vars(args))
    script.run()

if __name__ == '__main__':
    main()
```

### Shell Script Template

```bash
#!/bin/bash
# @category: <category>
# @description: <one-line description>
# @tags: <tag1, tag2>

set -euo pipefail
source "$ZSH_CONFIG/logging.zsh"

main() {
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    log_info "Starting process"
    # Implementation here
    log_success "Process complete"
}

main "$@"
```

---

## Summary

**Always remember:**
1. **Maximum 5 parameters** - anywhere, ever
2. **Metadata headers** - @category and @description required
3. **Options hash/dict** - for 3+ parameters
4. **Helper methods** - remove friction, hide complexity
5. **Base classes** - inherit common functionality
6. **Centralized logging** - use logging functions
7. **DRY** - don't repeat yourself
8. **Simple over clever** - boring code wins
9. **Dry run support** - for destructive operations
10. **Original working directory** - respect user's location

**The Golden Rules:**

> "Can I delete code instead of adding it?"
>
> "If I need more than 5 parameters, I'm doing too much"
>
> "Helper methods should remove friction, not add complexity"
>
> "Every script needs metadata headers - no exceptions"

Now go write beautiful, boring, maintainable scripts! 🚀
