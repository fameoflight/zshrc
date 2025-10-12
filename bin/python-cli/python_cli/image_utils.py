"""
Image utilities for file discovery, analysis, and comparison.
Shared functionality for find-similar-images and find-duplicate-images scripts.
"""

import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Set, Union, Any
import cv2
import numpy as np

# Import cache manager for efficient hashing
import sys
from pathlib import Path

# Add parent directory to path for cache_manager import
parent_dir = str(Path(__file__).parent.parent)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from .cache_manager import CacheManager

# Import progress bar utilities
try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False
    tqdm = None

# Global cache manager for image hashing
_hash_cache = CacheManager('image-hashing')


class ImageFile:
    """Represents an image file with basic metadata."""

    def __init__(self, file_path: str):
        self.file_path = str(Path(file_path).resolve())
        self._info: Optional[Dict] = None
        self._hash: Optional[str] = None

    @property
    def info(self) -> Optional[Dict]:
        """Get image metadata (dimensions, file size)."""
        if self._info is None:
            self._info = self._extract_info()
        return self._info

    @property
    def hash(self) -> str:
        """Get MD5 hash of file."""
        if self._hash is None:
            self._hash = self._calculate_hash()
        return self._hash

    @property
    def width(self) -> Optional[int]:
        """Get image width."""
        return self.info.get('width') if self.info else None

    @property
    def height(self) -> Optional[int]:
        """Get image height."""
        return self.info.get('height') if self.info else None

    @property
    def file_size(self) -> Optional[int]:
        """Get file size in bytes."""
        return self.info.get('file_size') if self.info else None

    @property
    def extension(self) -> str:
        """Get file extension."""
        return Path(self.file_path).suffix.lower()

    def _extract_info(self) -> Optional[Dict]:
        """Extract basic image information with caching."""
        try:
            # Check cache first
            cache_key = f"info:{self.file_path}"
            cached_info = _hash_cache.get_cached_data(cache_key)
            if cached_info:
                return cached_info

            # Extract info if not cached
            img = cv2.imread(self.file_path)
            if img is None:
                return None

            height, width = img.shape[:2]
            file_size = os.path.getsize(self.file_path)

            info = {
                'width': width,
                'height': height,
                'file_size': file_size,
                'aspect_ratio': width / height if height > 0 else 0
            }

            # Cache the result
            _hash_cache.cache_data(cache_key, info, self.file_path)

            return info
        except Exception:
            return None

    def _calculate_hash(self) -> str:
        """Calculate file signature using cache manager."""
        try:
            # Use cache manager's file signature method (faster than content hashing)
            return _hash_cache.get_file_signature(self.file_path)
        except Exception:
            return ""

    def exists(self) -> bool:
        """Check if file still exists."""
        return os.path.exists(self.file_path)

    def __str__(self) -> str:
        return self.file_path

    def __repr__(self) -> str:
        return f"ImageFile('{self.file_path}')"


class ImageDiscovery:
    """Utility class for discovering and filtering image files."""

    # Standard image formats supported by both scripts
    SUPPORTED_FORMATS: Set[str] = {
        '.jpg', '.jpeg', '.png', '.gif', '.bmp',
        '.tiff', '.tif', '.webp'
    }

    @classmethod
    def find_images(cls, directory: Union[str, Path],
                   min_size: int = 10240,
                   recursive: bool = True,
                   show_progress: bool = False) -> List[ImageFile]:
        """
        Find all image files in directory.

        Args:
            directory: Directory to search
            min_size: Minimum file size in bytes (default: 10KB)
            recursive: Search subdirectories (default: True)
            show_progress: Show progress bar (default: False)

        Returns:
            List of ImageFile objects
        """
        directory_path = Path(directory)
        if not directory_path.exists():
            return []

        image_files = []

        # Choose search method
        if recursive:
            pattern = "**/*"
        else:
            pattern = "*"

        # Find image files
        for ext in cls.SUPPORTED_FORMATS:
            # Search both lowercase and uppercase extensions
            for pattern_ext in [f"{pattern}{ext}", f"{pattern}{ext.upper()}"]:
                image_files.extend(directory_path.glob(pattern_ext))

        # Convert to ImageFile objects and filter by size
        valid_files = []
        save_interval = 100  # Save cache every 100 images

        # Create progress iterator if tqdm is available and progress is requested
        if show_progress and HAS_TQDM:
            file_iterator = tqdm(image_files, desc="Scanning images",
                                bar_format='{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}]',
                                ncols=80, ascii=True)
        else:
            file_iterator = image_files

        for i, file_path in enumerate(file_iterator):
            if file_path.is_file() and file_path.stat().st_size >= min_size:
                image_file = ImageFile(str(file_path))
                if image_file.exists() and image_file.info:  # Valid image
                    valid_files.append(image_file)

            # Save cache periodically during scanning
            if i > 0 and i % save_interval == 0:
                save_hash_cache()

        # Final cache save
        save_hash_cache()

        # Close progress bar if it was used
        if show_progress and HAS_TQDM and hasattr(file_iterator, 'close'):
            file_iterator.close()

        return valid_files

    @classmethod
    def filter_by_size(cls, images: List[ImageFile],
                      min_size: int = 10240) -> List[ImageFile]:
        """Filter images by minimum file size."""
        return [img for img in images if img.file_size and img.file_size >= min_size]

    @classmethod
    def filter_by_extension(cls, images: List[ImageFile],
                           extensions: Set[str]) -> List[ImageFile]:
        """Filter images by specific extensions."""
        return [img for img in images if img.extension in extensions]


class ImageComparison:
    """Utility class for comparing images."""

    @staticmethod
    def sizes_similar(size1: int, size2: int, tolerance: float = 0.05) -> bool:
        """
        Check if file sizes are similar within tolerance.

        Args:
            size1, size2: File sizes in bytes
            tolerance: Tolerance as percentage (default: 5%)

        Returns:
            True if sizes are similar within tolerance
        """
        if size1 == 0 or size2 == 0:
            return False

        ratio = max(size1, size2) / min(size1, size2)
        return ratio <= (1.0 + tolerance)

    @staticmethod
    def dimensions_similar(img1: ImageFile, img2: ImageFile,
                          tolerance: int = 10) -> bool:
        """
        Check if image dimensions are similar within tolerance.

        Args:
            img1, img2: ImageFile objects
            tolerance: Pixel tolerance for width/height difference

        Returns:
            True if dimensions are similar within tolerance
        """
        if not (img1.info and img2.info):
            return False

        width_diff = abs(img1.width - img2.width)
        height_diff = abs(img1.height - img2.height)

        return width_diff <= tolerance and height_diff <= tolerance

    @staticmethod
    def exact_duplicates(images: List[ImageFile]) -> Dict[str, List[ImageFile]]:
        """
        Find exact duplicates using file hashing.

        Args:
            images: List of ImageFile objects

        Returns:
            Dictionary mapping hash to list of duplicate images
        """
        duplicates = {}
        hash_groups = {}

        for img in images:
            if img.hash:
                if img.hash not in hash_groups:
                    hash_groups[img.hash] = []
                hash_groups[img.hash].append(img)

        # Keep only groups with multiple files
        for file_hash, files in hash_groups.items():
            if len(files) > 1:
                duplicates[file_hash] = files

        return duplicates

    @staticmethod
    def similar_by_size(images: List[ImageFile],
                       size_tolerance: float = 0.05,
                       dimension_tolerance: int = 10,
                       same_extension: bool = True) -> Dict[str, List[ImageFile]]:
        """
        Find similar images by size and dimensions.

        Args:
            images: List of ImageFile objects
            size_tolerance: File size tolerance percentage (default: 5%)
            dimension_tolerance: Pixel tolerance for dimensions (default: 10px)
            same_extension: Require same extension (default: True)

        Returns:
            Dictionary mapping representative hash to list of similar images
        """
        duplicates = {}
        processed = []

        for i, img1 in enumerate(images):
            if img1 in processed:
                continue

            if not (img1.file_size and img1.info):
                processed.append(img1)
                continue

            similar_files = [img1]

            for img2 in images[i+1:]:
                if img2 in processed:
                    continue

                if not (img2.file_size and img2.info):
                    continue

                # Check extension requirement
                if same_extension and img1.extension != img2.extension:
                    continue

                # Check size similarity
                if not ImageComparison.sizes_similar(img1.file_size, img2.file_size, size_tolerance):
                    continue

                # Check dimension similarity
                if not ImageComparison.dimensions_similar(img1, img2, dimension_tolerance):
                    continue

                # Images are similar
                similar_files.append(img2)
                processed.append(img2)

            processed.append(img1)

            if len(similar_files) > 1:
                # Use first image's hash as key
                duplicates[similar_files[0].hash] = similar_files

        return duplicates

    @staticmethod
    def standard_duplicates(images: List[ImageFile]) -> Dict[str, List[ImageFile]]:
        """
        Find duplicates using size + hash combination (standard mode).

        This is more efficient than hashing all files by grouping by size first.

        Args:
            images: List of ImageFile objects

        Returns:
            Dictionary mapping hash to list of duplicate images
        """
        duplicates = {}

        # Group by file size first
        size_groups = {}
        for img in images:
            if img.file_size:
                if img.file_size not in size_groups:
                    size_groups[img.file_size] = []
                size_groups[img.file_size].append(img)

        # Within same size groups, check hash
        for size, files in size_groups.items():
            if len(files) <= 1:
                continue

            hash_groups = {}
            for img in files:
                if img.hash:
                    if img.hash not in hash_groups:
                        hash_groups[img.hash] = []
                    hash_groups[img.hash].append(img)

            # Keep only groups with multiple files
            for file_hash, hash_files in hash_groups.items():
                if len(hash_files) > 1:
                    duplicates[file_hash] = hash_files

        return duplicates


class ImageAnalysis:
    """Advanced image analysis for similarity detection."""

    @staticmethod
    def extract_opencv_features(image_path: str) -> Dict[str, np.ndarray]:
        """
        Extract comprehensive features using OpenCV.

        This is the same feature extraction used by find-similar-images.

        Args:
            image_path: Path to image file

        Returns:
            Dictionary containing feature arrays
        """
        try:
            img = cv2.imread(image_path)
            if img is None:
                return {}

            features = {}

            # Convert to different color spaces
            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            # 1. Color histogram (HSV space)
            hist_h = cv2.calcHist([hsv], [0], None, [18], [0, 180])
            hist_s = cv2.calcHist([hsv], [1], None, [3], [0, 256])
            hist_v = cv2.calcHist([hsv], [2], None, [3], [0, 256])

            # Normalize histograms
            hist_h = cv2.normalize(hist_h, hist_h).flatten()
            hist_s = cv2.normalize(hist_s, hist_s).flatten()
            hist_v = cv2.normalize(hist_v, hist_v).flatten()

            # Combine histograms
            color_histogram = np.concatenate([hist_h, hist_s, hist_v])
            features['color_histogram'] = color_histogram

            # 2. Texture features
            try:
                from skimage.feature import local_binary_pattern
                radius = 3
                n_points = 8 * radius
                lbp = local_binary_pattern(gray, n_points, radius, method='uniform')
                lbp_hist, _ = np.histogram(lbp.ravel(), bins=n_points + 2)
                lbp_hist = lbp_hist.astype(float)
                lbp_hist /= (lbp_hist.sum() + 1e-7)
                features['texture_features'] = lbp_hist
            except ImportError:
                # Fallback: gradient-based texture
                grad_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
                grad_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
                magnitude = np.sqrt(grad_x**2 + grad_y**2)
                texture_hist, _ = np.histogram(magnitude.ravel(), bins=50)
                texture_hist = texture_hist.astype(float)
                texture_hist /= (texture_hist.sum() + 1e-7)
                features['texture_features'] = texture_hist

            # 3. Edge density
            edges = cv2.Canny(gray, 50, 150)
            edge_density = np.sum(edges > 0) / edges.size
            features['edge_density'] = np.array([edge_density])

            # 4. Shape descriptors
            contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if contours:
                largest_contour = max(contours, key=cv2.contourArea)
                area = cv2.contourArea(largest_contour)
                perimeter = cv2.arcLength(largest_contour, True)
                if perimeter > 0:
                    circularity = 4 * np.pi * area / (perimeter ** 2)
                else:
                    circularity = 0
                features['shape_circularity'] = np.array([circularity])
            else:
                features['shape_circularity'] = np.array([0.0])

            return features

        except Exception as e:
            print(f"⚠️  Error extracting features from {image_path}: {e}")
            return {}

    @staticmethod
    def calculate_similarity(features1: Dict[str, np.ndarray],
                           features2: Dict[str, np.ndarray]) -> float:
        """
        Calculate similarity between two feature sets.

        Uses weighted combination of different feature similarities.

        Args:
            features1, features2: Feature dictionaries

        Returns:
            Similarity score between 0.0 and 1.0
        """
        total_score = 0.0
        weight_sum = 0.0

        # Compare color histograms (weighted most heavily)
        if 'color_histogram' in features1 and 'color_histogram' in features2:
            hist1 = features1['color_histogram']
            hist2 = features2['color_histogram']

            correlation = np.corrcoef(hist1, hist2)[0, 1]
            if not np.isnan(correlation):
                total_score += max(0, correlation) * 0.4
                weight_sum += 0.4

        # Compare texture features
        if 'texture_features' in features1 and 'texture_features' in features2:
            tex1 = features1['texture_features']
            tex2 = features2['texture_features']

            dot_product = np.dot(tex1, tex2)
            norm1 = np.linalg.norm(tex1)
            norm2 = np.linalg.norm(tex2)

            if norm1 > 0 and norm2 > 0:
                cosine_sim = dot_product / (norm1 * norm2)
                total_score += cosine_sim * 0.3
                weight_sum += 0.3

        # Compare edge density
        if 'edge_density' in features1 and 'edge_density' in features2:
            edge1 = features1['edge_density']
            edge2 = features2['edge_density']

            # Handle both scalar and array types
            if isinstance(edge1, np.ndarray):
                edge1 = edge1[0] if edge1.size > 0 else 0.0
            if isinstance(edge2, np.ndarray):
                edge2 = edge2[0] if edge2.size > 0 else 0.0

            edge_sim = 1.0 - abs(edge1 - edge2) / max(edge1, edge2, 1e-7)
            total_score += edge_sim * 0.2
            weight_sum += 0.2

        # Compare shape circularity
        if 'shape_circularity' in features1 and 'shape_circularity' in features2:
            shape1 = features1['shape_circularity']
            shape2 = features2['shape_circularity']

            # Handle both scalar and array types
            if isinstance(shape1, np.ndarray):
                shape1 = shape1[0] if shape1.size > 0 else 0.0
            if isinstance(shape2, np.ndarray):
                shape2 = shape2[0] if shape2.size > 0 else 0.0

            shape_sim = 1.0 - abs(shape1 - shape2)
            total_score += shape_sim * 0.1
            weight_sum += 0.1

        return total_score / weight_sum if weight_sum > 0 else 0.0


# Cache management utility functions
def save_hash_cache():
    """Save the hash cache to disk."""
    try:
        _hash_cache.save_cache()
    except Exception as e:
        print(f"⚠️  Warning: Could not save hash cache: {e}")


def get_hash_cache_info() -> Dict[str, Any]:
    """Get information about the hash cache."""
    return _hash_cache.get_cache_info()


def clear_hash_cache() -> bool:
    """Clear the hash cache."""
    return _hash_cache.clear_cache()