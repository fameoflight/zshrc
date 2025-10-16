# Rust CLI Scripts and Functions
# This file contains Rust-specific utility scripts and functions
# Loaded from the main scripts.zsh file

# Note: Color logging functions are loaded from logging.zsh

# =============================================================================
# RUST CLI UTILITY FUNCTIONS
# =============================================================================

# Execute the Rust CLI utility with proper path setup
_execute_rust_cli() {
  local binary_name="$1"
  local binary_path="$ZSH_CONFIG/bin/rust-cli/target/release/$binary_name"
  shift # Remove binary name from arguments

  if [[ ! -f "$binary_path" ]]; then
    log_error "$binary_name not found at $binary_path"
    log_info "Building $binary_name in release mode..."
    cd "$ZSH_CONFIG/bin/rust-cli" || return 1

    # Try to build the project
    if command -v cargo >/dev/null 2>&1; then
      cargo build --release
      if [[ $? -ne 0 ]]; then
        log_error "Failed to build $binary_name"
        return 1
      fi
    else
      log_error "Cargo not found. Please install Rust."
      return 1
    fi

    # Check if binary was created successfully
    if [[ ! -f "$binary_path" ]]; then
      log_error "Build completed but $binary_name still not found at $binary_path"
      return 1
    fi
  fi

  if [[ ! -x "$binary_path" ]]; then
    log_info "Making $binary_name executable..."
    chmod +x "$binary_path"
  fi

  # Execute the binary
  "$binary_path" "$@"
}

# =============================================================================
# RUST UTILITY COMMANDS
# =============================================================================

# Rust-based disk usage analyzer with parallel processing
disk-usage() {
  log_info "Running Rust disk usage analyzer..."
  _execute_rust_cli "rust-cli" disk-usage "$@"
}

# Rust-based LLM chat interface with TUI support
llm-chat() {
  log_info "Running Rust LLM chat interface..."
  _execute_rust_cli "rust-cli" llm-chat "$@"
}

# =============================================================================
# RUST DEVELOPMENT FUNCTIONS
# =============================================================================

# Build the Rust CLI project in release mode
build-rust-cli() {
  local rust_dir="$ZSH_CONFIG/bin/rust-cli"

  if [[ ! -d "$rust_dir" ]]; then
    log_error "Rust project directory not found: $rust_dir"
    return 1
  fi

  log_info "Building Rust CLI project in release mode..."
  cd "$rust_dir" || return 1

  if command -v cargo >/dev/null 2>&1; then
    cargo build --release
    if [[ $? -eq 0 ]]; then
      log_success "Rust CLI built successfully"
      local binary_path="$rust_dir/target/release/rust-cli"
      if [[ -f "$binary_path" ]]; then
        log_file_created "$binary_path"
      fi
    else
      log_error "Failed to build Rust CLI"
      return 1
    fi
  else
    log_error "Cargo not found. Please install Rust."
    return 1
  fi
}

# Build the Rust CLI project in debug mode
build-rust-cli-debug() {
  local rust_dir="$ZSH_CONFIG/bin/rust-cli"

  if [[ ! -d "$rust_dir" ]]; then
    log_error "Rust project directory not found: $rust_dir"
    return 1
  fi

  log_info "Building Rust CLI project in debug mode..."
  cd "$rust_dir" || return 1

  if command -v cargo >/dev/null 2>&1; then
    cargo build
    if [[ $? -eq 0 ]]; then
      log_success "Rust CLI built successfully in debug mode"
      local binary_path="$rust_dir/target/debug/rust-cli"
      if [[ -f "$binary_path" ]]; then
        log_file_created "$binary_path"
      fi
    else
      log_error "Failed to build Rust CLI"
      return 1
    fi
  else
    log_error "Cargo not found. Please install Rust."
    return 1
  fi
}

# Run tests for the Rust CLI project
test-rust-cli() {
  local rust_dir="$ZSH_CONFIG/bin/rust-cli"

  if [[ ! -d "$rust_dir" ]]; then
    log_error "Rust project directory not found: $rust_dir"
    return 1
  fi

  log_info "Running Rust CLI tests..."
  cd "$rust_dir" || return 1

  if command -v cargo >/dev/null 2>&1; then
    cargo test
    if [[ $? -eq 0 ]]; then
      log_success "All tests passed"
    else
      log_error "Some tests failed"
      return 1
    fi
  else
    log_error "Cargo not found. Please install Rust."
    return 1
  fi
}

# Clean build artifacts
clean-rust-cli() {
  local rust_dir="$ZSH_CONFIG/bin/rust-cli"

  if [[ ! -d "$rust_dir" ]]; then
    log_error "Rust project directory not found: $rust_dir"
    return 1
  fi

  log_info "Cleaning Rust CLI build artifacts..."
  cd "$rust_dir" || return 1

  if command -v cargo >/dev/null 2>&1; then
    cargo clean
    log_success "Build artifacts cleaned"
  else
    log_error "Cargo not found. Please install Rust."
    return 1
  fi
}

# Check Rust and Cargo installation
check-rust-installation() {
  log_info "Checking Rust installation..."

  if command -v rustc >/dev/null 2>&1; then
    local rust_version=$(rustc --version)
    log_success "Rust found: $rust_version"
  else
    log_error "Rust not found. Please install Rust from https://rustup.rs/"
    return 1
  fi

  if command -v cargo >/dev/null 2>&1; then
    local cargo_version=$(cargo --version)
    log_success "Cargo found: $cargo_version"
  else
    log_error "Cargo not found. Please install Rust."
    return 1
  fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# List all Rust CLI scripts and functions
list-rust-scripts() {
  echo "🦀 Rust CLI Scripts and Functions:"
  echo ""

  echo "⚙️  Rust Utility Commands:"
  echo "   disk-usage              - Fast disk usage analyzer with parallel processing"
  echo "   llm-chat                - LLM chat interface with TUI support"
  echo ""

  echo "🔧 Development Commands:"
  echo "   build-rust-cli          - Build Rust CLI in release mode"
  echo "   build-rust-cli-debug    - Build Rust CLI in debug mode"
  echo "   test-rust-cli           - Run Rust CLI tests"
  echo "   clean-rust-cli          - Clean build artifacts"
  echo "   check-rust-installation - Verify Rust and Cargo installation"
  echo ""

  echo "💡 Usage Examples:"
  echo "   disk-usage ./path --depth 3 --files 10"
  echo "   llm-chat --model gpt-4 --api-key your-key"
  echo "   build-rust-cli            # Build for production"
  echo "   build-rust-cli-debug      # Build for development"
  echo "   test-rust-cli             # Run test suite"
  echo ""

  echo "📚 Project Documentation:"
  echo "   See bin/rust-cli/RUST.md for architecture details"
  echo "   See bin/rust-cli/src/ for source code"
}