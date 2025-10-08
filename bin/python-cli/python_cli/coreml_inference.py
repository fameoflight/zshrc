"""
CoreML inference implementation for python-cli.

Handles image upscaling using CoreML models on Apple Silicon.
"""

import numpy as np
from pathlib import Path
from PIL import Image
import cv2
import math
import time
from contextlib import contextmanager
from typing import Optional
from .utils import find_model_file

try:
    import coremltools as ct
    COREML_AVAILABLE = True
except ImportError:
    COREML_AVAILABLE = False


class TimingHelper:
    """Helper class for timing operations with detailed metrics."""

    def __init__(self, operation_name: str, show_progress: bool = False, tracker=None):
        self.operation_name = operation_name
        self.show_progress = show_progress
        self.tracker = tracker
        self.start_time = None
        self.end_time = None
        self.duration = None

    def __enter__(self):
        self.start_time = time.time()
        if self.show_progress:
            print(f'⏳ {self.operation_name}...')
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.end_time = time.time()
        self.duration = self.end_time - self.start_time
        if not self.show_progress:
            print(f'✅ {self.operation_name} completed in {self.duration:.3f}s')

        # Add to tracker if provided
        if self.tracker:
            self.tracker.add_timing(self.operation_name, self.duration)

    def get_duration(self) -> float:
        """Get the duration of the timed operation."""
        return self.duration if self.duration is not None else 0.0


class PerformanceTracker:
    """Tracks multiple timing operations and generates summary reports."""

    def __init__(self):
        self.timings = {}
        self.total_start = None

    def start_total(self):
        """Start timing the total operation."""
        self.total_start = time.time()

    def add_timing(self, name: str, duration: float):
        """Add a timing measurement."""
        self.timings[name] = duration

    def create_timing(self, name: str, show_progress: bool = False) -> TimingHelper:
        """Create a new TimingHelper for this operation."""
        return TimingHelper(name, show_progress, self)

    def print_summary(self, total_time: Optional[float] = None):
        """Print a formatted performance summary table."""
        if total_time is None and self.total_start:
            total_time = time.time() - self.total_start

        if not total_time:
            return

        print(f'')
        print(f'📊 Performance Summary:')
        print(f'   ┌─────────────────────────────────────────┐')
        print(f'   │ Step                │ Time      │ %    │')
        print(f'   ├─────────────────────────────────────────┤')

        for name, duration in self.timings.items():
            percentage = (duration / total_time) * 100 if total_time > 0 else 0
            # Truncate name if too long
            display_name = name[:18] + '...' if len(name) > 18 else name
            print(f'   │ {display_name:<18} │ {duration:>7.3f}s │ {percentage:>4.1f}% │')

        print(f'   ├─────────────────────────────────────────┤')
        print(f'   │ {"TOTAL":<18} │ {total_time:>7.3f}s │ 100% │')
        print(f'   └─────────────────────────────────────────┘')


class TimingResult:
    """Container for timing results."""
    def __init__(self):
        self.duration = 0.0


@contextmanager
def timing(operation_name: str, show_progress: bool = False):
    """Context manager for timing operations.

    Usage:
        with timing("Loading image") as t:
            # do something
            pass
        print(f"Duration: {t.duration}s")

    Args:
        operation_name: Name of the operation being timed
        show_progress: If True, shows "⏳" message during operation
    """
    start_time = time.time()
    result = TimingResult()

    if show_progress:
        print(f'⏳ {operation_name}...')

    try:
        yield result
    finally:
        result.duration = time.time() - start_time
        if not show_progress:
            print(f'✅ {operation_name} completed in {result.duration:.3f}s')


class CoreMLInference:
    """CoreML inference class for image upscaling."""

    def __init__(self, model_path: str, compute_units=None, scale_factor=4):
        with timing("CoreML initialization"):
            if not COREML_AVAILABLE:
                raise ImportError("coremltools not available. Install with: pip install coremltools")

            # Resolve model path using the utility function
            try:
                resolved_model_path = find_model_file(model_path, "coreml")
                # For .mlpackage, use the directory, not the internal .mlmodel file
                if resolved_model_path.name == "model.mlmodel" and resolved_model_path.parent.name == "com.apple.CoreML":
                    # Use the .mlpackage directory instead
                    resolved_model_path = resolved_model_path.parent.parent.parent
            except FileNotFoundError:
                raise FileNotFoundError(f"CoreML model not found: {model_path}")

            self.model_path = resolved_model_path
            self.scale_factor = scale_factor

            # Set optimal compute units for Apple Silicon
            if compute_units is None:
                # Use ALL for maximum performance on Apple Silicon
                compute_units = ct.ComputeUnit.ALL
                print(f'   • Using ComputeUnit.ALL for maximum performance')
            else:
                print(f'   • Using specified compute units: {compute_units}')

            # Load and compile model
            with timing("Model loading and compilation"):
                self.model = ct.models.MLModel(str(resolved_model_path), compute_units=compute_units)

            print(f'   • Model: {Path(resolved_model_path).name}')
            print(f'   • Scale factor: {scale_factor}x')
            print(f'')

    def _load_and_preprocess_image(self, image_path: str) -> np.ndarray:
        """Load and preprocess image for CoreML model."""
        # Load image
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Could not load image: {image_path}")

        # Convert BGR to RGB
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        # Convert to float32 and normalize to [0, 1]
        img = img.astype(np.float32) / 255.0

        # Add batch dimension and change to CHW format
        img = np.transpose(img, (2, 0, 1))  # HWC -> CHW
        img = np.expand_dims(img, axis=0)    # Add batch dimension

        return img

    def _save_output_image(self, output_array: np.ndarray, output_path: str):
        """Save the output array as an image."""
        # Remove batch dimension and transpose
        img = output_array.squeeze(0)  # Remove batch
        img = np.transpose(img, (1, 2, 0))  # CHW -> HWC

        # Clip values to [0, 1] and convert to uint8
        img = np.clip(img, 0, 1) * 255.0
        img = img.astype(np.uint8)

        # Save using PIL
        Image.fromarray(img).save(output_path)

    def _get_optimal_tile_size(self, image_shape):
        """Get optimal tile size for CoreML processing."""
        height, width = image_shape
        total_pixels = height * width

        # CoreML on Apple Silicon works well with moderate tile sizes
        if total_pixels > 2048*2048:  # > 4MP
            return 256
        elif total_pixels > 1024*1024:  # > 1MP
            return 512
        else:
            return 1024

    def _process_tiled_inference(self, input_data: np.ndarray) -> np.ndarray:
        """Process large images using tiled inference."""
        batch, channels, height, width = input_data.shape
        tile_size = self._get_optimal_tile_size((height, width))

        # Calculate output dimensions
        output_height = height * self.scale_factor
        output_width = width * self.scale_factor

        print(f'🧩 Using tiled inference: tile_size={tile_size}, output={output_width}x{output_height}')

        # Initialize output array
        output = np.zeros((batch, channels, output_height, output_width), dtype=np.float32)

        # Calculate tiles
        tiles_x = math.ceil(width / tile_size)
        tiles_y = math.ceil(height / tile_size)
        total_tiles = tiles_x * tiles_y

        print(f'   Processing {total_tiles} tiles...')

        tile_times = []
        completed = 0

        for y in range(tiles_y):
            for x in range(tiles_x):
                start_x = x * tile_size
                start_y = y * tile_size
                end_x = min(start_x + tile_size, width)
                end_y = min(start_y + tile_size, height)

                # Extract tile
                tile = input_data[:, :, start_y:end_y, start_x:end_x]

                # Process tile with timing
                with timing(f"Tile {completed+1}/{total_tiles}", show_progress=False) as tile_timing:
                    output_dict = self.model.predict({'input': tile})
                    tile_output = list(output_dict.values())[0]

                # Place tile in output
                scale = self.scale_factor
                out_start_x = start_x * scale
                out_start_y = start_y * scale
                out_end_x = end_x * scale
                out_end_y = end_y * scale

                output[:, :, out_start_y:out_end_y, out_start_x:out_end_x] = tile_output

                tile_times.append(tile_timing.duration)
                completed += 1

                if completed % max(1, total_tiles // 10) == 0 or completed == total_tiles:
                    avg_time = sum(tile_times) / len(tile_times)
                    remaining = (total_tiles - completed) * avg_time
                    latest_tile_time = tile_times[-1]
                    print(f'      Progress: {completed}/{total_tiles} tiles ({100*completed/total_tiles:.0f}%) - Latest: {latest_tile_time:.3f}s - ETA: {remaining:.1f}s')

        # Calculate statistics
        total_time = sum(tile_times)
        avg_tile_time = total_time / total_tiles
        tiles_per_second = total_tiles / total_time
        min_tile_time = min(tile_times)
        max_tile_time = max(tile_times)

        print(f'✅ Tiled inference completed in {total_time:.2f}s')
        print(f'   • Average per tile: {avg_tile_time:.3f}s')
        print(f'   • Fastest tile: {min_tile_time:.3f}s')
        print(f'   • Slowest tile: {max_tile_time:.3f}s')
        print(f'   • Tiles per second: {tiles_per_second:.1f}')

        return output

    def upscale_image(self, input_path: str, output_path: str, tile_size=None):
        """Upscale an image using the CoreML model with optimizations."""
        tracker = PerformanceTracker()
        tracker.start_total()

        try:
            print(f'🚀 Starting CoreML inference...')

            # Load and preprocess input image
            with tracker.create_timing("Load & Preprocess") as timing_helper:
                input_data = self._load_and_preprocess_image(input_path)
                load_time = timing_helper.get_duration()

            batch, channels, height, width = input_data.shape
            total_pixels = height * width
            print(f'📐 Input: {width}x{height} ({total_pixels:,} pixels)')

            # Decide processing method based on image size
            if total_pixels > 512*512 or (tile_size and tile_size < min(height, width)):
                # Use tiled inference for large images
                with tracker.create_timing("Tiled Inference") as timing_helper:
                    output_data = self._process_tiled_inference(input_data)
                    inference_time = timing_helper.get_duration()
            else:
                # Use direct inference for smaller images
                print('⚡ Using direct inference...')
                with tracker.create_timing("Model Inference") as timing_helper:
                    output_dict = self.model.predict({'input': input_data})
                    output_data = list(output_dict.values())[0]
                    inference_time = timing_helper.get_duration()

            # Save result
            with tracker.create_timing("Save Output") as timing_helper:
                self._save_output_image(output_data, output_path)
                save_time = timing_helper.get_duration()

            # Calculate final statistics
            total_time = time.time() - tracker.total_start
            out_height, out_width = output_data.shape[2] * self.scale_factor, output_data.shape[3] * self.scale_factor
            output_pixels = out_height * out_width
            throughput = output_pixels / total_time / 1000000  # Megapixels per second

            print(f'✨ Upscaling completed!')
            tracker.print_summary(total_time)

            print(f'📐 Output: {out_width}x{out_height} ({output_pixels:,} pixels)')
            print(f'⚡ Throughput: {throughput:.1f} MP/s')
            print(f'🚀 Speedup: {output_pixels/total_time/1000000:.1f}x faster than real-time')

        except Exception as e:
            total_time = time.time() - tracker.total_start
            print(f'❌ CoreML inference failed after {total_time:.3f}s: {e}')
            raise RuntimeError(f"CoreML inference failed: {e}")

    def upscale_batch(self, input_paths: list, output_paths: list):
        """Process multiple images in batch for improved throughput."""
        if len(input_paths) != len(output_paths):
            raise ValueError("input_paths and output_paths must have same length")

        with timing(f"Batch processing {len(input_paths)} images", show_progress=True):
            total_pixels_processed = 0
            image_times = []

            for i, (input_path, output_path) in enumerate(zip(input_paths, output_paths)):
                print(f'\n📸 [{i+1}/{len(input_paths)}] Processing: {Path(input_path).name}')

                with timing(f"Image {i+1}") as image_timing:
                    self.upscale_image(input_path, output_path)

                image_times.append(image_timing.duration)

                # Estimate pixels processed (rough estimate based on typical image sizes)
                estimated_pixels = 1920 * 1080 * 4  # Assuming 1080p -> 4K upscaling
                total_pixels_processed += estimated_pixels

            # Calculate batch statistics
            total_time = sum(image_times)
            avg_time = sum(image_times) / len(image_times)
            min_time = min(image_times)
            max_time = max(image_times)
            throughput_mp = total_pixels_processed / total_time / 1000000

            print(f'\n📊 Batch Processing Summary:')
            print(f'   ┌─────────────────────────────────────────┐')
            print(f'   │ Metric              │ Value             │')
            print(f'   ├─────────────────────────────────────────┤')
            print(f'   │ Images processed     │ {len(input_paths):>17} │')
            print(f'   │ Total time           │ {total_time:>17.3f}s │')
            print(f'   │ Average per image    │ {avg_time:>17.3f}s │')
            print(f'   │ Fastest image        │ {min_time:>17.3f}s │')
            print(f'   │ Slowest image        │ {max_time:>17.3f}s │')
            print(f'   │ Throughput           │ {len(input_paths)/total_time:>17.2f} img/s │')
            print(f'   │ Megapixels/s         │ {throughput_mp:>17.1f} MP/s │')
            print(f'   └─────────────────────────────────────────┘')