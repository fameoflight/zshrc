#!/usr/bin/env python3
"""
Modular PyTorch inference script for image processing
Uses the python-cli package for reusable inference components
"""

import sys
import os
import argparse

# Add the python-cli package to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'python-cli'))

from python_cli.esrgan import ESRGANInference
from python_cli.yolo import YOLOInference
from python_cli.utils import get_optimal_device


def main():
    parser = argparse.ArgumentParser(description='Process images using PyTorch models')
    parser.add_argument('--input', required=True, help='Input image path')
    parser.add_argument('--output', required=True, help='Output image path')
    parser.add_argument('--model', required=True, help='PyTorch model path')
    parser.add_argument('--scale', type=int, default=4, help='Scale factor (default: 4)')
    parser.add_argument('--tile', type=int, default=None, help='Tile size for large images (default: auto-optimize)')
    parser.add_argument('--workers', type=int, default=None, help='Number of parallel workers (default: auto-optimize)')
    parser.add_argument('--batch-size', type=int, default=None, help='Batch size for processing (default: auto-optimize)')
    parser.add_argument('--auto-tile', action='store_true', help='Automatically optimize tile size for performance')
    parser.add_argument('--model-type', choices=['esrgan', 'yolo'], default='esrgan', help='Model type (default: esrgan)')
    parser.add_argument('--confidence', type=float, default=0.25, help='Confidence threshold for YOLO detection (default: 0.25)')
    parser.add_argument('--visualize', action='store_true', help='Create visualization with bounding boxes (YOLO only)')

    args = parser.parse_args()

    try:
        # Validate input file
        if not os.path.exists(args.input):
            print(f'❌ Input file not found: {args.input}')
            sys.exit(1)

        # Note: Model validation is handled by the inference classes
        # which support both model names (e.g., "YOLOv8n") and full paths

        # Determine device
        device = get_optimal_device()
        if device.type == 'mps':
            print(f'🚀 Using MPS (Apple Silicon GPU) acceleration')
        elif device.type == 'cuda':
            print(f'🚀 Using CUDA GPU acceleration')
        else:
            print(f'💻 Using CPU (no GPU acceleration available)')

        print(f'🤖 PyTorch Image Processing')
        print(f'Input: {args.input}')
        print(f'Output: {args.output}')
        print(f'Model: {args.model}')
        print(f'Model type: {args.model_type}')
        print(f'Scale factor: {args.scale}x')
        print(f'Device: {device}')
        print('')

        # Create appropriate inference engine and process
        if args.model_type == 'esrgan':
            inference_engine = ESRGANInference.create_from_model_path(
                args.model,
                scale_factor=args.scale,
                device=device
            )

            # Process the image with smart auto-optimization
            output_tensor = inference_engine.process_image(
                input_path=args.input,
                output_path=args.output,
                tile_size=args.tile,
                max_workers=args.workers,
                batch_size=args.batch_size
            )

            print('')
            print('✅ Processing completed successfully!')

        elif args.model_type == 'yolo':
            inference_engine = YOLOInference.create_from_model_path(
                args.model,
                confidence_threshold=args.confidence,
                device=device
            )

            # Run person detection
            result = inference_engine.detect_persons(
                image_path=args.input,
                visualize=args.visualize,
                output_path=args.output if args.visualize else None
            )

            print('')
            print('✅ Detection completed successfully!')
            print(f'📊 Results:')
            print(f'   • Has person: {result["has_person"]}')
            print(f'   • Person count: {result["person_count"]}')
            if result['confidence_scores']:
                avg_conf = sum(result['confidence_scores']) / len(result['confidence_scores'])
                print(f'   • Average confidence: {avg_conf:.2%}')

        else:
            print(f'❌ Unsupported model type: {args.model_type}')
            sys.exit(1)

    except Exception as e:
        print(f'❌ Processing failed: {e}')

        # Provide helpful suggestions based on error type
        if "out of memory" in str(e).lower():
            print('')
            print('💡 Suggestions to fix memory issues:')
            if args.tile:
                print(f'   • Reduce tile size: --tile {max(128, args.tile // 2)}')
            else:
                print('   • Reduce tile size: --tile 256')
            if args.batch_size:
                print(f'   • Reduce batch size: --batch-size {max(1, args.batch_size // 2)}')
            else:
                print('   • Reduce batch size: --batch-size 2')
            if args.workers and args.workers > 1:
                print(f'   • Reduce workers: --workers {max(1, args.workers // 2)}')
            else:
                print('   • Reduce workers: --workers 1')
            print('   • Use smaller image or free up GPU memory')
        elif " MPS " in str(e) and "convolution" in str(e):
            print('')
            print('💡 MPS convolution not supported. Try:')
            print('   • CUDA GPU if available')
            print('   • CPU processing (may be slower)')
        else:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()