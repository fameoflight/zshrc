"""
YOLOv8 inference for human detection
"""

import torch
import cv2
import numpy as np
from PIL import Image
from pathlib import Path

try:
    from ultralytics import YOLO
except ImportError:
    raise ImportError("ultralytics package is required. Install with: pip install ultralytics>=8.0.0")


class YOLOInference:
    """YOLOv8 inference for person detection"""

    # COCO dataset class IDs - person is class 0
    PERSON_CLASS_ID = 0

    def __init__(self, model_path, device=None, confidence_threshold=0.25):
        """
        Initialize YOLO model for person detection

        Args:
            model_path: Path to YOLOv8 .pt model file or model name (e.g., "YOLOv8n")
            device: torch.device or None for auto-detection
            confidence_threshold: Minimum confidence for detections (0.0-1.0)
        """
        # Resolve model path (supports both full paths and model names)
        from python_cli.utils import find_model_file
        try:
            resolved_path = find_model_file(model_path, model_type="pytorch")
            self.model_path = str(resolved_path)
        except FileNotFoundError:
            # If not found via finder, try as-is (might be a direct path)
            self.model_path = model_path

        self.confidence_threshold = confidence_threshold

        # Set device
        if device is None:
            from python_cli.utils import get_optimal_device
            device = get_optimal_device()
        self.device = device

        # Load model
        self.model = self._load_model()

    def _load_model(self):
        """Load YOLOv8 model"""
        print(f'📦 Loading YOLOv8 model from {self.model_path}')

        # Load model using ultralytics
        model = YOLO(self.model_path)

        # Set device
        device_str = 'mps' if self.device.type == 'mps' else str(self.device)
        model.to(device_str)

        print(f'✅ Model loaded successfully on {self.device}')
        return model

    def detect_persons(self, image_path, visualize=False, output_path=None):
        """
        Detect persons in an image

        Args:
            image_path: Path to input image
            visualize: If True, draw bounding boxes on image
            output_path: Path to save visualization (required if visualize=True)

        Returns:
            dict with:
                - has_person: bool, whether any person detected
                - person_count: int, number of persons detected
                - detections: list of dicts with bbox, confidence for each person
                - confidence_scores: list of confidence scores for all persons
        """
        print(f'🔍 Analyzing image: {image_path}')

        # Run inference
        results = self.model(image_path, conf=self.confidence_threshold, verbose=False)

        # Extract person detections (class 0 in COCO dataset)
        persons = []

        for result in results:
            boxes = result.boxes
            for box in boxes:
                class_id = int(box.cls[0])
                if class_id == self.PERSON_CLASS_ID:
                    confidence = float(box.conf[0])
                    bbox = box.xyxy[0].cpu().numpy()  # [x1, y1, x2, y2]

                    persons.append({
                        'bbox': bbox.tolist(),
                        'confidence': confidence,
                        'class': 'person'
                    })

        # Prepare response
        has_person = len(persons) > 0
        person_count = len(persons)
        confidence_scores = [p['confidence'] for p in persons]

        result_dict = {
            'has_person': has_person,
            'person_count': person_count,
            'detections': persons,
            'confidence_scores': confidence_scores
        }

        # Print results
        if has_person:
            avg_confidence = sum(confidence_scores) / len(confidence_scores)
            print(f'✅ Found {person_count} person(s) (avg confidence: {avg_confidence:.2%})')
            for i, person in enumerate(persons, 1):
                print(f'   Person {i}: confidence {person["confidence"]:.2%}')
        else:
            print(f'❌ No persons detected')

        # Visualize if requested
        if visualize:
            if output_path is None:
                raise ValueError("output_path is required when visualize=True")
            self._visualize_detections(image_path, persons, output_path)

        return result_dict

    def _visualize_detections(self, image_path, detections, output_path):
        """Draw bounding boxes on image and save"""
        print(f'🎨 Creating visualization...')

        # Load image
        img = cv2.imread(str(image_path))
        if img is None:
            raise ValueError(f'Could not load image: {image_path}')

        # Draw bounding boxes
        for i, detection in enumerate(detections, 1):
            bbox = detection['bbox']
            confidence = detection['confidence']

            # Extract coordinates
            x1, y1, x2, y2 = [int(v) for v in bbox]

            # Draw rectangle (green color)
            cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)

            # Add label
            label = f"Person {i}: {confidence:.2%}"
            label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)

            # Draw label background
            cv2.rectangle(img, (x1, y1 - label_size[1] - 10),
                         (x1 + label_size[0], y1), (0, 255, 0), -1)

            # Draw label text
            cv2.putText(img, label, (x1, y1 - 5),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)

        # Save image
        cv2.imwrite(str(output_path), img)
        print(f'💾 Visualization saved to: {output_path}')

    def batch_detect(self, image_paths, output_dir=None, visualize=False):
        """
        Detect persons in multiple images

        Args:
            image_paths: List of image paths
            output_dir: Directory to save visualizations (if visualize=True)
            visualize: Whether to create visualizations

        Returns:
            dict mapping image_path -> detection results
        """
        results = {}

        for image_path in image_paths:
            output_path = None
            if visualize and output_dir:
                output_dir = Path(output_dir)
                output_dir.mkdir(parents=True, exist_ok=True)
                output_path = output_dir / f"{Path(image_path).stem}_detected.jpg"

            result = self.detect_persons(image_path, visualize=visualize, output_path=output_path)
            results[str(image_path)] = result

        return results

    @classmethod
    def create_from_model_path(cls, model_path, confidence_threshold=0.25, device=None):
        """Factory method to create YOLOInference instance"""
        return cls(model_path, device=device, confidence_threshold=confidence_threshold)
