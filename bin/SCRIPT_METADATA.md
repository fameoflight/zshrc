# Script Metadata Standard

## Header Format

All scripts must include metadata headers in this format:

```ruby
#!/usr/bin/env ruby
# @category: git
# @description: Split large commits into smaller logical commits
# @tags: automation, interactive
```

```python
#!/usr/bin/env python3
# @category: media
# @description: Upscale images using PyTorch models
# @tags: ml, image-processing
```

```bash
#!/bin/bash
# @category: setup
# @description: Configure Claude Code CLI
# @tags: configuration, ai
```

## Metadata Fields

### Required Fields

- **@category**: Primary category (see categories below)
- **@description**: One-line description of what the script does

### Optional Fields

- **@tags**: Comma-separated tags for additional filtering
- **@dependencies**: External tools required (e.g., `ffmpeg, imagemagick`)
- **@language**: Explicitly specify language if not obvious from extension

## Standard Categories

### Primary Categories

- **git** - Git operations and automation
- **media** - Image/video/audio processing
- **system** - System utilities and management
- **setup** - Installation and configuration scripts
- **backup** - Backup and restore tools
- **dev** - Development tools and utilities
- **files** - File operations and manipulation
- **data** - Data processing and analysis
- **communication** - Email, messaging, etc.

### Subcategories (via tags)

Use tags to add subcategories:
- `@tags: image, ml` - Media script for ML image processing
- `@tags: macos, optimization` - System script for macOS optimization
- `@tags: interactive, batch` - File operation with interactive UI

## Auto-Generation

The `categories.yml` file is **auto-generated** from these headers.

To regenerate after adding/updating headers:

```bash
generate-categories  # Scans all scripts and updates categories.yml
```

## Parsing Rules

1. Headers must appear in the first 10 lines of the file
2. Headers must start with `# @` (with space after #)
3. Format: `# @field: value`
4. Multi-word values don't need quotes
5. Tags are comma-separated, spaces optional

## Examples

### Ruby Script

```ruby
#!/usr/bin/env ruby
# @category: git
# @description: Intelligently rebase commits with automatic conflict resolution
# @tags: automation, interactive, rebase
# @dependencies: git

require_relative '../.common/script_base'
```

### Python Script

```python
#!/usr/bin/env python3
# @category: media
# @description: Upscale images using ESRGAN PyTorch models
# @tags: ml, image-processing, pytorch
# @dependencies: python3, pytorch

import sys
from python_cli.esrgan import ESRGANInference
```

### Shell Script

```bash
#!/bin/bash
# @category: backup
# @description: Backup Xcode settings and snippets
# @tags: xcode, macos, backup

set -euo pipefail
source "$ZSH_CONFIG/logging.zsh"
```

## Integration

### ZSH Completion

Completion uses `categories.yml` to provide:
- Category-based filtering: `list-scripts git<TAB>`
- Tag-based search: `find-script pytorch<TAB>`

### list-scripts Command

```bash
list-scripts              # All scripts grouped by category
list-scripts git          # Only git category
list-scripts --tag ml     # All scripts tagged 'ml'
list-scripts --lang ruby  # All Ruby scripts
```

## Maintenance

When adding new scripts:

1. Add metadata headers (required)
2. Run `generate-categories` to update categories.yml
3. Commit both the script and updated categories.yml

The CI/CD pipeline can validate that all scripts have proper headers.
