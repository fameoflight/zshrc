#!/usr/bin/env python3
"""
Optimized video upscaling using direct CoreML implementation
No python-cli dependency - uses CoreML directly for optimal Apple Silicon performance
"""

import cv2
import numpy as np
import coremltools as ct
from pathlib import Path
import time
import sys
import os
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
import multiprocessing as mp
import tempfile
import shutil
import json
from typing import Dict, List, Tuple, Optional

# Try to import tqdm for nice progress bars
try:
    from tqdm import tqdm
except ImportError:
    # Fallback simple progress bar if tqdm not available
    class tqdm:
        def __init__(self, iterable, **kwargs):
            self.iterable = iterable
            self.total = kwargs.get('total', len(
                iterable) if hasattr(iterable, '__len__') else None)
            self.desc = kwargs.get('desc', '')
            self.unit = kwargs.get('unit', 'it')
            self.current = 0

        def __iter__(self):
            for item in self.iterable:
                yield item
                self.current += 1
                if self.total:
                    percent = (self.current * 100) // self.total
                    print(
                        f"\r{self.desc}: {percent}% ({self.current}/{self.total})", end="", flush=True)
                else:
                    print(f"\r{self.desc}: {self.current} {self.unit}",
                          end="", flush=True)

        def update(self, n=1):
            self.current += n
            if self.total:
                percent = (self.current * 100) // self.total
                print(
                    f"\r{self.desc}: {percent}% ({self.current}/{self.total})", end="", flush=True)
            else:
                print(f"\r{self.desc}: {self.current} {self.unit}",
                      end="", flush=True)

        def close(self):
            print()  # New line when done


class CoreMLVideoUpscaler:
    """Video upscaler using direct CoreML implementation for optimal Apple Silicon performance"""

    def __init__(self, model_path: str, interpolation_mode: str = "rife4.9", frame_interval: int = 1):
        self.model_path = model_path
        self.model = None
        self.tile_size = self._calculate_optimal_tile_size()
        self.interpolation_mode = interpolation_mode
        self.rife_interpolator = None
        self.frame_interval = frame_interval

        # Skip RIFE initialization if interval=1 (no interpolation needed)
        if frame_interval == 1:
            print(f"ℹ️  Interval=1: Upscaling all frames, RIFE interpolation disabled")
            self.interpolation_mode = "linear"
        # Initialize RIFE interpolator if needed
        elif interpolation_mode != "linear":
            try:
                from rife_interpolation import RIFEInterpolator, find_rife_model
                rife_model_path = find_rife_model(interpolation_mode)
                self.rife_interpolator = RIFEInterpolator(
                    rife_model_path, interpolation_mode)
                print(f"🎬 RIFE {interpolation_mode} interpolation enabled")
            except Exception as e:
                print(f"⚠️  RIFE initialization failed: {e}")
                print(f"   • Falling back to linear interpolation")
                self.interpolation_mode = "linear"

    def _calculate_optimal_tile_size(self) -> int:
        """Calculate optimal tile size for CoreML on high-performance systems"""
        # With 60-core GPU, we can handle much larger tiles for better performance
        # Optimized for high-end GPUs with many cores (matches image processing)
        return 1024

    def load_model(self):
        """Load CoreML model directly"""
        if self.model is not None:
            return

        # Skip verbose loading for batch processing (model loaded once per batch)
        if not hasattr(self, '_batch_loading'):
            print(
                f"🔄 Loading CoreML model: {os.path.basename(self.model_path)}")
            print(f"   • Tile size: {self.tile_size}")

        if not os.path.exists(self.model_path):
            raise FileNotFoundError(
                f"CoreML model file not found: {self.model_path}")

        try:
            # Load CoreML model
            self.model = ct.models.MLModel(self.model_path)
            if not hasattr(self, '_batch_loading'):
                print("✅ CoreML model loaded successfully")
        except Exception as e:
            raise RuntimeError(f"Failed to load CoreML model: {e}")

    def preprocess_image(self, img: np.ndarray) -> Dict[str, np.ndarray]:
        """Preprocess image for CoreML model input"""
        # CoreML models typically expect (1, 3, H, W) format in float32
        img = img.astype(np.float32) / 255.0
        img = np.transpose(img, (2, 0, 1))  # HWC -> CHW
        img = np.expand_dims(img, axis=0)   # Add batch dimension

        return {"input": img}

    def postprocess_image(self, output_dict: Dict[str, np.ndarray]) -> np.ndarray:
        """Postprocess CoreML model output to image"""
        # CoreML output should be (1, 3, H, W) format
        if isinstance(output_dict, dict):
            output = list(output_dict.values())[0]
        else:
            output = output_dict

        # Remove batch dimension and transpose CHW -> HWC
        output = np.squeeze(output, axis=0)
        output = np.transpose(output, (1, 2, 0))

        # Convert to uint8
        output = np.clip(output * 255.0, 0, 255).astype(np.uint8)
        return output

    def upscale_image_tiled(self, img: np.ndarray) -> np.ndarray:
        """Upscale image using tiled CoreML processing for optimal memory efficiency"""
        h, w = img.shape[:2]
        scale = 4
        output_h, output_w = h * scale, w * scale

        # Initialize output
        output = np.zeros((output_h, output_w, 3), dtype=np.uint8)

        # Process tiles with larger overlap for 60-core GPU optimization
        overlap = 64  # Larger overlap for better quality with fewer tiles

        for y in range(0, h, self.tile_size - overlap):
            for x in range(0, w, self.tile_size - overlap):
                # Calculate tile boundaries
                y_end = min(y + self.tile_size, h)
                x_end = min(x + self.tile_size, w)

                # Extract tile
                tile = img[y:y_end, x:x_end]

                # Skip if tile is too small
                if tile.shape[0] < 16 or tile.shape[1] < 16:
                    continue

                try:
                    # Process tile with CoreML
                    input_dict = self.preprocess_image(tile)
                    output_dict = self.model.predict(input_dict)
                    upscaled_tile = self.postprocess_image(output_dict)

                    # Calculate output boundaries
                    out_y = y * scale
                    out_x = x * scale
                    out_y_end = out_y + upscaled_tile.shape[0]
                    out_x_end = out_x + upscaled_tile.shape[1]

                    # Handle edge cases
                    if out_y_end > output_h:
                        out_y_end = output_h
                        upscaled_tile = upscaled_tile[:output_h - out_y, :]
                    if out_x_end > output_w:
                        out_x_end = output_w
                        upscaled_tile = upscaled_tile[:, :output_w - out_x]

                    # Place tile in output with simpler overlapping approach
                    if upscaled_tile.size > 0:  # Only place if tile has valid dimensions
                        if y == 0 and x == 0:
                            # First tile - no blending needed
                            output[out_y:out_y_end,
                                   out_x:out_x_end] = upscaled_tile
                        else:
                            # Simple approach: just place tile with minimal overlap handling
                            # This avoids complex blending that can cause dimension mismatches
                            tile_h, tile_w = upscaled_tile.shape[:2]
                            output_h_region = min(
                                out_y_end - out_y, output_h - out_y)
                            output_w_region = min(
                                out_x_end - out_x, output_w - out_x)

                            # Ensure we don't try to place empty tiles
                            if tile_h > 0 and tile_w > 0 and output_h_region > 0 and output_w_region > 0:
                                # Clip tile to fit within bounds
                                place_h = min(tile_h, output_h_region)
                                place_w = min(tile_w, output_w_region)
                                output[out_y:out_y + place_h, out_x:out_x +
                                       place_w] = upscaled_tile[:place_h, :place_w]

                except Exception as e:
                    print(
                        f"⚠️  Warning: Failed to process tile at ({x}, {y}): {e}")
                    # Fallback to simple resize for this region
                    fallback_tile = cv2.resize(tile, (tile.shape[1] * scale, tile.shape[0] * scale),
                                               interpolation=cv2.INTER_LANCZOS4)
                    output[y * scale:(y + tile.shape[0]) * scale,
                           x * scale:(x + tile.shape[1]) * scale] = fallback_tile

        return output

    def upscale_batch_direct(self, frames: List[np.ndarray], batch_size: int = 4) -> List[np.ndarray]:
        """Optimized batch upscale using CoreML with true parallel processing for 60-core GPU"""
        if not frames:
            return []

        # Pre-load model ONCE for entire batch to maximize performance
        self._batch_loading = True  # Flag to reduce loading verbosity
        self.load_model()
        delattr(self, '_batch_loading')  # Clean up the flag

        # Optimize tile size for video frames (smaller than images due to memory constraints)
        original_tile_size = self.tile_size
        self.tile_size = 1024  # Optimized for video frame processing

        results = []

        # Process frames in batches for better GPU utilization
        for i in range(0, len(frames), batch_size):
            batch = frames[i:i + batch_size]

            try:
                # Check if all frames have same dimensions (required for batching)
                shapes = [f.shape for f in batch]
                if len(set(shapes)) == 1:
                    # Same dimensions - can use true batch processing
                    batch_results = self._upscale_batch_parallel(batch)
                    results.extend(batch_results)
                else:
                    # Different dimensions - process sequentially
                    for frame in batch:
                        upscaled_frame = self.upscale_image_tiled(frame)
                        results.append(upscaled_frame)

            except Exception as e:
                # Fallback to sequential processing
                for frame in batch:
                    try:
                        upscaled_frame = self.upscale_image_tiled(frame)
                        results.append(upscaled_frame)
                    except:
                        h, w = frame.shape[:2]
                        fallback = cv2.resize(
                            frame, (w * 4, h * 4), interpolation=cv2.INTER_LANCZOS4)
                        results.append(fallback)

        # Restore original tile size
        self.tile_size = original_tile_size
        return results

    def _upscale_batch_parallel(self, frames: List[np.ndarray]) -> List[np.ndarray]:
        """Process multiple frames in parallel using batch dimension"""
        if not frames:
            return []

        # Check if frames are small enough to process without tiling
        h, w = frames[0].shape[:2]
        use_tiling = h > 720 or w > 1280  # Use tiling only for larger frames

        if not use_tiling:
            # Direct batch processing without tiling (much faster)
            batch_tensor = []
            for frame in frames:
                input_dict = self.preprocess_image(frame)
                batch_tensor.append(input_dict['input'])

            # Concatenate along batch dimension
            batch_input = np.concatenate(batch_tensor, axis=0)

            # Process batch through CoreML
            try:
                output_dict = self.model.predict({'input': batch_input})
                batch_output = list(output_dict.values())[0]

                # Split batch back into individual frames
                results = []
                for i in range(len(frames)):
                    frame_output = np.expand_dims(batch_output[i], axis=0)
                    upscaled = self.postprocess_image(frame_output)
                    results.append(upscaled)

                return results

            except Exception as e:
                print(
                    f"⚠️  Batch processing failed: {e}, falling back to tiled")
                # Fallback to tiled processing
                pass

        # Use tiled processing for large frames or if batch failed
        results = []
        for frame in frames:
            upscaled = self.upscale_image_tiled(frame)
            results.append(upscaled)
        return results

    def _is_animation_frame(self, frame: np.ndarray) -> bool:
        """Detect if frame is likely from animation using edge detection"""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges > 0) / edges.size
        return edge_density > 0.02  # Higher edge density suggests animation

    def _interpolate_frames(self, current_frame: np.ndarray, prev_upscaled: np.ndarray,
                            next_upscaled: np.ndarray, ratio: float, out_width: int, out_height: int) -> np.ndarray:
        """Advanced frame interpolation with content awareness"""
        try:
            # Simple linear interpolation of upscaled frames
            interpolated = cv2.addWeighted(
                prev_upscaled, 1 - ratio, next_upscaled, ratio, 0)

            # Enhance with details from current frame (scaled up)
            current_scaled = cv2.resize(current_frame, (out_width, out_height),
                                        interpolation=cv2.INTER_LANCZOS4)

            # Calculate difference to extract missing details
            detail_diff = cv2.absdiff(current_scaled, interpolated)

            # Apply detail enhancement selectively
            detail_threshold = 10
            detail_mask = cv2.cvtColor(
                detail_diff, cv2.COLOR_BGR2GRAY) > detail_threshold

            # Blend details back in
            result = interpolated.copy()
            result[detail_mask] = (
                0.7 * interpolated[detail_mask] + 0.3 * current_scaled[detail_mask]).astype(np.uint8)

            return result

        except Exception as e:
            print(f"⚠️  Interpolation failed, using simple resize: {e}")
            return cv2.resize(current_frame, (out_width, out_height), interpolation=cv2.INTER_LANCZOS4)

    def _smart_interpolate_frames(self, prev_upscaled: np.ndarray, next_upscaled: np.ndarray, ratio: float) -> np.ndarray:
        """Smart frame interpolation using RIFE or high-quality fallback"""

        if self.interpolation_mode == "linear":
            # Simple linear interpolation
            return cv2.addWeighted(prev_upscaled, 1 - ratio, next_upscaled, ratio, 0)

        elif self.rife_interpolator is not None:
            # Use RIFE interpolation
            try:
                result = self.rife_interpolator.interpolate_frame(
                    prev_upscaled, next_upscaled, ratio)
                return result
            except Exception as e:
                print(
                    f"⚠️  RIFE interpolation failed for frame (ratio={ratio:.2f}): {e}")
                # Fallback to high-quality interpolation
                return self._high_quality_interpolation(prev_upscaled, next_upscaled, ratio)

        else:
            # High-quality fallback
            return self._high_quality_interpolation(prev_upscaled, next_upscaled, ratio)

    def _high_quality_interpolation(self, frame1: np.ndarray, frame2: np.ndarray, ratio: float) -> np.ndarray:
        """High-quality interpolation fallback when RIFE is not available"""

        # Multi-step interpolation for better quality
        if ratio <= 0.0:
            return frame1.copy()
        elif ratio >= 1.0:
            return frame2.copy()

        # Ensure frames are same size
        h, w = frame1.shape[:2]
        frame2_resized = cv2.resize(frame2, (w, h))

        # Primary linear interpolation
        primary = cv2.addWeighted(frame1, 1 - ratio, frame2_resized, ratio, 0)

        # Add subtle sharpening for better detail preservation
        kernel = np.array([[-1, -1, -1],
                          [-1,  9, -1],
                          [-1, -1, -1]]) / 9.0

        sharpened = cv2.filter2D(primary, -1, kernel)

        # Blend for natural look
        result = cv2.addWeighted(primary, 0.8, sharpened, 0.2, 0)

        return result

    def estimate_processing_time(self, input_video: str, frame_interval: int = 30) -> Dict:
        """Estimate video processing time"""
        cap = cv2.VideoCapture(input_video)
        if not cap.isOpened():
            return {}

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        duration = total_frames / fps if fps > 0 else 0

        cap.release()

        frames_to_process = max(1, total_frames // frame_interval)

        # CoreML time estimation - much faster than PyTorch on Apple Silicon
        # CoreML is ~3x faster than PyTorch MPS
        time_per_frame = 0.8 + (width * height) / (1920 * 1080) * 0.3

        estimated_time = frames_to_process * time_per_frame
        speedup = duration / estimated_time if estimated_time > 0 else 0

        return {
            'total_frames': total_frames,
            'fps': fps,
            'resolution': (width, height),
            'duration': duration,
            'frames_to_process': frames_to_process,
            'estimated_time': estimated_time,
            'speedup': speedup,
            'output_resolution': (width * 4, height * 4)
        }

    def upscale_video_optimized(self, input_video: str, output_video: str,
                                frame_interval: int = 30, workers: int = 4) -> bool:
        """Optimized video upscaling with direct CoreML processing and resume support"""

        print(f"🎬 Starting optimized video upscaling...")
        print(f"   • Input: {input_video}")
        print(f"   • Output: {output_video}")
        print(f"   • Frame interval: {frame_interval}")
        print(f"   • Workers: {workers}")

        # Create temporary directory with consistent name for resume support
        import hashlib
        video_hash = hashlib.md5(input_video.encode()).hexdigest()[:8]
        temp_dir = os.path.join(tempfile.gettempdir(),
                                f"video_upscale_{video_hash}")

        # Check if resuming
        resume_mode = False
        if os.path.exists(temp_dir):
            print(f"🔄 Found existing progress, resuming from previous session...")
            resume_mode = True
        else:
            os.makedirs(temp_dir, exist_ok=True)

        # Open input video
        cap = cv2.VideoCapture(input_video)
        if not cap.isOpened():
            print(f"❌ Could not open video: {input_video}")
            return False

        # Get video properties
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        print(f"   • Input resolution: {width}x{height}")
        print(f"   • FPS: {fps:.1f}")
        print(f"   • Total frames: {total_frames}")

        # Setup output video (temporary file, will combine with audio later)
        out_width = width * 4
        out_height = height * 4
        temp_video = os.path.join(temp_dir, "temp_video.mp4")
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(temp_video, fourcc, fps, (out_width, out_height))

        if not out.isOpened():
            print(f"❌ Could not create temporary video: {temp_video}")
            cap.release()
            return False

        try:
            # Load model
            self.load_model()

            frame_tasks = []
            processed_frames = {}

            # Check if input video has audio and prepare for audio extraction
            temp_audio = None
            has_audio = False

            try:
                # Try to use moviepy to check for audio
                from moviepy import VideoFileClip
                print(f"   🔍 Checking for audio track...")

                with VideoFileClip(input_video) as clip:
                    if clip.audio is not None:
                        has_audio = True
                        temp_audio = os.path.join(temp_dir, "temp_audio.mp3")
                        print(
                            f"   🎵 Audio track detected, will preserve original audio")

                        # Extract audio using moviepy
                        audio_clip = clip.audio
                        audio_clip.write_audiofile(temp_audio, logger=None)
                        audio_clip.close()
                    else:
                        print(f"   ℹ️  No audio track detected in video")

            except ImportError:
                print(f"   ⚠️  moviepy not available, video will be video-only")
                print(f"   💡 Install with: pip install moviepy")
            except Exception as e:
                print(f"   ⚠️  Could not process audio: {e}")
                print(f"   ℹ️  Output video will be video-only")

            start_time = time.time()
            frame_idx = 0

            # First pass: Extract and process key frames
            print("📸 Extracting key frames...")

            # Collect key frames with progress bar
            key_frames = []
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

            # Check for existing processed frames if resuming
            existing_frames = set()
            if resume_mode:
                for filename in os.listdir(temp_dir):
                    if filename.startswith("upscaled_") and filename.endswith(".jpg"):
                        frame_num = int(filename.split("_")[1].split(".")[0])
                        existing_frames.add(frame_num)
                        processed_frames[frame_num] = os.path.join(
                            temp_dir, filename)
                if existing_frames:
                    print(
                        f"   • Found {len(existing_frames)} already processed frames")

            with tqdm(total=total_frames, desc="📸 Scanning video", unit="frames") as pbar:
                while True:
                    ret, frame = cap.read()
                    if not ret:
                        break

                    if frame_idx % frame_interval == 0:
                        # Skip if already processed
                        if frame_idx not in existing_frames:
                            key_frames.append((frame_idx, frame.copy()))

                    frame_idx += 1
                    pbar.update(1)

            cap.release()

            frames_to_process = len(key_frames)
            frames_already_done = len(existing_frames)
            total_key_frames = frames_to_process + frames_already_done

            if resume_mode and frames_already_done > 0:
                print(
                    f"🔄 Resume: {frames_already_done}/{total_key_frames} frames already done, {frames_to_process} remaining")
            else:
                print(f"🔄 Found {total_key_frames} key frames to upscale")

            # Process frames in batches with progress bar
            batch_size = min(workers, len(key_frames))
            start_processing = time.time()

            print(f"⚡ Using batch size: {batch_size} for parallel processing")

            with tqdm(total=len(key_frames), desc="🎬 Processing key frames", unit="frames") as pbar:
                for i in range(0, len(key_frames), batch_size):
                    batch = key_frames[i:i + batch_size]
                    batch_frames = [frame for _, frame in batch]

                    # Process batch directly with parallel processing
                    upscaled_batch = self.upscale_batch_direct(
                        batch_frames, batch_size=batch_size)

                    # Save processed frames
                    for (frame_idx, _), upscaled_frame in zip(batch, upscaled_batch):
                        temp_output = os.path.join(
                            temp_dir, f"upscaled_{frame_idx:06d}.jpg")
                        cv2.imwrite(temp_output, upscaled_frame)
                        processed_frames[frame_idx] = temp_output

                    # Update progress bar by batch size
                    pbar.update(len(batch))

            processing_time = time.time() - start_processing
            print(f"🧠 Frame processing completed in {processing_time:.1f}s")

            # Second pass: Advanced frame reconstruction with smart interpolation
            interp_method = "RIFE" if self.interpolation_mode != "linear" else "linear"
            print(
                f"🎞️ Reconstructing video with {interp_method} interpolation ({self.interpolation_mode})...")
            cap = cv2.VideoCapture(input_video)
            frame_idx = 0
            last_upscaled = None
            next_upscaled = None

            # Pre-load next key frame for better interpolation
            key_frame_indices = sorted(processed_frames.keys())
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

            with tqdm(total=total_frames, desc="🎞️ Reconstructing video", unit="frames") as pbar:
                while True:
                    ret, frame = cap.read()
                    if not ret:
                        break

                    if frame_idx in processed_frames:
                        # Use upscaled key frame
                        upscaled_frame = cv2.imread(
                            processed_frames[frame_idx])
                        if upscaled_frame is not None:
                            last_upscaled = upscaled_frame.copy()

                            # Pre-load next key frame if available
                            current_key_idx = key_frame_indices.index(
                                frame_idx) if frame_idx in key_frame_indices else -1
                            if current_key_idx < len(key_frame_indices) - 1:
                                next_key_idx = key_frame_indices[current_key_idx + 1]
                                next_upscaled = cv2.imread(
                                    processed_frames[next_key_idx])
                            else:
                                next_upscaled = None
                        else:
                            # Fallback to resize
                            last_upscaled = cv2.resize(frame, (out_width, out_height),
                                                       interpolation=cv2.INTER_LANCZOS4)
                            next_upscaled = None
                        upscaled_frame = last_upscaled
                    else:
                        # Optimized interpolation between key frames
                        if last_upscaled is not None:
                            # Simple linear interpolation with upscaled key frames
                            # Find next key frame
                            next_key_idx = min(
                                [idx for idx in key_frame_indices if idx > frame_idx], default=None)

                            if next_key_idx is not None:
                                # Load next key frame if needed
                                if next_upscaled is None or 'current_next_idx' not in locals() or next_key_idx != current_next_idx:
                                    next_upscaled = cv2.imread(
                                        processed_frames[next_key_idx])
                                    current_next_idx = next_key_idx

                                if next_upscaled is not None:
                                    # Calculate simple interpolation ratio
                                    prev_key_idx = max(
                                        [idx for idx in key_frame_indices if idx < frame_idx], default=None)
                                    if prev_key_idx is not None:
                                        total_gap = next_key_idx - prev_key_idx
                                        current_gap = frame_idx - prev_key_idx
                                        ratio = current_gap / total_gap if total_gap > 0 else 0

                                        # Smart interpolation (RIFE or high-quality fallback)
                                        upscaled_frame = self._smart_interpolate_frames(
                                            last_upscaled, next_upscaled, ratio)
                                    else:
                                        upscaled_frame = last_upscaled
                                else:
                                    upscaled_frame = last_upscaled
                            else:
                                # No next key frame, use last upscaled
                                upscaled_frame = last_upscaled
                        else:
                            # First frames - resize but with high quality
                            upscaled_frame = cv2.resize(frame, (out_width, out_height),
                                                        interpolation=cv2.INTER_LANCZOS4)

                    out.write(upscaled_frame)
                    frame_idx += 1
                    pbar.update(1)

            cap.release()
            out.release()

            # Combine video with audio if audio was detected
            if has_audio and temp_audio and os.path.exists(temp_audio):
                try:
                    print(f"🎵 Adding audio track to final video...")

                    # Use ffmpeg directly to combine video with audio (more reliable than moviepy)
                    import subprocess

                    ffmpeg_cmd = [
                        'ffmpeg',
                        '-i', temp_video,      # Input video
                        '-i', temp_audio,      # Input audio
                        # Copy video stream (no re-encoding)
                        '-c:v', 'copy',
                        '-c:a', 'aac',         # Encode audio as AAC
                        '-shortest',           # Match shortest stream duration
                        '-y',                  # Overwrite output
                        output_video
                    ]

                    result = subprocess.run(
                        ffmpeg_cmd, capture_output=True, text=True)

                    if result.returncode == 0:
                        print(f"✅ Audio successfully added to output video")
                    else:
                        print(f"⚠️  ffmpeg failed: {result.stderr}")
                        # Fallback to video-only
                        shutil.copy2(temp_video, output_video)

                except Exception as e:
                    print(f"⚠️  Failed to combine audio with video: {e}")
                    print(f"   • Output video will be video-only")
                    # Copy video-only as fallback
                    shutil.copy2(temp_video, output_video)
            else:
                # No audio detected, just copy the video
                shutil.copy2(temp_video, output_video)

            total_time = time.time() - start_time
            video_duration = total_frames / fps if fps > 0 else 0
            speedup = video_duration / total_time if total_time > 0 else 0

            print(f"✅ Video upscaling completed!")
            print(
                f"   • Total time: {total_time:.1f}s ({total_time/60:.1f} minutes)")
            print(f"   • Video duration: {video_duration:.1f}s")
            print(f"   • Processing speed: {speedup:.1f}x real-time")
            print(f"   • Output: {output_video}")
            if has_audio:
                print(f"   • Audio: Preserved from original video")
            else:
                print(f"   • Audio: Not detected in original video")

            # Clean up temp directory on success
            print(f"🧹 Cleaning up temporary files...")
            try:
                shutil.rmtree(temp_dir)
                print(f"   • Temporary files removed")
            except Exception as e:
                print(f"   ⚠️  Could not remove temp directory: {temp_dir}")
                print(f"   • You can manually remove it later")

            return True

        except Exception as e:
            print(f"❌ Error during video processing: {e}")
            if 'out' in locals():
                out.release()
            if 'cap' in locals():
                cap.release()

            # Keep temp directory on failure for resume
            if 'temp_dir' in locals():
                print(f"💾 Progress saved in: {temp_dir}")
                print(f"   • Run the same command again to resume from where it stopped")

            return False

        finally:
            # Don't cleanup on error - let resume functionality use it
            pass


def find_coreml_model_file(model_name: str) -> str:
    """Find CoreML model file in standard locations"""
    zsh_config = os.environ.get('ZSH_CONFIG', '/Users/hemantv/zshrc')
    models_dir = os.path.join(zsh_config, '.models')

    # Check for CoreML model with different extensions
    possible_paths = [
        os.path.join(models_dir, f"{model_name}.mlmodel"),
        os.path.join(models_dir, f"{model_name}.mlpackage"),
        os.path.join(models_dir, "coreml", f"{model_name}.mlmodel"),
        os.path.join(models_dir, "coreml", f"{model_name}.mlpackage"),
        os.path.join(models_dir, "apple-silicon",
                     "models", f"{model_name}.mlmodel"),
        os.path.join(models_dir, "apple-silicon",
                     "models", f"{model_name}.mlpackage"),
        os.path.join(models_dir, f"{model_name}.mlmodelc"),  # Compiled model
    ]

    for path in possible_paths:
        if os.path.exists(path):
            return path

    # If not found, try to find any .mlmodel file with similar name
    import glob
    pattern = os.path.join(models_dir, "**", f"*{model_name}*.mlmodel")
    matches = glob.glob(pattern, recursive=True)
    if matches:
        return matches[0]

    # Check for .mlpackage files
    pattern = os.path.join(models_dir, "**", f"*{model_name}*.mlpackage")
    matches = glob.glob(pattern, recursive=True)
    if matches:
        return matches[0]

    # Check for compiled models
    pattern = os.path.join(models_dir, "**", f"*{model_name}*.mlmodelc")
    matches = glob.glob(pattern, recursive=True)
    if matches:
        return matches[0]

    return model_name  # Return as-is, will raise error later


def main():
    """Main function for video upscaling"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Optimized video upscaling using direct CoreML')
    parser.add_argument('input', help='Input video path')
    parser.add_argument('output', nargs='?',
                        help='Output video path (optional)')
    parser.add_argument(
        '--model', default='RealESRGAN_x4plus', help='CoreML model name')
    parser.add_argument('--interval', type=int, default=30,
                        help='Process every Nth frame')
    parser.add_argument('--workers', type=int, default=4,
                        help='Number of workers')
    parser.add_argument('--estimate', action='store_true',
                        help='Only estimate processing time')
    parser.add_argument('--interpolation', default='rife4.9',
                        choices=['rife4.9', 'rife4.7', 'rife4.6',
                                 'rife4.3', 'rife', 'rife-lite', 'linear'],
                        help='Frame interpolation method (default: rife4.9)')

    args = parser.parse_args()

    # Validate input file
    if not os.path.exists(args.input):
        print(f"❌ Input file not found: {args.input}")
        return 1

    # Generate output path if not provided
    if args.output is None:
        input_path = Path(args.input)
        args.output = str(input_path.parent /
                          f"{input_path.stem}_upscaled{input_path.suffix}")

    # Find CoreML model file
    model_path = find_coreml_model_file(args.model)

    # Initialize CoreML upscaler
    try:
        upscaler = CoreMLVideoUpscaler(
            model_path, args.interpolation, args.interval)
    except Exception as e:
        print(f"❌ Failed to initialize CoreML upscaler: {e}")
        return 1

    # Estimate processing time
    print("🔍 Analyzing video...")
    estimate = upscaler.estimate_processing_time(args.input, args.interval)

    if estimate:
        print(f"📊 Video Analysis Results:")
        print(
            f"   • Resolution: {estimate['resolution'][0]}x{estimate['resolution'][1]}")
        print(
            f"   • Duration: {estimate['duration']:.1f}s ({estimate['total_frames']} frames @ {estimate['fps']:.1f}fps)")
        print(f"   • Processing interval: every {args.interval}th frame")
        print(f"   • Frames to upscale: {estimate['frames_to_process']}")
        print(
            f"   • Estimated time: {estimate['estimated_time']:.1f}s ({estimate['estimated_time']/60:.1f} minutes)")
        print(f"   • Processing speed: {estimate['speedup']:.1f}x real-time")
        print(
            f"   • Output resolution: {estimate['output_resolution'][0]}x{estimate['output_resolution'][1]}")

        if estimate['speedup'] < 0.5:
            print(f"   ⚠️  Processing will be slower than real-time")
        elif estimate['speedup'] < 2:
            print(f"   ⚠️  Processing will be slower than playback")
        else:
            print(f"   ✅ Processing will be faster than playback")

    if args.estimate:
        return 0

    # Process video
    success = upscaler.upscale_video_optimized(
        args.input,
        args.output,
        args.interval,
        args.workers
    )

    if success:
        print(f"✅ Video upscaling completed successfully!")
        print(f"   Result saved to: {args.output}")
        return 0
    else:
        print(f"❌ Video upscaling failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
