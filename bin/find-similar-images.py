#!/usr/bin/env python3
"""
Similar Image Search using Computer Vision
Finds visually similar images in a database using OpenCV feature extraction
"""

import sys
import os
import argparse
import sqlite3
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from python_cli.utils import safe_remove_file

import cv2
import numpy as np


class SimilarImageSearch:
    """Similar image search system using OpenCV features"""

    def __init__(self, db_file: str = None):
        if db_file is None:
            db_file = str(Path.home() / '.config' / 'zsh' /
                          'similar_images.sqlite.db')

        self.db_file = db_file
        self.supported_formats = {
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.webp'}

    def init_database(self):
        """Initialize SQLite database for image features"""
        os.makedirs(os.path.dirname(self.db_file), exist_ok=True)

        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()

        # Create images table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS images (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT UNIQUE NOT NULL,
                width INTEGER,
                height INTEGER,
                file_size INTEGER,
                aspect_ratio REAL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        # Create features table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS features (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                image_id INTEGER,
                feature_type TEXT,
                feature_data TEXT,
                FOREIGN KEY (image_id) REFERENCES images (id) ON DELETE CASCADE
            )
        ''')

        # Create indexes for performance
        cursor.execute(
            'CREATE INDEX IF NOT EXISTS idx_images_path ON images (file_path)')
        cursor.execute(
            'CREATE INDEX IF NOT EXISTS idx_features_image_id ON features (image_id)')
        cursor.execute(
            'CREATE INDEX IF NOT EXISTS idx_features_type ON features (feature_type)')

        conn.commit()
        conn.close()
        print(f"✅ Database initialized: {self.db_file}")

    def extract_opencv_features(self, image_path: str) -> Dict[str, Any]:
        """Extract comprehensive features using OpenCV"""
        try:
            # Read image
            img = cv2.imread(image_path)
            if img is None:
                return {}

            features = {}

            # Convert to different color spaces
            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            # 1. Color histogram (HSV space - more robust to lighting)
            hist_h = cv2.calcHist([hsv], [0], None, [18], [0, 180])
            hist_s = cv2.calcHist([hsv], [1], None, [3], [0, 256])
            hist_v = cv2.calcHist([hsv], [2], None, [3], [0, 256])

            # Normalize histograms
            hist_h = cv2.normalize(hist_h, hist_h).flatten()
            hist_s = cv2.normalize(hist_s, hist_s).flatten()
            hist_v = cv2.normalize(hist_v, hist_v).flatten()

            # Combine histograms
            color_histogram = np.concatenate([hist_h, hist_s, hist_v])
            features['color_histogram'] = color_histogram.tolist()

            # 2. Texture features using Local Binary Patterns
            try:
                from skimage.feature import local_binary_pattern
                radius = 3
                n_points = 8 * radius
                lbp = local_binary_pattern(
                    gray, n_points, radius, method='uniform')
                lbp_hist, _ = np.histogram(lbp.ravel(), bins=n_points + 2)
                lbp_hist = lbp_hist.astype(float)
                lbp_hist /= (lbp_hist.sum() + 1e-7)
                features['texture_features'] = lbp_hist.tolist()
            except ImportError:
                # Fallback: use gradient-based texture
                grad_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
                grad_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
                magnitude = np.sqrt(grad_x**2 + grad_y**2)
                texture_hist, _ = np.histogram(magnitude.ravel(), bins=50)
                texture_hist = texture_hist.astype(float)
                texture_hist /= (texture_hist.sum() + 1e-7)
                features['texture_features'] = texture_hist.tolist()

            # 3. Edge density
            edges = cv2.Canny(gray, 50, 150)
            edge_density = np.sum(edges > 0) / edges.size
            features['edge_density'] = float(edge_density)

            # 4. Shape descriptors using contours
            contours, _ = cv2.findContours(
                edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if contours:
                # Find largest contour
                largest_contour = max(contours, key=cv2.contourArea)
                # Shape features
                area = cv2.contourArea(largest_contour)
                perimeter = cv2.arcLength(largest_contour, True)
                if perimeter > 0:
                    circularity = 4 * np.pi * area / (perimeter ** 2)
                else:
                    circularity = 0
                features['shape_circularity'] = float(circularity)
            else:
                features['shape_circularity'] = 0.0

            return features

        except Exception as e:
            print(f"⚠️  Error extracting features from {image_path}: {e}")
            return {}

    def add_directory(self, directory_path: str, min_size: int = 10240):
        """Add all images from directory to database"""
        directory = Path(directory_path)
        if not directory.exists():
            print(f"❌ Directory not found: {directory_path}")
            return

        print(f"🔍 Scanning directory: {directory_path}")

        # Find all image files
        image_files = []
        for ext in self.supported_formats:
            image_files.extend(directory.rglob(f'*{ext}'))
            image_files.extend(directory.rglob(f'*{ext.upper()}'))

        # Filter by minimum size
        valid_files = [f for f in image_files if f.stat().st_size >= min_size]

        print(
            f"📊 Found {len(valid_files)} image files (min size: {min_size} bytes)")

        if not valid_files:
            print("⚠️  No valid image files found")
            return

        # Initialize database
        self.init_database()

        # Connect to database
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()

        added_count = 0
        skipped_count = 0

        for i, image_file in enumerate(valid_files, 1):
            file_path = str(image_file)

            # Check if already exists
            cursor.execute(
                'SELECT id FROM images WHERE file_path = ?', (file_path,))
            if cursor.fetchone():
                skipped_count += 1
                continue

            # Get basic image info
            try:
                img = cv2.imread(file_path)
                if img is None:
                    continue

                height, width = img.shape[:2]
                file_size = image_file.stat().st_size
                aspect_ratio = width / height

                # Insert image record
                cursor.execute('''
                    INSERT INTO images (file_path, width, height, file_size, aspect_ratio)
                    VALUES (?, ?, ?, ?, ?)
                ''', (file_path, width, height, file_size, aspect_ratio))

                image_id = cursor.lastrowid

                # Extract and store features
                features = self.extract_opencv_features(file_path)

                for feature_type, feature_data in features.items():
                    cursor.execute('''
                        INSERT INTO features (image_id, feature_type, feature_data)
                        VALUES (?, ?, ?)
                    ''', (image_id, feature_type, json.dumps(feature_data)))

                added_count += 1

                if i % 100 == 0:
                    print(f"📈 Processed {i}/{len(valid_files)} files...")
                    conn.commit()

            except Exception as e:
                print(f"⚠️  Error processing {file_path}: {e}")
                continue

        conn.commit()
        conn.close()

        print(f"✅ Completed!")
        print(f"   • Added: {added_count} new images")
        print(f"   • Skipped: {skipped_count} existing images")
        print(f"   • Database: {self.db_file}")

    def calculate_similarity(self, features1: Dict, features2: Dict) -> float:
        """Calculate similarity between two feature sets"""
        total_score = 0.0
        weight_sum = 0.0

        # Compare color histograms (weighted most heavily)
        if 'color_histogram' in features1 and 'color_histogram' in features2:
            hist1 = np.array(features1['color_histogram'])
            hist2 = np.array(features2['color_histogram'])

            # Calculate correlation coefficient
            correlation = np.corrcoef(hist1, hist2)[0, 1]
            if not np.isnan(correlation):
                total_score += max(0, correlation) * 0.4
                weight_sum += 0.4

        # Compare texture features
        if 'texture_features' in features1 and 'texture_features' in features2:
            tex1 = np.array(features1['texture_features'])
            tex2 = np.array(features2['texture_features'])

            # Cosine similarity
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

            edge_sim = 1.0 - abs(edge1 - edge2) / max(edge1, edge2, 1e-7)
            total_score += edge_sim * 0.2
            weight_sum += 0.2

        # Compare shape circularity
        if 'shape_circularity' in features1 and 'shape_circularity' in features2:
            shape1 = features1['shape_circularity']
            shape2 = features2['shape_circularity']

            shape_sim = 1.0 - abs(shape1 - shape2)
            total_score += shape_sim * 0.1
            weight_sum += 0.1

        return total_score / weight_sum if weight_sum > 0 else 0.0

    def search_similar_images(self, query_image: str, max_results: int = 10, threshold: float = 0.3) -> List[Tuple[str, float]]:
        """Find similar images to query image"""
        if not os.path.exists(query_image):
            print(f"❌ Query image not found: {query_image}")
            return []

        if not os.path.exists(self.db_file):
            print(f"❌ Database not found: {self.db_file}")
            print("💡 Use --add to build a database first")
            return []

        print(f"🔍 Searching for images similar to: {query_image}")

        # Extract features from query image
        query_features = self.extract_opencv_features(query_image)
        if not query_features:
            print("❌ Could not extract features from query image")
            return []

        # Connect to database
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()

        # Get all images except the query image itself
        cursor.execute('''
            SELECT id, file_path FROM images
            WHERE file_path != ?
            ORDER BY created_at DESC
        ''', (os.path.abspath(query_image),))

        results = []

        for image_id, file_path in cursor.fetchall():
            # Get features for this image
            cursor.execute(
                'SELECT feature_type, feature_data FROM features WHERE image_id = ?', (image_id,))
            db_features = {}

            for feature_type, feature_data in cursor.fetchall():
                db_features[feature_type] = json.loads(feature_data)

            if db_features:
                similarity = self.calculate_similarity(
                    query_features, db_features)
                if similarity >= threshold:
                    results.append((file_path, similarity))

        conn.close()

        # Sort by similarity (descending) and limit results
        results.sort(key=lambda x: x[1], reverse=True)
        return results[:max_results]

    def show_statistics(self):
        """Display database statistics"""
        if not os.path.exists(self.db_file):
            print("❌ Database not found")
            return

        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()

        # Basic stats
        cursor.execute('SELECT COUNT(*) FROM images')
        total_images = cursor.fetchone()[0]

        cursor.execute('SELECT COUNT(DISTINCT feature_type) FROM features')
        feature_types = cursor.fetchone()[0]

        cursor.execute(
            'SELECT AVG(width), AVG(height), MIN(width), MIN(height), MAX(width), MAX(height) FROM images')
        res_stats = cursor.fetchone()

        # Database size
        db_size = os.path.getsize(self.db_file) / (1024 * 1024)  # MB

        print("📊 Database Statistics")
        print("=" * 50)
        print(f"Total Images: {total_images}")
        print(f"Feature Types: {feature_types}")
        print(f"DB Size:      {db_size:.1f} MB")
        print()

        if res_stats[0]:
            print("Resolution Statistics:")
            print(f"  • Average: {res_stats[0]:.0f}×{res_stats[1]:.0f}")
            print(
                f"  • Range:   {res_stats[2]}×{res_stats[3]} to {res_stats[4]}×{res_stats[5]}")

        conn.close()


def main():
    parser = argparse.ArgumentParser(
        description='Find similar images using computer vision',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --add ~/Photos/vacation           # Add directory to database
  %(prog)s query.jpg                        # Search for similar images
  %(prog)s query.jpg --results 20           # More results
  %(prog)s query.jpg --threshold 0.5         # Higher threshold
  %(prog)s --stats                          # Show database statistics
  %(prog)s --rebuild                        # Rebuild database
        """
    )

    parser.add_argument('query_image', nargs='?',
                        help='Query image for similarity search')
    parser.add_argument('--add', metavar='DIRECTORY',
                        help='Add directory to image database')
    parser.add_argument('--results', type=int, default=10,
                        help='Maximum results to return (default: 10)')
    parser.add_argument('--threshold', type=float, default=0.3,
                        help='Similarity threshold (0.0-1.0, default: 0.3)')
    parser.add_argument('--stats', action='store_true',
                        help='Show database statistics')
    parser.add_argument('--rebuild', action='store_true',
                        help='Rebuild database (delete existing)')
    parser.add_argument('--min-size', type=int, default=10240,
                        help='Minimum file size in bytes (default: 10KB)')
    parser.add_argument('--db', metavar='FILE',
                        help='Custom database file path')

    args = parser.parse_args()

    # Create search instance
    search = SimilarImageSearch(args.db)

    # Handle rebuild
    if args.rebuild:
        if os.path.exists(search.db_file):
            safe_remove_file(search.db_file)
            print(f"🗑️  Moved existing database to trash: {search.db_file}")

    # Handle add directory
    if args.add:
        search.add_directory(args.add, args.min_size)
        return

    # Handle statistics
    if args.stats:
        search.show_statistics()
        return

    # Handle search
    if args.query_image:
        results = search.search_similar_images(
            args.query_image,
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
        parser.print_help()


if __name__ == '__main__':
    main()
