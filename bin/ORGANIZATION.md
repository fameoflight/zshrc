# Script Organization System

**Status**: ✅ Complete
**Date**: 2025-11-16
**Scripts Organized**: 56 scripts across 9 categories

## Overview

The zshrc repository now uses a metadata-based organization system that maintains the existing directory structure while adding powerful discovery and categorization capabilities.

## Quick Start

```bash
# Discover all scripts by category
list-scripts

# Filter by specific category
list-scripts git
list-scripts media
list-scripts dev

# Use tab completion
list-scripts <TAB>    # Shows all categories with counts

# Regenerate categories.yml
generate-categories

# Validate all metadata
generate-categories --validate

# Find scripts without headers
generate-categories --missing
```

## Organization Structure

### Directory Layout (Unchanged)

```
bin/
├── ruby-cli/bin/          # 41 Ruby scripts
├── python-cli/            # 10 Python scripts
├── *.sh                   # 12 Shell scripts
├── categories.yml         # Auto-generated metadata
└── ORGANIZATION.md        # This file
```

**Key principle**: Files stay in their language-specific directories. Organization is via metadata, not file movement.

### Metadata Headers

All scripts include standardized headers:

**Ruby Example:**
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Split large commits into smaller logical commits
# @tags: automation, interactive
```

**Python Example:**
```python
#!/usr/bin/env python3
# @category: media
# @description: PyTorch inference CLI for image processing
# @tags: ml, pytorch, image-processing
```

**Shell Example:**
```bash
#!/bin/bash
# @category: setup
# @description: Configure Claude Code CLI settings
# @tags: claude, ai, symlink
```

## Categories

### 🐙 git (9 scripts)
Git utilities and automation tools
- git-commit-deletes.rb, git-commit-dir.rb, git-commit-renames.rb
- git-commit-splitter.rb, git-smart-rebase.rb, git-compress.rb
- git-history.rb, git-common.rb, git-template.rb

### 🎬 media (3 scripts)
Video/audio/image processing and manipulation
- clip-video.rb, youtube-transcript-chat.rb
- watermark_detector.py

### ⚙️ system (9 scripts)
System configuration and management
- battery-info.rb, game-mode.rb, spotlight-manage.rb
- stacked-monitor.rb, check-camera-mic.rb, uninstall-app.rb
- network-speed.rb, calibre-update.sh, macos-oled-optimize.sh

### 🛠️ setup (7 scripts)
Installation and setup automation
- agent-setup.sh, claude-setup.sh, gemini-setup.sh
- iterm-setup.sh, setup-hooks.sh, macos-optimize.sh
- setup-dev-tools.rb

### 💾 backup (4 scripts)
Backup and restore utilities
- dropbox-backup.sh, iterm-backup.sh
- vscode-backup.sh, xcode-backup.sh

### 🔧 dev (15 scripts)
Development tools (Xcode, Electron, etc.)
- xcode-icon-generator.rb, xcode-add-file.rb, xcode-delete-file.rb
- xcode-view-files.rb, xcode-list-categories.rb
- auto-retry.rb, console-log-remover.rb, electron-icon-generator.rb
- llm-generate.rb, generate-categories.rb, investigate-naval-js.rb
- test-click-naval.rb
- convert_to_coreml.py, rife_arch.py

### 📁 files (7 scripts)
File operations and utilities
- change-extension.rb, comment-only-changes.rb, largest-files.rb
- merge-markdown.rb, merge-pdf.rb, safari-epub.rb, website-epub.rb

### 📊 data (1 script)
Data processing and analysis
- openrouter-usage.rb

### 📧 communication (1 script)
Email and messaging tools
- gmail-inbox.rb

## Tools

### generate-categories

Auto-generates `categories.yml` from script headers.

**Location**: `bin/ruby-cli/bin/generate-categories.rb`

**Features**:
- Scans all scripts for @category, @description, @tags
- Generates YAML with metadata and statistics
- Validates metadata integrity
- Identifies scripts missing headers
- No external dependencies (standalone Ruby)

**Usage**:
```bash
generate-categories                    # Generate categories.yml
generate-categories --validate         # Validate all metadata
generate-categories --missing          # Show scripts without headers
generate-categories --output path.yml  # Custom output path
```

**Output Format** (categories.yml):
```yaml
version: '1.0'
generated_at: '2025-11-16T17:24:19Z'
categories:
  git:
    - name: git-commit-deletes.rb
      path: bin/ruby-cli/bin/git-commit-deletes.rb
      language: Ruby
      description: Commit only deleted files with interactive confirmation
      tags:
        - automation
        - interactive
        - cleanup
statistics:
  total_scripts: 56
  total_categories: 9
  by_language:
    Ruby: 41
    Shell: 12
    Python: 3
```

### list-scripts

Enhanced discovery interface with category filtering.

**Location**: `bin/scripts.zsh`

**Features**:
- Reads from categories.yml
- Category filtering support
- Rich emoji formatting
- Tab completion for categories
- Shows statistics and metadata

**Usage**:
```bash
list-scripts              # Show all scripts by category
list-scripts git          # Show only git scripts
list-scripts media        # Show only media scripts
list-scripts <TAB>        # Tab complete categories
```

**Output Example**:
```
📜 Custom Scripts by Category
Generated: 2025-11-16T17:24:19Z
Total: 56 scripts in 9 categories
============================================================

🐙 Git (9 scripts):
   💎 git-commit-deletes.rb       Commit only deleted files
   💎 git-commit-splitter.rb      Split large commits
   ...

🎬 Media (3 scripts):
   💎 clip-video.rb               Clip video segments
   🐍 watermark_detector.py       Detect watermarks in images
   ...
```

## Tab Completion

ZSH tab completion is available for category filtering.

**Location**: `functions.d/_list-scripts`

**Features**:
- Completes category names
- Shows script counts in descriptions
- Dynamic emoji indicators
- Error handling for missing categories.yml

**Example**:
```bash
list-scripts <TAB>

# Shows:
backup          💾 4 scripts
communication   📧 1 scripts
data            📊 1 scripts
dev             🔧 15 scripts
...
```

## Workflow

### Adding a New Script

1. **Create script with metadata header**:
   ```ruby
   #!/usr/bin/env ruby
   # frozen_string_literal: true
   # @category: git
   # @description: Your script description
   # @tags: tag1, tag2, tag3
   ```

2. **Regenerate categories.yml**:
   ```bash
   generate-categories
   ```

3. **Verify**:
   ```bash
   list-scripts git    # Should show your new script
   ```

4. **Commit both files**:
   ```bash
   git add bin/ruby-cli/bin/your-script.rb bin/categories.yml
   git commit -m "Add your-script with git category"
   ```

### Validating Organization

```bash
# Check all scripts have valid metadata
generate-categories --validate

# Find scripts missing headers
generate-categories --missing

# Test category filtering
list-scripts git
list-scripts media
list-scripts dev
```

### Maintaining the System

**When to regenerate categories.yml**:
- After adding new scripts
- After modifying metadata headers
- After renaming scripts
- Before committing changes

**Best practices**:
- Always include @category (required)
- Provide clear @description (recommended)
- Add relevant @tags (recommended)
- Test with `list-scripts` before committing
- Run `generate-categories --validate` periodically

## Statistics

**Current Distribution** (as of 2025-11-16):

```
Categories:
  backup:         4 scripts (7%)
  communication:  1 script  (2%)
  data:           1 script  (2%)
  dev:           15 scripts (27%)
  files:          7 scripts (13%)
  git:            9 scripts (16%)
  media:          3 scripts (5%)
  setup:          7 scripts (13%)
  system:         9 scripts (16%)

Languages:
  Ruby:   41 scripts (73%)
  Shell:  12 scripts (21%)
  Python:  3 scripts (5%)

Total: 56 scripts across 9 categories
```

## Implementation Details

### Files Modified/Created

**New Files**:
- `bin/categories.yml` - Auto-generated metadata
- `bin/ruby-cli/bin/generate-categories.rb` - Generation tool
- `functions.d/_list-scripts` - ZSH completion
- `bin/ORGANIZATION.md` - This documentation

**Modified Files**:
- `bin/scripts.zsh` - Enhanced list-scripts function
- `bin/ruby-cli/scripts.zsh` - Added generate-categories wrapper
- `AGENT.md` / `CLAUDE.md` - Added organization documentation
- 62 script files - Added metadata headers

### Git History

**Branch**: `claude/organize-zshrc-017tJYfw2RwJsT5xf4gQbbz7`

**Commits** (7 total):
1. Add metadata headers to all Shell scripts
2. Remove duplicate dropbox-backup copy.sh file
3. Add generate-categories tool and initial categories.yml
4. Add generate-categories wrapper function
5. Enhance list-scripts with category filtering
6. Add ZSH tab completion for list-scripts
7. Document script organization system in AGENT.md

## Future Enhancements

**Potential improvements**:
- Add tag-based filtering: `list-scripts --tag interactive`
- Support for multiple categories per script
- Search by description keywords
- Usage tracking and recommendations
- Auto-completion for individual script names
- Integration with `scripts` unified interface
- Category-based script aliasing

## Troubleshooting

**Issue**: `categories.yml not found` error
```bash
# Solution: Generate it
generate-categories
```

**Issue**: Script not showing in list-scripts
```bash
# Check if metadata headers exist
grep -n "@category:" bin/ruby-cli/bin/your-script.rb

# Regenerate categories
generate-categories

# Verify
list-scripts your-category
```

**Issue**: Validation errors
```bash
# See what's wrong
generate-categories --validate

# Find missing headers
generate-categories --missing
```

**Issue**: Tab completion not working
```bash
# Reload ZSH completion
source ~/.zshrc

# Or reload just the completion
autoload -U compinit && compinit
```

## References

- **SCRIPTS.md** - Complete script development guide
- **AGENT.md / CLAUDE.md** - Repository documentation for Claude Code
- **SCRIPT_METADATA.md** - Detailed metadata header specification
- **ORGANIZE_PLAN.md** - Original implementation plan and progress tracking
- **RULES.md** - Script development patterns and best practices
- **PRINCIPLES.md** - Universal software engineering principles

---

**Maintained by**: Claude Code organization system
**Last updated**: 2025-11-16
**Status**: Production Ready ✅
