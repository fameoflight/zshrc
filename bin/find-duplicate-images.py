#!/usr/bin/env python3
"""
Duplicate Image Finder using File Analysis
Finds duplicate images using file hashing and similarity comparison
"""

import sys
import os
import argparse
import hashlib
from python_cli.utils import safe_remove_file
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import shutil

import cv2
import numpy as np


class DuplicateImageFinder:
    """Find duplicate images using file analysis and comparison"""

    def __init__(self):
        self.supported_formats = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.webp'}

    def get_image_info(self, image_path: str) -> Optional[Dict]:
        """Get basic image information"""
        try:
            img = cv2.imread(image_path)
            if img is None:
                return None

            height, width = img.shape[:2]
            file_size = os.path.getsize(image_path)

            return {
                'width': width,
                'height': height,
                'file_size': file_size
            }
        except Exception:
            return None

    def calculate_file_hash(self, file_path: str) -> str:
        """Calculate MD5 hash of file"""
        hash_md5 = hashlib.md5()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception:
            return ""

    def find_image_files(self, directory: str, min_size: int = 10240) -> List[str]:
        """Find all image files in directory"""
        directory_path = Path(directory)
        if not directory_path.exists():
            return []

        image_files = []
        for ext in self.supported_formats:
            image_files.extend(directory_path.rglob(f'*{ext}'))
            image_files.extend(directory_path.rglob(f'*{ext.upper()}'))

        # Filter by minimum size
        valid_files = [
            str(f) for f in image_files
            if f.stat().st_size >= min_size
        ]

        return valid_files

    def sizes_similar(self, size1: int, size2: int, tolerance: float = 0.05) -> bool:
        """Check if file sizes are similar within tolerance"""
        if size1 == 0 or size2 == 0:
            return False

        ratio = max(size1, size2) / min(size1, size2)
        return ratio <= (1.0 + tolerance)

    def files_similar(self, file1: str, file2: str) -> bool:
        """Check if two image files are similar"""
        # Same extension check
        ext1 = Path(file1).suffix.lower()
        ext2 = Path(file2).suffix.lower()
        if ext1 != ext2:
            return False

        try:
            info1 = self.get_image_info(file1)
            info2 = self.get_image_info(file2)

            if not info1 or not info2:
                return True  # Can't determine, assume similar

            # Check dimensions (within 10 pixels)
            width_diff = abs(info1['width'] - info2['width'])
            height_diff = abs(info1['height'] - info2['height'])

            return width_diff <= 10 and height_diff <= 10

        except Exception:
            return True  # If we can't determine, assume similar

    def find_duplicates_strict(self, image_files: List[str]) -> Dict[str, List[str]]:
        """Find exact duplicates using file hashing"""
        duplicates = {}

        # Group by file hash
        hash_groups = {}
        for file_path in image_files:
            file_hash = self.calculate_file_hash(file_path)
            if file_hash:
                if file_hash not in hash_groups:
                    hash_groups[file_hash] = []
                hash_groups[file_hash].append(file_path)

        # Keep only groups with multiple files
        for file_hash, files in hash_groups.items():
            if len(files) > 1:
                duplicates[file_hash] = files

        return duplicates

    def find_duplicates_standard(self, image_files: List[str]) -> Dict[str, List[str]]:
        """Find duplicates using file size + hash combination"""
        duplicates = {}

        # Group by file size first (more efficient)
        size_groups = {}
        for file_path in image_files:
            try:
                file_size = os.path.getsize(file_path)
                if file_size not in size_groups:
                    size_groups[file_size] = []
                size_groups[file_size].append(file_path)
            except OSError:
                continue

        # Within same size groups, check hash
        for size, files in size_groups.items():
            if len(files) <= 1:
                continue

            hash_groups = {}
            for file_path in files:
                file_hash = self.calculate_file_hash(file_path)
                if file_hash:
                    if file_hash not in hash_groups:
                        hash_groups[file_hash] = []
                    hash_groups[file_hash].append(file_path)

            # Keep only groups with multiple files
            for file_hash, hash_files in hash_groups.items():
                if len(hash_files) > 1:
                    duplicates[file_hash] = hash_files

        return duplicates

    def find_similar_duplicates(self, image_files: List[str]) -> Dict[str, List[str]]:
        """Find similar duplicates using file size and basic comparison"""
        duplicates = {}
        processed = []

        for i, file1 in enumerate(image_files):
            if file1 in processed:
                continue

            try:
                size1 = os.path.getsize(file1)
                similar_files = [file1]

                for file2 in image_files[i+1:]:
                    if file2 in processed:
                        continue

                    size2 = os.path.getsize(file2)

                    # Check if sizes are similar (within 5%)
                    if self.sizes_similar(size1, size2):
                        # Additional similarity checks
                        if self.files_similar(file1, file2):
                            similar_files.append(file2)
                            processed.append(file2)

                processed.append(file1)

                if len(similar_files) > 1:
                    file_hash = self.calculate_file_hash(file1)
                    duplicates[file_hash] = similar_files

            except OSError:
                continue

        return duplicates

    def find_duplicates(self, image_files: List[str], mode: str = 'standard') -> Dict[str, List[str]]:
        """Find duplicates based on mode"""
        if mode == 'strict':
            return self.find_duplicates_strict(image_files)
        elif mode == 'tolerant':
            return self.find_similar_duplicates(image_files)
        else:  # standard
            return self.find_duplicates_standard(image_files)

    def show_duplicates(self, duplicates: Dict[str, List[str]]):
        """Display duplicate groups"""
        if not duplicates:
            print("✅ No duplicate images found!")
            return

        total_duplicates = sum(len(files) - 1 for files in duplicates.values())
        total_space_saved = 0

        print(f"\n🔍 Found {len(duplicates)} duplicate groups ({total_duplicates} duplicate files)")
        print("=" * 80)

        for group_index, (file_hash, files) in enumerate(duplicates.items(), 1):
            print(f"\n📁 Group {group_index}: {len(files)} duplicates")
            print("-" * 50)

            original = files[0]
            dup_files = files[1:]

            # Original file
            size_mb = os.path.getsize(original) / (1024 * 1024)
            mtime = os.path.getmtime(original)
            mtime_str = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M')

            print(f"  📄 Original: {original}")
            print(f"      Size: {size_mb:.1f}MB | Modified: {mtime_str}")

            # Duplicate files
            for i, dup_file in enumerate(dup_files, 1):
                dup_size_mb = os.path.getsize(dup_file) / (1024 * 1024)
                dup_mtime = os.path.getmtime(dup_file)
                dup_mtime_str = datetime.fromtimestamp(dup_mtime).strftime('%Y-%m-%d %H:%M')

                print(f"  📄 Duplicate {i}: {dup_file}")
                print(f"      Size: {dup_size_mb:.1f}MB | Modified: {dup_mtime_str}")
                total_space_saved += os.path.getsize(dup_file)

        print(f"\n💾 Total space that could be saved: {total_space_saved / (1024 * 1024):.1f}MB")

    def delete_duplicates(self, duplicates: Dict[str, List[str]], confirm: bool = True) -> int:
        """Delete duplicate files"""
        total_files = sum(len(files) - 1 for files in duplicates.values())

        if confirm:
            response = input(f"\n🗑️  Delete {total_files} duplicate files? [y/N]: ").strip().lower()
            if response not in ['y', 'yes']:
                print("Cancelled.")
                return 0

        total_deleted = 0
        total_space_freed = 0

        for file_hash, files in duplicates.items():
            dup_files = files[1:]  # Keep first file as original

            for dup_file in dup_files:
                try:
                    size = os.path.getsize(dup_file)
                    safe_remove_file(dup_file)
                    total_deleted += 1
                    total_space_freed += size
                    print(f"✅ Moved to trash: {dup_file}")
                except Exception as e:
                    print(f"❌ Failed to delete {dup_file}: {e}")

        space_freed_mb = total_space_freed / (1024 * 1024)
        print(f"\n✅ Deleted {total_deleted} files, freed {space_freed_mb:.1f}MB")
        return total_deleted

    def move_duplicates(self, duplicates: Dict[str, List[str]], move_to: str) -> int:
        """Move duplicate files to directory"""
        move_path = Path(move_to)
        move_path.mkdir(parents=True, exist_ok=True)

        total_files = sum(len(files) - 1 for files in duplicates.values())

        response = input(f"\n📁 Move {total_files} duplicate files to {move_to}? [y/N]: ").strip().lower()
        if response not in ['y', 'yes']:
            print("Cancelled.")
            return 0

        moved_count = 0

        for file_hash, files in duplicates.items():
            dup_files = files[1:]  # Keep first file as original

            for dup_file in dup_files:
                try:
                    original_path = Path(dup_file)
                    new_name = move_path / original_path.name

                    # Handle name conflicts
                    counter = 1
                    while new_name.exists():
                        stem = original_path.stem
                        suffix = original_path.suffix
                        new_name = move_path / f"{stem}_{counter}{suffix}"
                        counter += 1

                    shutil.move(dup_file, new_name)
                    moved_count += 1
                    print(f"✅ Moved: {dup_file} -> {new_name}")
                except Exception as e:
                    print(f"❌ Failed to move {dup_file}: {e}")

        print(f"\n✅ Moved {moved_count} files to {move_to}")
        return moved_count


def main():
    parser = argparse.ArgumentParser(
        description='Find duplicate images using file analysis',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s ~/Pictures                           # Find duplicates in Pictures
  %(prog)s --strict ~/Photos                    # Exact matches only
  %(prog)s --tolerant --delete ~/Downloads      # Find similar and delete
  %(prog)s --move-to ~/Duplicates ~/Photos      # Move duplicates to folder
  %(prog)s --min-size 100 ~/Wallpapers          # Ignore files smaller than 100KB
        """
    )

    parser.add_argument('directory', help='Directory to search for duplicates')
    parser.add_argument('--strict', action='store_true', help='Strict mode (exact matches only)')
    parser.add_argument('--tolerant', action='store_true', help='Tolerant mode (similar images)')
    parser.add_argument('--min-size', type=int, default=10240, help='Minimum file size in bytes (default: 10KB)')
    parser.add_argument('--delete', action='store_true', help='Prompt to delete duplicates')
    parser.add_argument('--move-to', metavar='PATH', help='Move duplicates to directory')
    parser.add_argument('--quiet', action='store_true', help='Less verbose output')

    args = parser.parse_args()

    if not os.path.exists(args.directory):
        print(f"❌ Directory not found: {args.directory}")
        sys.exit(1)

    # Determine scan mode
    if args.strict:
        mode = 'strict'
        mode_desc = 'Strict (exact matches)'
    elif args.tolerant:
        mode = 'tolerant'
        mode_desc = 'Tolerant (similar images)'
    else:
        mode = 'standard'
        mode_desc = 'Standard (exact + metadata)'

    # Create finder instance
    finder = DuplicateImageFinder()

    if not args.quiet:
        print("🔍 Duplicate Image Finder")
        print(f"Scanning: {args.directory}")
        print(f"Mode: {mode_desc}")
        print(f"Minimum size: {args.min_size // 1024}KB")
        print()

    # Find image files
    image_files = finder.find_image_files(args.directory, args.min_size)

    if not image_files:
        print("⚠️  No image files found")
        sys.exit(0)

    if not args.quiet:
        print(f"📊 Found {len(image_files)} image files")

    # Find duplicates
    duplicates = finder.find_duplicates(image_files, mode)

    if not duplicates:
        if not args.quiet:
            print("✅ No duplicate images found!")
        sys.exit(0)

    # Show results
    finder.show_duplicates(duplicates)

    # Handle actions
    if args.delete:
        finder.delete_duplicates(duplicates, confirm=not args.quiet)
    elif args.move_to:
        finder.move_duplicates(duplicates, args.move_to)


if __name__ == '__main__':
    main()