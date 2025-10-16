#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/archive/script_base'
require_relative '../lib/archive/core_utilities/system'

# Installs Homebrew packages for different development categories.
class SetupDevTools < ScriptBase
  PACKAGES = {
    'core-utils' => {
      title: 'core utilities',
      formulae: %w[tree wget watch ripgrep fd bat eza htop jq yq]
    },
    'dev-utils' => {
      title: 'development utilities',
      formulae: %w[duti fswatch ssh-copy-id rmtrash sleepwatcher pkgconf dockutil librsvg]
    },
    'modern-cli' => {
      title: 'modern CLI tools',
      formulae: %w[zoxide starship fzf claude-code gemini-cli yt-dlp]
    },
    'editors' => {
      title: 'editors and IDEs',
      casks: %w[visual-studio-code zed lm-studio],
      formulae: %w[vim neovim]
    }
  }.freeze

  def script_emoji; '🛠️'; end
  def script_title; 'Setup Development Tools'; end
  def script_description; 'Installs Homebrew formulae and casks for development.'; end
  def script_arguments; '<category>'; end

  def run
    category = args.first || 'all'
    log_banner("Setup Development Tools: #{category}")

    validate_category(category)

    categories_to_install = (category == 'all') ? PACKAGES.keys : [category]
    categories_to_install.each do |cat|
      install_category(cat)
    end

    show_completion('Development tools setup')
  end

  private

  def install_category(category_key)
    config = PACKAGES[category_key]
    log_section("Installing #{config[:title]}")

    install_formulae(config[:formulae])
    install_casks(config[:casks])
    run_post_install_hooks(category_key)
  end

  def install_formulae(formulae)
    return unless formulae&.any?

    log_progress("Installing formulae: #{formulae.join(' ')}")
    # NOTE: SCRIPTS.md mentions install_formulae, but looping is safer.
    formulae.each do |pkg|
      System::Homebrew.install_formula(pkg, quiet: true)
    end
  end

  def install_casks(casks)
    return unless casks&.any?

    log_progress("Installing casks: #{casks.join(' ')}")
    casks.each do |cask|
      System::Homebrew.install_cask(cask, quiet: true)
    end
  end

  def run_post_install_hooks(category_key)
    case category_key
    when 'modern-cli'
      log_info('Configuring Claude CLI auto-updates...')
      System.execute('claude config set autoUpdates false',
                     description: 'Disable Claude auto-updates',
                     quiet: true)
    end
  end

  def validate_category(category)
    return if category == 'all' || PACKAGES.key?(category)

    log_error "Invalid category: '#{category}'"
    show_usage
    exit 1
  end

  def show_usage
    puts "\nUsage: #{script_name} [category]"
    puts "\nAvailable categories:"
    PACKAGES.each do |key, config|
      puts "  #{key.ljust(12)} - Installs #{config[:title]}"
    end
    puts "  all".ljust(12) + " - Installs all categories (default)"
  end
end

SetupDevTools.execute if __FILE__ == $0
