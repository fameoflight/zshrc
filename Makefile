# ZSH Configuration Setup Makefile
# Author: Hemant Verma <fameoflight@gmail.com>

# =============================================================================
# VARIABLES
# =============================================================================

# Color definitions for enhanced output
# These can also be inherited from logging.zsh if available
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
MAGENTA := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
BOLD := \033[1m
DIM := \033[2m
NC := \033[0m# No Color

# XDG Base Directory Specification
XDG_CONFIG_HOME := ${HOME}/.config
XDG_CACHE_HOME := ${HOME}/.cache

# ZSH Configuration Paths
ZSH_CONFIG := ${XDG_CONFIG_HOME}/zsh
ZSH_CACHE := ${XDG_CACHE_HOME}/zsh
ZSH_LOCAL := ${HOME}/.local
USER_BIN := ${HOME}/bin

# Project Paths
ZSH := ${HOME}/zshrc
SETTINGS := ${ZSH}/Settings

# User Information
NAME := Hemant Verma
EMAIL := fameoflight@gmail.com

# System Detection
UNAME := $(shell uname)

# Package Lists for Homebrew
CORE_UTILS_BREW := tree wget watch ripgrep fd bat eza htop jq yq rg
DEV_UTILS_BREW := duti fswatch ssh-copy-id rmtrash sleepwatcher pkgconf dockutil librsvg opencv cloudflare/cloudflare/cloudflared sccache llvm
MODERN_CLI_BREW := zoxide starship fzf claude-code gemini-cli yt-dlp displayplacer uhubctl
EDITORS_CASK := visual-studio-code zed lm-studio ollama
MAC_APPS_CASK := iterm2 rectangle raycast docker postman tableplus the-unarchiver keka slack zoom monitorcontrol

# =============================================================================
# MAIN TARGETS
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: all help setup
all: detect-platform

setup: install app-settings ai-tools
	@echo -e "$(BOLD)$(GREEN)✅ Complete system setup finished$(NC)"
	@echo -e "$(BOLD)$(CYAN)🎉 Your development environment is ready!$(NC)"

help:
	@echo -e "$(BOLD)$(CYAN)🐚 ZSH Configuration Setup$(NC)"
	@echo ""
	@echo -e "$(BOLD)$(BLUE)🎯 Main targets:$(NC)"
	@echo -e "  $(GREEN)setup$(NC)     - 🚀 Complete setup"
	@echo -e "  $(GREEN)all$(NC)        - 🔍 Auto-detect platform and run setup"
	@echo -e "  $(GREEN)mac$(NC)       - 🍎 Complete macOS setup"
	@echo -e "  $(GREEN)install$(NC)   - 📦 Install shell configurations only"
	@echo ""
	@echo -e "$(BOLD)$(YELLOW)🍺 Package Management:$(NC)"
	@echo -e "  $(GREEN)brew$(NC)      - Complete Homebrew setup"
	@echo -e "  $(GREEN)dev-tools$(NC) - Install all development tools"
	@echo -e "  $(GREEN)core-utils$(NC) - Essential CLI utilities"
	@echo -e "  $(GREEN)modern-cli$(NC) - Modern CLI tools (fzf, starship, claude-code)"
	@echo -e "  $(GREEN)editors$(NC)   - Text editors and IDEs"
	@echo ""
	@echo -e "$(BOLD)$(GREEN)🐍 Languages:$(NC)"
	@echo -e "  $(GREEN)python$(NC)    - Python and Poetry"
	@echo -e "  $(GREEN)ruby$(NC)      - Ruby via RVM"
	@echo -e "  $(GREEN)flutter$(NC)   - Flutter SDK with mobile support"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)🤖 AI/ML Tools:$(NC)"
	@echo -e "  $(GREEN)pytorch-setup$(NC) - Setup PyTorch models for image upscaling (includes OpenCV)"
	@echo ""
	@echo -e "$(BOLD)$(MAGENTA)⚙️  Configuration:$(NC)"
	@echo -e "  $(GREEN)app-settings$(NC) - Restore all application settings"
	@echo -e "  $(GREEN)ai-tools$(NC)     - Setup Claude and Gemini"
	@echo -e "  $(GREEN)github-setup$(NC) - Configure Git"
	@echo -e "  $(GREEN)macos-optimize$(NC) - Optimize macOS settings"
	@echo ""
	@echo -e "$(BOLD)$(RED)🩺 Troubleshooting:$(NC)"
	@echo -e "  $(GREEN)doctor$(NC)   - Run system diagnostics"
	@echo -e "  $(GREEN)debug$(NC)    - Profile ZSH startup performance"
	@echo -e "  $(GREEN)fix-brew$(NC) - Fix Homebrew issues"
	@echo -e "  $(GREEN)update$(NC)   - Update repository and packages"
	@echo -e "  $(GREEN)clean$(NC)    - Clean temporary files"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)💡 Tip: Use scripts directly for granular control:$(NC)"
	@echo -e "  $(YELLOW)bash scripts/setup-dev-tools.sh modern-cli$(NC)"
	@echo -e "  $(YELLOW)bash scripts/restore-settings.sh vscode$(NC)"


detect-platform:
ifeq ($(UNAME), Darwin)
	@echo "🍎 Detected macOS - running macOS setup"
	@$(MAKE) mac
else ifeq ($(UNAME), Linux)
	@echo "🐧 Detected Linux - running Linux setup"
	@$(MAKE) linux
else
	@echo "❌ Unsupported platform: $(UNAME)"
	@exit 1
endif

# =============================================================================
# AI/ML TOOLS TARGETS
# =============================================================================

.PHONY: pytorch-setup python-models

pytorch-setup:
	@echo -e "$(BOLD)$(CYAN)🤖 Setting up PyTorch models for Apple Silicon$(NC)"
	@echo -e "$(DIM)This will download and convert PyTorch models to CoreML format$(NC)"
	@echo ""
	@echo -e "$(YELLOW)🧹 Cleaning existing Apple Silicon models...$(NC)"
	@rm -rf ${HOME}/.config/zsh/.models/apple-silicon
	@if [ -f "scripts/setup-pytorch-models.rb" ]; then \
		ruby scripts/setup-pytorch-models.rb; \
	else \
		echo -e "$(RED)❌ Setup script not found: scripts/setup-pytorch-models.rb$(NC)"; \
		exit 1; \
	fi

python-models: pytorch-setup

# =============================================================================
# PLATFORM-SPECIFIC TARGETS
# =============================================================================

.PHONY: mac linux common mac-settings macos-optimize macos-oled-optimize post-mac-setup
mac: check-requirements common brew dev-tools python ruby postgres github-tools mac-apps mac-utils mac-settings app-settings ai-tools setup-hooks post-mac-setup

linux: common linux-packages linux-settings

common: install github-setup

post-mac-setup:
	@bash scripts/post-mac-setup.sh

# =============================================================================
# REQUIREMENTS & VALIDATION
# =============================================================================

.PHONY: check-requirements
check-requirements:
	@echo "🔍 Checking requirements..."
	@command -v git >/dev/null 2>&1 || { echo "❌ Git is required but not installed"; exit 1; }
	@echo "✅ Requirements check passed"

# =============================================================================
# PACKAGE MANAGERS
# =============================================================================

# =============================================================================
# HOMEBREW - Package manager setup and maintenance
# =============================================================================

.PHONY: brew brew-install brew-update brew-essentials
brew: brew-install brew-update brew-essentials
	@echo -e "$(BOLD)$(GREEN)✅ Homebrew setup complete$(NC)"

# Install Homebrew if not present
brew-install:
	@echo -e "$(BLUE)🍺 Checking Homebrew installation...$(NC)"
	@if ! command -v brew >/dev/null 2>&1; then \
		echo -e "$(YELLOW)📥 Installing Homebrew...$(NC)"; \
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
	else \
		echo -e "$(GREEN)✅ Homebrew already installed$(NC)"; \
	fi

# Update Homebrew and all packages
brew-update:
	@echo -e "$(CYAN)🔄 Updating Homebrew and packages...$(NC)"
	-@brew update    # Update Homebrew itself || echo -e "$(YELLOW)⚠️  Homebrew update failed, continuing...$(NC)"
	-@brew upgrade   # Upgrade all installed packages || echo -e "$(YELLOW)⚠️  Package upgrade failed, continuing...$(NC)"
	-@brew cleanup   # Clean up old versions || echo -e "$(YELLOW)⚠️  Brew cleanup failed, continuing...$(NC)"

# Install essential Homebrew packages for this setup
brew-essentials:
	@echo "📦 Installing essential packages..."
	-@brew install zsh-completions  # ZSH tab completions || echo -e "$(YELLOW)⚠️  zsh-completions install failed, continuing...$(NC)"
	-@brew install mas              # Mac App Store CLI || echo -e "$(YELLOW)⚠️  mas install failed, continuing...$(NC)"

.PHONY: linux-packages
linux-packages:
	@echo "🐧 Installing Linux packages..."
	@echo "🔄 Updating package lists..."
	@sudo apt-get update
	@echo "📦 Installing essential packages..."
	@sudo apt-get install -y zsh git wget curl tree

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================

# =============================================================================
# DEVELOPMENT TOOLS - Broken into smaller, focused targets
# =============================================================================

.PHONY: dev-tools core-utils dev-utils modern-cli editors
dev-tools: brew core-utils dev-utils modern-cli editors
	@echo -e "$(BOLD)$(GREEN)✅ Development tools installation complete$(NC)"

# Install essential command-line utilities
core-utils:
	@bash scripts/setup-dev-tools.sh core-utils || echo -e "$(YELLOW)⚠️  core-utils installation failed, continuing...$(NC)"

# Install development utilities
dev-utils:
	@bash scripts/setup-dev-tools.sh dev-utils || echo -e "$(YELLOW)⚠️  dev-utils installation failed, continuing...$(NC)"

# Install modern CLI tools and enhancements
modern-cli:
	@bash scripts/setup-dev-tools.sh modern-cli || echo -e "$(YELLOW)⚠️  modern-cli installation failed, continuing...$(NC)"

# Install text editors and IDEs
editors:
	@bash scripts/setup-dev-tools.sh editors || echo -e "$(YELLOW)⚠️  editors installation failed, continuing...$(NC)"

.PHONY: python
python: brew
	@bash scripts/setup-languages.sh python || echo -e "$(YELLOW)⚠️  Python setup failed, continuing...$(NC)"

.PHONY: ruby ruby-gems
ruby: brew ruby-gems
	@bash scripts/setup-languages.sh ruby || echo -e "$(YELLOW)⚠️  Ruby setup failed, continuing...$(NC)"

ruby-gems:
	@echo -e "$(BLUE)💎 Installing Ruby gems for CLI tools...$(NC)"
	@cd bin/ruby-cli && source $$HOME/.rvm/scripts/rvm && rvm use 3.2.4 && bundle install || echo -e "$(YELLOW)⚠️  Ruby gems installation failed, continuing...$(NC)"

.PHONY: postgres
postgres: brew
	@bash scripts/setup-languages.sh postgres || echo -e "$(YELLOW)⚠️  PostgreSQL setup failed, continuing...$(NC)"

.PHONY: flutter
flutter: brew xcode-update
	@bash scripts/setup-languages.sh flutter || echo -e "$(YELLOW)⚠️  Flutter setup failed, continuing...$(NC)"

.PHONY: github-tools
github-tools: brew
	@bash scripts/setup-macos.sh github-tools || echo -e "$(YELLOW)⚠️  GitHub tools setup failed, continuing...$(NC)"

.PHONY: xcode-setup
xcode-setup:
	@bash scripts/setup-macos.sh xcode-setup || echo -e "$(YELLOW)⚠️  Xcode setup failed, continuing...$(NC)"

.PHONY: xcode-backup vscode-backup iterm-backup iterm-setup
xcode-backup:
	@bash "${ZSH}/bin/xcode-backup.sh" || echo -e "$(YELLOW)⚠️  Xcode backup failed, continuing...$(NC)"

vscode-backup:
	@bash "${ZSH}/bin/vscode-backup.sh" || echo -e "$(YELLOW)⚠️  VSCode backup failed, continuing...$(NC)"

iterm-backup:
	@bash "${ZSH}/bin/iterm-backup.sh" || echo -e "$(YELLOW)⚠️  iTerm backup failed, continuing...$(NC)"

iterm-setup:
	@bash "${ZSH}/bin/iterm-setup.sh" || echo -e "$(YELLOW)⚠️  iTerm setup failed, continuing...$(NC)"

.PHONY: claude-setup claude-link
claude-setup: claude-link
	@bash scripts/restore-settings.sh claude || echo -e "$(YELLOW)⚠️  Claude setup failed, continuing...$(NC)"

# Create symlink for Claude binary to expected native installation path
claude-link:
	@bash scripts/restore-settings.sh claude-link || echo -e "$(YELLOW)⚠️  Claude link creation failed, continuing...$(NC)"

.PHONY: vscode-setup
vscode-setup:
	@bash scripts/restore-settings.sh vscode || echo -e "$(YELLOW)⚠️  VSCode setup failed, continuing...$(NC)"

# =============================================================================
# macOS APPLICATIONS
# =============================================================================

.PHONY: mac-apps mac-utils
mac-apps: github-tools xcode-setup
	@bash scripts/setup-macos.sh mac-apps || echo -e "$(YELLOW)⚠️  Mac apps installation failed, continuing...$(NC)"

mac-utils:
	@echo "🔨 Building mac-utils..."
	@cd mac-utils && make -j$$(nproc) || echo -e "$(YELLOW)⚠️  mac-utils build failed, continuing...$(NC)"
	@echo "📦 Installing mac-utils to $$HOME/bin..."
	@mkdir -p $$HOME/bin
	@cp -f mac-utils/bin/* $$HOME/bin/ || echo -e "$(YELLOW)⚠️  mac-utils copy failed, continuing...$(NC)"
	@echo "🔗 Creating convenient symlinks..."
	@cd $$HOME/bin && ln -sf ToggleHDR toggle-hdr || echo -e "$(YELLOW)⚠️  symlink creation failed, continuing...$(NC)"
	@echo -e "$(BOLD)$(GREEN)✅ mac-utils installation complete$(NC)"

# =============================================================================
# SYSTEM SETTINGS
# =============================================================================

.PHONY: mac-settings
mac-settings: macos-optimize

# Optimize macOS system settings for developers
.PHONY: macos-optimize
macos-optimize:
	@bash scripts/setup-macos.sh macos-optimize

# Optimize macOS settings specifically for OLED displays
.PHONY: macos-oled-optimize
macos-oled-optimize:
	@bash scripts/setup-macos.sh macos-oled-optimize

.PHONY: setup-hooks
setup-hooks:
	@bash scripts/setup-macos.sh setup-hooks

.PHONY: uninstall-hooks
uninstall-hooks:
	@echo -e "$(MAGENTA)🗑️  Uninstalling wake and sleep hooks...$(NC)"
	@echo -e "$(CYAN)🚀 Stopping sleepwatcher service...$(NC)"
	-@brew services stop sleepwatcher
	@echo -e "$(CYAN)🔗 Removing script symlinks...$(NC)"
	@rm -f "${HOME}/.wakeup"
	@rm -f "${HOME}/.sleep"
	@echo -e "$(CYAN)📱 Unloading and removing LaunchAgent...$(NC)"
	-@launchctl unload "${HOME}/Library/LaunchAgents/com.hemantv.wakeup.plist" 2>/dev/null
	@rm -f "${HOME}/Library/LaunchAgents/com.hemantv.wakeup.plist"
	@echo -e "$(CYAN)🔗 Removing from Login Items if present...$(NC)"
	-@osascript -e 'tell application "System Events" to delete login item "wakeup.sh"' 2>/dev/null || true
	@echo -e "$(BOLD)$(GREEN)✅ Wake and sleep hooks uninstalled$(NC)"

.PHONY: linux-settings
linux-settings:
	@echo "⚙️  Configuring Linux settings..."
	@sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100



# =============================================================================
# SETTINGS RESTORATION
# =============================================================================

.PHONY: app-settings ai-tools restore-all-settings restore-ruby-config
app-settings: restore-iterm restore-vscode restore-xcode restore-sublime restore-dock restore-ruby-config
	@echo -e "$(BOLD)$(GREEN)✅ Application settings restoration complete$(NC)"

ai-tools: restore-claude restore-gemini
	@echo -e "$(BOLD)$(GREEN)✅ AI tools setup complete$(NC)"

restore-all-settings: app-settings ai-tools
	@echo -e "$(BOLD)$(GREEN)✅ All settings restored successfully$(NC)"

.PHONY: restore-iterm
restore-iterm:
	@bash scripts/restore-settings.sh iterm || echo -e "$(YELLOW)⚠️  iTerm settings restore failed, continuing...$(NC)"

.PHONY: restore-vscode
restore-vscode:
	@bash scripts/restore-settings.sh vscode || echo -e "$(YELLOW)⚠️  VSCode settings restore failed, continuing...$(NC)"

.PHONY: restore-xcode
restore-xcode:
	@bash scripts/setup-macos.sh xcode-setup || echo -e "$(YELLOW)⚠️  Xcode setup failed, continuing...$(NC)"

.PHONY: restore-sublime
restore-sublime:
	@bash scripts/restore-settings.sh sublime || echo -e "$(YELLOW)⚠️  Sublime settings restore failed, continuing...$(NC)"

.PHONY: restore-dock
restore-dock:
	@bash scripts/restore-settings.sh dock || echo -e "$(YELLOW)⚠️  Dock settings restore failed, continuing...$(NC)"

.PHONY: restore-claude
restore-claude:
	@bash scripts/restore-settings.sh claude || echo -e "$(YELLOW)⚠️  Claude settings restore failed, continuing...$(NC)"

.PHONY: restore-gemini gemini-setup
restore-gemini: gemini-setup

gemini-setup:
	@bash scripts/restore-settings.sh gemini || echo -e "$(YELLOW)⚠️  Gemini setup failed, continuing...$(NC)"

.PHONY: restore-ruby-config
restore-ruby-config:
	@bash scripts/restore-settings.sh ruby-config || echo -e "$(YELLOW)⚠️  Ruby config restore failed, continuing...$(NC)"

.PHONY: restore-rust-config
restore-rust-config:
	@bash scripts/restore-settings.sh rust-config || echo -e "$(YELLOW)⚠️  Rust config restore failed, continuing...$(NC)"

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

.PHONY: install install-zsh install-bash install-externals
install: install-externals install-zsh install-bash
	@echo "✅ Shell configuration installation complete"

install-zsh:
	@echo "🐚 Installing ZSH configuration..."
	@echo "🔗 Linking main zshrc file..."
	@rm -rf "${HOME}/.zshrc"
	@ln -sf ${HOME}/zshrc/zshrc ${HOME}/.zshrc
	@echo "📁 Creating directories..."
	@mkdir -p ${XDG_CONFIG_HOME}
	@mkdir -p ${ZSH_CACHE}
	@mkdir -p ${ZSH_LOCAL}/bin
	@mkdir -p ${ZSH_LOCAL}/share
	@mkdir -p functions.d
	@echo "🔗 Creating zsh config symlink..."
	@if [ ! -L ${ZSH_CONFIG} ]; then ln -sf ${PWD} ${ZSH_CONFIG}; fi
	@echo "🦘 Creating autojump symlink..."
	@if [ -f "${PWD}/autojump/autojump" ] && [ ! -L ${ZSH_LOCAL}/bin/autojump ]; then \
		ln -sf ${PWD}/autojump/autojump ${ZSH_LOCAL}/bin/autojump; \
	fi
	@echo "📝 Creating private config file..."
	@touch private.zsh
	@touch private.final.zsh

install-bash:
	@echo "🐚 Installing Bash configuration..."
	@echo "💾 Backing up existing bashrc..."
	@if [ -f "${HOME}/.bashrc" ]; then mv ${HOME}/.bashrc ${PWD}/bashrc.bak; fi
	@echo "🔗 Linking bashrc..."
	@rm -rf "${HOME}/.bashrc"
	@ln -sf ${PWD}/bashrc ${HOME}/.bashrc
	@echo "🔗 Linking profile..."
	@rm -rf "${HOME}/.profile"
	@ln -sf ${PWD}/profile ${HOME}/.profile

install-externals:
	@echo "📦 Installing external dependencies..."
	@echo "🔄 Updating git submodules..."
	@git submodule update --init --recursive || echo -e "$(YELLOW)⚠️  Submodule update failed, continuing...$(NC)"

# =============================================================================
# GIT CONFIGURATION
# =============================================================================

.PHONY: github-setup
github-setup:
	@bash scripts/setup-git.sh || echo -e "$(YELLOW)⚠️  Git setup failed, continuing...$(NC)"

# =============================================================================
# MAINTENANCE
# =============================================================================

.PHONY: update clean
update:
	@bash scripts/troubleshooting.sh update || echo -e "$(YELLOW)⚠️  Update failed, continuing...$(NC)"

clean:
	@bash scripts/troubleshooting.sh clean || echo -e "$(YELLOW)⚠️  Clean failed, continuing...$(NC)"

# =============================================================================
# REPOSITORY MAINTENANCE
# =============================================================================

.PHONY: find-orphans
find-orphans:
	@echo "🔍 Finding orphaned targets in Makefile..."
	@cd bin/ruby-cli && bundle exec ruby bin/internal-find-orphaned-targets.rb || echo -e "$(YELLOW)⚠️  Orphaned targets search failed, continuing...$(NC)"

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

# =============================================================================
# TROUBLESHOOTING - Fix common issues and run diagnostics
# =============================================================================

.PHONY: debug debug-profile debug-baseline debug-compare debug-components debug-recommendations debug-test-optimizations fix-brew fix-brew-only brew-doctor brew-clean brew-relink xcode-update doctor

# ZSH startup performance debugging
debug:
	@echo -e "$(BOLD)$(CYAN)🔍 ZSH Startup Performance Debugging$(NC)"
	@echo -e "$(DIM)Running comprehensive ZSH startup analysis...$(NC)"
	@echo ""
	@bash scripts/debug.zsh || echo -e "$(YELLOW)⚠️  ZSH debug failed, continuing...$(NC)"

debug-profile:
	@echo -e "$(BOLD)$(CYAN)🔍 Detailed ZSH Startup Profiling$(NC)"
	@echo ""
	@bash scripts/debug.zsh profile || echo -e "$(YELLOW)⚠️  ZSH profile debug failed, continuing...$(NC)"

debug-baseline:
	@echo -e "$(BOLD)$(CYAN)📊 ZSH Baseline Performance Testing$(NC)"
	@echo ""
	@bash scripts/debug.zsh baseline || echo -e "$(YELLOW)⚠️  ZSH baseline testing failed, continuing...$(NC)"

debug-compare:
	@echo -e "$(BOLD)$(CYAN)⚖️  ZSH Performance Comparison$(NC)"
	@echo ""
	@bash scripts/debug.zsh compare || echo -e "$(YELLOW)⚠️  ZSH comparison failed, continuing...$(NC)"

debug-components:
	@echo -e "$(BOLD)$(CYAN)🔧 ZSH Component Analysis$(NC)"
	@echo ""
	@bash scripts/debug.zsh components || echo -e "$(YELLOW)⚠️  ZSH component analysis failed, continuing...$(NC)"

debug-recommendations:
	@echo -e "$(BOLD)$(CYAN)💡 ZSH Optimization Recommendations$(NC)"
	@echo ""
	@bash scripts/debug.zsh recommend || echo -e "$(YELLOW)⚠️  ZSH recommendations failed, continuing...$(NC)"

debug-test-optimizations:
	@echo -e "$(BOLD)$(CYAN)✅ Testing ZSH Optimizations$(NC)"
	@echo ""
	@bash scripts/debug.zsh test-optimizations || echo -e "$(YELLOW)⚠️  ZSH optimization testing failed, continuing...$(NC)"
fix-brew: fix-permissions brew-doctor brew-update brew-relink xcode-update
	@echo -e "$(BOLD)$(GREEN)✅ Homebrew troubleshooting complete$(NC)"

# Fix Homebrew without changing system permissions (recommended)
fix-brew-only: brew-doctor brew-update brew-relink xcode-update
	@echo -e "$(BOLD)$(GREEN)✅ Homebrew troubleshooting complete (no permission changes)$(NC)"

# Run Homebrew's built-in diagnostic tool
brew-doctor:
	@bash scripts/troubleshooting.sh brew-doctor || echo -e "$(YELLOW)⚠️  Brew doctor failed, continuing...$(NC)"

# Clean incomplete Homebrew processes and cache
brew-clean:
	@bash scripts/troubleshooting.sh brew-clean || echo -e "$(YELLOW)⚠️  Brew clean failed, continuing...$(NC)"

# Fix broken package symlinks
brew-relink:
	@bash scripts/troubleshooting.sh brew-relink || echo -e "$(YELLOW)⚠️  Brew relink failed, continuing...$(NC)"

# Install or update Xcode and Command Line Tools
xcode-update:
	@bash scripts/troubleshooting.sh xcode-update || echo -e "$(YELLOW)⚠️  Xcode update failed, continuing...$(NC)"

# Fix system permissions
fix-permissions:
	@bash scripts/troubleshooting.sh fix-permissions || echo -e "$(YELLOW)⚠️  Fix permissions failed, continuing...$(NC)"

# Run comprehensive system diagnostics
doctor:
	@bash scripts/troubleshooting.sh system-doctor || echo -e "$(YELLOW)⚠️  System diagnostics failed, continuing...$(NC)"

# =============================================================================
# RUST PROGRAMS
# =============================================================================

.PHONY: rust
rust:
	@echo -e "$(BOLD)$(CYAN)🦀 Building Rust programs with optimizations...$(NC)"

	@cd bin/rust-cli && \
		if [ "$(CLEAN)" = "true" ] || [ "$(CLEAN)" = "1" ]; then \
			echo -e "$(YELLOW)🧹 Cleaning previous builds...$(NC)"; \
			cargo clean; \
		fi && \
		RUSTFLAGS="-C target-cpu=native -C opt-level=3" \
		RUSTC_WRAPPER=sccache \
		cargo build --release
	@echo -e "$(BOLD)$(GREEN)✅ Rust programs built successfully$(NC)"
	@echo -e "$(CYAN)📦 Optimized binaries available at: bin/rust-cli/target/release/$(NC)"
	@if [ "$(CLEAN)" = "true" ] || [ "$(CLEAN)" = "1" ]; then \
		echo -e "$(CYAN)💡 For faster builds next time, run: make rust$(NC)"; \
	else \
		echo -e "$(CYAN)💡 For a completely fresh build, run: CLEAN=1 make rust$(NC)"; \
	fi

# =============================================================================
# React INK PROGRAMS
# =============================================================================

.PHONY: ink

ink:
	@echo -e "$(BOLD)$(CYAN)🖌️  Building React Ink programs...$(NC)"
	@cd ~/workspace/ink-cli && { \
		if [ "$(CLEAN)" = "true" ] || [ "$(CLEAN)" = "1" ]; then \
			echo -e "$(YELLOW)🧹 Cleaning previous builds...$(NC)"; \
			rm -rf node_modules; \
		fi; \
		rm -rf dist; \
		echo -e "$(BLUE)📦 Installing dependencies...$(NC)"; \
		if [ -f "$$HOME/.config/nvm/nvm.sh" ]; then \
			. "$$HOME/.config/nvm/nvm.sh" && nvm use default && npm install --legacy-peer-deps; \
		else \
			npm install --legacy-peer-deps; \
		fi; \
		echo -e "$(BLUE)🚀 Building project...$(NC)"; \
		if [ -f "$$HOME/.config/nvm/nvm.sh" ]; then \
			. "$$HOME/.config/nvm/nvm.sh" && nvm use default && npm run build; \
		else \
			npm run build; \
		fi; \
	}
	@echo -e "$(BOLD)$(GREEN)✅ React Ink programs built successfully$(NC)"

# =============================================================================
# UTILITIES
# =============================================================================

.prompt-yesno:
	@exec 9<&0 0</dev/tty; \
	echo "$(message) [Y/n]:"; \
	[[ -z $$FOUNDATION_NO_WAIT ]] && read -r yn || yn="y"; \
	exec 0<&9 9<&-; \
	case $$yn in [Nn]*) echo "Cancelled" >&2 && exit 1;; *) echo "Proceeding..." >&2;; esac
