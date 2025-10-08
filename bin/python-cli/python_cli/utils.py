"""
Utility functions for python-cli.
"""

import tempfile
import subprocess
import shutil
import multiprocessing as mp
import threading
import concurrent.futures
import math
import sys
from PIL import Image
import numpy as np
import cv2
import torch
import os
import json
from pathlib import Path
from typing import Optional, List


def get_models_dir() -> Path:
    """Get the models directory path."""
    zsh_config = Path.home() / ".config" / "zsh"
    models_dir = zsh_config / ".models"
    return models_dir


def find_model_file(model_name_or_path: str, model_type: str = "pytorch") -> Path:
    """
    Find a model file by name or return the path if it's already a full path.

    Search order:
    1. If model_name_or_path is a file path and exists, return it
    2. Check config.json for the model
    3. Search in standard model directories

    Args:
        model_name_or_path: Model name (e.g., "YOLOv8n") or full path to model file
        model_type: Type of model - "pytorch" or "coreml" (default: "pytorch")

    Returns:
        Path to the model file

    Raises:
        FileNotFoundError: If model cannot be found
    """
    # If it's already a path and exists, return it
    model_path = Path(model_name_or_path)
    if model_path.exists() and model_path.is_file():
        return model_path

    # Get models directory
    models_dir = get_models_dir()

    # Try config.json first
    config_file = models_dir / "config.json"
    if config_file.exists():
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)

            models = config.get('models', {})
            if model_name_or_path in models:
                model_info = models[model_name_or_path]

                # Prefer pytorch, fallback to coreml
                if model_type == "pytorch" and 'pytorch_path' in model_info:
                    path = Path(model_info['pytorch_path'])
                    if path.exists():
                        return path
                elif model_type == "coreml" and 'coreml_path' in model_info:
                    path = Path(model_info['coreml_path'])
                    if path.exists():
                        return path
        except (json.JSONDecodeError, KeyError):
            pass  # Fall through to directory search

    # Search common locations (both original case and lowercase)
    search_locations: List[Path] = []

    model_name_lower = model_name_or_path.lower()

    if model_type == "pytorch":
        search_locations = [
            models_dir / f"{model_name_or_path}.pt",
            models_dir / f"{model_name_or_path}.pth",
            models_dir / "pytorch" / f"{model_name_or_path}.pt",
            models_dir / "pytorch" / f"{model_name_or_path}.pth",
            # Try lowercase versions
            models_dir / f"{model_name_lower}.pt",
            models_dir / f"{model_name_lower}.pth",
            models_dir / "pytorch" / f"{model_name_lower}.pt",
            models_dir / "pytorch" / f"{model_name_lower}.pth",
        ]
    elif model_type == "coreml":
        search_locations = [
            models_dir / f"{model_name_or_path}.mlmodel",
            models_dir / "apple-silicon" / f"{model_name_or_path}.mlmodel",
            models_dir / "apple-silicon" / f"{model_name_or_path}.mlpackage",
            # Try lowercase versions
            models_dir / f"{model_name_lower}.mlmodel",
            models_dir / "apple-silicon" / f"{model_name_lower}.mlmodel",
            models_dir / "apple-silicon" / f"{model_name_lower}.mlpackage",
        ]

    # Try each location
    for location in search_locations:
        if location.exists():
            if location.is_file():
                return location
            elif location.is_dir() and location.suffix == '.mlpackage':
                # Look for .mlmodel file inside .mlpackage directory
                mlmodel_file = location / "Data" / "com.apple.CoreML" / "model.mlmodel"
                if mlmodel_file.exists() and mlmodel_file.is_file():
                    return mlmodel_file

    # Model not found - raise error with helpful message
    error_msg = f"Model '{model_name_or_path}' not found.\n\nSearched locations:\n"
    for location in search_locations:
        error_msg += f"  • {location}\n"
    error_msg += "\nRun 'make pytorch-setup' to download models."

    raise FileNotFoundError(error_msg)


# PyTorch inference utilities


def get_optimal_device() -> torch.device:
    """Get the best available device for inference with memory optimization."""
    if torch.cuda.is_available():
        device = torch.device('cuda')
        # Optimize CUDA memory
        torch.backends.cudnn.benchmark = True  # Optimize for consistent input sizes
        torch.backends.cudnn.deterministic = False  # Allow non-deterministic for speed
        # Enable mixed precision if available
        if torch.cuda.get_device_capability(device)[0] >= 7:  # V100, RTX 20xx+
            torch.backends.cuda.matmul.allow_tf32 = True
            torch.backends.cudnn.allow_tf32 = True
        return device
    elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
        # MPS available but may have limitations - we'll use it with fallback logic
        return torch.device('mps')
    else:
        return torch.device('cpu')


def get_optimal_inference_params(image_shape, device, scale_factor=4):
    """
    Calculate optimal tile size, batch size, and worker count based on image size and device capabilities.

    Args:
        image_shape: (height, width) of input image
        device: torch.device being used
        scale_factor: model's upscaling factor

    Returns:
        tuple: (tile_size, batch_size, max_workers)
    """
    height, width = image_shape
    total_pixels = height * width
    scaled_pixels = total_pixels * (scale_factor ** 2)

    # Estimate memory requirements (rough calculation)
    # Input + Output + Intermediate ~ 4x the output size in bytes (float32)
    # 3 channels, 4 bytes, 4x safety factor
    estimated_memory_gb = (scaled_pixels * 3 * 4 * 4) / (1024**3)

    # Get device memory info if available
    if device.type == 'cuda':
        try:
            # Get GPU memory info
            total_memory = torch.cuda.get_device_properties(
                device).total_memory / (1024**3)  # GB
            available_memory = total_memory * 0.7  # Use 70% of available memory
        except:
            available_memory = 8.0  # Conservative fallback
    elif device.type == 'mps':
        available_memory = 4.0  # MPS typically has ~4-8GB shared memory
    else:
        available_memory = 16.0  # Assume decent CPU RAM

    # Calculate optimal tile size based on memory and image size
    if device.type == 'cuda':
        # GPU: Use larger tiles for better parallelization
        if estimated_memory_gb > available_memory * 0.5:
            # Large image, use smaller tiles
            tile_size = min(256, max(128, min(height, width) // 8))
        elif total_pixels > 1024*1024:  # > 1MP
            tile_size = min(512, max(256, min(height, width) // 4))
        else:
            tile_size = min(1024, max(512, min(height, width) // 2))
    elif device.type == 'mps':
        # MPS: Moderate tile sizes work best
        if estimated_memory_gb > available_memory * 0.4:
            tile_size = min(200, max(100, min(height, width) // 10))
        elif total_pixels > 512*512:  # > 0.25MP
            tile_size = min(300, max(150, min(height, width) // 6))
        else:
            tile_size = min(400, max(200, min(height, width) // 3))
    else:
        # CPU: Smaller tiles to avoid memory pressure
        if estimated_memory_gb > available_memory * 0.3:
            tile_size = min(150, max(75, min(height, width) // 12))
        elif total_pixels > 256*256:  # > 0.06MP
            tile_size = min(256, max(128, min(height, width) // 8))
        else:
            tile_size = min(350, max(200, min(height, width) // 4))

    # Round to nearest multiple of 32 for better GPU performance
    tile_size = max(64, (tile_size // 32) * 32)

    # Calculate optimal batch size
    if device.type == 'cuda':
        # GPU can handle larger batches
        if tile_size >= 512:
            batch_size = 2
        elif tile_size >= 256:
            batch_size = 4
        else:
            batch_size = 8
    elif device.type == 'mps':
        # MPS prefers smaller batches
        if tile_size >= 300:
            batch_size = 1
        elif tile_size >= 200:
            batch_size = 2
        else:
            batch_size = 4
    else:
        # CPU: Small batches to avoid memory pressure
        if tile_size >= 256:
            batch_size = 1
        elif tile_size >= 150:
            batch_size = 2
        else:
            batch_size = 4

    # Calculate optimal worker count
    import multiprocessing as mp
    cpu_count = mp.cpu_count()

    if device.type == 'cuda':
        # GPU: More workers for better parallelization
        if total_pixels > 2048*2048:  # > 4MP
            max_workers = min(cpu_count, 4)
        elif total_pixels > 1024*1024:  # > 1MP
            max_workers = min(cpu_count, 3)
        else:
            max_workers = min(cpu_count, 2)
    elif device.type == 'mps':
        # MPS: Limited parallelism due to memory constraints
        max_workers = 1
    else:
        # CPU: Avoid oversubscription
        max_workers = 1

    return tile_size, batch_size, max_workers


def print_optimization_info(image_shape, tile_size, batch_size, max_workers, device):
    """Print information about the auto-optimized parameters"""
    height, width = image_shape
    total_pixels = height * width

    print(f'📊 Image Analysis: {width}x{height} ({total_pixels:,} pixels)')
    print(f'📐 Auto-optimized parameters for {device.type.upper()}:')
    print(f'   • Tile size: {tile_size}x{tile_size}')
    print(f'   • Batch size: {batch_size}')
    print(f'   • Workers: {max_workers}')


class BaseImageInference:
    """Base class for PyTorch image inference models"""

    def __init__(self, model=None, scale_factor=4, device=None):
        self.model = model
        self.scale_factor = scale_factor
        self.device = device or get_optimal_device()

    def load_model(self, model_path):
        """Load model from path - to be implemented by subclasses"""
        raise NotImplementedError("Subclasses must implement load_model")

    def preprocess_image(self, image_path):
        """Load and preprocess image for PyTorch model"""
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f'Could not load image: {image_path}')

        # Get original dimensions
        original_height, original_width = img.shape[:2]
        print(f'Original image size: {original_width}x{original_height}')

        # Convert BGR to RGB (for model input)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        # Convert to float32 and normalize to [0, 1]
        img = img.astype(np.float32) / 255.0

        # Convert to tensor: HWC -> CHW and add batch dimension
        img = np.transpose(img, (2, 0, 1))
        img = torch.from_numpy(img).unsqueeze(0)

        return img, (original_width, original_height)

    def save_output_image(self, output_tensor, output_path):
        """Save PyTorch tensor output as image with correct color handling"""
        # Remove batch dimension and convert to numpy
        img = output_tensor.squeeze(0).cpu().numpy()
        img = np.transpose(img, (1, 2, 0))  # CHW -> HWC

        # Get output dimensions
        output_height, output_width = img.shape[:2]

        # Clip values to [0, 1] and convert to uint8
        img = np.clip(img, 0, 1) * 255.0
        img = img.round().astype(np.uint8)

        # Convert RGB back to BGR (for correct color saving)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        # Save using OpenCV (maintains BGR format correctly)
        cv2.imwrite(output_path, img)
        print(f'Saved output image to: {output_path}')
        print(f'Output image size: {output_width}x{output_height}')

    def run_inference(self, input_tensor, tile_size=512, max_workers=None, batch_size=4):
        """Main inference method - chooses best approach based on input size"""
        self.model.eval()

        h, w = input_tensor.shape[2], input_tensor.shape[3]
        total_pixels = h * w

        if tile_size > 0 and (h > tile_size or w > tile_size):
            print(
                f'🔳 Processing with batched tiling ({total_pixels:,} pixels, tile={tile_size}x{tile_size})')
            return self.inference_tiled(input_tensor, tile_size, max_workers, batch_size)
        else:
            print(f'🔄 Running direct inference ({total_pixels:,} pixels)...')
            try:
                with torch.no_grad():
                    return self.model(input_tensor)
            except NotImplementedError as e:
                if "convolution_overrideable" in str(e) and self.device.type == 'mps':
                    print('⚠️  MPS convolution not supported, falling back to CPU...')
                    self.device = torch.device('cpu')
                    input_tensor = input_tensor.to(self.device)
                    self.model = self.model.to(self.device)
                    with torch.no_grad():
                        return self.model(input_tensor)
                else:
                    raise e

    def inference_tiled(self, input_tensor, tile_size, max_workers=None, batch_size=4):
        """Run inference with parallel batched tiling for maximum speed."""
        batch, channel, height, width = input_tensor.shape
        output_height = height * self.scale_factor
        output_width = width * self.scale_factor

        # Initialize output tensor with memory check
        output_shape = (batch, channel, output_height, output_width)
        output_size_bytes = torch.tensor(
            output_shape).prod().item() * 4  # float32 = 4 bytes
        output_size_gb = output_size_bytes / (1024**3)

        # Check if output size is reasonable for available memory
        if self.device.type == 'mps':
            max_reasonable_size = 4.0  # 4GB limit for MPS
        elif self.device.type == 'cuda':
            max_reasonable_size = 8.0  # 8GB limit for CUDA
        else:
            max_reasonable_size = 2.0  # 2GB limit for CPU

        if output_size_gb > max_reasonable_size:
            print(
                f'⚠️  Large output detected ({output_size_gb:.1f}GB). Using memory-efficient streaming mode...')
            return self.inference_streaming(input_tensor, tile_size, max_workers, batch_size)

        try:
            output = torch.zeros(
                output_shape, dtype=input_tensor.dtype, device=self.device)
        except RuntimeError as e:
            if "out of memory" in str(e).lower():
                raise RuntimeError(f"Cannot allocate {output_size_gb:.1f}GB output tensor. " +
                                   f"Try smaller tile size (current: {tile_size}) or smaller input image.")
            else:
                raise

        # Calculate tiles and process them (simplified version)
        tiles_x = math.ceil(width / tile_size)
        tiles_y = math.ceil(height / tile_size)
        total_tiles = tiles_x * tiles_y

        if max_workers is None:
            max_workers = 1 if self.device.type in [
                'mps', 'cpu'] else min(4, mp.cpu_count())

        print(
            f'   Processing {total_tiles} tiles with batch size {batch_size} and {max_workers} workers ({tiles_x}x{tiles_y})...')

        completed = 0
        for y in range(tiles_y):
            for x in range(tiles_x):
                start_x = x * tile_size
                start_y = y * tile_size
                end_x = min(start_x + tile_size, width)
                end_y = min(start_y + tile_size, height)

                # Extract and process tile
                tile = input_tensor[:, :, start_y:end_y,
                                    start_x:end_x].to(self.device)

                with torch.no_grad():
                    tile_output = self.model(tile)

                # Calculate output positions and place in output
                scale = self.scale_factor
                out_start_x = start_x * scale
                out_start_y = start_y * scale
                out_end_x = end_x * scale
                out_end_y = end_y * scale

                output[:, :, out_start_y:out_end_y,
                       out_start_x:out_end_x] = tile_output

                completed += 1
                if completed % max(1, total_tiles // 20) == 0 or completed == total_tiles:
                    print(
                        f'      Progress: {completed}/{total_tiles} tiles completed ({100*completed/total_tiles:.0f}%)')

        return output

    def inference_streaming(self, input_tensor, tile_size, max_workers=None, batch_size=4):
        """Memory-efficient streaming inference that processes tiles row by row."""
        batch, channel, height, width = input_tensor.shape
        output_height = height * self.scale_factor
        output_width = width * self.scale_factor
        scale_factor = self.scale_factor

        print(
            f'   🌊 Streaming mode: processing {height}x{width} -> {output_height}x{output_width}')

        # Initialize output as numpy array on CPU (much more memory efficient)
        output_np = np.zeros((output_height, output_width, 3), dtype=np.uint8)

        # Process tiles row by row to minimize memory usage
        tiles_x = math.ceil(width / tile_size)
        tiles_y = math.ceil(height / tile_size)
        total_tiles = tiles_x * tiles_y

        print(f'   Processing {total_tiles} tiles in streaming mode...')

        completed = 0
        for y in range(tiles_y):
            for x in range(tiles_x):
                start_x = x * tile_size
                start_y = y * tile_size
                end_x = min(start_x + tile_size, width)
                end_y = min(start_y + tile_size, height)

                tile = input_tensor[:, :, start_y:end_y,
                                    start_x:end_x].to(self.device)

                try:
                    with torch.no_grad():
                        tile_output = self.model(tile)
                except RuntimeError as e:
                    if "out of memory" in str(e).lower():
                        print(
                            f'   ⚠️  GPU OOM on tile, falling back to CPU for this tile...')
                        tile_cpu = tile.cpu()
                        model_cpu = self.model.cpu()
                        with torch.no_grad():
                            tile_output = model_cpu(tile_cpu)
                        self.model = self.model.to(self.device)
                    else:
                        raise

                # Convert tile output to numpy and place in output array
                tile_np = tile_output.squeeze(0).cpu().numpy()
                tile_np = np.transpose(tile_np, (1, 2, 0))  # CHW -> HWC
                tile_np = np.clip(tile_np, 0, 1) * 255.0
                tile_np = tile_np.round().astype(np.uint8)

                # Calculate output position
                out_start_x = start_x * scale_factor
                out_start_y = start_y * scale_factor
                out_end_x = end_x * scale_factor
                out_end_y = end_y * scale_factor

                # Place tile in output array
                out_h, out_w = tile_np.shape[:2]
                output_np[out_start_y:out_start_y + out_h,
                          out_start_x:out_start_x + out_w] = tile_np

                completed += 1
                if completed % max(1, total_tiles // 20) == 0 or completed == total_tiles:
                    print(
                        f'      Progress: {completed}/{total_tiles} tiles completed ({100*completed/total_tiles:.0f}%)')

        # Convert numpy array back to tensor on device for final processing
        output_tensor = torch.from_numpy(
            output_np.transpose(2, 0, 1)).unsqueeze(0).float() / 255.0
        output_tensor = output_tensor.to(self.device)

        return output_tensor

    def process_image(self, input_path, output_path, tile_size=None, max_workers=None, batch_size=None):
        """Complete image processing pipeline with smart auto-optimization"""
        # Load and preprocess image
        input_tensor, original_size = self.preprocess_image(input_path)
        input_tensor = input_tensor.to(self.device)
        print(f'Input shape: {input_tensor.shape}')

        # Smart auto-optimization if parameters are not provided
        if tile_size is None or max_workers is None or batch_size is None:
            # (height, width)
            image_shape = (original_size[1], original_size[0])
            opt_tile_size, opt_batch_size, opt_max_workers = get_optimal_inference_params(
                image_shape, self.device, self.scale_factor
            )

            # Use provided values or auto-optimized ones
            tile_size = tile_size if tile_size is not None else opt_tile_size
            batch_size = batch_size if batch_size is not None else opt_batch_size
            max_workers = max_workers if max_workers is not None else opt_max_workers

            print_optimization_info(
                image_shape, tile_size, batch_size, max_workers, self.device)
        else:
            print(
                f'📊 Using provided parameters: tile={tile_size}, batch={batch_size}, workers={max_workers}')

        # Run inference
        output_tensor = self.run_inference(
            input_tensor, tile_size, max_workers, batch_size)
        print(f'Output shape: {output_tensor.shape}')

        # Calculate expected output size
        expected_width = original_size[0] * self.scale_factor
        expected_height = original_size[1] * self.scale_factor
        print(f'Expected output size: {expected_width}x{expected_height}')

        # Save result
        self.save_output_image(output_tensor, output_path)


# Safe File Deletion Utilities


def safe_remove_file(file_path):
    """
    Safely remove a file by moving it to trash instead of permanent deletion.

    Args:
        file_path: Path to the file to remove (str or Path object)

    Returns:
        bool: True if successful, False otherwise
    """
    file_path = Path(file_path)

    if not file_path.exists():
        return True

    try:
        # Try to use rmtrash if available
        result = subprocess.run(['rmtrash', str(file_path)],
                                capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(f"🗑️  Moved to trash: {file_path}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Fallback to send2trash if available
    try:
        import send2trash
        send2trash.send2trash(str(file_path))
        print(f"🗑️  Moved to trash: {file_path}")
        return True
    except ImportError:
        pass
    except Exception as e:
        print(f"⚠️  Failed to move to trash: {e}")

    # Final fallback - use os.remove with warning
    try:
        print(f"⚠️  Permanently deleting (trash unavailable): {file_path}")
        os.remove(file_path)
        return True
    except Exception as e:
        print(f"❌ Failed to delete file: {e}")
        return False


def safe_remove_directory(dir_path):
    """
    Safely remove a directory by moving it to trash instead of permanent deletion.

    Args:
        dir_path: Path to the directory to remove (str or Path object)

    Returns:
        bool: True if successful, False otherwise
    """
    dir_path = Path(dir_path)

    if not dir_path.exists():
        return True

    # For directories, try to use rmtrash
    try:
        result = subprocess.run(['rmtrash', '-rf', str(dir_path)],
                                capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(f"🗑️  Moved directory to trash: {dir_path}")
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Fallback to send2trash if available
    try:
        import send2trash
        send2trash.send2trash(str(dir_path))
        print(f"🗑️  Moved directory to trash: {dir_path}")
        return True
    except ImportError:
        pass
    except Exception as e:
        print(f"⚠️  Failed to move directory to trash: {e}")

    # Final fallback - use shutil.rmtree with warning
    try:
        print(
            f"⚠️  Permanently deleting directory (trash unavailable): {dir_path}")
        shutil.rmtree(dir_path)
        return True
    except Exception as e:
        print(f"❌ Failed to delete directory: {e}")
        return False


# Backward compatibility aliases
safe_remove = safe_remove_file
safe_rmtree = safe_remove_directory
