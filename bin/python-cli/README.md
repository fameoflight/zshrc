# Python CLI for PyTorch Models with CoreML Optimization

A modern Python CLI tool for running PyTorch models with CoreML optimization on Apple Silicon.

## Installation

```bash
# Set up models and environment
make pytorch-setup

# Install python-cli as editable package
cd bin/python-cli
pip install -e .
```

## Usage

### Basic Commands

```bash
# List available models
python-cli models

# Upscale an image (uses default model)
python-cli upscale photo.jpg

# Upscale with specific model
python-cli upscale photo.jpg --model RealESRGAN_x4plus

# Custom output path
python-cli upscale photo.jpg result.jpg

# Show configuration
python-cli config
```

### Examples

```bash
# Simple upscaling
python-cli upscale input.jpg

# Using specific model and custom output
python-cli upscale input.jpg output.jpg --model RealESRGAN_x4plus

# List all available models
python-cli models

# Show configuration info
python-cli config
```

## Available Models

- `RealESRGAN_x4plus` (default) - General 4x upscaler with CoreML optimization
- Additional models added via setup script

## Features

- **CoreML Optimization**: Automatically uses CoreML models when available for Apple Silicon performance
- **PyTorch Fallback**: Falls back to PyTorch inference if CoreML not available
- **Auto-generated Output**: Smart output filename generation
- **Rich CLI**: Beautiful terminal output with progress and status information
- **Type Safety**: Built with Typer for modern CLI with type hints

## Architecture

- `python-cli/` - Main CLI package
- `python_cli/cli.py` - Main CLI interface with Typer
- `python_cli/config.py` - Configuration management
- `python_cli/coreml_inference.py` - CoreML inference implementation
- `python_cli/pytorch_inference.py` - PyTorch fallback inference
- `python_cli/utils.py` - Utility functions

## Model Setup

Models are downloaded and converted using:

```bash
make pytorch-setup
```

This will:
1. Download PyTorch models to `~/.config/zsh/.models/pytorch/`
2. Convert to CoreML format for Apple Silicon
3. Store CoreML models in `~/.config/zsh/.models/apple-silicon/`
4. Update configuration with available models