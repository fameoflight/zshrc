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

# System Detection
UNAME := $(shell uname)

# Package Lists for Homebrew
CORE_UTILS_BREW := tree wget watch ripgrep fd bat eza htop jq yq
DEV_UTILS_BREW := duti fswatch ssh-copy-id rmtrash sleepwatcher pkgconf dockutil librsvg
MODERN_CLI_BREW := zoxide starship fzf claude-code gemini-cli yt-dlp
EDITORS_CASK := visual-studio-code zed lm-studio
MAC_APPS_CASK := iterm2 rectangle raycast docker postman tableplus the-unarchiver keka slack zoom

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
	@echo -e "  $(GREEN)setup$(NC)           - 🚀 Complete setup - restore all settings and configurations"
	@echo -e "  $(GREEN)all$(NC)              - 🔍 Auto-detect platform and run setup"
	@echo -e "  $(GREEN)mac$(NC)             - 🍎 Complete macOS setup"
	@echo -e "  $(GREEN)linux$(NC)           - 🐧 Complete Linux setup"
	@echo -e "  $(GREEN)install$(NC)         - 📦 Install shell configurations only"
	@echo ""
	@echo -e "$(BOLD)$(YELLOW)🍺 Homebrew targets:$(NC)"
	@echo -e "  $(GREEN)brew$(NC)            - 🚀 Complete Homebrew setup (install + update + essentials)"
	@echo -e "  $(GREEN)brew-install$(NC)    - 📥 Install Homebrew if missing"
	@echo -e "  $(GREEN)brew-update$(NC)     - 🔄 Update Homebrew and all packages"
	@echo -e "  $(GREEN)brew-essentials$(NC) - 📦 Install essential packages (zsh-completions, mas)"
	@echo ""
	@echo "🛠️  Development tools (modular):"
	@echo "  dev-tools       - 🎯 Install all development tools"
	@echo "  core-utils      - ⚡ Essential CLI utilities (tree, wget, ripgrep, etc.)"
	@echo "  dev-utils       - 🔧 Development utilities (duti, fswatch, etc.)"
	@echo "  modern-cli      - ✨ Modern CLI tools (zoxide, starship, fzf, claude-code)"
	@echo "  editors         - 📝 Text editors and IDEs (VS Code, Zed, vim, neovim)"
	@echo ""
	@echo "🐍 Language environments:"
	@echo "  python          - 🐍 Install Python and Poetry"
	@echo "  ruby            - 💎 Install Ruby via RVM"
	@echo "  flutter         - 🦋 Install Flutter SDK with Android and iOS support"
	@echo ""
	@echo "⚙️  Application setup:"
	@echo "  xcode-setup     - 🎨 Setup Xcode themes and bindings"
	@echo "  xcode-update    - 📱 Install/update Xcode and Command Line Tools"
	@echo "  vscode-setup    - 💻 Setup VS Code settings and extensions"
	@echo "  claude-setup    - 🤖 Setup Claude Code settings via symlinks"
	@echo "  github-setup    - 🐙 Configure Git settings"
	@echo "  mac-settings    - ⚡ Configure macOS system settings (calls macos-optimize)"
	@echo "  macos-optimize  - ⚡ Optimize macOS system settings for developers"
	@echo "  macos-oled-optimize - 🖥️  Optimize macOS settings for OLED displays (burn-in prevention)"
	@echo "  setup-hooks     - ⚙️  Setup wake/sleep hooks and login scripts"
	@echo "  uninstall-hooks - 🗑️  Remove wake/sleep hooks and login scripts"
	@echo ""
	@echo "🔄 Settings restoration:"
	@echo "  app-settings    - 📱 Restore all application settings (iTerm, VS Code, Xcode, Sublime, Dock, Ruby)"
	@echo "  ai-tools        - 🤖 Setup AI development tools (Claude, Gemini)"
	@echo "  restore-iterm   - 🖥️  Restore iTerm2 settings"
	@echo "  restore-vscode  - 💻 Restore VS Code settings"
	@echo "  restore-xcode   - 🎨 Restore Xcode settings"
	@echo "  restore-sublime - 📝 Restore Sublime Text settings"
	@echo "  restore-dock    - 🔵 Restore macOS Dock settings"
	@echo "  restore-ruby-config - 💎 Restore Ruby configuration (IRB, Gem, ctags)"
	@echo "  restore-claude  - 🤖 Setup Claude Code"
	@echo "  gemini-setup    - 🤖 Setup Gemini CLI settings via symlinks"
	@echo "  restore-gemini  - 🤖 Setup Gemini CLI (alias for gemini-setup)"
	@echo ""
	@echo "💾 Backup targets:"
	@echo "  xcode-backup    - 📋 Backup current Xcode settings"
	@echo "  vscode-backup   - 📋 Backup current VS Code settings"
	@echo "  iterm-backup    - 📋 Backup current iTerm2 settings"
	@echo "  iterm-setup     - ⚙️  Restore iTerm2 settings from backup"
	@echo ""
	@echo "🩺 Troubleshooting:"
	@echo "  fix-brew        - 🔧 Fix Homebrew issues (with permissions)"
	@echo "  fix-brew-only   - ⭐ Fix Homebrew issues (without permissions) - recommended"
	@echo "  brew-doctor     - 🩺 Run Homebrew diagnostics"
	@echo "  brew-clean      - 🧹 Clean incomplete Homebrew processes and cache"
	@echo "  brew-relink     - 🔗 Fix broken package symlinks"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  update          - 🔄 Update repository and submodules"
	@echo "  clean           - 🧹 Clean up temporary files"


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
# PLATFORM-SPECIFIC TARGETS
# =============================================================================

.PHONY: mac linux common mac-settings macos-optimize macos-oled-optimize post-mac-setup-message
mac: check-requirements common brew dev-tools python ruby postgres github-tools mac-apps mac-settings app-settings ai-tools setup-hooks post-mac-setup-message find-orphans

linux: common linux-packages linux-settings

common: install github-setup

post-mac-setup-message:
	@echo -e "$(BOLD)$(GREEN)✅ Complete macOS setup finished successfully!$(NC)"
	@echo ""
	@echo -e "$(BOLD)$(CYAN)🎉 Your development environment is now fully configured.$(NC)"
	@echo ""
	@echo -e "$(BOLD)$(YELLOW)💡 Suggested next steps:$(NC)"
	@echo -e "  - $(GREEN)Restart your terminal$(NC) to apply all changes."
	@echo -e "  - Run $(CYAN)make help$(NC) to see all available commands."
	@echo -e "  - Customize your setup further by editing $(YELLOW)private.zsh$(NC)."
	@echo -e "  - If you use an OLED display, consider running $(CYAN)make macos-oled-optimize$(NC)."
	@echo ""

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
	-@brew update    # Update Homebrew itself
	-@brew upgrade   # Upgrade all installed packages
	-@brew cleanup   # Clean up old versions

# Install essential Homebrew packages for this setup
brew-essentials:
	@echo "📦 Installing essential packages..."
	-@brew install zsh-completions  # ZSH tab completions
	-@brew install mas              # Mac App Store CLI

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
	@echo -e "$(MAGENTA)📦 Installing core utilities...$(NC)"
	@for pkg in $(CORE_UTILS_BREW); do \
		brew install $$pkg || echo "⚠️  Could not install $$pkg (may already be installed)"; \
	done

# Install development utilities
dev-utils:
	@echo "🔧 Installing development utilities..."
	@for pkg in $(DEV_UTILS_BREW); do \
		brew install $$pkg || echo "⚠️  Could not install $$pkg (may already be installed)"; \
	done

# Install modern CLI tools and enhancements
modern-cli:
	@echo "✨ Installing modern CLI tools..."
	@for pkg in $(MODERN_CLI_BREW); do \
		brew install $$pkg || echo "⚠️  Could not install $$pkg (may already be installed)"; \
	done

	claude config set -g autoUpdates false

# Install text editors and IDEs
editors:
	@echo "📝 Installing editors and IDEs..."
	@for cask in $(EDITORS_CASK); do \
		brew install --cask $$cask || echo "⚠️  Could not install $$cask (may already be installed)"; \
	done
	-@brew install vim || true        # Classic editor
	-@brew install neovim || true     # Modern Vim

.PHONY: python
python: brew
	@echo "🐍 Setting up Python..."
	-@brew install python@3.11
	-@brew install pyenv
	@echo "Installing Poetry..."
	-@curl -sSL https://install.python-poetry.org | python3 -
	@echo "Installing common Python tools..."
	-@pip3 install --user black flake8 mypy pytest

.PHONY: ruby ruby-gems
ruby: brew ruby-gems
	@echo "💎 Setting up Ruby..."
	@if ! command -v rvm >/dev/null 2>&1; then \
		echo "Installing RVM..."; \
		\curl -sSL https://get.rvm.io | bash -s stable; \
	fi
	@echo "⚙️  Configuring RVM settings..."
	@if command -v rvm >/dev/null 2>&1; then \
		rvm rvmrc warning ignore /Users/hemantv/zshrc/Gemfile; \
		echo "✅ RVM rvmrc warning ignored for Gemfile"; \
	fi
	@echo "Setting up Ruby configuration files..."
	@if [ -f "${SETTINGS}/irbrc" ]; then \
		ln -sf ${SETTINGS}/irbrc ${HOME}/.irbrc; \
		echo "✅ Linked .irbrc"; \
	fi
	@if [ -f "${SETTINGS}/gemrc" ]; then \
		ln -sf ${SETTINGS}/gemrc ${HOME}/.gemrc; \
		echo "✅ Linked .gemrc"; \
	fi
	@if [ -f "${SETTINGS}/ctags_for_ruby" ]; then \
		chmod +x ${SETTINGS}/ctags_for_ruby; \
		ln -sf ${SETTINGS}/ctags_for_ruby ${USER_BIN}/ctags_for_ruby; \
		echo "✅ Linked ctags_for_ruby to ${USER_BIN}/"; \
	fi
	@mkdir -p ${USER_BIN}
	@echo "Installing ctags for Ruby development..."
	-@brew install ctags

# Install Ruby gems for bin
ruby-gems:
	@echo -e "$(MAGENTA)💎 Installing Ruby gems for bin...$(NC)"
	@if ! command -v bundle >/dev/null 2>&1; then \
		echo "Installing Bundler..."; \
		gem install bundler; \
	fi
	@if [ -f "Gemfile" ]; then \
		echo "Installing gems from Gemfile..."; \
		bundle config set --local path 'vendor/bundle'; \
		bundle install; \
		echo -e "$(GREEN)✅ Ruby gems installed successfully$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  No Gemfile found - skipping gem installation$(NC)"; \
	fi

.PHONY: postgres
postgres: brew
	@echo "🐘 Installing PostgreSQL..."
	-@brew install postgresql@15
	-@brew services start postgresql@15

.PHONY: flutter
flutter: brew xcode-update
	@echo "🦋 Setting up Flutter development environment..."
	@echo "📦 Installing Flutter SDK..."
	-@brew install flutter
	@echo "🤖 Setting up Android development..."
	-@brew install --cask android-studio
	-@brew install android-sdk
	@echo "🔧 Configuring Android SDK paths..."
	@mkdir -p "$$HOME/Library/Android/sdk"
	@if [ -d "/opt/homebrew/share/android-sdk" ]; then \
		echo "Linking Android SDK..."; \
		ln -sf "/opt/homebrew/share/android-sdk" "$$HOME/Library/Android/sdk"; \
	fi
	@echo "📱 Installing Android SDK components..."
	-@sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.1"
	@echo "🍎 Setting up iOS development tools..."
	-@brew install cocoapods
	@echo "📦 Setting up CocoaPods with RVM..."
	-@gem install cocoapods
	@echo "🔧 Accepting Android licenses..."
	-@yes | flutter doctor --android-licenses
	@echo "🔍 Running Flutter doctor..."
	-@flutter doctor
	@echo ""
	@echo "✅ Flutter development environment setup complete!"
	@echo ""
	@echo "📋 Next steps:"
	@echo "  1. Open Android Studio and complete the setup wizard"
	@echo "  2. Create an Android Virtual Device (AVD) or connect a physical device"
	@echo "  3. Run 'flutter doctor' again to verify setup"
	@echo "  4. For iOS development, run 'xcodebuild -downloadPlatform iOS' (requires Xcode)"
	@echo "  5. Test with: flutter run -d chrome (web) or flutter run -d macos (desktop)"

.PHONY: github-tools
github-tools: brew
	@echo "🐙 Installing GitHub tools..."
	-@brew install gh
	-@brew install git-lfs
	-@brew install --cask github

.PHONY: xcode-setup
xcode-setup:
	@echo "🔧 Setting up Xcode configuration..."
	@echo "Installing Xcode if not present..."
	-@mas install 497799835 2>/dev/null || echo "Xcode already installed or not available via Mac App Store"
	@echo "Setting up Xcode user preferences..."
	@mkdir -p "${HOME}/Library/Developer/Xcode/UserData/FontAndColorThemes"
	@mkdir -p "${HOME}/Library/Developer/Xcode/UserData/KeyBindings"
	@if [ -f "${SETTINGS}/XCode/UserData/FontAndColorThemes/Solarized Dark.dvtcolortheme" ]; then \
		cp "${SETTINGS}/XCode/UserData/FontAndColorThemes/Solarized Dark.dvtcolortheme" \
		   "${HOME}/Library/Developer/Xcode/UserData/FontAndColorThemes/"; \
		echo "✅ Installed Solarized Dark color theme"; \
	fi
	@if [ -f "${SETTINGS}/XCode/UserData/KeyBindings/Default.idekeybindings" ]; then \
		cp "${SETTINGS}/XCode/UserData/KeyBindings/Default.idekeybindings" \
		   "${HOME}/Library/Developer/Xcode/UserData/KeyBindings/"; \
		echo "✅ Installed custom key bindings"; \
	fi
	@echo "Setting Solarized Dark as default theme..."
	-@defaults write com.apple.dt.Xcode DVTFontAndColorCurrentTheme "Solarized Dark.dvtcolortheme" 2>/dev/null || echo "⚠️  Could not set default theme (Xcode may need to be running)"
	@echo "Installing Xcode command line tools..."
	-@xcode-select --install 2>/dev/null || echo "Command line tools already installed"
	@echo ""
	@echo "🔄 Note: You may need to restart Xcode for theme changes to take effect"
	@echo "📝 To manually set the theme: Xcode → Settings → Themes → Select 'Solarized Dark'"

.PHONY: xcode-backup
xcode-backup:
	@bash "${ZSH}/bin/xcode-backup.sh"

.PHONY: vscode-backup
vscode-backup:
	@bash "${ZSH}/bin/vscode-backup.sh"

.PHONY: iterm-backup
iterm-backup:
	@bash "${ZSH}/bin/iterm-backup.sh"

.PHONY: iterm-setup
iterm-setup:
	@bash "${ZSH}/bin/iterm-setup.sh"

.PHONY: claude-setup
claude-setup:
	@bash "${ZSH}/bin/claude-setup.sh"

.PHONY: vscode-setup
vscode-setup:
	@echo "⚙️  Setting up VS Code configuration..."
	@echo "Installing VS Code if not present..."
	-@brew install --cask visual-studio-code
	@echo "Setting up VS Code user settings..."
	@mkdir -p "${HOME}/Library/Application Support/Code/User"
	@if [ -d "${SETTINGS}/VSCode/User" ]; then \
		echo "Copying VS Code settings from repository..."; \
		cp -r "${SETTINGS}/VSCode/User/"* "${HOME}/Library/Application Support/Code/User/"; \
		echo "✅ VS Code settings applied from ${SETTINGS}/VSCode/User/"; \
	else \
		echo "⚠️  No VS Code settings found in repository to apply"; \
	fi
	@if [ -f "${SETTINGS}/VSCode/extensions.txt" ]; then \
		echo "Installing VS Code extensions from list..."; \
		while read extension; do \
			if [ -n "$$extension" ]; then \
				code --install-extension "$$extension" 2>/dev/null || echo "⚠️  Could not install extension: $$extension"; \
			fi; \
		done < "${SETTINGS}/VSCode/extensions.txt"; \
		echo "✅ VS Code extensions installation completed"; \
	else \
		echo "⚠️  No extensions list found to install"; \
	fi
	@echo ""
	@echo "🔄 Note: You may need to restart VS Code for all settings to take effect"

# =============================================================================
# macOS APPLICATIONS
# =============================================================================

.PHONY: mac-apps
mac-apps: github-tools xcode-setup
	@echo "🖥️  Installing macOS applications..."
	@for cask in $(MAC_APPS_CASK); do \
		brew install --cask $$cask || echo "⚠️  Could not install $$cask (may already be installed)"; \
	done
	@echo -e "$(BOLD)$(GREEN)✅ macOS applications installation complete$(NC)"

# =============================================================================
# SYSTEM SETTINGS
# =============================================================================

.PHONY: mac-settings
mac-settings: macos-optimize

# Optimize macOS system settings for developers
.PHONY: macos-optimize
macos-optimize:
	@echo -e "$(MAGENTA)⚡ Optimizing macOS system settings...$(NC)"
	@if [ -f "bin/macos-optimize.sh" ]; then \
		echo -e "$(CYAN)🚀 Running macOS optimization script...$(NC)"; \
		bash bin/macos-optimize.sh; \
		echo -e "$(BOLD)$(GREEN)✅ macOS optimization complete$(NC)"; \
	else \
		echo -e "$(RED)❌ macOS optimization script not found at bin/macos-optimize.sh$(NC)"; \
		return 1; \
	fi

# Optimize macOS settings specifically for OLED displays
.PHONY: macos-oled-optimize
macos-oled-optimize:
	@echo -e "$(MAGENTA)🖥️  Optimizing macOS for OLED displays...$(NC)"
	@if [ -f "bin/macos-oled-optimize.sh" ]; then \
		echo -e "$(CYAN)🚀 Running OLED optimization script...$(NC)"; \
		bash bin/macos-oled-optimize.sh; \
		echo -e "$(BOLD)$(GREEN)✅ OLED optimization complete$(NC)"; \
	else \
		echo -e "$(RED)❌ OLED optimization script not found at bin/macos-oled-optimize.sh$(NC)"; \
		return 1; \
	fi

.PHONY: setup-hooks
setup-hooks:
	@echo -e "$(MAGENTA)⚙️  Setting up wake and sleep hooks...$(NC)"
	@if [ -f "bin/setup-hooks.sh" ]; then \
		echo -e "$(CYAN)🚀 Running hooks setup script...$(NC)"; \
		bash bin/setup-hooks.sh; \
		echo -e "$(BOLD)$(GREEN)✅ Hooks setup complete$(NC)"; \
	else \
		echo -e "$(RED)❌ Hooks setup script not found at bin/setup-hooks.sh$(NC)"; \
		return 1; \
	fi

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
	@echo -e "$(CYAN)🖥️  Restoring iTerm2 settings...$(NC)"
	@if [ -f "bin/iterm-setup.sh" ]; then \
		bash "bin/iterm-setup.sh"; \
		echo -e "$(GREEN)✅ iTerm2 settings restored$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  iTerm2 setup script not found$(NC)"; \
	fi

.PHONY: restore-vscode
restore-vscode: vscode-setup

.PHONY: restore-xcode  
restore-xcode: xcode-setup

.PHONY: restore-sublime
restore-sublime:
	@echo -e "$(CYAN)📝 Restoring Sublime Text settings...$(NC)"
	@if [ -d "$(SETTINGS)/Sublime3" ]; then \
		echo "Setting up Sublime Text 3 configuration..."; \
		mkdir -p "${HOME}/Library/Application Support/Sublime Text 3/Packages/User"; \
		if [ -f "$(SETTINGS)/Sublime3/Preferences.sublime-settings" ]; then \
			cp "$(SETTINGS)/Sublime3/Preferences.sublime-settings" \
			   "${HOME}/Library/Application Support/Sublime Text 3/Packages/User/"; \
			echo -e "$(GREEN)✅ Sublime Text preferences restored$(NC)"; \
		fi; \
		if [ -d "$(SETTINGS)/Sublime3/User" ]; then \
			cp -r "$(SETTINGS)/Sublime3/User/"* \
			      "${HOME}/Library/Application Support/Sublime Text 3/Packages/User/"; \
			echo -e "$(GREEN)✅ Sublime Text user settings restored$(NC)"; \
		fi; \
	else \
		echo -e "$(YELLOW)⚠️  Sublime Text settings not found in repository$(NC)"; \
	fi

.PHONY: restore-dock
restore-dock:
	@echo -e "$(CYAN)🔵 Restoring macOS Dock settings...$(NC)"
	@if [ -f "$(SETTINGS)/dock.plist" ]; then \
		echo "Restoring Dock configuration..."; \
		cp "$(SETTINGS)/dock.plist" "${HOME}/Library/Preferences/com.apple.dock.plist"; \
		killall Dock 2>/dev/null || true; \
		echo -e "$(GREEN)✅ Dock settings restored and reloaded$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  Dock settings file not found$(NC)"; \
	fi

.PHONY: restore-claude
restore-claude:
	@echo -e "$(CYAN)🤖 Setting up Claude Code...$(NC)"
	@if [ -f "bin/claude-setup.sh" ]; then \
		bash "bin/claude-setup.sh"; \
		echo -e "$(GREEN)✅ Claude Code setup complete$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  Claude setup script not found$(NC)"; \
	fi

.PHONY: restore-gemini gemini-setup
restore-gemini: gemini-setup

gemini-setup:
	@echo -e "$(CYAN)🤖 Setting up Gemini CLI...$(NC)"
	@echo -e "$(BLUE)📁 Creating ~/.gemini directory...$(NC)"
	@mkdir -p ~/.gemini
	@echo -e "$(BLUE)🔗 Creating symlink for settings.json...$(NC)"
	@ln -sf "${SETTINGS}/Gemini/settings.json" ~/.gemini/settings.json
	@echo -e "$(GREEN)✅ Gemini CLI settings symlinked from Settings/Gemini/$(NC)"
	@if [ -f "bin/gemini-setup.sh" ]; then \
		echo -e "$(BLUE)🚀 Running additional Gemini setup script...$(NC)"; \
		bash "bin/gemini-setup.sh"; \
	fi
	@echo -e "$(GREEN)✅ Gemini CLI setup complete$(NC)"

.PHONY: claude-gemini-setup
claude-gemini-setup:
	@echo -e "$(CYAN)🤖 Setting up Claude-Gemini integration...$(NC)"
	@echo -e "$(BLUE)📦 Ensuring gemini-claude-proxy submodule is initialized...$(NC)"
	@git submodule update --init --recursive gemini-claude-proxy
	@echo -e "$(BLUE)🐍 Setting up Python virtual environment...$(NC)"
	@cd gemini-claude-proxy && python3.11 -m venv .venv
	@echo -e "$(BLUE)📦 Installing Python dependencies...$(NC)"
	@cd gemini-claude-proxy && .venv/bin/pip install -r requirements.txt
	@echo -e "$(BLUE)⚙️  Setting up environment configuration...$(NC)"
	@if [ -f "gemini-claude-proxy/.env.example" ]; then \
		cp gemini-claude-proxy/.env.example gemini-claude-proxy/.env; \
		echo -e "$(GREEN)✅ Created .env from .env.example$(NC)"; \
	fi
	@echo -e "$(YELLOW)⚠️  Please add your Gemini API key to gemini-claude-proxy/.env$(NC)"
	@echo -e "$(BLUE)ℹ️  Or use: setup-gemini-key 'your-key-here'$(NC)"
	@echo -e "$(GREEN)✅ Claude-Gemini integration setup complete$(NC)"
	@echo -e "$(CYAN)🚀 Use 'claude-gemini' command to run Claude Code with Gemini API$(NC)"

.PHONY: restore-ruby-config
restore-ruby-config:
	@echo -e "$(CYAN)💎 Restoring Ruby configuration...$(NC)"
	@if [ -f "$(SETTINGS)/irbrc" ]; then \
		cp "$(SETTINGS)/irbrc" "${HOME}/.irbrc"; \
		echo -e "$(GREEN)✅ IRB configuration restored$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  IRB configuration file not found$(NC)"; \
	fi
	@if [ -f "$(SETTINGS)/gemrc" ]; then \
		cp "$(SETTINGS)/gemrc" "${HOME}/.gemrc"; \
		echo -e "$(GREEN)✅ Gem configuration restored$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  Gem configuration file not found$(NC)"; \
	fi
	@if [ -f "$(SETTINGS)/ctags_for_ruby" ]; then \
		mkdir -p "${USER_BIN}"; \
		cp "$(SETTINGS)/ctags_for_ruby" "${USER_BIN}/ctags_for_ruby"; \
		chmod +x "${USER_BIN}/ctags_for_ruby"; \
		echo -e "$(GREEN)✅ Ruby ctags configuration restored$(NC)"; \
	else \
		echo -e "$(YELLOW)⚠️  Ruby ctags file not found$(NC)"; \
	fi

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
	@git submodule update --init --recursive

# =============================================================================
# GIT CONFIGURATION
# =============================================================================

.PHONY: github-setup
github-setup:
	@echo "🐙 Configuring Git..."
	@echo "👤 Setting user information..."
	@git config --global --replace-all user.name "Hemant Verma"
	@git config --global --replace-all user.email "fameoflight@gmail.com"
	@echo "📝 Setting editors..."
	@git config --global --replace-all core.editor "code --wait"
	@git config --global --replace-all sequence.editor "code --wait"
	@echo "🚀 Setting push behavior..."
	@git config --global --replace-all push.default current
	@git config --global --replace-all push.recurseSubmodules on-demand
	@echo "🚫 Setting ignore file..."
	@git config --global --replace-all core.excludesfile "${SETTINGS}/.git_ignore"
	
	@echo "⚡ Setting up Git aliases..."
	@git config --global --replace-all alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
	@git config --global --replace-all alias.cp "cherry-pick"
	@git config --global --replace-all alias.ri "rebase --interactive"
	@git config --global --replace-all alias.rc "rebase --continue"
	@git config --global --replace-all alias.rb "rebase --abort"
	@git config --global --replace-all alias.co "checkout"
	@git config --global --replace-all alias.st "status"
	@git config --global --replace-all alias.pushf "push --force-with-lease"
	@git config --global --replace-all alias.master "checkout master"
	@git config --global --replace-all alias.main "checkout main"
	@git config --global --replace-all alias.url "remote show origin"
	@git config --global --replace-all alias.root "rev-parse --show-toplevel"
	
	@git config --global --replace-all alias.sshow "!f() { git stash show stash^{/$$*} -p; }; f"
	@git config --global --replace-all alias.sapply "!f() { git stash apply stash^{/$$*}; }; f"
	
	@echo "🔧 Configuring default editor associations..."
	@if command -v duti >/dev/null 2>&1; then \
		echo "📝 Setting VS Code as default for code files..."; \
		duti -s com.microsoft.VSCode .rb all; \
		duti -s com.microsoft.VSCode .js all; \
		duti -s com.microsoft.VSCode .json all; \
		duti -s com.microsoft.VSCode .md all; \
	fi

# =============================================================================
# MAINTENANCE
# =============================================================================

.PHONY: update clean
update:
	@echo "🔄 Updating repository and submodules..."
	@echo "🔗 Setting up tracking branch if needed..."
	@git branch --set-upstream-to=origin/master master 2>/dev/null || echo "✅ Branch tracking already set up"
	@echo "⬇️  Pulling latest changes..."
	@git pull origin master
	@echo "📦 Updating submodules..."
	@git submodule update --remote --merge
	@echo "🍺 Updating Homebrew packages..."
	@if command -v brew >/dev/null 2>&1; then brew update && brew upgrade; fi

clean:
	@echo "🧹 Cleaning up..."
	@echo "🗑️  Removing backup files..."
	@find . -name "*.bak" -delete
	@echo "🗑️  Removing .DS_Store files..."
	@find . -name ".DS_Store" -delete
	@echo "🍺 Cleaning Homebrew cache..."
	@if command -v brew >/dev/null 2>&1; then brew cleanup; fi

# =============================================================================
# REPOSITORY MAINTENANCE
# =============================================================================

.PHONY: find-orphans
find-orphans:
	@echo "🔍 Finding orphaned targets in Makefile..."
	@bundle exec ruby bin/internal-find-orphaned-targets.rb

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

# =============================================================================
# HOMEBREW TROUBLESHOOTING - Fix common Homebrew issues
# =============================================================================

.PHONY: fix-brew fix-brew-only brew-doctor brew-clean brew-relink xcode-update
fix-brew: fix-permissions brew-doctor brew-update brew-relink xcode-update
	@echo -e "$(BOLD)$(GREEN)✅ Homebrew troubleshooting complete$(NC)"

# Fix Homebrew without changing system permissions (recommended)
fix-brew-only: brew-doctor brew-update brew-relink xcode-update
	@echo -e "$(BOLD)$(GREEN)✅ Homebrew troubleshooting complete (no permission changes)$(NC)"

# Run Homebrew's built-in diagnostic tool
brew-doctor:
	@echo -e "$(BLUE)🩺 Running Homebrew diagnostics...$(NC)"
	@if command -v brew >/dev/null 2>&1; then \
		brew doctor; \
	else \
		echo -e "$(RED)❌ Homebrew not found, reinstalling...$(NC)"; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi

# Clean incomplete Homebrew processes and cache
brew-clean:
	@echo -e "$(CYAN)🧹 Cleaning incomplete Homebrew processes and cache...$(NC)"
	@if command -v brew >/dev/null 2>&1; then \
		echo -e "$(BLUE)🔍 Checking for incomplete downloads...$(NC)"; \
		ps aux | grep -i brew | grep -v grep | head -5; \
		echo -e "$(BLUE)🧹 Cleaning up Homebrew cache...$(NC)"; \
		brew cleanup; \
		echo -e "$(BLUE)🔧 Cleaning up services...$(NC)"; \
		brew services cleanup; \
		echo -e "$(GREEN)✅ Homebrew cleanup complete$(NC)"; \
	else \
		echo -e "$(RED)❌ Homebrew not available$(NC)"; \
	fi

# Fix broken package symlinks
brew-relink:
	@echo -e "$(CYAN)🔗 Relinking Homebrew packages...$(NC)"
	@if command -v brew >/dev/null 2>&1; then \
		brew link --overwrite $$(brew list --formula) || echo -e "$(YELLOW)⚠️  Some packages may already be linked$(NC)"; \
	else \
		echo -e "$(RED)❌ Homebrew not available for relinking$(NC)"; \
	fi

# Install or update Xcode and Command Line Tools
xcode-update:
	@echo "🛠️  Managing Xcode installation..."
	@if command -v mas >/dev/null 2>&1; then \
		if ! mas list | grep -q "497799835"; then \
			echo "📥 Installing Xcode via App Store..."; \
			mas install 497799835 2>/dev/null || echo "⚠️  Xcode install failed - try manually from App Store"; \
		else \
			echo "🔄 Updating Xcode via App Store..."; \
			mas upgrade 497799835 2>/dev/null || echo "⚠️  Xcode update failed - try manually from App Store"; \
		fi; \
	else \
		echo "⚠️  mas not available - install with 'brew install mas'"; \
	fi
	@echo "🔧 Updating Xcode Command Line Tools..."
	@softwareupdate --install --agree-to-license "Command Line Tools" 2>/dev/null || echo "ℹ️  Command Line Tools up to date or not available"

fix-permissions:
	@echo "🔒 Fixing permissions..."
	@if [ -d "/usr/local" ] && [ -w "/usr/local" ]; then \
		echo "Fixing /usr/local permissions..."; \
		sudo chown -R $(whoami):admin /usr/local 2>/dev/null || echo "⚠️  Could not fix /usr/local permissions (may not be needed)"; \
		sudo chmod -R g+w /usr/local 2>/dev/null || true; \
	else \
		echo "ℹ️  /usr/local not writable or doesn't exist (normal on Apple Silicon)"; \
	fi
	@if [ -d "/opt/homebrew" ]; then \
		echo "Fixing /opt/homebrew permissions..."; \
		sudo chown -R $(whoami):admin /opt/homebrew || echo "⚠️  Could not fix /opt/homebrew permissions"; \
		sudo chmod -R g+w /opt/homebrew || true; \
	else \
		echo "ℹ️  /opt/homebrew not found"; \
	fi

doctor:
	@echo "🩺 Running system diagnostics..."
	@echo "🖥️  Platform: $(UNAME)"
	@echo "🐚 Shell: $$SHELL"
	@echo "⚙️  ZSH Config: $(ZSH_CONFIG)"
	@echo "🔍 Checking tools:"
	@if command -v brew >/dev/null 2>&1; then echo "  🍺 Homebrew: ✅"; else echo "  🍺 Homebrew: ❌"; fi
	@if command -v git >/dev/null 2>&1; then echo "  🐙 Git: ✅"; else echo "  🐙 Git: ❌"; fi
	@if command -v python3 >/dev/null 2>&1; then echo "  🐍 Python: ✅"; else echo "  🐍 Python: ❌"; fi
	@if command -v node >/dev/null 2>&1; then echo "  🟢 Node.js: ✅"; else echo "  🟢 Node.js: ❌"; fi

# =============================================================================
# UTILITIES
# =============================================================================

.prompt-yesno:
	@exec 9<&0 0</dev/tty; \
	echo "$(message) [Y/n]:"; \
	[[ -z $$FOUNDATION_NO_WAIT ]] && read -r yn || yn="y"; \
	exec 0<&9 9<&-; \
	case $$yn in [Nn]*) echo "Cancelled" >&2 && exit 1;; *) echo "Proceeding..." >&2;; esac
