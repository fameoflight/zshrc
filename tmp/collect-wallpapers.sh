#!/bin/bash
set -euo pipefail

# Source logging functions if available
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
else
    # Fallback logging functions
    log_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
    log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
    log_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
    log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
    log_progress() { echo -e "\033[0;36m🔄 $1\033[0m"; }
fi

# Configuration
SOURCE_DIR="$HOME/Downloads"
DEST_DIR="$HOME/Pictures/Wallpapers"
EXTENSIONS=("jpg" "jpeg" "png" "webp" "bmp" "tiff" "heic" "gif")

log_info "Wallpaper Collection Script"
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"

# Create destination directory
mkdir -p "$DEST_DIR"
log_success "Created destination directory: $DEST_DIR"

# Build find command with all extensions
find_cmd="find \"$SOURCE_DIR\" -type f \\("
for i in "${!EXTENSIONS[@]}"; do
    if [ $i -gt 0 ]; then
        find_cmd+=" -o"
    fi
    find_cmd+=" -iname \"*.${EXTENSIONS[$i]}\""
done
find_cmd+=" \\)"

# Preview what will be collected
log_info "Scanning for wallpapers..."
wallpaper_count=$(eval "$find_cmd" | wc -l)
log_info "Found $wallpaper_count wallpaper files"

if [ "$wallpaper_count" -eq 0 ]; then
    log_warning "No wallpaper files found in $SOURCE_DIR"
    exit 0
fi

# Ask for confirmation
read -p "Proceed with moving $wallpaper_count files? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Operation cancelled"
    exit 0
fi

# Move files with conflict handling
log_progress "Moving wallpapers..."
moved=0
skipped=0

eval "$find_cmd" -print0 | while IFS= read -r -d '' file; do
    basename=$(basename "$file")
    counter=1
    dest="$DEST_DIR/$basename"

    # Handle filename conflicts
    while [[ -e "$dest" ]]; do
        name="${basename%.*}"
        ext="${basename##*.}"
        dest="$DEST_DIR/${name}_${counter}.${ext}"
        ((counter++))
    done

    if mv "$file" "$dest"; then
        echo "✅ $(basename "$dest")"
        ((moved++))
    else
        echo "❌ Failed: $file"
        ((skipped++))
    fi
done

log_success "Wallpaper collection complete!"
echo "📊 Summary:"
echo "   • Moved: $moved files"
echo "   • Skipped: $skipped files"
echo "   • Location: $DEST_DIR"