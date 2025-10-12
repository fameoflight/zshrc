#!/usr/bin/env python3
"""
Reusable cache management for CLI tools
Provides persistent caching with file signature validation
"""

import json
import hashlib
import os
from pathlib import Path
from typing import Dict, Any, Optional, Union


class CacheManager:
    """Generic cache manager for CLI tools"""

    def __init__(self, cache_name: str, cache_dir: Optional[str] = None):
        """
        Initialize cache manager

        Args:
            cache_name: Name of the cache (subdirectory)
            cache_dir: Override cache directory (defaults to PYTHON_CLI_CACHE)
        """
        self.cache_name = cache_name

        if cache_dir:
            self.cache_dir = Path(cache_dir)
        else:
            cache_env = os.environ.get('PYTHON_CLI_CACHE')
            if cache_env:
                self.cache_dir = Path(cache_env) / cache_name
            else:
                # Default to ~/.cache/zshrc/python-cli/cache_name
                self.cache_dir = Path.home() / '.cache' / 'zshrc' / 'python-cli' / cache_name

        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.cache_file = self.cache_dir / 'cache.json'

        # Load existing cache
        self.cache = self.load_cache()

    def load_cache(self) -> Dict[str, Any]:
        """Load cache from disk"""
        if self.cache_file.exists():
            try:
                with open(self.cache_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(f"⚠️  Warning: Could not load cache {self.cache_name}: {e}")
        return {}

    def save_cache(self):
        """Save cache to disk"""
        try:
            with open(self.cache_file, 'w') as f:
                json.dump(self.cache, f, indent=2)
        except IOError as e:
            print(f"⚠️  Warning: Could not save cache {self.cache_name}: {e}")

    def save_cache_atomic(self):
        """Save cache to disk atomically (write to temp file then rename)"""
        temp_file = self.cache_file.with_suffix('.tmp')
        try:
            with open(temp_file, 'w') as f:
                json.dump(self.cache, f, indent=2)
            temp_file.replace(self.cache_file)  # Atomic operation
        except IOError as e:
            print(f"⚠️  Warning: Could not save cache {self.cache_name}: {e}")
            # Clean up temp file if it exists
            if temp_file.exists():
                temp_file.unlink()

    def clear_cache(self):
        """Clear all cache data"""
        try:
            if self.cache_file.exists():
                self.cache_file.unlink()
                self.cache = {}
                return True
            return False
        except Exception as e:
            print(f"❌ Failed to clear cache {self.cache_name}: {e}")
            return False

    def get_file_signature(self, file_path: str) -> str:
        """Get a unique signature for a file based on path, size, and modification time"""
        try:
            stat = os.stat(file_path)
            signature_data = f"{file_path}:{stat.st_size}:{stat.st_mtime}"
            return hashlib.md5(signature_data.encode()).hexdigest()
        except OSError:
            return ""

    def is_cached(self, key: str) -> bool:
        """Check if key exists in cache"""
        return key in self.cache

    def get_cached_data(self, key: str) -> Optional[Any]:
        """Get cached data if available and valid"""
        if key not in self.cache:
            return None

        cached = self.cache[key]

        # If it's a file-based cache, validate signature
        if isinstance(cached, dict) and 'signature' in cached:
            current_signature = self.get_file_signature(key)
            if current_signature != cached.get('signature'):
                # File has changed, remove stale cache entry
                del self.cache[key]
                return None

        return cached.get('data') if isinstance(cached, dict) and 'data' in cached else cached

    def cache_data(self, key: str, data: Any, file_path: Optional[str] = None, auto_save: bool = False):
        """
        Cache data with optional file signature

        Args:
            key: Cache key (usually file path)
            data: Data to cache
            file_path: Path to file for signature validation (optional)
            auto_save: Whether to immediately save cache to disk (optional)
        """
        if file_path:
            signature = self.get_file_signature(file_path)
            if signature:
                self.cache[key] = {
                    'data': data,
                    'signature': signature
                }
        else:
            self.cache[key] = data

        # Auto-save if requested
        if auto_save:
            self.save_cache()

    def get_cache_info(self) -> Dict[str, Any]:
        """Get cache information"""
        info = {
            'cache_dir': str(self.cache_dir),
            'cache_file': str(self.cache_file),
            'cache_size': 0,
            'cache_entries': len(self.cache)
        }

        if self.cache_file.exists():
            info['cache_size'] = self.cache_file.stat().st_size

        return info

    def get_cache_stats(self) -> Dict[str, int]:
        """Get cache statistics"""
        return {
            'total_entries': len(self.cache),
            'file_entries': sum(1 for v in self.cache.values()
                              if isinstance(v, dict) and 'signature' in v)
        }


class ImageCacheManager(CacheManager):
    """Specialized cache manager for image processing"""

    def __init__(self, cache_dir: Optional[str] = None):
        super().__init__('image-processing', cache_dir)

    def cache_image_data(self, image_path: str, phash: str, info: Dict[str, Any]):
        """Cache image hash and info"""
        self.cache_data(image_path, {
            'phash': phash,
            'info': info
        }, image_path)

    def get_cached_image_data(self, image_path: str) -> Optional[Dict[str, Any]]:
        """Get cached image data if available and still valid"""
        return self.get_cached_data(image_path)

    def get_cached_or_compute(self, image_path: str, compute_func) -> Any:
        """
        Get data from cache or compute and cache it

        Args:
            image_path: Path to image file
            compute_func: Function that computes the data (takes image_path, returns data)
        """
        # Try cache first
        cached_data = self.get_cached_image_data(image_path)
        if cached_data:
            return cached_data

        # Compute and cache
        data = compute_func(image_path)
        if data:
            if isinstance(data, tuple) and len(data) == 2:
                # Assume (phash, info) tuple
                phash, info = data
                self.cache_image_data(image_path, phash, info)
            else:
                # Generic data
                self.cache_data(image_path, data, image_path)

        return data


# Factory function for easy usage
def get_cache_manager(cache_name: str, cache_dir: Optional[str] = None) -> CacheManager:
    """Get a cache manager instance"""
    return CacheManager(cache_name, cache_dir)


def get_image_cache_manager(cache_dir: Optional[str] = None) -> ImageCacheManager:
    """Get an image cache manager instance"""
    return ImageCacheManager(cache_dir)