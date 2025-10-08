# XCODE.md

_Xcode Project Management Documentation for Claude Code_

## Overview

Comprehensive Xcode project file management utilities for adding, viewing, and deleting files with automatic category detection and proper resource handling.

## Available Commands

### Core Utilities

```bash
xcode-add-file <file_path> [category]        # Add file with auto-detection
xcode-view-files [category]                  # View project files by category
xcode-delete-file <file_name>                # Remove file safely
xcode-list-categories                        # Show available categories
xcode-icon-generator                         # Generate app icons (run from project dir)
```

### Key Features

- **Automatic Project Detection**: Works in any Xcode project directory
- **Smart Category Inference**: Auto-detects file categories from paths and names
- **Resource File Handling**: Special handling for assets, plists, storyboards, etc.
- **Safe Deletion**: Handles different file types appropriately
- **Dry-run Support**: Preview changes before applying
- **Icon Generation**: Create modern app icons with customizable themes and colors

## File Categories

### Source Files

- **`app`** - App-level files (AppDelegate, SceneDelegate, main.swift, entitlements)
- **`ui`** - User interface components and views
- **`views`** - SwiftUI views and view components
- **`controllers`** - View controllers and navigation
- **`utils`** - General utilities and extensions
- **`models`** - Data models and Core ML models

### Resources

- **`resources`** - Assets, images, plists, storyboards, localization files

## Resource File Handling

### Asset Catalogs (.xcassets)
- Copied as entire directories to project root
- Automatically detected and included by Xcode
- No manual project file editing required

### Images (.png, .jpg, .jpeg, .pdf)
- Can be added to Assets.xcassets or as loose files
- Loose files placed in `ProjectName/Resources/Images/`
- Automatically added to Resources build phase

### Property Lists (.plist)
- **Info.plist**: Critical app configuration, placed in project root
- **Other plists**: Configuration resources in `ProjectName/Resources/`
- Accessible via `Bundle.main.path(forResource:ofType:)`

### Interface Builder (.storyboard, .xib)
- UI layout definitions placed in `ProjectName/UI/`
- Added to Resources build phase automatically
- Referenced via `UIStoryboard` or `loadNibNamed`

### Localization (.strings)
- Text localization files in `ProjectName/Resources/Localizable/`
- Support for language-specific folders (en.lproj, es.lproj)
- Added to Resources build phase

### Core ML Models (.mlmodel)
- Machine learning models in `ProjectName/Models/ML/`
- Xcode auto-generates Swift classes
- Accessible via Bundle and generated classes

## Usage Examples

### Adding Files

```bash
# Auto-detect category
xcode-add-file MyViewController.swift

# Specify category
xcode-add-file Helper.swift utils
xcode-add-file --category ui ContentView.swift

# Add resource with special handling
xcode-add-file Assets.xcassets              # Copies entire catalog
xcode-add-file icon.png                     # Provides asset/loose file options
xcode-add-file Info.plist                   # Warning about critical file
```

### Viewing Files

```bash
# View all project files
xcode-view-files

# Filter by category
xcode-view-files ui
xcode-view-files --category models

# Project summary only
xcode-view-files --summary
```

### Deleting Files

```bash
# Find and delete file
xcode-delete-file OldFile.swift

# Find only (no deletion)
xcode-delete-file Helper.swift --find-only

# Force deletion without confirmation
xcode-delete-file Test.swift --force

# Dry run to preview
xcode-delete-file --dry-run SomeFile.swift
```

### Category Management

```bash
# List all categories
xcode-list-categories

# Detailed info for specific category
xcode-list-categories ui

# Show with path patterns
xcode-list-categories --patterns

# JSON output
xcode-list-categories --json
```

### Icon Generation

```bash
# Generate all icons (run from project directory)
xcode-icon-generator

# Use minimal theme
xcode-icon-generator --theme minimal

# Generate iOS icons only
xcode-icon-generator --ios-only

# Use custom colors
xcode-icon-generator --color #FF6B6B --accent #4ECDC4

# Preview without generating
xcode-icon-generator --dry-run
```

**Icon Themes:**
- **modern**: Layered design with gradients and accents (default)
- **minimal**: Clean, simple circular design

**Color Options:**
- `--color`: Background color in hex format (e.g., #2D2D2D)
- `--accent`: Accent color in hex format (e.g., #0096FF)

**Generated Icons:**
- iOS: 1024px icons (normal, dark, tinted variants)
- macOS: All required sizes from 16px to 1024px

## Project Structure Detection

The utilities automatically detect:

- Project name from `.xcodeproj` directory
- Project file location (`project.pbxproj`)
- Existing directory structure
- File types and appropriate handling

## Common Options

### Global Flags
- `--dry-run` / `-d`: Preview changes without making them
- `--force` / `-f`: Skip confirmations
- `--verbose` / `-v`: Detailed output
- `--help` / `-h`: Show command help

### Category-specific Options
- `--category CATEGORY`: Specify file category
- `--list-categories`: Show available categories
- `--detailed`: Extended information display
- `--json`: JSON format output

## Safety Features

### Resource Protection
- **Info.plist**: Extra confirmation required
- **Asset Catalogs**: Directory-aware deletion
- **Interface Builder**: UI impact warnings
- **Core ML**: Functionality impact notices

### File System Safety
- Validates file existence before operations
- Creates directories only with confirmation
- Handles both files and directories appropriately
- Preserves important project structure

## Integration with Modern Xcode

### File System Synchronization
- Works with Xcode's modern `PBXFileSystemSynchronizedRootGroup`
- No manual project file editing required
- Xcode automatically detects file changes
- Build phases managed automatically

### Build Integration
- Files added to appropriate build phases
- Resources vs Sources detection
- Target inclusion handled by Xcode
- Clean project updates on next build

## Error Handling

### Common Issues
- **No project found**: Must be run in Xcode project directory
- **Unknown category**: Use `xcode-list-categories` to see available options
- **File exists**: Confirmation prompts prevent overwrites
- **Permission errors**: Clear error messages with resolution steps

### Recovery
- Dry-run mode for safe preview
- Detailed logging for troubleshooting
- Graceful handling of missing files
- Project validation before operations

## Best Practices

### File Organization
1. Use consistent category naming
2. Follow project directory structure
3. Group related files together
4. Keep resources properly organized

### Safe Operations
1. Always preview with `--dry-run` first
2. Use `--verbose` for detailed feedback
3. Backup project before bulk operations
4. Validate in Xcode after file operations

### Resource Management
1. Use Assets.xcassets for images when possible
2. Keep plists in appropriate directories
3. Organize localization files properly
4. Place Core ML models in dedicated folders

## Advanced Usage

### Batch Operations
```bash
# Process multiple files (shell loop)
for file in *.swift; do
  xcode-add-file "$file" utils
done

# Category-specific cleanup
xcode-view-files resources
# Review, then delete unwanted files
```

### Project Analysis
```bash
# Full project overview
xcode-view-files --summary

# Category breakdown
for cat in app ui views controllers utils models resources; do
  echo "=== $cat ==="
  xcode-view-files "$cat"
done
```

### Integration with Git
```bash
# Add files and review in git
xcode-add-file NewFeature.swift
git add .
git status
```

## Troubleshooting

### Common Solutions
- **Command not found**: Run `source ~/.zshrc` or restart terminal
- **Permission denied**: Check file permissions and ownership
- **Project not detected**: Ensure you're in the correct directory
- **Category mismatch**: Verify category names with `xcode-list-categories`

### Debug Mode
```bash
# Enable debug output
DEBUG=1 xcode-add-file MyFile.swift

# Verbose logging
xcode-add-file --verbose --debug MyFile.swift
```

---

**Note**: These utilities complement Xcode's built-in file management and are designed to work with modern Xcode project structures. Always validate changes in Xcode after running file operations.