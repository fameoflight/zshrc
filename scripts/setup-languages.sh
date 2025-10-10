#!/bin/bash

# Language Environments Setup Script
# Handles Python, Ruby, Flutter, and other language environment setups

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG="$(dirname "$SCRIPT_DIR")"
if [[ -f "$ZSH_CONFIG/logging.zsh" ]]; then
    source "$ZSH_CONFIG/logging.zsh"
fi

# Import utility functions
if [[ -f "$SCRIPT_DIR/utils/brew-install-quiet.sh" ]]; then
    BREW_INSTALL_QUIET="$SCRIPT_DIR/utils/brew-install-quiet.sh"
else
    BREW_INSTALL_QUIET=""
fi

# Function to install package quietly or fallback
install_package() {
    local package="$1"

    if [[ -n "$BREW_INSTALL_QUIET" ]]; then
        "$BREW_INSTALL_QUIET" "$package" || echo "⚠️  Could not install $package"
    else
        brew install "$package" >/dev/null 2>&1 || echo "⚠️  Could not install $package"
    fi
}

# Setup Python environment
setup_python() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Python..."
    else
        echo "🐍 Setting up Python..."
    fi

    # Install Python packages
    install_package "python@3.11"
    install_package "pyenv"

    # Install Poetry
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -

    # Install common Python tools
    echo "Installing common Python tools..."
    pip3 install --user black flake8 mypy pytest 2>/dev/null || echo "⚠️  Some Python tools may already be installed"

    if command -v log_success >/dev/null 2>&1; then
        log_success "Python setup complete"
    else
        echo "✅ Python setup complete"
    fi
}

# Setup Ruby environment
setup_ruby() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Ruby..."
    else
        echo "💎 Setting up Ruby..."
    fi

    # Install RVM if not present
    if ! command -v rvm >/dev/null 2>&1; then
        echo "Installing RVM..."
        \curl -sSL https://get.rvm.io | bash -s stable
    fi

    # Configure RVM settings
    echo "Configuring RVM settings..."
    if command -v rvm >/dev/null 2>&1; then
        rvm rvmrc warning ignore /Users/hemantv/zshrc/Gemfile
        echo "✅ RVM rvmrc warning ignored for Gemfile"
    fi

    # Setup Ruby configuration files
    echo "Setting up Ruby configuration files..."
    SETTINGS="$ZSH_CONFIG/Settings"
    USER_BIN="${HOME}/bin"

    if [[ -f "$SETTINGS/irbrc" ]]; then
        ln -sf "$SETTINGS/irbrc" "${HOME}/.irbrc"
        echo "✅ Linked .irbrc"
    fi

    if [[ -f "$SETTINGS/gemrc" ]]; then
        ln -sf "$SETTINGS/gemrc" "${HOME}/.gemrc"
        echo "✅ Linked .gemrc"
    fi

    if [[ -f "$SETTINGS/ctags_for_ruby" ]]; then
        chmod +x "$SETTINGS/ctags_for_ruby"
        mkdir -p "$USER_BIN"
        ln -sf "$SETTINGS/ctags_for_ruby" "$USER_BIN/ctags_for_ruby"
        echo "✅ Linked ctags_for_ruby to $USER_BIN/"
    fi

    mkdir -p "$USER_BIN"
    echo "Installing ctags for Ruby development..."
    install_package "ctags"

    # Setup Ruby gems
    setup_ruby_gems

    if command -v log_success >/dev/null 2>&1; then
        log_success "Ruby setup complete"
    else
        echo "✅ Ruby setup complete"
    fi
}

# Setup Ruby gems
setup_ruby_gems() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Installing Ruby gems..."
    else
        echo -e "$(MAGENTA)💎 Installing Ruby gems for bin...$(NC)"
    fi

    if ! command -v bundle >/dev/null 2>&1; then
        echo "Installing Bundler..."
        gem install bundler
    fi

    if [[ -f "Gemfile" ]]; then
        echo "Installing gems from Gemfile..."
        bundle config set --local path 'vendor/bundle'
        bundle install
        if command -v log_success >/dev/null 2>&1; then
            log_success "Ruby gems installed successfully"
        else
            echo "✅ Ruby gems installed successfully"
        fi
    else
        echo "⚠️  No Gemfile found - skipping gem installation"
    fi
}

# Setup PostgreSQL
setup_postgres() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Installing PostgreSQL..."
    else
        echo "🐘 Installing PostgreSQL..."
    fi

    install_package "postgresql@15"

    if command -v log_info >/dev/null 2>&1; then
        log_info "Starting PostgreSQL service..."
    else
        echo "Starting PostgreSQL service..."
    fi

    brew services start postgresql@15 >/dev/null 2>&1 || echo "⚠️  Could not start PostgreSQL service"

    if command -v log_success >/dev/null 2>&1; then
        log_success "PostgreSQL setup complete"
    else
        echo "✅ PostgreSQL setup complete"
    fi
}

# Setup Flutter development environment
setup_flutter() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Flutter development environment..."
    else
        echo "🦋 Setting up Flutter development environment..."
    fi

    # Install Xcode command line tools first
    echo "Updating Xcode and Command Line Tools..."
    if [[ -f "$SCRIPT_DIR/setup-macos.sh" ]]; then
        bash "$SCRIPT_DIR/setup-macos.sh" xcode-setup
    else
        echo "Installing Xcode command line tools..."
        xcode-select --install 2>/dev/null || echo "Command line tools already installed"
    fi

    # Install Flutter SDK
    echo "Installing Flutter SDK..."
    install_package "flutter"

    # Setup Android development
    echo "Setting up Android development..."
    brew install --cask android-studio >/dev/null 2>&1 || echo "Android Studio already installed"
    install_package "android-sdk"

    # Configure Android SDK paths
    echo "Configuring Android SDK paths..."
    mkdir -p "$HOME/Library/Android/sdk"
    if [[ -d "/opt/homebrew/share/android-sdk" ]]; then
        echo "Linking Android SDK..."
        ln -sf "/opt/homebrew/share/android-sdk" "$HOME/Library/Android/sdk"
    fi

    # Install Android SDK components
    echo "Installing Android SDK components..."
    sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.1" >/dev/null 2>&1 || echo "⚠️  SDK components may already be installed"

    # Setup iOS development tools
    echo "Setting up iOS development tools..."
    install_package "cocoapods"
    echo "Setting up CocoaPods with RVM..."
    gem install cocoapods >/dev/null 2>&1 || echo "CocoaPods already installed"

    # Accept Android licenses
    echo "Accepting Android licenses..."
    yes | flutter doctor --android-licenses >/dev/null 2>&1 || echo "⚠️  Android licenses may already be accepted"

    # Run Flutter doctor
    echo "Running Flutter doctor..."
    flutter doctor

    echo ""
    echo "✅ Flutter development environment setup complete!"
    echo ""
    echo "📋 Next steps:"
    echo " 1. Open Android Studio and complete the setup wizard"
    echo " 2. Create an Android Virtual Device (AVD) or connect a physical device"
    echo " 3. Run 'flutter doctor' again to verify setup"
    echo " 4. For iOS development, run 'xcodebuild -downloadPlatform iOS' (requires Xcode)"
    echo " 5. Test with: flutter run -d chrome (web) or flutter run -d macos (desktop)"

    if command -v log_success >/dev/null 2>&1; then
        log_success "Flutter setup complete"
    else
        echo "✅ Flutter setup complete"
    fi
}

# Setup Node.js environment with nvm (optional)
setup_node() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "Setting up Node.js with nvm..."
    else
        echo "🟢 Setting up Node.js with nvm..."
    fi

    # Install nvm if not present
    if ! command -v nvm >/dev/null 2>&1 && [[ ! -f "$HOME/.config/nvm/nvm.sh" ]]; then
        echo "Installing nvm (Node Version Manager)..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

        # Source zsh config to get proper nvm setup
        if [[ -f "$HOME/.zshrc" ]]; then
            source "$HOME/.zshrc" 2>/dev/null || true
        fi

        if command -v log_success >/dev/null 2>&1; then
            log_success "nvm installed successfully"
        else
            echo "✅ nvm installed successfully"
        fi
    else
        # Source zsh config to get proper nvm setup
        if [[ -f "$HOME/.zshrc" ]]; then
            source "$HOME/.zshrc" 2>/dev/null || true
        fi

        if command -v log_info >/dev/null 2>&1; then
            log_info "nvm already installed"
        else
            echo "ℹ️  nvm already installed"
        fi
    fi

    # Install and use Node.js 20
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        echo "Installing Node.js 20..."
        # Ensure nvm is loaded
        \. "$NVM_DIR/nvm.sh"
        nvm install 20
        nvm use 20
        nvm alias default 20

        # Verify installation
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)

        if command -v log_success >/dev/null 2>&1; then
            log_success "Node.js $NODE_VERSION and npm $NPM_VERSION installed successfully"
        else
            echo "✅ Node.js $NODE_VERSION and npm $NPM_VERSION installed successfully"
        fi

        # Install Yarn (latest version) using official script
        echo "Installing latest Yarn..."
        if ! command -v yarn >/dev/null 2>&1; then
            curl -o- -L https://yarnpkg.com/install.sh | bash
            # Add Yarn to PATH for current session
            export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
        else
            # Update existing Yarn to latest
            yarn set version latest
        fi

        # Install other common global packages
        echo "Installing other common Node.js packages..."
        npm install -g typescript ts-node nodemon 2>/dev/null || echo "⚠️  Some packages may already be installed"

        if command -v log_success >/dev/null 2>&1; then
            log_success "Common Node.js packages installed"
        else
            echo "✅ Common Node.js packages installed"
        fi
    else
        echo "❌ nvm installation not found. Please check the installation or restart your terminal and run the script again."
        exit 1
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Node.js setup with nvm complete"
    else
        echo "✅ Node.js setup with nvm complete"
    fi
}

# Main execution based on arguments
case "${1:-all}" in
    "python")
        setup_python
        ;;
    "ruby")
        setup_ruby
        ;;
    "ruby-gems")
        setup_ruby_gems
        ;;
    "postgres")
        setup_postgres
        ;;
    "flutter")
        setup_flutter
        ;;
    "node")
        setup_node
        ;;
    "all")
        setup_python
        setup_ruby
        setup_postgres

        if command -v log_info >/dev/null 2>&1; then
            log_info "Flutter setup requires manual confirmation due to size..."
        else
            echo "🦋 Flutter setup requires manual confirmation due to size..."
            echo "Run '$0 flutter' to setup Flutter development environment"
        fi

        if command -v log_success >/dev/null 2>&1; then
            log_success "Language environments setup complete"
        else
            echo "✅ Language environments setup complete"
        fi
        ;;
    *)
        echo "Usage: $0 [python|ruby|ruby-gems|postgres|flutter|node|all]"
        echo ""
        echo "Language environments:"
        echo " python    - Setup Python 3.11, pyenv, Poetry, and common tools"
        echo " ruby      - Setup Ruby via RVM with configuration files"
        echo " ruby-gems - Install Ruby gems from Gemfile"
        echo " postgres  - Install PostgreSQL 15 and start service"
        echo " flutter   - Setup Flutter SDK with Android and iOS support"
        echo " node      - Setup Node.js 20 with nvm and common packages"
        echo " all       - Setup all language environments (except Flutter)"
        exit 1
        ;;
esac