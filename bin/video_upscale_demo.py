#!/usr/bin/env python3
"""
Video upscaling demo using optimized CoreML batch processing
"""

import cv2
import numpy as np
from pathlib import Path
import time
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
import multiprocessing as mp

class VideoUpscaler:
    def __init__(self, model_path, scale_factor=4):
        self.model_path = model_path
        self.scale_factor = scale_factor
        # Model will be loaded per worker process to avoid memory issues

    def upscale_frame_worker(self, frame_data):
        """Worker function for parallel frame upscaling"""
        frame_path, output_path, frame_idx = frame_data

        # Load model in worker process
        import sys
        sys.path.insert(0, 'python-cli')
        from python_cli.coreml_inference import CoreMLInference

        try:
            model = CoreMLInference(self.model_path)
            model.upscale_image(frame_path, output_path)
            return frame_idx, True, None
        except Exception as e:
            return frame_idx, False, str(e)

    def upscale_video_selective(self, input_video, output_video,
                               frame_interval=30, batch_size=4):
        """
        Upscale video by processing key frames and interpolating

        Args:
            frame_interval: Process every Nth frame
            batch_size: Number of frames to process in parallel
        """
        print(f"🎬 Starting selective video upscaling...")
        print(f"   • Processing every {frame_interval}th frame")
        print(f"   • Batch size: {batch_size}")

        cap = cv2.VideoCapture(input_video)

        # Get video properties
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        print(f"   • Input: {width}x{height} @ {fps}fps ({total_frames} frames)")

        # Setup output video
        out_width = width * self.scale_factor
        out_height = height * self.scale_factor
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_video, fourcc, fps, (out_width, out_height))

        frame_tasks = []
        frame_idx = 0
        processed_frames = {}

        start_time = time.time()

        # First pass: Identify key frames and create tasks
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx % frame_interval == 0:
                # Save frame temporarily
                temp_path = f"temp_frame_{frame_idx:06d}.jpg"
                output_temp_path = f"temp_upscaled_{frame_idx:06d}.jpg"

                cv2.imwrite(temp_path, frame)
                frame_tasks.append((temp_path, output_temp_path, frame_idx))
                print(f"📸 Queued key frame {frame_idx}/{total_frames}")

            frame_idx += 1

        cap.release()
        print(f"🔄 Processing {len(frame_tasks)} key frames in parallel...")

        # Process frames in parallel batches
        with ProcessPoolExecutor(max_workers=batch_size) as executor:
            futures = []

            # Submit batch of frames
            for task in frame_tasks:
                future = executor.submit(self.upscale_frame_worker, task)
                futures.append(future)

            # Collect results
            for future in futures:
                frame_idx, success, error = future.result()
                if success:
                    print(f"✅ Frame {frame_idx} upscaled")
                    # Store processed frame path
                    for task in frame_tasks:
                        if task[2] == frame_idx:
                            processed_frames[frame_idx] = task[1]
                            break
                else:
                    print(f"❌ Frame {frame_idx} failed: {error}")

        # Second pass: Reconstruct video with interpolation
        print("🎞️ Reconstructing video with interpolation...")

        cap = cv2.VideoCapture(input_video)
        frame_idx = 0
        last_upscaled_frame = None

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx in processed_frames:
                # Use the upscaled key frame
                upscaled_frame = cv2.imread(processed_frames[frame_idx])
                last_upscaled_frame = upscaled_frame
                print(f"📹 Writing upscaled frame {frame_idx}")
            else:
                # Interpolate between key frames (simple resize for demo)
                if last_upscaled_frame is not None:
                    upscaled_frame = cv2.resize(frame, (out_width, out_height),
                                             interpolation=cv2.INTER_LANCZOS4)
                    print(f"📹 Writing interpolated frame {frame_idx}")
                else:
                    # First frames before first keyframe - just resize
                    upscaled_frame = cv2.resize(frame, (out_width, out_height),
                                             interpolation=cv2.INTER_LANCZOS4)

            out.write(upscaled_frame)
            frame_idx += 1

        # Cleanup
        cap.release()
        out.release()

        # Clean up temp files
        for task in frame_tasks:
            Path(task[0]).unlink(missing_ok=True)
            Path(task[1]).unlink(missing_ok=True)

        total_time = time.time() - start_time
        processed_seconds = total_frames / fps
        speedup = processed_seconds / total_time if total_time > 0 else 0

        print(f"✅ Video upscaling completed!")
        print(f"   • Total time: {total_time:.1f}s")
        print(f"   • Video duration: {processed_seconds:.1f}s")
        print(f"   • Processing speed: {speedup:.1f}x real-time")
        print(f"   • Output: {output_video}")

    def estimate_processing_time(self, input_video, frame_interval=30):
        """Estimate how long video processing will take"""
        cap = cv2.VideoCapture(input_video)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        cap.release()

        frames_to_process = total_frames // frame_interval
        video_duration = total_frames / fps

        # Estimate based on our CoreML timing (1.1s per frame)
        estimated_time = frames_to_process * 1.1
        speedup = video_duration / estimated_time if estimated_time > 0 else 0

        print(f"📊 Processing estimate for {input_video}:")
        print(f"   • Total frames: {total_frames}")
        print(f"   • Frames to process: {frames_to_process} (1 every {frame_interval})")
        print(f"   • Video duration: {video_duration:.1f}s")
        print(f"   • Estimated processing time: {estimated_time:.1f}s")
        print(f"   • Expected speedup: {speedup:.1f}x real-time")

        return estimated_time


def main():
    """Demo video upscaling"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python video_upscale_demo.py <input_video> [output_video]")
        print("")
        print("Examples:")
        print("  python video_upscale_demo.py input.mp4")
        print("  python video_upscale_demo.py input.mp4 output.mp4")
        return

    input_video = sys.argv[1]
    output_video = sys.argv[2] if len(sys.argv) > 2 else input_video.replace('.mp4', '_upscaled.mp4')

    if not Path(input_video).exists():
        print(f"❌ Input video not found: {input_video}")
        return

    # Initialize upscaler
    model_path = "RealESRGAN_x4plus"  # Will be resolved automatically
    upscaler = VideoUpscaler(model_path)

    # Estimate processing time first
    print("🔍 Analyzing video...")
    upscaler.estimate_processing_time(input_video)

    # Ask user to continue
    response = input("\nContinue with upscaling? (y/N): ")
    if response.lower() != 'y':
        print("❌ Cancelled")
        return

    # Process video
    upscaler.upscale_video_selective(
        input_video=input_video,
        output_video=output_video,
        frame_interval=30,  # Process every 30th frame
        batch_size=4        # Process 4 frames in parallel
    )


if __name__ == "__main__":
    main()