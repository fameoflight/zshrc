#!/usr/bin/env python3
"""
Similar Image Search using Computer Vision
Finds visually similar images in a database using OpenCV feature extraction
"""

import sys
import os
import argparse
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional, Any
from python_cli.utils import safe_remove_file, create_progress_bar
from python_cli.image_utils import ImageFile, ImageDiscovery, ImageAnalysis, ImageComparison, save_hash_cache
from python_cli.cache_manager import CacheManager

import cv2
import numpy as np


class SimilarImageSearch:
    """Similar image search system using OpenCV features"""

    def __init__(self, cache_name: str = None):
        if cache_name is None:
            cache_name = 'similar-images'

        self.cache_manager = CacheManager(cache_name)
        self.index_file = self.cache_manager.cache_dir / 'image_index.json'
        self.image_index = self.load_image_index()
        # No need to store supported formats - use ImageDiscovery class

    def load_image_index(self) -> Dict[str, Any]:
        """Load image index from cache"""
        if self.index_file.exists():
            try:
                with open(self.index_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(f"⚠️  Warning: Could not load image index: {e}")
        return {}

    def save_image_index(self):
        """Save image index to cache atomically"""
        temp_file = self.index_file.with_suffix('.tmp')
        try:
            with open(temp_file, 'w') as f:
                json.dump(self.image_index, f, indent=2)
            temp_file.replace(self.index_file)  # Atomic operation
        except IOError as e:
            print(f"⚠️  Warning: Could not save image index: {e}")
            # Clean up temp file if it exists
            if temp_file.exists():
                temp_file.unlink()

    def init_cache(self):
        """Initialize cache system for image features"""
        print(f"✅ Cache initialized: {self.cache_manager.cache_dir}")

    def extract_opencv_features(self, image_path: str) -> Dict[str, Any]:
        """Extract comprehensive features using OpenCV"""
        # Use shared feature extraction from ImageAnalysis
        features = ImageAnalysis.extract_opencv_features(image_path)

        # Convert numpy arrays to lists for JSON serialization
        return {
            key: (value.tolist() if isinstance(value, np.ndarray) else value)
            for key, value in features.items()
        }

    def add_directory(self, directory_path: str, min_size: int = 10240):
        """Add all images from directory to cache"""
        directory = Path(directory_path)
        if not directory.exists():
            print(f"❌ Directory not found: {directory_path}")
            return

        print(f"🔍 Scanning directory: {directory_path}")

        # Use shared image discovery with built-in progress
        image_objects = ImageDiscovery.find_images(directory_path, min_size, show_progress=True)

        print(
            f"📊 Found {len(image_objects)} image files (min size: {min_size} bytes)")

        if not image_objects:
            print("⚠️  No valid image files found")
            return

        # Initialize cache
        self.init_cache()

        added_count = 0
        skipped_count = 0
        save_interval = 50  # Save every 50 images

        print("🔍 Extracting features and adding to cache...")

        # Create progress bar for processing
        progress_bar = create_progress_bar(
            image_objects,
            desc="Processing images"
        )

        for i, image_obj in enumerate(progress_bar):
            file_path = image_obj.file_path

            # Check if already exists in cache
            if self.cache_manager.is_cached(file_path):
                skipped_count += 1
                continue

            # Use ImageFile metadata
            if not image_obj.info:
                continue

            # Extract features
            features = self.extract_opencv_features(file_path)
            if not features:
                continue

            # Cache the features with auto-save
            self.cache_manager.cache_data(file_path, features, file_path, auto_save=True)

            # Update image index for quick lookup
            self.image_index[file_path] = {
                'width': image_obj.width,
                'height': image_obj.height,
                'file_size': image_obj.file_size,
                'aspect_ratio': image_obj.info.get('aspect_ratio', 0),
                'added_at': datetime.now().isoformat()
            }

            added_count += 1

            # Save progress periodically (every save_interval images)
            if added_count % save_interval == 0:
                self.save_image_index()
                save_hash_cache()
                print(f"\n💾 Saved progress: {added_count} images processed")

        # Final save
        self.save_image_index()
        save_hash_cache()

        print(f"✅ Completed!")
        print(f"   • Added: {added_count} new images")
        print(f"   • Skipped: {skipped_count} existing images")
        print(f"   • Cache: {self.cache_manager.cache_dir}")

    def find_duplicates(self, directory_path: str, min_size: int = 10240):
        """Find duplicate images in directory using shared comparison logic."""
        directory = Path(directory_path)
        if not directory.exists():
            print(f"❌ Directory not found: {directory_path}")
            return

        print(f"🔍 Scanning directory for duplicates: {directory_path}")
        print(f"Mode: Tolerant (similar images by size and dimensions)")
        print(f"Minimum size: {min_size // 1024}KB")

        # Use shared image discovery with progress
        image_objects = ImageDiscovery.find_images(directory_path, min_size, show_progress=True)

        if not image_objects:
            print("⚠️  No image files found")
            return

        print(f"📊 Found {len(image_objects)} image files")

        # Find duplicates using shared comparison logic
        duplicates = ImageComparison.similar_by_size(
            image_objects,
            size_tolerance=0.05,  # 5% size tolerance
            dimension_tolerance=10,  # 10 pixels tolerance
            same_extension=True
        )

        if not duplicates:
            print("✅ No duplicate images found!")
            return

        # Show duplicate results
        self._show_duplicates(duplicates)

    def _show_duplicates(self, duplicates: Dict[str, List[ImageFile]]):
        """Display duplicate groups (adapted from find-duplicate-images.py)."""
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
            size_mb = original.file_size / (1024 * 1024) if original.file_size else 0
            mtime = os.path.getmtime(original.file_path)
            mtime_str = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M')

            print(f"  📄 Original: {original.file_path}")
            print(f"      Size: {size_mb:.1f}MB | Modified: {mtime_str}")

            # Duplicate files
            for i, dup_file in enumerate(dup_files, 1):
                dup_size_mb = dup_file.file_size / (1024 * 1024) if dup_file.file_size else 0
                dup_mtime = os.path.getmtime(dup_file.file_path)
                dup_mtime_str = datetime.fromtimestamp(dup_mtime).strftime('%Y-%m-%d %H:%M')

                print(f"  📄 Duplicate {i}: {dup_file.file_path}")
                print(f"      Size: {dup_size_mb:.1f}MB | Modified: {dup_mtime_str}")
                total_space_saved += dup_file.file_size or 0

        print(f"\n💾 Total space that could be saved: {total_space_saved / (1024 * 1024):.1f}MB")

    def calculate_similarity(self, features1: Dict, features2: Dict) -> float:
        """Calculate similarity between two feature sets"""
        # Convert lists back to numpy arrays for similarity calculation
        features1_arrays = {
            key: np.array(value) if isinstance(value, list) else value
            for key, value in features1.items()
        }
        features2_arrays = {
            key: np.array(value) if isinstance(value, list) else value
            for key, value in features2.items()
        }

        # Use shared similarity calculation from ImageAnalysis
        return ImageAnalysis.calculate_similarity(features1_arrays, features2_arrays)

    def search_similar_images(self, query_image: str, max_results: int = 10, threshold: float = 0.3) -> List[Tuple[str, float]]:
        """Find similar images to query image"""
        if not os.path.exists(query_image):
            print(f"❌ Query image not found: {query_image}")
            return []

        if not self.image_index:
            print(f"❌ No cached images found")
            print("💡 Use --add to build a cache first")
            return []

        print(f"🔍 Searching for images similar to: {query_image}")

        # Extract features from query image
        query_features = self.extract_opencv_features(query_image)
        if not query_features:
            print("❌ Could not extract features from query image")
            return []

        results = []

        # Iterate through all cached images except the query image itself
        for file_path in self.image_index.keys():
            if os.path.abspath(file_path) == os.path.abspath(query_image):
                continue

            # Get cached features for this image
            cached_features = self.cache_manager.get_cached_data(file_path)
            if cached_features:
                similarity = self.calculate_similarity(query_features, cached_features)
                if similarity >= threshold:
                    results.append((file_path, similarity))

        # Sort by similarity (descending) and limit results
        results.sort(key=lambda x: x[1], reverse=True)
        return results[:max_results]

    def show_statistics(self):
        """Display cache statistics"""
        if not self.image_index:
            print("❌ No cached images found")
            return

        # Get cache information
        cache_info = self.cache_manager.get_cache_info()
        cache_stats = self.cache_manager.get_cache_stats()

        # Calculate statistics from image index
        total_images = len(self.image_index)
        widths = [info['width'] for info in self.image_index.values() if info.get('width')]
        heights = [info['height'] for info in self.image_index.values() if info.get('height')]

        avg_width = sum(widths) / len(widths) if widths else 0
        avg_height = sum(heights) / len(heights) if heights else 0
        min_width = min(widths) if widths else 0
        min_height = min(heights) if heights else 0
        max_width = max(widths) if widths else 0
        max_height = max(heights) if heights else 0

        print("📊 Cache Statistics")
        print("=" * 50)
        print(f"Total Images:    {total_images}")
        print(f"Cache Entries:   {cache_stats['total_entries']}")
        print(f"Cache Size:      {cache_info['cache_size'] / (1024 * 1024):.1f} MB")
        print(f"Cache Directory: {cache_info['cache_dir']}")
        print()

        if avg_width > 0:
            print("Resolution Statistics:")
            print(f"  • Average: {avg_width:.0f}×{avg_height:.0f}")
            print(f"  • Range:   {min_width}×{min_height} to {max_width}×{max_height}")


def main():
    parser = argparse.ArgumentParser(
        description='Find similar images using computer vision',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --add ~/Photos/vacation           # Add directory to cache
  %(prog)s query.jpg                        # Find similar images to query.jpg
  %(prog)s query.jpg --results 20           # More similar image results
  %(prog)s query.jpg --threshold 0.5         # Higher similarity threshold
  %(prog)s ~/Pictures/Wallpapers            # Find duplicates in directory
  %(prog)s --stats                          # Show cache statistics
  %(prog)s --rebuild                        # Rebuild cache
        """
    )

    parser.add_argument('path', nargs='?',
                        help='Image file or directory to search for duplicates/similar images')
    parser.add_argument('--add', metavar='DIRECTORY',
                        help='Add directory to image cache')
    parser.add_argument('--results', type=int, default=10,
                        help='Maximum results to return (default: 10)')
    parser.add_argument('--threshold', type=float, default=0.3,
                        help='Similarity threshold (0.0-1.0, default: 0.3)')
    parser.add_argument('--stats', action='store_true',
                        help='Show cache statistics')
    parser.add_argument('--rebuild', action='store_true',
                        help='Rebuild cache (delete existing)')
    parser.add_argument('--min-size', type=int, default=10240,
                        help='Minimum file size in bytes (default: 10KB)')
    parser.add_argument('--cache', metavar='NAME',
                        help='Custom cache name')

    args = parser.parse_args()

    # Create search instance
    search = SimilarImageSearch(args.cache)

    # Handle rebuild
    if args.rebuild:
        if search.cache_manager.clear_cache():
            print(f"🗑️  Cleared existing cache: {search.cache_manager.cache_dir}")
        if search.index_file.exists():
            search.index_file.unlink()
            print(f"🗑️  Cleared image index: {search.index_file}")
        search.image_index = {}

    # Handle add directory
    if args.add:
        search.add_directory(args.add, args.min_size)
        return

    # Handle statistics
    if args.stats:
        search.show_statistics()
        return

    # Handle file/directory search
    if args.path:
        path = Path(args.path)

        if path.is_dir():
            # Directory: find duplicates
            search.find_duplicates(args.path, args.min_size)
        elif path.is_file():
            # File: find similar images
            results = search.search_similar_images(
                str(path),
                args.results,
                args.threshold
            )

            if results:
                print(
                    f"\n🎯 Found {len(results)} similar images (threshold: {args.threshold}):")
                print("=" * 80)

                for i, (file_path, similarity) in enumerate(results, 1):
                    print(f"{i:2d}. {similarity:.3f} - {file_path}")
            else:
                print("❌ No similar images found")
                print("💡 Try lowering the threshold with --threshold 0.2")
        else:
            print(f"❌ Path not found: {args.path}")
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
