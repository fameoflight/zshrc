"""
PyTorch inference fallback for python-cli.

Handles image upscaling using PyTorch models when CoreML is not available.
"""

from pathlib import Path
import subprocess
import sys


class PyTorchInference:
    """PyTorch inference class for image upscaling (fallback)."""

    def __init__(self, model_path: str):
        if not Path(model_path).exists():
            raise FileNotFoundError(f"PyTorch model not found: {model_path}")

        self.model_path = model_path

    def upscale_image(self, input_path: str, output_path: str):
        """Upscale an image using PyTorch model via upscaler-pro-models."""
        try:
            from .utils import get_python_executable, get_upscaler_dir

            # Get paths
            python_exe = get_python_executable()
            upscaler_dir = get_upscaler_dir()
            inference_script = upscaler_dir / "inference_pipeline.py"

            if not inference_script.exists():
                raise FileNotFoundError(f"Inference script not found: {inference_script}")

            # Run inference using the existing pipeline
            cmd = [
                str(python_exe),
                str(inference_script),
                "--input", input_path,
                "--output", output_path,
                "--model_path", self.model_path
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                error_msg = result.stderr or result.stdout
                raise RuntimeError(f"PyTorch inference failed: {error_msg}")

        except Exception as e:
            raise RuntimeError(f"PyTorch inference failed: {e}")