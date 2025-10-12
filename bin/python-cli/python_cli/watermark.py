"""
Watermark detection PyTorch model implementation using ConvNeXt-tiny
Detects whether an image contains watermarks or not
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import transforms
import numpy as np
import json
import os
from pathlib import Path

from .utils import BaseImageInference, find_model_file
from .cache_manager import get_cache_manager


class LayerNorm(nn.Module):
    """LayerNorm that supports two data formats: channels_last (default) or channels_first.
    The ordering of the dimensions in the inputs. channels_last corresponds to inputs with
    shape (batch_size, height, width, channels) while channels_first corresponds to inputs
    with shape (batch_size, channels, height, width).
    """
    def __init__(self, normalized_shape, eps=1e-6, data_format="channels_last"):
        super().__init__()
        self.weight = nn.Parameter(torch.ones(normalized_shape))
        self.bias = nn.Parameter(torch.zeros(normalized_shape))
        self.eps = eps
        self.data_format = data_format
        if self.data_format not in ["channels_last", "channels_first"]:
            raise NotImplementedError
        self.normalized_shape = (normalized_shape, )

    def forward(self, x):
        if self.data_format == "channels_last":
            return F.layer_norm(x, self.normalized_shape, self.weight, self.bias, self.eps)
        elif self.data_format == "channels_first":
            u = x.mean(1, keepdim=True)
            s = (x - u).pow(2).mean(1, keepdim=True)
            x = (x - u) / torch.sqrt(s + self.eps)
            x = self.weight[:, None, None] * x + self.bias[:, None, None]
            return x


class ConvNeXtBlock(torch.nn.Module):
    """ConvNeXt Block implementation"""

    def __init__(self, dim, drop_path=0., layer_scale_init_value=1e-6):
        super().__init__()
        self.dwconv = nn.Conv2d(dim, dim, kernel_size=7, padding=3, groups=dim)
        self.norm = LayerNorm(dim, eps=1e-6)
        self.pwconv1 = nn.Linear(dim, 4 * dim)
        self.act = nn.GELU()
        self.pwconv2 = nn.Linear(4 * dim, dim)
        self.gamma = nn.Parameter(layer_scale_init_value * torch.ones((dim)),
                                  requires_grad=True) if layer_scale_init_value > 0 else None
        self.drop_path = nn.Identity()  # Simplified for inference

    def forward(self, x):
        input = x
        x = self.dwconv(x)
        x = x.permute(0, 2, 3, 1)  # (N, C, H, W) -> (N, H, W, C)
        x = self.norm(x)
        x = self.pwconv1(x)
        x = self.act(x)
        x = self.pwconv2(x)
        if self.gamma is not None:
            x = self.gamma * x
        x = x.permute(0, 3, 1, 2)  # (N, H, W, C) -> (N, C, H, W)
        x = input + self.drop_path(x)
        return x


class ConvNeXt(torch.nn.Module):
    """ConvNeXt implementation for watermark detection"""

    def __init__(self, in_chans=3, num_classes=1000,
                 depths=[3, 3, 9, 3], dims=[96, 192, 384, 768],
                 layer_scale_init_value=1e-6):
        super().__init__()

        self.dims = dims
        self.downsample_layers = nn.ModuleList()

        # Stem
        stem = nn.Sequential(
            nn.Conv2d(in_chans, dims[0], kernel_size=4, stride=4),
            LayerNorm(dims[0], eps=1e-6, data_format="channels_first")
        )
        self.downsample_layers.append(stem)

        # Downsampling layers
        for i in range(3):
            downsample_layer = nn.Sequential(
                LayerNorm(dims[i], eps=1e-6, data_format="channels_first"),
                nn.Conv2d(dims[i], dims[i+1], kernel_size=2, stride=2),
            )
            self.downsample_layers.append(downsample_layer)

        # Stages
        self.stages = nn.ModuleList()
        cur = 0
        for i in range(4):
            stage = nn.Sequential(
                *[ConvNeXtBlock(dim=dims[i], layer_scale_init_value=layer_scale_init_value)
                  for j in range(depths[i])]
            )
            self.stages.append(stage)
            cur += depths[i]

        self.norm = nn.LayerNorm(dims[-1], eps=1e-6)
        self.head = nn.Linear(dims[-1], num_classes)

    def forward_features(self, x):
        for i in range(4):
            x = self.downsample_layers[i](x)
            x = self.stages[i](x)
        return self.norm(x.mean([-2, -1]))  # Global average pooling

    def forward(self, x):
        x = self.forward_features(x)
        x = self.head(x)
        return x


class WatermarkInference(BaseImageInference):
    """Watermark detection inference class using ConvNeXt-tiny"""

    def __init__(self, device=None, enable_cache=True):
        # Watermark detection doesn't use scale factor like upscaling models
        super().__init__(scale_factor=1, device=device)

        # ImageNet normalization for ConvNeXt
        self.transform = transforms.Compose([
            transforms.Resize((256, 256)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

        # Initialize cache manager
        self.enable_cache = enable_cache
        if enable_cache:
            self.cache_manager = get_cache_manager('watermark-detection')
            print(f"📁 Cache initialized: {self.cache_manager.cache_dir}")
        else:
            self.cache_manager = None

        # Pre-compute model hash for cache key (much faster than state_dict)
        self._model_hash = None

    def load_model(self, model_path):
        """Load ConvNeXt-tiny watermark detection model"""
        # Resolve model path (supports both full paths and model names)
        try:
            resolved_path = find_model_file(model_path, model_type="pytorch")
            model_path = str(resolved_path)
        except FileNotFoundError:
            # If not found via finder, try as-is (might be a direct path)
            pass

        print(f'Loading ConvNeXt-tiny watermark detection model from {model_path}...')

        # Create ConvNeXt-tiny model with watermark detection head
        model = ConvNeXt(
            depths=[3, 3, 9, 3],
            dims=[96, 192, 384, 768]
        )

        # Custom head for watermark detection (2 classes: clean, watermarked)
        model.head = nn.Sequential(
            nn.Linear(in_features=768, out_features=512),
            nn.GELU(),
            nn.Linear(in_features=512, out_features=256),
            nn.GELU(),
            nn.Linear(in_features=256, out_features=2),
        )

        # Load weights
        state_dict = torch.load(model_path, map_location='cpu', weights_only=False)

        # Handle different state dict formats
        if 'model' in state_dict:
            state_dict = state_dict['model']
        elif 'state_dict' in state_dict:
            state_dict = state_dict['state_dict']

        # Clean up state dict keys if needed
        if any('module.' in k for k in state_dict.keys()):
            new_state_dict = {}
            for k, v in state_dict.items():
                new_key = k.replace('module.', '') if k.startswith('module.') else k
                new_state_dict[new_key] = v
            state_dict = new_state_dict

        model.load_state_dict(state_dict, strict=False)
        model.eval()
        model = model.to(self.device)

        print('✅ ConvNeXt-tiny watermark detection model loaded successfully!')
        self.model = model

        # Compute model hash once for efficient cache key generation
        if self.enable_cache:
            # Use a simple hash based on model parameters count and first layer weights
            # Much faster than converting entire state_dict to string
            total_params = sum(p.numel() for p in model.parameters())
            first_layer_weight = list(model.parameters())[0].flatten()[:10].mean().item()
            self._model_hash = hash(f"convnext_watermark_{total_params}_{first_layer_weight}")

        return model

    def preprocess_image(self, image_path):
        """Load and preprocess image for watermark detection"""
        try:
            img = Image.open(image_path).convert("RGB")
        except Exception as e:
            raise ValueError(f'Could not load image: {image_path}. Error: {e}')

        original_size = img.size  # (width, height)

        # Apply transforms
        input_tensor = self.transform(img)
        input_tensor = input_tensor.unsqueeze(0)  # Add batch dimension

        return input_tensor, original_size

    def _get_cache_key(self, image_path: str) -> str:
        """Generate cache key for watermark detection"""
        # Use pre-computed model hash for much faster cache key generation
        model_info = self._model_hash if self._model_hash else "no_model"
        return f"watermark_detection:{image_path}:{model_info}"

    def detect_watermark(self, image_path, use_cache=None):
        """Detect if image contains watermark"""
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")

        # Determine if caching should be used
        should_cache = use_cache if use_cache is not None else self.enable_cache

        # Check cache first
        if should_cache and self.cache_manager:
            cache_key = self._get_cache_key(image_path)
            cached_result = self.cache_manager.get_cached_data(cache_key)
            if cached_result:
                # Validate cached result has required keys
                if isinstance(cached_result, dict) and 'prediction' in cached_result:
                    return cached_result
                else:
                    # Invalid cache entry, remove it
                    print(f'⚠️  Invalid cache entry for {image_path}, removing...')
                    del self.cache_manager.cache[cache_key]
                    self.cache_manager.save_cache_atomic()

        # Load and preprocess image
        input_tensor, original_size = self.preprocess_image(image_path)
        input_tensor = input_tensor.to(self.device)

        # Run inference
        with torch.no_grad():
            outputs = self.model(input_tensor)

        # Get prediction
        probabilities = torch.nn.functional.softmax(outputs, dim=1)
        confidence, predicted = torch.max(outputs, 1)
        confidence_score = confidence.item()
        prediction = predicted.item()
        probability_scores = probabilities.squeeze().cpu().numpy()

        # Convert prediction to human-readable format
        has_watermark = prediction == 1  # Assuming class 1 = watermarked
        watermark_prob = probability_scores[1]  # Probability of being watermarked
        clean_prob = probability_scores[0]  # Probability of being clean

        result = {
            'file': image_path,  # Add file path for identification
            'has_watermark': bool(has_watermark),
            'prediction': 'watermarked' if has_watermark else 'clean',
            'confidence': float(confidence_score),
            'watermark_probability': float(watermark_prob),
            'clean_probability': float(clean_prob),
            'probabilities': {
                'clean': float(clean_prob),
                'watermarked': float(watermark_prob)
            }
        }

        # Cache the result
        if should_cache and self.cache_manager:
            cache_key = self._get_cache_key(image_path)
            self.cache_manager.cache_data(cache_key, result, image_path, auto_save=True)

        return result

    @classmethod
    def create_from_model_path(cls, model_path, device=None, enable_cache=True, input_size=None):
        """Factory method to create WatermarkInference from model path"""
        inference = cls(device=device, enable_cache=enable_cache)
        # input_size is ignored for now - using fixed 256x256 for compatibility
        inference.load_model(model_path)
        return inference

    def get_cache_info(self):
        """Get cache information"""
        if not self.cache_manager:
            return {"cache_enabled": False}

        info = self.cache_manager.get_cache_info()
        info["cache_enabled"] = True
        return info

    def clear_cache(self):
        """Clear watermark detection cache"""
        if self.cache_manager:
            return self.cache_manager.clear_cache()
        return False