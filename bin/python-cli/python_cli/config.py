"""
Configuration management for python-cli.

Handles loading and accessing model configuration.
"""

import json
from pathlib import Path
from typing import Dict, Any

from .utils import get_models_dir


class Config:
    """Configuration class for python-cli."""

    def __init__(self, config_data: Dict[str, Any]):
        self.models = config_data.get("models", {})
        self.default_model = config_data.get("default_model", "RealESRGAN_x4plus")
        self.paths = config_data.get("paths", {})
        self.updated_at = config_data.get("updated_at", "")

    @classmethod
    def load(cls) -> "Config":
        """Load configuration from the default location."""
        config_file = get_models_dir() / "config.json"

        if not config_file.exists():
            raise FileNotFoundError(
                f"Configuration file not found: {config_file}\n"
                "Run 'make pytorch-setup' to set up models and configuration."
            )

        try:
            with open(config_file, 'r') as f:
                config_data = json.load(f)
            return cls(config_data)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid configuration file: {e}")

    def get_model_path(self, model_name: str) -> str:
        """Get the model path for a specific model, preferring CoreML."""
        if model_name not in self.models:
            raise ValueError(f"Model '{model_name}' not found in configuration")

        model_info = self.models[model_name]

        # Prefer CoreML path if available
        coreml_path = model_info.get("coreml_path")
        if coreml_path and Path(coreml_path).exists():
            return coreml_path

        # Fallback to PyTorch path
        pytorch_path = model_info.get("pytorch_path")
        if pytorch_path and Path(pytorch_path).exists():
            return pytorch_path

        raise ValueError(f"No valid model files found for '{model_name}'")