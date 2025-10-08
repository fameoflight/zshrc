# ZSH & Development Environment Configuration

This repository contains a comprehensive, modular ZSH configuration designed for a powerful and efficient development workflow. It originated from Sebastian Tramp's ZSH configuration and has been heavily customized by Hemant Verma.

The setup is highly automated, using a `Makefile` for installation, system configuration, and management of application settings.

## ✨ Features

- **Modular Design**: Configuration is split into logical files (`aliases.zsh`, `functions.zsh`, `git.zsh`, etc.) for easy management.
- **Powerful Scripting System**: A collection of custom Ruby and Bash scripts, accessible via ZSH functions or `make` targets, to automate common tasks.
- **Automated Setup**: A `Makefile` provides a simple interface for initial installation, setup for macOS and Linux, and ongoing maintenance.
- **AI-Powered Workflow**: Seamless integration for AI tools like Claude and Gemini, with helper functions and automated setup.
- **Platform-Aware**: Automatically detects and loads specific configurations for macOS (`darwin.zsh`) and Linux (`linux.zsh`).
- **Extensive Git Integration**: Includes a rich set of aliases (`lg`, `cp`, `ri`, etc.), push behavior defaults, and editor configurations.
- **Syntax Highlighting**: Integrates `zsh-syntax-highlighting` as a Git submodule for real-time command feedback.
- **Application Settings Management**: Backup and restore configurations for tools like VS Code, Xcode, iTerm2, and more.
- **Rich Terminal Experience**: Enhanced with emojis and a consistent color scheme for better readability, all managed by a centralized logging system.

## 🚀 Installation

### Prerequisites

- `git`: To clone the repository.
- `zsh`: As the target shell.
- `make`: To run the automated setup commands.
- **macOS**: `Xcode Command Line Tools` are required. The setup will attempt to install them.

### 1. Clone the Repository

Clone this repository to your home directory, preferably to `~/zshrc`.

```bash
git clone https://github.com/your-username/your-repo-name.git ~/zshrc
cd ~/zshrc
```

### 2. Run the Installer

The `Makefile` handles the entire setup process.

#### Full Installation (Recommended)

This command creates the necessary symlinks for ZSH and Bash, installs external dependencies (submodules), and sets up required directories.

```bash
make install
```

#### Complete macOS Setup

For macOS users, the `make mac` target provides a comprehensive setup that includes:
- Installing Homebrew and essential packages.
- Installing development tools and language runtimes (Python, Ruby).
- Configuring macOS system settings for development.
- Restoring application settings from the `Settings/` directory.

```bash
make mac
```

After installation, **restart your terminal** to load the new configuration.

## 🏗️ Architecture

The configuration is loaded in a specific order to ensure dependencies are met and settings can be overridden correctly.

### Core Configuration Flow

1.  `logging.zsh`: Centralized logging functions (loaded first for universal access).
2.  `environment.zsh`: Environment variables and PATH management.
3.  `options.zsh`: ZSH shell options and settings.
4.  `prompt.zsh`: Command prompt configuration.
5.  `functions.zsh`: Custom shell functions and key bindings.
6.  `aliases.zsh`: Command aliases and suffix handlers.
7.  **Platform-specific files**: `darwin.zsh` (macOS) or `linux.zsh`.
8.  **Application-specific files**: `git.zsh`, `rails.zsh`, `claude.zsh`, etc.
9.  `completion.zsh`: Tab completion setup.
10. `private.zsh`: For user-specific private configurations (this file is not tracked by Git).

## 🛠️ Custom Scripts System

A key feature of this repository is its powerful three-tier scripting system, primarily built with Ruby.

- **To see all available scripts and their descriptions, run `make list-scripts`**.

### Script Tiers

1.  **ZSH Utility Functions**: Interactive scripts for daily use, available directly in the shell.
    - `calibre-update`: Updates the Calibre e-book manager.
    - `stack-monitors`: Configures a stacked external monitor setup on macOS.
    - `merge-pdf`: Merges multiple PDF files into a single document.
    - `uninstall-app`: A comprehensive application uninstaller for macOS.

2.  **Setup/Backup Scripts (Makefile Only)**: Scripts for system configuration, backups, and one-time setup tasks. These are only accessible via `make` targets to prevent accidental execution.
    - `make macos-optimize`: Optimizes macOS system settings for developers.
    - `make xcode-backup`: Backs up Xcode themes, key bindings, and settings.
    - `make vscode-backup`: Backs up VS Code settings and extensions list.
    - `make iterm-setup`: Restores iTerm2 settings from the repository.

3.  **Repository Maintenance Scripts (Makefile Only)**: Internal scripts for maintaining the repository itself.
    - `make find-orphans`: Finds and reports Makefile targets that don't correspond to a script.

## 🤖 AI Tool Integration

This setup includes first-class support for AI command-line tools.

### Setup

API keys are optional but required for full functionality. They can be stored in a `private.env` file in the repository root. Helper functions are provided to manage them:

```bash
# For Claude
setup-claude-key "sk-ant-api03-your-key-here"

# For Gemini
setup-gemini-key "AIzaSyYour-gemini-key-here"
```

### Available Functions & Aliases

- `claude` / `cc`: Wrapper for the Claude Code CLI.
- `gemini-cli` / `gg`: Wrapper for the Gemini CLI.

## ⚙️ Makefile Usage

The `Makefile` is the central hub for managing this configuration.

### Common Commands

- `make help`: Displays a list of all available targets and their descriptions.
- `make install`: Installs the shell configuration.
- `make mac`: Runs the full macOS setup.
- `make update`: Pulls the latest changes from the repository and updates submodules.
- `make app-settings`: Restores settings for all supported applications (iTerm, VS Code, etc.).
- `make list-scripts`: Shows all custom scripts available.

## Credits

- Originally based on the ZSH configuration of **Sebastian Tramp**.
- Customized and extended by **Hemant Verma** (<fameoflight@gmail.com>).
