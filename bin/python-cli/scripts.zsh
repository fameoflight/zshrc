# Python CLI Scripts and Functions
# This file contains Python-specific utility scripts and AI/ML functionality
# Loaded from the main scripts.zsh file

# Note: Color logging functions are loaded from logging.zsh

# =============================================================================
# PYTHON CLI UTILITY FUNCTIONS
# =============================================================================

# Execute a Python script with proper path setup
_execute_python_cli_script() {
  local script_name="$1"
  local script_path="$ZSH_CONFIG/bin/python-cli/$1"
  shift # Remove script name from arguments

  if [[ ! -f "$script_path" ]]; then
    log_error "$script_name not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making $script_name executable..."
    chmod +x "$script_path"
  fi

  # Check if we need the virtual environment
  local venv_path="$ZSH_CONFIG/.models/venv/bin/python"
  if [[ -f "$venv_path" ]]; then
    log_info "Using Python virtual environment..."
    "$venv_path" "$script_path" "$@"
  else
    log_info "Using system Python..."
    python3 "$script_path" "$@"
  fi
}

# =============================================================================
# AI/ML MODEL INFERENCE FUNCTIONS
# =============================================================================

# PyTorch image upscaling using RealESRGAN and other models
upscale-image() {
  local script_path="$ZSH_CONFIG/bin/upscale-image"

  if [[ ! -f "$script_path" ]]; then
    log_error "upscale-image script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making upscale-image executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Video upscaling utility - AI-powered video upscaling with selective frame processing
upscale-video() {
  local script_path="$ZSH_CONFIG/bin/upscale-video"

  if [[ ! -f "$script_path" ]]; then
    log_error "upscale-video script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making upscale-video executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Human detection utility using YOLOv8 models
detect-human() {
  local script_path="$ZSH_CONFIG/bin/detect-human"

  if [[ ! -f "$script_path" ]]; then
    log_error "detect-human script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making detect-human script executable..."
    chmod +x "$script_path"
  fi

  bash "$script_path" "$@"
}

# Watermark detection using ConvNeXt-tiny model
detect-watermark() {
  local usage="Usage: detect-watermark <input_file_or_directory> [--output <json_file>] [--model <model_name>] [--confidence <threshold>] [--no-cache]"

  # Build arguments for Python script
  local python_args=()

  # Parse arguments and pass to Python
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output)
        python_args+=("--output" "$2")
        shift 2
        ;;
      --model)
        python_args+=("--model" "$2")
        shift 2
        ;;
      --confidence)
        python_args+=("--confidence" "$2")
        shift 2
        ;;
      --no-cache)
        python_args+=("--no-cache")
        shift
        ;;
      --cache-info)
        python_args+=("--cache-info")
        shift
        ;;
      --clear-cache)
        python_args+=("--clear-cache")
        shift
        ;;
      --help|-h)
        echo "$usage"
        echo ""
        echo "Examples:"
        echo "  detect-watermark image.jpg                          # Single file analysis"
        echo "  detect-watermark ./images                          # Batch process directory"
        echo "  detect-watermark image.jpg --output file.json     # Save to JSON file"
        echo "  detect-watermark ./photos --confidence 0.8        # Custom confidence threshold"
        echo "  detect-watermark --cache-info                      # Show cache information"
        return 0
        ;;
      -*)
        log_error "Unknown option: $1"
        log_error "$usage"
        return 1
        ;;
      *)
        # Positional argument - input file or directory
        python_args+=("$1")
        shift
        ;;
    esac
  done

  # If no arguments passed, show help
  if [[ ${#python_args[@]} -eq 0 ]]; then
    echo "$usage"
    return 0
  fi

  # Find the watermark detection script
  local watermark_script="$ZSH_CONFIG/bin/python-cli/watermark_detector.py"
  if [[ ! -f "$watermark_script" ]]; then
    log_error "Watermark detection script not found: $watermark_script"
    return 1
  fi

  # Make sure it's executable
  if [[ ! -x "$watermark_script" ]]; then
    chmod +x "$watermark_script"
  fi

  # Run Python script
  local venv_path="$ZSH_CONFIG/.models/venv/bin/python"
  if [[ -f "$venv_path" ]]; then
    "$venv_path" "$watermark_script" "${python_args[@]}"
  else
    python3 "$watermark_script" "${python_args[@]}"
  fi
}

# PyTorch model inference - generic interface for all PyTorch models
pytorch-infer() {
  local usage="Usage: pytorch-infer <input> <output> <model> <model_type> [options]"

  local input="$1"
  local output="$2"
  local model="$3"
  local model_type="$4"
  shift 4  # Remove first 4 arguments

  if [[ -z "$input" || -z "$output" || -z "$model" || -z "$model_type" ]]; then
    log_error "$usage"
    log_error "Available model types: esrgan, yolo, coreml, watermark"
    return 1
  fi

  log_info "Running PyTorch inference..."
  log_info "Input: $input"
  log_info "Output: $output"
  log_info "Model: $model"
  log_info "Model type: $model_type"

  local pytorch_script="$ZSH_CONFIG/bin/pytorch_inference.py"
  if [[ ! -f "$pytorch_script" ]]; then
    log_error "PyTorch inference script not found: $pytorch_script"
    return 1
  fi

  # Run inference
  local venv_path="$ZSH_CONFIG/.models/venv/bin/python"
  if [[ -f "$venv_path" ]]; then
    "$venv_path" "$pytorch_script" \
      --input "$input" \
      --output "$output" \
      --model "$model" \
      --model-type "$model_type" \
      "$@"
  else
    python3 "$pytorch_script" \
      --input "$input" \
      --output "$output" \
      --model "$model" \
      --model-type "$model_type" \
      "$@"
  fi
}

# =============================================================================
# COMPUTER VISION FUNCTIONS
# =============================================================================

# Similar image search using computer vision
find-similar-images() {
  local script_path="$ZSH_CONFIG/bin/find-similar-images.py"

  if [[ ! -f "$script_path" ]]; then
    log_error "Similar image search script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making find-similar-images.py executable..."
    chmod +x "$script_path"
  fi

  python3 "$script_path" "$@"
}

# Find duplicate images in a folder
find-duplicate-images() {
  local script_path="$ZSH_CONFIG/bin/find-duplicate-images.py"

  if [[ ! -f "$script_path" ]]; then
    log_error "Duplicate image finder script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    log_info "Making find-duplicate-images.py executable..."
    chmod +x "$script_path"
  fi

  python3 "$script_path" "$@"
}

# =============================================================================
# MODEL MANAGEMENT FUNCTIONS
# =============================================================================

# Setup PyTorch models for Apple Silicon (includes watermark detection model)
setup-pytorch-models() {
  log_info "Setting up PyTorch models..."
  cd "$ZSH_CONFIG" && make pytorch-setup
}

# List available PyTorch models
list-pytorch-models() {
  local models_file="$ZSH_CONFIG/scripts/pytorch-models.json"

  if [[ ! -f "$models_file" ]]; then
    log_error "PyTorch models configuration not found: $models_file"
    return 1
  fi

  log_info "Available PyTorch models:"

  if command -v jq >/dev/null 2>&1; then
    jq -r 'to_entries[] | "  • \(.key): \(.value.description)"' "$models_file"
  else
    # Fallback without jq
    echo "  Available models (run 'make pytorch-setup' to download):"
    echo "  • RealESRGAN_x4plus: Real-ESRGAN general 4x upscaler"
    echo "  • SwinIR_4x: SwinIR 4x super-resolution model"
    echo "  • YOLOv8n: YOLOv8 nano - person detection"
    echo "  • RIFE4.9: RIFE 4.9 frame interpolation model"
    echo "  • RIFE4.7: RIFE 4.7 frame interpolation model"
    echo "  • ConvNeXt-tiny: ConvNeXx-tiny model for watermark detection"
  fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# List all Python CLI scripts and functions
list-python-cli-scripts() {
  echo "🐍 Python CLI Scripts and Functions:"
  echo ""

  echo "🤖 AI/ML Model Inference:"
  echo "   upscale-image           - Upscale images using PyTorch models"
  echo "   upscale-video           - Upscale videos using AI models"
  echo "   detect-human            - Detect humans in images using YOLOv8"
  echo "   detect-watermark        - Detect watermarks using ConvNeXt-tiny"
  echo "   pytorch-infer           - Generic PyTorch model inference"
  echo ""

  echo "🔍 Computer Vision:"
  echo "   find-similar-images     - Find similar images using computer vision"
  echo "   find-duplicate-images   - Find duplicate images in a folder"
  echo ""

  echo "⚙️  Model Management:"
  echo "   setup-pytorch-models    - Download and setup PyTorch models"
  echo "   list-pytorch-models     - List available PyTorch models"
  echo ""

  echo "💡 Usage Examples:"
  echo "   detect-watermark image.jpg                                    # Single file analysis"
  echo "   detect-watermark ./images                                    # Batch process directory"
  echo "   detect-watermark image.jpg --output results.json             # Save to JSON file"
  echo "   detect-watermark ./photos --confidence 0.8                    # Custom confidence threshold"
  echo "   upscale-image input.jpg output.jpg --model RealESRGAN_x4plus"
  echo "   detect-human photo.jpg --visualize"
  echo "   pytorch-infer input.jpg output.jpg ConvNeXt-tiny watermark"
}