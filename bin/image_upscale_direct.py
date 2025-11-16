#!/usr/bin/env python3
# @category: media
# @description: Optimized image upscaling using CoreML for Apple Silicon
# @tags: ml, coreml, image-processing, apple-silicon

"""
Optimized image upscaling using direct CoreML implementation
No python-cli dependency - uses CoreML directly for optimal Apple Silicon performance
"""

import cv2
import numpy as np
import coremltools as ct
from pathlib import Path
import time
import sys
import os
import argparse
from typing import Dict, Optional

# Try to import tqdm for nice progress bars
try:
    from tqdm import tqdm
except ImportError:
    # Fallback simple progress bar if tqdm not available
    class tqdm:
        def __init__(self, iterable=None, **kwargs):
            self.iterable = iterable
            self.total = kwargs.get('total', len(
                iterable) if hasattr(iterable, '__len__') else None)
            self.desc = kwargs.get('desc', '')
            self.unit = kwargs.get('unit', 'it')
            self.current = 0

        def __iter__(self):
            if self.iterable is not None:
                for item in self.iterable:
                    yield item
                    self.current += 1
                    if self.total:
                        percent = (self.current * 100) // self.total
                        print(
                            f"\r{self.desc}: {percent}% ({self.current}/{self.total})", end="", flush=True)
                    else:
                        print(
                            f"\r{self.desc}: {self.current} {self.unit}", end="", flush=True)

        def update(self, n=1):
            self.current += n
            if self.total:
                percent = (self.current * 100) // self.total
                print(
                    f"\r{self.desc}: {percent}% ({self.current}/{self.total})", end="", flush=True)
            else:
                print(f"\r{self.desc}: {self.current} {self.unit}",
                      end="", flush=True)

        def close(self):
            print()  # New line when done


class CoreMLImageUpscaler:
    """Image upscaler using direct CoreML implementation for optimal Apple Silicon performance"""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.tile_size = self._calculate_optimal_tile_size()

    def _calculate_optimal_tile_size(self) -> int:
        """Calculate optimal tile size for CoreML on high-performance systems"""
        # With 60-core GPU, we can handle much larger tiles for better performance
        return 1024  # Optimized for high-end GPUs with many cores

    def load_model(self):
        """Load CoreML model directly"""
        if self.model is not None:
            return

        print(f"🔄 Loading CoreML model: {self.model_path}")
        print(f"   • Tile size: {self.tile_size}")

        if not os.path.exists(self.model_path):
            raise FileNotFoundError(
                f"CoreML model file not found: {self.model_path}")

        try:
            # Load CoreML model
            self.model = ct.models.MLModel(self.model_path)
            print("✅ CoreML model loaded successfully")
        except Exception as e:
            raise RuntimeError(f"Failed to load CoreML model: {e}")

    def preprocess_image(self, img: np.ndarray) -> Dict[str, np.ndarray]:
        """Preprocess image for CoreML model input"""
        # CoreML models typically expect (1, 3, H, W) format in float32
        img = img.astype(np.float32) / 255.0
        img = np.transpose(img, (2, 0, 1))  # HWC -> CHW
        img = np.expand_dims(img, axis=0)   # Add batch dimension

        return {"input": img}

    def postprocess_image(self, output_dict: Dict[str, np.ndarray]) -> np.ndarray:
        """Postprocess CoreML model output to image"""
        # CoreML output should be (1, 3, H, W) format
        if isinstance(output_dict, dict):
            output = list(output_dict.values())[0]
        else:
            output = output_dict

        # Remove batch dimension and transpose CHW -> HWC
        output = np.squeeze(output, axis=0)
        output = np.transpose(output, (1, 2, 0))

        # Convert to uint8
        output = np.clip(output * 255.0, 0, 255).astype(np.uint8)
        return output

    def upscale_image_tiled(self, img: np.ndarray, scale: int = 4) -> np.ndarray:
        """Upscale image using tiled CoreML processing for optimal memory efficiency"""
        h, w = img.shape[:2]
        output_h, output_w = h * scale, w * scale

        # For smaller images, process directly without tiling
        if h <= self.tile_size and w <= self.tile_size:
            print(f"   Processing image directly ({h}x{w})")
            input_dict = self.preprocess_image(img)
            output_dict = self.model.predict(input_dict)
            return self.postprocess_image(output_dict)

        print(
            f"   Processing image with tiles ({h}x{w} -> {output_h}x{output_w})")

        # Initialize output
        output = np.zeros((output_h, output_w, 3), dtype=np.uint8)

        # Process tiles with overlap for seamless blending
        overlap = 64  # Larger overlap for better quality
        scale_factor = scale

        for y in range(0, h, self.tile_size - overlap):
            for x in range(0, w, self.tile_size - overlap):
                # Calculate tile boundaries
                y_end = min(y + self.tile_size, h)
                x_end = min(x + self.tile_size, w)

                # Extract tile
                tile = img[y:y_end, x:x_end]

                # Skip if tile is too small
                if tile.shape[0] < 32 or tile.shape[1] < 32:
                    continue

                try:
                    # Process tile with CoreML
                    input_dict = self.preprocess_image(tile)
                    output_dict = self.model.predict(input_dict)
                    upscaled_tile = self.postprocess_image(output_dict)

                    # Calculate output boundaries
                    out_y = y * scale_factor
                    out_x = x * scale_factor
                    out_y_end = out_y + upscaled_tile.shape[0]
                    out_x_end = out_x + upscaled_tile.shape[1]

                    # Handle edge cases
                    if out_y_end > output_h:
                        out_y_end = output_h
                        upscaled_tile = upscaled_tile[:output_h - out_y, :]
                    if out_x_end > output_w:
                        out_x_end = output_w
                        upscaled_tile = upscaled_tile[:, :output_w - out_x]

                    # Blend tiles with overlapping regions
                    if y == 0 and x == 0:
                        # First tile - no blending needed
                        output[out_y:out_y_end, out_x:out_x_end] = upscaled_tile
                    else:
                        # Blend overlapping regions
                        blend_overlap = overlap * scale_factor

                        # Top edge blending
                        if y > 0 and out_y < output_h:
                            blend_start = max(0, out_y - blend_overlap // 2)
                            blend_end = min(
                                out_y + blend_overlap // 2, output_h)
                            if blend_start < blend_end and blend_end <= out_y_end:
                                # Calculate alpha weights
                                alpha_weights = np.linspace(
                                    0.3, 1.0, blend_end - blend_start)
                                for c in range(3):
                                    output[blend_start:blend_end, out_x:out_x_end, c] = (
                                        alpha_weights * upscaled_tile[blend_start - out_y:blend_end - out_y, c] +
                                        (1 - alpha_weights) *
                                        output[blend_start:blend_end,
                                               out_x:out_x_end, c]
                                    ).astype(np.uint8)

                        # Left edge blending
                        if x > 0 and out_x < output_w:
                            blend_start = max(0, out_x - blend_overlap // 2)
                            blend_end = min(out_x + blend_overlap // 2, out_w)
                            if blend_start < blend_end and blend_end <= out_x_end:
                                # Calculate alpha weights
                                alpha_weights = np.linspace(
                                    0.3, 1.0, blend_end - blend_start)
                                for c in range(3):
                                    output[out_y:out_y_end, blend_start:blend_end, c] = (
                                        alpha_weights * upscaled_tile[blend_start - out_x:blend_end - out_x, c] +
                                        (1 - alpha_weights) *
                                        output[out_y:out_y_end,
                                               blend_start:blend_end, c]
                                    ).astype(np.uint8)

                        # Fill non-overlapping region
                        fill_y = out_y + (blend_overlap // 2 if y > 0 else 0)
                        fill_x = out_x + (blend_overlap // 2 if x > 0 else 0)
                        fill_y_end = min(out_y_end, output_h)
                        fill_x_end = min(out_x_end, output_w)

                        if fill_y < fill_y_end and fill_x < fill_x_end:
                            src_y = fill_y - out_y
                            src_x = fill_x - out_x
                            src_y_end = fill_y_end - out_y
                            src_x_end = fill_x_end - out_x

                            output[fill_y:fill_y_end,
                                   fill_x:fill_x_end] = upscaled_tile[src_y:src_y_end, src_x:src_x_end]

                except Exception as e:
                    print(
                        f"⚠️  Warning: Failed to process tile at ({x}, {y}): {e}")
                    # Fallback to simple resize for this region
                    fallback_tile = cv2.resize(tile, (tile.shape[1] * scale, tile.shape[0] * scale),
                                               interpolation=cv2.INTER_LANCZOS4)
                    output[y * scale:(y + tile.shape[0]) * scale,
                           x * scale:(x + tile.shape[1]) * scale] = fallback_tile

        return output

    def upscale_image(self, input_path: str, output_path: str, scale: int = 4) -> bool:
        """Main image upscaling function with CoreML"""

        print(f"🎨 Starting CoreML image upscaling...")
        print(f"   • Input: {input_path}")
        print(f"   • Output: {output_path}")
        print(f"   • Scale: {scale}x")

        # Load input image
        img = cv2.imread(input_path)
        if img is None:
            print(f"❌ Could not read input image: {input_path}")
            return False

        h, w = img.shape[:2]
        print(f"   • Input resolution: {w}x{h}")

        # Load model
        try:
            self.load_model()
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            return False

        # Process image
        start_time = time.time()
        try:
            upscaled_img = self.upscale_image_tiled(img, scale)
        except Exception as e:
            print(f"❌ Failed to upscale image: {e}")
            return False

        processing_time = time.time() - start_time
        output_h, output_w = upscaled_img.shape[:2]

        print(f"   • Output resolution: {output_w}x{output_h}")
        print(f"   • Processing time: {processing_time:.2f}s")
        print(
            f"   • Processing speed: {(w*h)/(processing_time*1000000):.2f} MP/s")

        # Save output image
        try:
            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            cv2.imwrite(output_path, upscaled_img)
            print(f"✅ Image upscaling completed successfully!")
            print(f"   • Result saved to: {output_path}")
            return True
        except Exception as e:
            print(f"❌ Failed to save output image: {e}")
            return False


def find_coreml_model_file(model_name: str) -> str:
    """Find CoreML model file in standard locations"""
    zsh_config = os.environ.get('ZSH_CONFIG', '/Users/hemantv/zshrc')
    models_dir = os.path.join(zsh_config, '.models')

    # Check for CoreML model with different extensions
    possible_paths = [
        os.path.join(models_dir, f"{model_name}.mlmodel"),
        os.path.join(models_dir, f"{model_name}.mlpackage"),
        os.path.join(models_dir, "coreml", f"{model_name}.mlmodel"),
        os.path.join(models_dir, "coreml", f"{model_name}.mlpackage"),
        os.path.join(models_dir, "apple-silicon",
                     "models", f"{model_name}.mlmodel"),
        os.path.join(models_dir, "apple-silicon",
                     "models", f"{model_name}.mlpackage"),
        os.path.join(models_dir, f"{model_name}.mlmodelc"),  # Compiled model
    ]

    for path in possible_paths:
        if os.path.exists(path):
            return path

    # If not found, try to find any .mlmodel file with similar name
    import glob
    pattern = os.path.join(models_dir, "**", f"*{model_name}*.mlmodel")
    matches = glob.glob(pattern, recursive=True)
    if matches:
        return matches[0]

    # Check for .mlpackage files
    pattern = os.path.join(models_dir, "**", f"*{model_name}*.mlpackage")
    matches = glob.glob(pattern, recursive=True)
    if matches:
        return matches[0]

    # Check for compiled models
    pattern = os.path.join(models_dir, "**", f"*{model_name}*.mlmodelc")
    matches = glob.glob(pattern, recursive=True)
    if matches:
        return matches[0]

    return model_name  # Return as-is, will raise error later


def main():
    """Main function for image upscaling"""
    parser = argparse.ArgumentParser(
        description='Optimized image upscaling using direct CoreML')
    parser.add_argument('input', help='Input image path')
    parser.add_argument('output', nargs='?',
                        help='Output image path (optional)')
    parser.add_argument(
        '--model', default='RealESRGAN_x4plus', help='CoreML model name')
    parser.add_argument('--scale', type=int, default=4,
                        help='Upscale factor (2, 4)')
    parser.add_argument('--tile', type=int,
                        help='Tile size for large images (auto-optimized)')

    args = parser.parse_args()

    # Validate input file
    if not os.path.exists(args.input):
        print(f"❌ Input file not found: {args.input}")
        return 1

    # Generate output path if not provided
    if args.output is None:
        input_path = Path(args.input)
        args.output = str(input_path.parent /
                          f"{input_path.stem}_upscaled{input_path.suffix}")

    # Validate scale factor
    if args.scale not in [2, 4]:
        print(f"❌ Scale factor must be 2 or 4, got {args.scale}")
        return 1

    # Find CoreML model file
    model_path = find_coreml_model_file(args.model)

    # Initialize CoreML upscaler
    try:
        upscaler = CoreMLImageUpscaler(model_path)
    except Exception as e:
        print(f"❌ Failed to initialize CoreML upscaler: {e}")
        return 1

    # Override tile size if provided
    if args.tile:
        upscaler.tile_size = args.tile
        print(f"   • Using custom tile size: {args.tile}")

    # Process image
    success = upscaler.upscale_image(args.input, args.output, args.scale)

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
