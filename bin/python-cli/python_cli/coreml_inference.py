"""
CoreML inference implementation for python-cli.

Handles image upscaling using CoreML models on Apple Silicon.
"""

import numpy as np
from pathlib import Path
from PIL import Image
import cv2

try:
    import coremltools as ct
    COREML_AVAILABLE = True
except ImportError:
    COREML_AVAILABLE = False


class CoreMLInference:
    """CoreML inference class for image upscaling."""

    def __init__(self, model_path: str):
        if not COREML_AVAILABLE:
            raise ImportError("coremltools not available. Install with: pip install coremltools")

        if not Path(model_path).exists():
            raise FileNotFoundError(f"CoreML model not found: {model_path}")

        self.model_path = model_path
        self.model = ct.models.MLModel(model_path)

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

    def upscale_image(self, input_path: str, output_path: str):
        """Upscale an image using the CoreML model."""
        try:
            # Load and preprocess input image
            input_data = self._load_and_preprocess_image(input_path)

            # Make prediction
            output_dict = self.model.predict({'input': input_data})

            # Get output (assuming single output)
            output_key = list(output_dict.keys())[0]
            output_data = output_dict[output_key]

            # Save result
            self._save_output_image(output_data, output_path)

        except Exception as e:
            raise RuntimeError(f"CoreML inference failed: {e}")