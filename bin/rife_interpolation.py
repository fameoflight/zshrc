#!/usr/bin/env python3
"""
RIFE (Real-time Intermediate Flow Estimation) Video Frame Interpolation
Optimized for Apple Silicon with PyTorch MPS backend

Usage: rife_interpolation.py --frame1 frame1.jpg --frame2 frame2.jpg --ratio 0.5 --output result.jpg
"""

import torch
import torch.nn.functional as F
import numpy as np
import cv2
import os
import sys
import argparse
import time
from typing import Optional, Tuple
from pathlib import Path

# Add python-cli to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'python-cli'))
from rife_arch import IFNet

class RIFEInterpolator:
    """RIFE frame interpolation with Apple Silicon optimization"""

    def __init__(self, model_path: str, model_version: str = "rife4.9"):
        """
        Initialize RIFE interpolator

        Args:
            model_path: Path to RIFE model weights
            model_version: RIFE model version ("rife4.9", "rife4.7", etc.)
        """
        self.model_version = model_version
        self.device = torch.device('mps' if torch.backends.mps.is_available() else 'cpu')
        self.scale = 1.0
        self.ensemble = False

        print(f"🎬 Initializing RIFE {model_version} interpolator...")
        print(f"   • Device: {self.device}")
        print(f"   • Model path: {model_path}")

        self.model = self._load_rife_model(model_path)

    def _load_rife_model(self, model_path: str):
        """Load RIFE model weights"""
        try:
            if not os.path.exists(model_path):
                raise FileNotFoundError(f"RIFE model not found: {model_path}")

            # Create IFNet model
            model = IFNet(scale=self.scale, ensemble=self.ensemble)

            # Load state dict
            state_dict = torch.load(model_path, map_location=self.device, weights_only=False)

            # Handle different state dict formats
            if 'state_dict' in state_dict:
                state_dict = state_dict['state_dict']
            elif 'model' in state_dict:
                state_dict = state_dict['model']

            # Remove 'module.' prefix if present (from DataParallel)
            new_state_dict = {}
            for k, v in state_dict.items():
                name = k.replace('module.', '') if k.startswith('module.') else k
                new_state_dict[name] = v

            model.load_state_dict(new_state_dict, strict=False)
            model.eval().to(self.device)

            print(f"✅ RIFE {self.model_version} model loaded successfully")
            return model

        except Exception as e:
            print(f"❌ Failed to load RIFE model: {e}")
            raise

    def preprocess_frame(self, frame: np.ndarray) -> torch.Tensor:
        """Preprocess frame for RIFE model"""
        # Convert BGR to RGB
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Convert to float32 and normalize to [0, 1]
        tensor = torch.from_numpy(frame_rgb).float() / 255.0

        # Transpose HWC to CHW
        tensor = tensor.permute(2, 0, 1)

        # Add batch dimension
        tensor = tensor.unsqueeze(0).to(self.device)

        return tensor

    def postprocess_frame(self, tensor: torch.Tensor) -> np.ndarray:
        """Postprocess RIFE output tensor back to numpy image"""
        # Remove batch dimension and move to CPU
        tensor = tensor.squeeze(0).cpu()

        # Convert to numpy and denormalize
        frame_np = tensor.numpy().transpose(1, 2, 0)
        frame_np = (frame_np * 255).astype(np.uint8)

        # Convert RGB back to BGR
        frame_bgr = cv2.cvtColor(frame_np, cv2.COLOR_RGB2BGR)

        return frame_bgr

    def interpolate_frame(self, frame1: np.ndarray, frame2: np.ndarray, ratio: float) -> np.ndarray:
        """
        Generate intermediate frame between frame1 and frame2

        Args:
            frame1: First frame (numpy array BGR)
            frame2: Second frame (numpy array BGR)
            ratio: Interpolation ratio (0.0 = frame1, 1.0 = frame2)

        Returns:
            Interpolated frame (numpy array BGR)
        """
        if ratio <= 0.0:
            return frame1.copy()
        elif ratio >= 1.0:
            return frame2.copy()

        start_time = time.time()

        # Preprocess frames
        img0 = self.preprocess_frame(frame1)
        img1 = self.preprocess_frame(frame2)

        # Generate intermediate frame with RIFE
        with torch.no_grad():
            # Get image dimensions
            h, w = img0.shape[2:4]

            # Pad to multiple of 32 for RIFE
            ph = ((h - 1) // 32 + 1) * 32
            pw = ((w - 1) // 32 + 1) * 32
            padding = (0, pw - w, 0, ph - h)
            img0 = F.pad(img0, padding, mode='replicate')
            img1 = F.pad(img1, padding, mode='replicate')

            # Create flow grids for warping
            h_padded, w_padded = img0.shape[2:4]
            tenFlow_div = torch.tensor([w_padded, h_padded], device=self.device).view(1, 2, 1, 1)

            # Create backwarp grid (width, height) - note the order!
            grid_y, grid_x = torch.meshgrid(
                torch.linspace(-1, 1, h_padded, device=self.device),
                torch.linspace(-1, 1, w_padded, device=self.device),
                indexing='ij'
            )
            backwarp_tenGrid = torch.stack([grid_x, grid_y], dim=0).unsqueeze(0)

            # Encode frames
            f0 = self.model.encode(img0)
            f1 = self.model.encode(img1)

            # Create timestep tensor
            timestep = torch.full((1, 1, h_padded, w_padded), ratio, device=self.device)

            # Run RIFE inference
            interpolated = self.model(img0, img1, timestep, tenFlow_div, backwarp_tenGrid, f0, f1)

            # Remove padding
            interpolated = interpolated[:, :, :h, :w]

            processing_time = time.time() - start_time

        # Postprocess result
        result = self.postprocess_frame(interpolated)

        return result


class HighQualityInterpolator:
    """Fallback high-quality interpolation when RIFE is not available"""

    @staticmethod
    def interpolate_frame(frame1: np.ndarray, frame2: np.ndarray, ratio: float) -> np.ndarray:
        """High-quality interpolation using advanced OpenCV techniques"""

        if ratio <= 0.0:
            return frame1.copy()
        elif ratio >= 1.0:
            return frame2.copy()

        # Resize frames to common dimensions
        h, w = frame1.shape[:2]
        frame1_resized = cv2.resize(frame1, (w, h))
        frame2_resized = cv2.resize(frame2, (w, h))

        # Multi-blend interpolation for better quality
        # This simulates some of RIFE's quality improvements

        # Primary linear interpolation
        primary = cv2.addWeighted(frame1_resized, 1 - ratio, frame2_resized, ratio, 0)

        # Add sharpening for better detail preservation
        kernel = np.array([[-1, -1, -1],
                          [-1,  9, -1],
                          [-1, -1, -1]]) / 9.0

        sharpened = cv2.filter2D(primary, -1, kernel)

        # Blend sharpened result with primary for natural look
        result = cv2.addWeighted(primary, 0.7, sharpened, 0.3, 0)

        return result


def find_rife_model(model_version: str) -> str:
    """Find RIFE model file in standard locations"""

    # Map model versions to standard filenames
    model_files = {
        "rife4.9": "rife49.pth",
        "rife4.7": "rife47.pth",
        "rife4.6": "rife46.pth",
        "rife4.3": "rife43.pth",
        "rife": "rife49.pth",  # Default to 4.9 (latest)
        "rife-lite": "rife_lite.pth"
    }

    if model_version not in model_files:
        model_version = "rife4.9"  # Default fallback to latest

    model_filename = model_files[model_version]

    # Search in standard model directories
    zsh_config = os.environ.get('ZSH_CONFIG', '/Users/hemantv/zshrc')
    search_paths = [
        os.path.join(zsh_config, '.models', 'rife', model_filename),
        os.path.join(zsh_config, '.models', model_filename),
        os.path.join(zsh_config, '.models', 'interpolation', model_filename),
        os.path.join(zsh_config, '.models', 'apple-silicon', 'rife', model_filename),
    ]

    for path in search_paths:
        if os.path.exists(path):
            return path

    # Return the expected path even if it doesn't exist (will trigger download)
    return os.path.join(zsh_config, '.models', 'rife', model_filename)


def main():
    """Command line interface for RIFE interpolation"""
    parser = argparse.ArgumentParser(description='RIFE Video Frame Interpolation')
    parser.add_argument('--frame1', required=True, help='First input frame path')
    parser.add_argument('--frame2', required=True, help='Second input frame path')
    parser.add_argument('--ratio', type=float, default=0.5, help='Interpolation ratio (0.0-1.0)')
    parser.add_argument('--output', required=True, help='Output frame path')
    parser.add_argument('--model', default='rife4.9',
                       choices=['rife4.9', 'rife4.7', 'rife4.6', 'rife4.3', 'rife', 'rife-lite'],
                       help='RIFE model version')
    parser.add_argument('--fallback', action='store_true',
                       help='Use high-quality interpolation fallback if RIFE model not found')

    args = parser.parse_args()

    # Validate inputs
    if not os.path.exists(args.frame1):
        print(f"❌ First frame not found: {args.frame1}")
        return 1

    if not os.path.exists(args.frame2):
        print(f"❌ Second frame not found: {args.frame2}")
        return 1

    if not 0.0 <= args.ratio <= 1.0:
        print(f"❌ Ratio must be between 0.0 and 1.0, got {args.ratio}")
        return 1

    # Load frames
    frame1 = cv2.imread(args.frame1)
    frame2 = cv2.imread(args.frame2)

    if frame1 is None:
        print(f"❌ Could not read first frame: {args.frame1}")
        return 1

    if frame2 is None:
        print(f"❌ Could not read second frame: {args.frame2}")
        return 1

    print(f"🎬 RIFE Frame Interpolation")
    print(f"   • Frame 1: {args.frame1}")
    print(f"   • Frame 2: {args.frame2}")
    print(f"   • Ratio: {args.ratio}")
    print(f"   • Model: {args.model}")
    print(f"   • Output: {args.output}")

    try:
        # Try RIFE interpolation
        model_path = find_rife_model(args.model)
        interpolator = RIFEInterpolator(model_path, args.model)

        result = interpolator.interpolate_frame(frame1, frame2, args.ratio)

    except Exception as e:
        if args.fallback:
            print(f"⚠️  RIFE interpolation failed ({e}), using high-quality fallback")
            result = HighQualityInterpolator.interpolate_frame(frame1, frame2, args.ratio)
        else:
            print(f"❌ RIFE interpolation failed: {e}")
            print(f"💡 Use --fallback for high-quality interpolation without RIFE model")
            return 1

    # Save result
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    success = cv2.imwrite(args.output, result)

    if success:
        print(f"✅ Interpolated frame saved to: {args.output}")
        return 0
    else:
        print(f"❌ Failed to save output frame: {args.output}")
        return 1


if __name__ == "__main__":
    exit(main())