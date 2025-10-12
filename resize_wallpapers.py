#!/usr/bin/env python3
"""
Resize images larger than 2160 pixels to 2160px while maintaining aspect ratio.
"""

import os
import sys
from pathlib import Path
import time

try:
    from PIL import Image
    # Increase decompression bomb limit for large wallpaper images
    Image.MAX_IMAGE_PIXELS = None
except ImportError:
    print("❌ PIL (Pillow) not found. Install with: pip3 install Pillow")
    sys.exit(1)

def show_progress_bar(current, total, length=50):
    """Display a simple progress bar."""
    percent = current / total
    filled_length = int(length * percent)
    bar = '█' * filled_length + '-' * (length - filled_length)
    print(f'\rProgress: |{bar}| {current}/{total} ({percent:.1%})', end='', flush=True)

def get_image_dimensions(image_path):
    """Get image dimensions using PIL."""
    try:
        with Image.open(image_path) as img:
            return img.width, img.height
    except Exception as e:
        print(f"Error reading {os.path.basename(image_path)}: {e}")
        return None, None

def resize_image(image_path, max_dimension=2160):
    """Resize image to fit within max_dimension while maintaining aspect ratio."""
    try:
        with Image.open(image_path) as img:
            width, height = img.size

            # Check if resizing is needed
            if width <= max_dimension and height <= max_dimension:
                return False  # No resizing needed

            # Calculate new dimensions maintaining aspect ratio
            if width > height:
                new_width = max_dimension
                new_height = int(height * max_dimension / width)
            else:
                new_height = max_dimension
                new_width = int(width * max_dimension / height)

            # Resize the image
            img_resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

            # Save the resized image (same format and quality)
            img_resized.save(image_path, optimize=True, quality=95)

            print(f"✅ Resized: {os.path.basename(image_path)} ({width}x{height} → {new_width}x{new_height})")
            return True

    except Exception as e:
        print(f"❌ Failed to resize {os.path.basename(image_path)}: {e}")
        return False

def main():
    wallpapers_dir = "/Users/hemantv/Pictures/Wallpapers"
    max_dimension = 2160

    if not os.path.exists(wallpapers_dir):
        print(f"❌ Directory not found: {wallpapers_dir}")
        sys.exit(1)

    # Supported image extensions
    extensions = {'.jpg', '.jpeg', '.png', '.webp', '.tiff', '.heic'}

    # Find all image files
    image_files = []
    for root, dirs, files in os.walk(wallpapers_dir):
        for file in files:
            if Path(file).suffix.lower() in extensions:
                image_files.append(os.path.join(root, file))

    print(f"🔍 Found {len(image_files)} total images")

    # Count images that need resizing
    need_resize = 0
    large_images = []

    print("\n📏 Analyzing image sizes...")
    for i, image_path in enumerate(image_files, 1):
        show_progress_bar(i, len(image_files))
        width, height = get_image_dimensions(image_path)
        if width and height and (width > max_dimension or height > max_dimension):
            need_resize += 1
            large_images.append(image_path)
    print()  # New line after progress bar

    print(f"📊 Found {need_resize} images larger than {max_dimension}px")

    if need_resize == 0:
        print("✅ All images are already appropriately sized!")
        return

    # Ask for confirmation (skip if --yes argument provided)
    if len(sys.argv) > 1 and sys.argv[1] == '--yes':
        print(f"🔄 Auto-confirming resize of {need_resize} images to {max_dimension}px")
    else:
        response = input(f"\n🔄 Resize {need_resize} images to {max_dimension}px (maintaining aspect ratio)? [y/N]: ")
        if response.lower() != 'y':
            print("❌ Operation cancelled")
            return

    # Resize images
    print(f"\n🔄 Resizing images...")
    success_count = 0

    for i, image_path in enumerate(large_images, 1):
        show_progress_bar(i, len(large_images), 40)
        if resize_image(image_path, max_dimension):
            success_count += 1
    print()  # New line after progress bar

    print(f"\n✅ Successfully resized {success_count}/{len(large_images)} images")

if __name__ == "__main__":
    main()