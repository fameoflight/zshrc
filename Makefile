# ZSH Configuration Setup Makefile
# Author: Hemant Verma <fameoflight@gmail.com>

# =============================================================================
# VARIABLES
# =============================================================================

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

# =============================================================================
# MAIN TARGETS
# =============================================================================

.PHONY: all help
all: detect-platform

help:
	@echo "ZSH Configuration Setup"
	@echo ""
	@echo "Main targets:"
	@echo "  all              - Auto-detect platform and run setup"
	@echo "  mac             - Complete macOS setup"
	@echo "  linux           - Complete Linux setup"
	@echo "  install         - Install shell configurations only"
	@echo ""
	@echo "Component targets:"
	@echo "  brew            - Install/update Homebrew"
	@echo "  dev-tools       - Install development tools"
	@echo "  python          - Install Python and Poetry"
	@echo "  ruby            - Install Ruby via RVM"
	@echo "  xcode-setup     - Setup Xcode themes and bindings"
	@echo "  vscode-setup    - Setup VS Code settings and extensions"
	@echo "  claude-setup    - Setup Claude Code settings from backup"
	@echo "  github-setup    - Configure Git settings"
	@echo ""
	@echo "Backup targets:"
	@echo "  xcode-backup    - Backup current Xcode settings"
	@echo "  vscode-backup   - Backup current VS Code settings"
	@echo "  claude-backup   - Backup current Claude Code settings"
	@echo ""
	@echo "Maintenance:"
	@echo "  update          - Update repository and submodules"
	@echo "  clean           - Clean up temporary files"

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

.PHONY: mac linux common
mac: check-requirements common brew dev-tools python ruby github-tools mac-apps mac-settings

linux: common linux-packages linux-settings

common: install github-setup

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

.PHONY: brew
brew:
	@echo "🍺 Setting up Homebrew..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "Homebrew already installed"; \
	fi
	@echo "Updating Homebrew..."
	-@brew update
	-@brew upgrade
	-@brew cleanup
	-@brew install zsh-completions
	-@brew install mas

.PHONY: linux-packages
linux-packages:
	@echo "📦 Installing Linux packages..."
	@sudo apt-get update
	@sudo apt-get install -y zsh git wget curl tree

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================

.PHONY: dev-tools
dev-tools: brew
	@echo "🛠️  Installing development tools..."
	# Core utilities
	-@brew install tree
	-@brew install wget
	-@brew install watch
	-@brew install ripgrep
	-@brew install fd
	-@brew install bat
	-@brew install exa
	-@brew install htop
	-@brew install jq
	-@brew install yq
	
	# Development utilities
	-@brew install duti
	-@brew install fswatch
	-@brew install ssh-copy-id
	-@brew install rmtrash
	
	# Modern CLI tools
	-@brew install zoxide
	-@brew install starship
	-@brew install fzf
	
	# Editors and IDEs
	-@brew install --cask visual-studio-code
	-@brew install --cask zed
	-@brew install vim
	-@brew install neovim

.PHONY: python
python: brew
	@echo "🐍 Setting up Python..."
	-@brew install python@3.11
	-@brew install pyenv
	@echo "Installing Poetry..."
	-@curl -sSL https://install.python-poetry.org | python3 -
	@echo "Installing common Python tools..."
	-@pip3 install --user black flake8 mypy pytest

.PHONY: ruby
ruby: brew
	@echo "💎 Setting up Ruby..."
	@if ! command -v rvm >/dev/null 2>&1; then \
		echo "Installing RVM..."; \
		\curl -sSL https://get.rvm.io | bash -s stable; \
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

.PHONY: postgres
postgres: brew
	@echo "🐘 Installing PostgreSQL..."
	-@brew install postgresql@15
	-@brew services start postgresql@15

.PHONY: github-tools
github-tools: brew
	@echo "🐙 Installing GitHub tools..."
	-@brew install gh
	-@brew install git-lfs
	-@brew install --cask github-desktop

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
	@bash "${ZSH}/scripts/xcode-backup.sh"

.PHONY: vscode-backup
vscode-backup:
	@bash "${ZSH}/scripts/vscode-backup.sh"

.PHONY: claude-backup
claude-backup:
	@bash "${ZSH}/scripts/claude-backup.sh"

.PHONY: claude-setup
claude-setup:
	@bash "${ZSH}/scripts/claude-setup.sh"

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
			fi \
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
	# Productivity
	-@brew install --cask iterm2
	-@brew install --cask rectangle
	-@brew install --cask raycast
	-@brew install --cask finder-toolbar
	
	# Development
	-@brew install --cask docker
	-@brew install --cask postman
	-@brew install --cask tableplus
	
	# Utilities
	-@brew install --cask the-unarchiver
	-@brew install --cask keka
	-@brew install --cask cleanmaster- cleaner
	
	# Optional (commented out - uncomment as needed)
	# -@brew install --cask slack
	# -@brew install --cask discord
	# -@brew install --cask zoom

# =============================================================================
# SYSTEM SETTINGS
# =============================================================================

.PHONY: mac-settings
mac-settings:
	@echo "⚙️  Configuring macOS settings..."
	@if [ -f "osx.sh" ]; then bash osx.sh; fi

.PHONY: linux-settings
linux-settings:
	@echo "⚙️  Configuring Linux settings..."
	@sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

.PHONY: install install-zsh install-bash install-externals
install: install-externals install-zsh install-bash
	@echo "✅ Shell configuration installation complete"

install-zsh:
	@echo "🐚 Installing ZSH configuration..."
	@rm -rf "${HOME}/.zshrc"
	@ln -sf ${HOME}/zshrc/zshrc ${HOME}/.zshrc
	@echo "Creating directories..."
	@mkdir -p ${XDG_CONFIG_HOME}
	@mkdir -p ${ZSH_CACHE}
	@mkdir -p ${ZSH_LOCAL}/bin
	@mkdir -p ${ZSH_LOCAL}/share
	@mkdir -p functions.d
	@echo "Creating zsh config symlink..."
	@if [ ! -L ${ZSH_CONFIG} ]; then ln -sf ${PWD} ${ZSH_CONFIG}; fi
	@echo "Creating autojump symlink..."
	@if [ -f "${PWD}/autojump/autojump" ] && [ ! -L ${ZSH_LOCAL}/bin/autojump ]; then \
		ln -sf ${PWD}/autojump/autojump ${ZSH_LOCAL}/bin/autojump; \
	fi
	@touch private.zsh

install-bash:
	@echo "🐚 Installing Bash configuration..."
	@if [ -f "${HOME}/.bashrc" ]; then mv ${HOME}/.bashrc ${PWD}/bashrc.bak; fi
	@rm -rf "${HOME}/.bashrc"
	@ln -sf ${PWD}/bashrc ${HOME}/.bashrc
	@rm -rf "${HOME}/.profile"
	@ln -sf ${PWD}/profile ${HOME}/.profile

install-externals:
	@echo "📦 Installing external dependencies..."
	@git submodule update --init --recursive

# =============================================================================
# GIT CONFIGURATION
# =============================================================================

.PHONY: github-setup
github-setup:
	@echo "🔧 Configuring Git..."
	@git config --global --replace-all user.name "Hemant Verma"
	@git config --global --replace-all user.email "fameoflight@gmail.com"
	@git config --global --replace-all core.editor "code --wait"
	@git config --global --replace-all sequence.editor "code --wait"
	@git config --global --replace-all push.default current
	@git config --global --replace-all push.recurseSubmodules on-demand
	@git config --global --replace-all core.excludesfile "${SETTINGS}/.git_ignore"
	
	@echo "Setting up Git aliases..."
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
	
	@echo "Configuring default editor associations..."
	@if command -v duti >/dev/null 2>&1; then \
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
	@echo "Setting up tracking branch if needed..."
	@git branch --set-upstream-to=origin/master master 2>/dev/null || echo "Branch tracking already set up"
	@git pull origin master
	@git submodule update --remote --merge
	@if command -v brew >/dev/null 2>&1; then brew update && brew upgrade; fi

clean:
	@echo "🧹 Cleaning up..."
	@find . -name "*.bak" -delete
	@find . -name ".DS_Store" -delete
	@if command -v brew >/dev/null 2>&1; then brew cleanup; fi

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

.PHONY: fix-brew fix-permissions doctor
fix-brew: fix-permissions
	@echo "🩺 Fixing Homebrew..."
	@if command -v brew >/dev/null 2>&1; then \
		brew doctor; \
		brew update; \
		brew cleanup; \
	fi

fix-permissions:
	@echo "🔒 Fixing permissions..."
	@if [ -d "/usr/local" ]; then \
		sudo chown -R $(whoami):admin /usr/local; \
		sudo chmod -R g+w /usr/local; \
	fi
	@if [ -d "/opt/homebrew" ]; then \
		sudo chown -R $(whoami):admin /opt/homebrew; \
		sudo chmod -R g+w /opt/homebrew; \
	fi

doctor:
	@echo "🩺 Running system diagnostics..."
	@echo "Platform: $(UNAME)"
	@echo "Shell: $$SHELL"
	@echo "ZSH Config: $(ZSH_CONFIG)"
	@if command -v brew >/dev/null 2>&1; then echo "Homebrew: ✅"; else echo "Homebrew: ❌"; fi
	@if command -v git >/dev/null 2>&1; then echo "Git: ✅"; else echo "Git: ❌"; fi
	@if command -v python3 >/dev/null 2>&1; then echo "Python: ✅"; else echo "Python: ❌"; fi
	@if command -v node >/dev/null 2>&1; then echo "Node.js: ✅"; else echo "Node.js: ❌"; fi

# =============================================================================
# UTILITIES
# =============================================================================

.prompt-yesno:
	@exec 9<&0 0</dev/tty; \
	echo "$(message) [Y/n]:"; \
	[[ -z $$FOUNDATION_NO_WAIT ]] && read -r yn || yn="y"; \
	exec 0<&9 9<&-; \
	case $$yn in [Nn]*) echo "Cancelled" >&2 && exit 1;; *) echo "Proceeding..." >&2;; esac