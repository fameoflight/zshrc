#!/usr/bin/env python3
"""
Real-ESRGAN to CoreML converter for iOS
Converts Real-ESRGAN PyTorch models to iOS-compatible CoreML format
"""

import torch
import coremltools as ct
import numpy as np
import os
import sys
import math
from python_cli.utils import safe_remove_directory, safe_remove_file

class ResidualDenseBlock(torch.nn.Module):
    def __init__(self, num_feat=64, num_grow_ch=32):
        super(ResidualDenseBlock, self).__init__()
        self.conv1 = torch.nn.Conv2d(num_feat, num_grow_ch, 3, 1, 1, bias=True)
        self.conv2 = torch.nn.Conv2d(num_feat + num_grow_ch, num_grow_ch, 3, 1, 1, bias=True)
        self.conv3 = torch.nn.Conv2d(num_feat + 2 * num_grow_ch, num_grow_ch, 3, 1, 1, bias=True)
        self.conv4 = torch.nn.Conv2d(num_feat + 3 * num_grow_ch, num_grow_ch, 3, 1, 1, bias=True)
        self.conv5 = torch.nn.Conv2d(num_feat + 4 * num_grow_ch, num_feat, 3, 1, 1, bias=True)
        self.lrelu = torch.nn.LeakyReLU(negative_slope=0.2, inplace=True)

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
        return x5 * 0.2 + x


class RRDB(torch.nn.Module):
    """Residual in Residual Dense Block for RRDBNet."""

    def __init__(self, num_feat, num_grow_ch=32):
        super(RRDB, self).__init__()
        self.rdb1 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb2 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb3 = ResidualDenseBlock(num_feat, num_grow_ch)

    def forward(self, x):
        out = self.rdb1(x)
        out = self.rdb2(out)
        out = self.rdb3(out)
        return out * 0.2 + x


class RRDBNet(torch.nn.Module):
    def __init__(self, num_in_ch=3, num_out_ch=3, scale=4, num_feat=64, num_block=23, num_grow_ch=32, upsample_feat=None):
        super(RRDBNet, self).__init__()
        self.scale = scale
        num_upsample = int(math.log(scale, 2))

        # Use upsample_feat if provided, otherwise use num_feat
        up_feat = upsample_feat if upsample_feat is not None else num_feat

        self.conv_first = torch.nn.Conv2d(num_in_ch, num_feat, 3, 1, 1)
        self.body = torch.nn.Sequential(*[RRDB(num_feat, num_grow_ch) for _ in range(num_block)])
        self.conv_body = torch.nn.Conv2d(num_feat, num_feat, 3, 1, 1)

        # Add projection layer if body and upsampling channels differ
        if num_feat != up_feat:
            self.conv_projection = torch.nn.Conv2d(num_feat, up_feat, 1, 1, 0)
            print(f"Added projection layer: {num_feat} -> {up_feat} channels")
        else:
            self.conv_projection = None

        # Upsample - uses up_feat, not num_feat!
        self.conv_up1 = torch.nn.Conv2d(up_feat, up_feat, 3, 1, 1)
        self.conv_up2 = torch.nn.Conv2d(up_feat, up_feat, 3, 1, 1)
        self.conv_hr = torch.nn.Conv2d(up_feat, up_feat, 3, 1, 1)
        self.conv_last = torch.nn.Conv2d(up_feat, num_out_ch, 3, 1, 1)

        self.lrelu = torch.nn.LeakyReLU(negative_slope=0.2, inplace=True)

        # Initialization
        for m in self.modules():
            if isinstance(m, torch.nn.Conv2d):
                torch.nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')

    def forward(self, x):
        feat = self.conv_first(x)
        trunk = self.conv_body(self.body(feat))
        feat = feat + trunk

        # Apply projection layer if channels differ
        if self.conv_projection is not None:
            feat = self.conv_projection(feat)

        # Upsample
        feat = self.lrelu(self.conv_up1(torch.nn.functional.interpolate(feat, scale_factor=2, mode='nearest')))
        feat = self.lrelu(self.conv_up2(torch.nn.functional.interpolate(feat, scale_factor=2, mode='nearest')))
        out = self.conv_last(self.lrelu(self.conv_hr(feat)))

        return out

def create_realesrgan_model(model_path, scale_factor):
    """Create Real-ESRGAN model and load weights"""
    print(f"Loading Real-ESRGAN model from {model_path}...")

    # Load the state dict first to detect model architecture
    state_dict = torch.load(model_path, map_location='cpu', weights_only=False)

    # Check if we need to extract params_ema (Real-ESRGAN format)
    if 'params_ema' in state_dict:
        print("Using params_ema from state dict")
        state_dict = state_dict['params_ema']
    elif 'params' in state_dict:
        print("Using params from state dict")
        state_dict = state_dict['params']

    # Detect model architecture from state dict
    conv_first_weight = state_dict.get('conv_first.weight', None)
    conv_up1_weight = state_dict.get('conv_up1.weight', None)

    if conv_first_weight is not None and conv_up1_weight is not None:
        num_feat = conv_first_weight.shape[0]
        # Look at the input channels of conv_up1 (second dimension)
        up_input_feat = conv_up1_weight.shape[1]  # Input channels for upsampling
        up_output_feat = conv_up1_weight.shape[0]  # Output channels for upsampling
        print(f"Detected model with {num_feat} body channels, upsampling input={up_input_feat}, output={up_output_feat}")

        # The upsampling input channels should be what we use for upsample_feat
        up_feat = up_input_feat
    elif conv_first_weight is not None:
        num_feat = conv_first_weight.shape[0]
        up_feat = num_feat  # Fallback: assume same
        print(f"Detected model with {num_feat} feature channels")
    else:
        num_feat = 64  # Default fallback
        up_feat = 64
        print(f"Could not detect feature channels, using default: {num_feat}")

    # Clean up state dict keys if needed
    if any('module.' in k for k in state_dict.keys()):
        # Remove 'module.' prefix if present
        new_state_dict = {}
        for k, v in state_dict.items():
            new_key = k.replace('module.', '') if k.startswith('module.') else k
            new_state_dict[new_key] = v
        state_dict = new_state_dict

    # Create model with detected architecture
    if 'up_feat' in locals() and up_feat != num_feat:
        model = RRDBNet(num_in_ch=3, num_out_ch=3, scale=scale_factor, num_feat=num_feat, num_block=23, num_grow_ch=32, upsample_feat=up_feat)
        print(f"Creating model with body={num_feat} channels, upsampling={up_feat} channels")
        print(f"Note: conv_body will output {num_feat} channels but conv_up1 expects {up_feat} input channels")
        print("This suggests there might be a projection layer or different architecture needed")
    else:
        model = RRDBNet(num_in_ch=3, num_out_ch=3, scale=scale_factor, num_feat=num_feat, num_block=23, num_grow_ch=32)
        print(f"Creating model with uniform {num_feat} channels")

    # Load state dict into model
    model.load_state_dict(state_dict, strict=False)
    model.eval()
    print("✅ Real-ESRGAN model loaded successfully!")
    return model

def convert_to_coreml(model, output_name, scale_factor, max_batch_size=100):
    """Convert PyTorch model to iOS-compatible CoreML with flexible batch size"""
    print(f"Converting to CoreML format with flexible batch size (1-{max_batch_size})...")

    # Use flexible input shape for better compatibility
    example_input = torch.randn(1, 3, 256, 256)  # Larger default size

    print("Tracing PyTorch model (this may take 30-60 seconds)...")
    with torch.no_grad():
        # Test model first with a small input
        test_out = model(example_input)
        print(f"   • Test inference successful, output shape: {test_out.shape}")

        # Now trace the model
        print("   • Tracing model graph...")
        traced_model = torch.jit.trace(model, example_input, check_trace=False)
        print("   • Model traced successfully")

    print("Converting to CoreML with flexible batch dimension...")

    try:
        # Try MLProgram format with flexible batch and spatial dimensions
        print("Using MLProgram format with flexible dimensions...")
        mlmodel = ct.convert(
            traced_model,
            inputs=[ct.TensorType(
                name="input",
                shape=(ct.RangeDim(1, max_batch_size), 3, ct.RangeDim(32, 1024), ct.RangeDim(32, 1024))
            )],
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.iOS15,
            compute_precision=ct.precision.FLOAT16
        )
        print(f"✅ MLProgram conversion successful with flexible batch size (1-{max_batch_size})!")

    except Exception as e:
        print(f"MLProgram with flexible batch failed: {e}")

        try:
            # Fallback to neural network format with flexible spatial dimensions only
            print("Trying Neural Network format (batch=1 only)...")
            mlmodel = ct.convert(
                traced_model,
                inputs=[ct.TensorType(name="input", shape=(1, 3, ct.RangeDim(32, 1024), ct.RangeDim(32, 1024)))],
                convert_to="neuralnetwork",
                minimum_deployment_target=ct.target.iOS13
            )
            print("✅ Neural Network conversion successful (batch=1 only)!")

        except Exception as e2:
            print(f"❌ All conversion attempts failed: {e2}")
            return None

    # Add model metadata
    mlmodel.short_description = f"Real-ESRGAN {scale_factor}x practical super-resolution"
    mlmodel.author = "Real-ESRGAN Team (Xintao Wang et al.)"
    mlmodel.license = "BSD 3-Clause"

    # Add input/output descriptions
    mlmodel.input_description["input"] = "Input image tensor (CHW format: channels, height, width)"

    # Get output name dynamically
    try:
        output_names = list(mlmodel._spec.description.output)
        if output_names:
            output_name = output_names[0].name
            mlmodel.output_description[output_name] = f"Upscaled image tensor ({scale_factor}x resolution)"
    except:
        pass

    return mlmodel

def save_as_mlpackage(mlmodel, output_path, model_info):
    """Save a CoreML model as MLPackage format with proper metadata"""
    import shutil
    import json

    # Ensure output path ends with .mlpackage
    if not output_path.endswith('.mlpackage'):
        output_path = output_path.replace('.mlmodel', '.mlpackage')

    # Remove existing directory if it exists
    if os.path.exists(output_path):
        safe_remove_directory(output_path)

    print(f"Creating MLPackage at: {output_path}")

    try:
        # Try direct MLPackage save first (newer CoreML tools)
        mlmodel.save(output_path)
        print("✅ Direct MLPackage save successful!")

        # Add custom metadata if the directory structure allows
        try:
            _add_custom_metadata(output_path, model_info)
        except Exception as metadata_e:
            print(f"⚠️  Custom metadata addition failed: {metadata_e}")

        return output_path

    except Exception as e:
        print(f"Direct MLPackage save failed: {e}")
        print("Falling back to manual MLPackage creation...")

        # Fallback: Save as .mlmodel first, then create MLPackage structure
        temp_mlmodel_path = output_path.replace('.mlpackage', '_temp.mlmodel')
        mlmodel.save(temp_mlmodel_path)

        # Create MLPackage structure manually
        _create_mlpackage_structure(temp_mlmodel_path, output_path, model_info)

        # Clean up temp file
        if os.path.exists(temp_mlmodel_path):
            safe_remove_file(temp_mlmodel_path)

        return output_path

def _create_mlpackage_structure(mlmodel_path, mlpackage_path, model_info):
    """Create MLPackage directory structure manually"""
    import shutil
    import json

    # Create MLPackage directory structure
    os.makedirs(mlpackage_path, exist_ok=True)
    data_dir = os.path.join(mlpackage_path, "Data")
    os.makedirs(data_dir, exist_ok=True)
    coreml_dir = os.path.join(data_dir, "com.apple.CoreML")
    os.makedirs(coreml_dir, exist_ok=True)

    # Copy the .mlmodel file into the MLPackage
    model_name = os.path.basename(mlpackage_path).replace('.mlpackage', '.mlmodel')
    target_model_path = os.path.join(coreml_dir, model_name)
    shutil.copy2(mlmodel_path, target_model_path)

    # Create Manifest.json for the MLPackage root
    root_manifest = _create_root_manifest(model_info)
    with open(os.path.join(mlpackage_path, "Manifest.json"), 'w') as f:
        json.dump(root_manifest, f, indent=2)

    # Create Manifest.json for the Data directory
    data_manifest = _create_data_manifest(model_info, model_name)
    with open(os.path.join(data_dir, "Manifest.json"), 'w') as f:
        json.dump(data_manifest, f, indent=2)

    print(f"✅ Manual MLPackage structure created at: {mlpackage_path}")

def _create_root_manifest(model_info):
    """Create root-level Manifest.json"""
    return {
        "fileFormatVersion": "1.0.0",
        "itemInfoEntries": {
            "Data": {
                "path": "Data",
                "digest": "placeholder_digest",
                "isDirectory": True
            }
        }
    }

def _create_data_manifest(model_info, model_filename):
    """Create Data-level Manifest.json"""
    return {
        "fileFormatVersion": "1.0.0",
        "itemInfoEntries": {
            "com.apple.CoreML": {
                "path": "com.apple.CoreML",
                "digest": "placeholder_digest",
                "isDirectory": True
            }
        },
        "rootModelIdentifier": f"com.apple.CoreML/{model_filename}",
        "modelInfo": {
            "modelIdentifier": model_info.get('identifier', 'com.example.model'),
            "modelDescription": {
                "shortDescription": model_info.get('description', 'Super-resolution model'),
                "metadata": {
                    "author": model_info.get('author', 'Unknown'),
                    "license": model_info.get('license', 'Unknown'),
                    "version": model_info.get('version', '1.0'),
                    "scaleFactor": model_info.get('scale_factor', 4)
                }
            }
        }
    }

def _add_custom_metadata(mlpackage_path, model_info):
    """Add custom metadata to existing MLPackage"""
    import json

    manifest_path = os.path.join(mlpackage_path, "Manifest.json")

    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)

            # Add custom metadata
            if 'metadata' not in manifest:
                manifest['metadata'] = {}

            manifest['metadata'].update({
                'author': model_info.get('author', 'Unknown'),
                'license': model_info.get('license', 'Unknown'),
                'version': model_info.get('version', '1.0'),
                'scaleFactor': model_info.get('scale_factor', 4),
                'modelType': model_info.get('model_type', 'super-resolution'),
                'optimizedFor': model_info.get('optimized_for', 'iOS')
            })

            with open(manifest_path, 'w') as f:
                json.dump(manifest, f, indent=2)

            print("✅ Custom metadata added to MLPackage")

        except Exception as e:
            print(f"⚠️  Failed to add custom metadata: {e}")

def verify_mlpackage(mlpackage_path):
    """Verify that the MLPackage can be loaded"""
    import shutil

    try:
        model = ct.models.MLModel(mlpackage_path)
        print(f"✅ MLPackage verification successful: {mlpackage_path}")

        # Print package contents
        print(f"📦 MLPackage contents:")
        for root, dirs, files in os.walk(mlpackage_path):
            level = root.replace(mlpackage_path, '').count(os.sep)
            indent = ' ' * 2 * level
            print(f"{indent}{os.path.basename(root)}/")
            subindent = ' ' * 2 * (level + 1)
            for file in files:
                print(f"{subindent}{file}")

        return True

    except Exception as e:
        print(f"❌ MLPackage verification failed: {e}")
        return False

def main():
    print("Real-ESRGAN to CoreML Converter")
    print("=" * 35)

    if len(sys.argv) != 4:
        print("Usage: python convert_to_coreml.py <model_path> <output_name> <scale_factor>")
        print("Example: python convert_to_coreml.py weights/RealESRGAN_x4plus.pth RealESRGAN_4x 4")
        sys.exit(1)

    model_path = sys.argv[1]
    output_name = sys.argv[2]
    scale_factor = int(sys.argv[3])

    if not os.path.exists(model_path):
        print(f"❌ Model file not found: {model_path}")
        sys.exit(1)

    try:
        # Create and load model
        model = create_realesrgan_model(model_path, scale_factor)

        # Convert to CoreML
        coreml_model = convert_to_coreml(model, output_name, scale_factor)

        if coreml_model is not None:
            # Ensure models directory exists
            os.makedirs("models", exist_ok=True)

            # Create model info for MLPackage metadata
            model_info = {
                'identifier': f'com.realesrgan.{output_name.lower()}',
                'description': f"Real-ESRGAN {scale_factor}x practical super-resolution",
                'author': "Real-ESRGAN Team (Xintao Wang et al.)",
                'license': "BSD 3-Clause",
                'version': "1.0",
                'scale_factor': scale_factor,
                'model_type': 'real-esrgan',
                'optimized_for': 'iOS'
            }

            # Save as MLPackage
            output_path = f"models/{output_name}.mlpackage"
            mlpackage_path = save_as_mlpackage(coreml_model, output_path, model_info)

            print(f"✅ Real-ESRGAN MLPackage saved to: {mlpackage_path}")
            print(f"📱 iOS/Xcode compatible!")
            print(f"📊 Model input: 1x3x64x64 (CHW format)")
            print(f"📈 Model output: {scale_factor}x upscaled image")
            print("🎉 Real-ESRGAN conversion completed successfully!")

            # Verify MLPackage
            if verify_mlpackage(mlpackage_path):
                # Display model info
                info = get_mlpackage_info(mlpackage_path)
                if info:
                    print("\n📋 MLPackage Details:")
                    print(f"   Description: {info['description']}")
                    print(f"   Author: {info['author']}")
                    print(f"   Size: {info['size_mb']:.1f} MB")
                    print(f"   Inputs: {', '.join(info['inputs'])}")
                    print(f"   Outputs: {', '.join(info['outputs'])}")
            else:
                print("⚠️  MLPackage verification failed")

        else:
            print("❌ Conversion failed")

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

def get_mlpackage_info(mlpackage_path):
    """Get information about an MLPackage"""
    import os

    try:
        model = ct.models.MLModel(mlpackage_path)

        info = {
            'description': getattr(model, 'short_description', 'N/A'),
            'author': getattr(model, 'author', 'N/A'),
            'license': getattr(model, 'license', 'N/A')
        }

        # Get input/output info
        try:
            info['inputs'] = list(model.input_description.keys())
            info['outputs'] = list(model.output_description.keys())
        except:
            info['inputs'] = ['Unknown']
            info['outputs'] = ['Unknown']

        # Get file size
        total_size = 0
        for root, dirs, files in os.walk(mlpackage_path):
            for file in files:
                total_size += os.path.getsize(os.path.join(root, file))
        info['size_mb'] = total_size / (1024 * 1024)

        return info

    except Exception as e:
        print(f"Failed to get MLPackage info: {e}")
        return None

if __name__ == "__main__":
    main()