#!/usr/bin/env python3
"""
Watermark detection script using ConvNeXt-tiny model
Thin Python wrapper with all logic moved from shell
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Any

try:
    from tqdm import tqdm
except ImportError:
    print("⚠️  tqdm not found, progress bar will not be available. Install with: pip install tqdm")
    tqdm = None

# Add python-cli to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from python_cli.watermark import WatermarkInference


def find_image_files(directory: str) -> List[str]:
    """Find all image files in a directory"""
    supported_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif', '.webp'}
    image_files = []

    try:
        dir_path = Path(directory)
        if not dir_path.is_dir():
            raise ValueError(f"Not a directory: {directory}")

        # Find all image files recursively
        for ext in supported_extensions:
            for file_path in dir_path.rglob(f'*{ext}'):
                image_files.append(str(file_path))
            for file_path in dir_path.rglob(f'*{ext.upper()}'):
                image_files.append(str(file_path))

        # Sort files for consistent processing
        image_files.sort()
        return image_files

    except Exception as e:
        print(f"❌ Error scanning directory {directory}: {e}")
        return []


def find_model_file(model_name):
    """Find model file by name using search patterns"""
    models_dir = Path.home() / ".config" / "zsh" / ".models"

    possible_paths = [
        models_dir / "pytorch" / f"{model_name}.pth",
        models_dir / "pytorch" / f"{model_name}.pt",
        models_dir / "pytorch" / f"{model_name}_watermarks_detector.pth",
        models_dir / "pytorch" / "convnext-tiny_watermarks_detector.pth",
        models_dir / f"{model_name}.pth",
        models_dir / f"{model_name}.pt",
        models_dir / f"{model_name}_watermarks_detector.pth",
        models_dir / model_name,
    ]

    for path in possible_paths:
        if path.exists():
            return str(path)

    return None


def display_human_readable_results(result, prediction, file_path=None):
    """Display results in human-readable format"""
    if file_path:
        print(f"\n🔍 Detection Results for: {file_path}")
    else:
        print(f"\n🔍 Detection Results:")
    print(f"   • Prediction: {prediction}")

    if 'confidence' in result:
        confidence_pct = int(result['confidence'] * 100)
        print(f"   • Confidence: {confidence_pct}%")

    if 'watermark_probability' in result:
        watermark_pct = int(result['watermark_probability'] * 100)
        print(f"   • Watermark probability: {watermark_pct}%")

    if 'clean_probability' in result:
        clean_pct = int(result['clean_probability'] * 100)
        print(f"   • Clean probability: {clean_pct}%")


def display_batch_results(results: List[Dict[str, Any]], confidence_threshold: float = 0.7):
    """Display batch processing results"""
    watermark_files = []
    clean_files = []
    low_confidence_files = []

    for result in results:
        file_path = result['file_path']
        prediction = result['result']['prediction']
        confidence = result['result']['confidence']

        # Determine category
        if confidence < confidence_threshold:
            low_confidence_files.append(result)
        elif prediction == 'watermarked':
            watermark_files.append(result)
        else:
            clean_files.append(result)

    # Summary
    print(f"\n📊 Batch Processing Summary:")
    print(f"   • Total files processed: {len(results)}")
    print(f"   • Files with watermarks: {len(watermark_files)}")
    print(f"   • Clean files: {len(clean_files)}")
    print(f"   • Low confidence files (< {int(confidence_threshold * 100)}%): {len(low_confidence_files)}")

    # Show files with watermarks
    if watermark_files:
        print(f"\n🎯 Files with Watermarks:")
        for item in watermark_files:
            file_path = item['file_path']
            result = item['result']
            confidence_pct = int(result['confidence'] * 100)
            watermark_pct = int(result['watermark_probability'] * 100)
            print(f"   • {file_path}")
            print(f"     - Confidence: {confidence_pct}%")
            print(f"     - Watermark probability: {watermark_pct}%")

    # Show low confidence files
    if low_confidence_files:
        print(f"\n⚠️  Low Confidence Files (< {int(confidence_threshold * 100)}%):")
        for item in low_confidence_files:
            file_path = item['file_path']
            result = item['result']
            confidence_pct = int(result['confidence'] * 100)
            prediction = result['prediction']
            print(f"   • {file_path}")
            print(f"     - Prediction: {prediction}")
            print(f"     - Confidence: {confidence_pct}%")

    # Show clean files summary
    if clean_files:
        print(f"\n✅ Clean Files: {len(clean_files)} files")
        if len(clean_files) <= 5:  # Show all if few
            for item in clean_files:
                print(f"   • {item['file_path']}")
        else:
            print(f"   • First 5 files:")
            for item in clean_files[:5]:
                print(f"     - {item['file_path']}")
            print(f"   • ... and {len(clean_files) - 5} more files")


def process_single_file(inference: WatermarkInference, file_path: str, confidence_threshold: float) -> Dict[str, Any]:
    """Process a single image file"""
    try:
        result = inference.detect_watermark(file_path)
        return {
            'file_path': file_path,
            'result': result,
            'success': True
        }
    except Exception as e:
        return {
            'file_path': file_path,
            'result': {'error': str(e)},
            'success': False
        }


def handle_cache_operations(cache_info=False, clear_cache=False):
    """Handle cache information and clearing operations"""
    # Create a temporary inference instance to access cache
    try:
        temp_inference = WatermarkInference(enable_cache=True)

        if cache_info:
            cache_info_data = temp_inference.get_cache_info()
            print(f"\n📊 Cache Information:")
            print(f"   • Cache enabled: {cache_info_data.get('cache_enabled', False)}")
            if cache_info_data.get('cache_enabled'):
                print(f"   • Cache directory: {cache_info_data.get('cache_dir', 'N/A')}")
                print(f"   • Cache file: {cache_info_data.get('cache_file', 'N/A')}")
                print(f"   • Cache size: {cache_info_data.get('cache_size', 0)} bytes")
                print(f"   • Cache entries: {cache_info_data.get('cache_entries', 0)}")

        if clear_cache:
            cleared = temp_inference.clear_cache()
            if cleared:
                print(f"✅ Cache cleared successfully!")
            else:
                print(f"⚠️  Cache was already empty or couldn't be cleared")

    except Exception as e:
        print(f"❌ Cache operation failed: {e}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description='Detect watermarks in images using ConvNeXt-tiny model',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s image.jpg                              # Single file analysis
  %(prog)s image.jpg --output results.json       # Save to JSON file
  %(prog)s image.jpg --model ConvNeXt-tiny      # Specify model
  %(prog)s ./images                              # Batch processing directory
  %(prog)s ./images --confidence 0.8            # Custom confidence threshold
  %(prog)s image.jpg --no-cache                  # Disable caching
  %(prog)s --cache-info                          # Show cache information
  %(prog)s --clear-cache                         # Clear cache
        """
    )

    parser.add_argument('input_path', nargs='?', help='Input image file or directory containing images')
    parser.add_argument('--output', help='Output JSON file path (optional)')
    parser.add_argument('--model', default='ConvNeXt-tiny', help='Model name (default: ConvNeXt-tiny)')
    parser.add_argument('--confidence', type=float, default=0.7, help='Confidence threshold for watermark detection (default: 0.7)')
    parser.add_argument('--no-cache', action='store_true', help='Disable caching for this run')
    parser.add_argument('--cache-info', action='store_true', help='Show cache information')
    parser.add_argument('--clear-cache', action='store_true', help='Clear watermark detection cache')

    args = parser.parse_args()

    # Handle cache info and clear cache operations (no input required)
    if args.cache_info or args.clear_cache:
        handle_cache_operations(args.cache_info, args.clear_cache)
        return

    # Validate that input path is provided
    if not args.input_path:
        print(f"❌ Input path is required for watermark detection", file=sys.stderr)
        parser.print_help()
        sys.exit(1)

    # Validate confidence threshold
    if not 0.0 <= args.confidence <= 1.0:
        print(f"❌ Confidence threshold must be between 0.0 and 1.0", file=sys.stderr)
        sys.exit(1)

    # Validate input path exists
    if not os.path.exists(args.input_path):
        print(f"❌ Input path not found: {args.input_path}", file=sys.stderr)
        sys.exit(1)

    # Determine if input is file or directory
    is_directory = os.path.isdir(args.input_path)
    if is_directory:
        input_type = "directory"
    else:
        input_type = "file"

    # Find model file
    model_file = find_model_file(args.model)
    if not model_file:
        print(f"❌ Model not found: {args.model}", file=sys.stderr)
        print(f"❌ Please run 'setup-pytorch-models' to download the model", file=sys.stderr)
        sys.exit(1)

    try:
        # Initialize watermark detection
        inference = WatermarkInference.create_from_model_path(
            model_file,
            enable_cache=not args.no_cache
        )

        if is_directory:
            # Batch processing for directory
            print(f"🔍 Processing directory: {args.input_path}")
            print(f"🤖 Using model: {args.model}")
            print(f"📁 Using model file: {model_file}")
            print(f"📋 Caching: {'disabled' if args.no_cache else 'enabled'}")
            print(f"🎯 Confidence threshold: {int(args.confidence * 100)}%")

            # Find all image files
            image_files = find_image_files(args.input_path)
            if not image_files:
                print(f"⚠️  No image files found in directory: {args.input_path}")
                return

            print(f"📸 Found {len(image_files)} image files")

            # Process files with progress bar
            results = []
            files_iter = image_files
            if tqdm:
                files_iter = tqdm(image_files, desc="🔍 Detecting watermarks", unit="image")

            for file_path in files_iter:
                result = process_single_file(inference, file_path, args.confidence)
                results.append(result)

                # Update progress bar description if using tqdm
                if tqdm:
                    if result['success']:
                        confidence_pct = int(result['result']['confidence'] * 100)
                        prediction = result['result']['prediction']
                        status = "🎯 WATERMARK" if prediction == 'watermarked' and confidence_pct >= int(args.confidence * 100) else "✅ CLEAN"
                        files_iter.set_postfix_str(f"Current: {status} ({confidence_pct}%)")
                    else:
                        files_iter.set_postfix_str("Current: ❌ Error")
                else:
                    # Fallback without tqdm
                    if result['success']:
                        confidence_pct = int(result['result']['confidence'] * 100)
                        prediction = result['result']['prediction']
                        status = "🎯 WATERMARK" if prediction == 'watermarked' and confidence_pct >= int(args.confidence * 100) else "✅ CLEAN"
                        print(f"   {file_path}: {status} ({confidence_pct}% confidence)")
                    else:
                        print(f"   {file_path}: ❌ Error")

            # Display batch results
            display_batch_results(results, args.confidence)

            # Save results to file if requested
            if args.output:
                with open(args.output, 'w') as f:
                    json.dump(results, f, indent=2)
                print(f"\n📄 Batch results saved to: {args.output}")

            # Summary of processing
            successful = sum(1 for r in results if r['success'])
            print(f"\n✅ Batch processing completed: {successful}/{len(results)} files processed successfully")

        else:
            # Single file processing
            print(f"🔍 Detecting watermarks in: {args.input_path}")
            print(f"🤖 Using model: {args.model}")
            print(f"📁 Using model file: {model_file}")
            print(f"📋 Caching: {'disabled' if args.no_cache else 'enabled'}")
            print(f"🎯 Confidence threshold: {int(args.confidence * 100)}%")

            # Run detection
            result = inference.detect_watermark(args.input_path)

            # Handle output
            if args.output:
                # Save to JSON file
                with open(args.output, 'w') as f:
                    json.dump(result, f, indent=2)
                print(f"📄 Results saved to: {args.output}")

            # Display human-readable results
            display_human_readable_results(result, result['prediction'], args.input_path)

            # Check confidence threshold
            confidence_pct = int(result['confidence'] * 100)
            if result['confidence'] < args.confidence:
                print(f"\n⚠️  Low confidence detection ({confidence_pct}% < {int(args.confidence * 100)}% threshold)")
            elif result['prediction'] == 'watermarked':
                print(f"\n🎯 Watermark detected with high confidence ({confidence_pct}% >= {int(args.confidence * 100)}% threshold)")

            print(f"\n✅ Watermark detection completed successfully!")

    except Exception as e:
        print(f"❌ Watermark detection failed: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()