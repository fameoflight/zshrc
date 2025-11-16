#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Create private repositories from public templates interactively
# @tags: automation, interactive, template

require_relative '../../.common/interactive_script_base'

# Interactive Git Template Manager
# Automates the process of creating private repositories from public templates
class GitTemplate < InteractiveScriptBase
  def script_emoji; '🔧'; end
  def script_title; 'Git Template Manager'; end
  def script_description; 'Interactive tool to create private repos from public templates'; end
  def script_arguments; '[OPTIONS]'; end

  def add_custom_options(opts)
    opts.on('-l', '--list', 'List all git repositories in workspace') do
      @options[:list] = true
    end

    opts.on('-d', '--depth NUMBER', Integer, 'Search depth for git repositories (default: unlimited)') do |depth|
      @options[:depth] = depth
    end

    opts.on('-w', '--workspace PATH', 'Workspace path (default: ~/workspace)') do |path|
      @options[:workspace] = path
    end

    opts.on('--workflow', 'Show daily workflow guide') do
      @options[:workflow] = true
    end
  end

  def run
    log_banner(script_title)

    if @options[:list]
      list_repositories
      show_completion(script_title)
      return
    end

    if @options[:workflow]
      show_workflow_guide
      show_completion(script_title)
      return
    end

    start_interactive_mode
  end

  def menu_options
    [
      menu_option("🔍", "Find and select template repo", :select_template),
      menu_option("📋", "Show daily workflow guide", :workflow),
      menu_option("📁", "List all git repositories", :list_repos),
      help_option(:help),
      refresh_option(:refresh)
    ]
  end

  def handle_menu_choice(choice)
    case choice
    when :select_template
      select_and_setup_template
    when :workflow
      show_workflow_guide
    when :list_repos
      list_repositories
    when :refresh
      @repositories = nil
      log_success "Repository cache cleared"
    when :help
      show_help
    else
      log_warning "Unknown choice: #{choice}"
    end
  end

  private

  def find_git_repositories
    return @repositories if @repositories

    workspace_path = @options[:workspace] || File.expand_path('~/workspace')
    max_depth = @options[:depth] || nil

    log_info "Searching for git repositories in: #{workspace_path}"
    log_progress "Scanning directories..."

    @repositories = []

    begin
      if max_depth
        # Limited depth search
        (1..max_depth).each do |depth|
          pattern = "#{workspace_path}#{'/*' * depth}/.git"
          Dir.glob(pattern).each do |git_dir|
            repo_path = File.dirname(git_dir)
            @repositories << get_repo_info(repo_path) if File.directory?(git_dir)
          end
        end
      else
        # Unlimited depth search
        Dir.glob("#{workspace_path}/**/.git").each do |git_dir|
          repo_path = File.dirname(git_dir)
          @repositories << get_repo_info(repo_path) if File.directory?(git_dir)
        end
      end
    rescue StandardError => e
      log_error "Error searching repositories: #{e.message}"
    end

    @repositories.sort_by! { |repo| repo[:name].downcase }
    log_success "Found #{@repositories.length} git repositories"
    @repositories
  end

  def get_repo_info(repo_path)
    name = File.basename(repo_path)
    {
      name: name,
      path: repo_path,
      remote_url: get_remote_url(repo_path),
      branch: get_current_branch(repo_path),
      last_modified: File.mtime(repo_path)
    }
  end

  def get_remote_url(repo_path)
    Dir.chdir(repo_path) do
      result = `git config --get remote.origin.url 2>/dev/null`.strip
      result.empty? ? 'No remote' : result
    end
  rescue StandardError
    'Unknown'
  end

  def get_current_branch(repo_path)
    Dir.chdir(repo_path) do
      result = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      result.empty? ? 'unknown' : result
    end
  rescue StandardError
    'unknown'
  end

  def select_and_setup_template
    repositories = find_git_repositories

    if repositories.empty?
      log_error "No git repositories found in workspace"
      log_info "Try specifying a different workspace with --workspace PATH"
      return
    end

    # Interactive repository selection
    repo_choices = repositories.map do |repo|
      display_text = "#{repo[:name]} (#{repo[:remote_url]})"
      { name: display_text, value: repo }
    end

    selected_repo = interactive_select(
      "Select template repository:",
      repo_choices
    )

    return unless selected_repo

    setup_template_workflow(selected_repo)
  end

  def setup_template_workflow(template_repo)
    log_section "Template Setup Workflow"
    puts
    log_info "Selected template: #{template_repo[:name]}"
    log_info "Path: #{template_repo[:path]}"
    log_info "Remote: #{template_repo[:remote_url]}"
    puts

    # Get user inputs
    app_name = ask_string("Enter name for your new app:", required: true)
    github_username = ask_string("Enter your GitHub username:", required: true)

    puts
    log_section "Setup Configuration"
    puts "Template: #{template_repo[:name]}"
    puts "New app name: #{app_name}"
    puts "GitHub username: #{github_username}"
    puts

    return unless confirm_action("Proceed with this configuration?")

    execute_setup_process(template_repo, app_name, github_username)
  end

  def execute_setup_process(template_repo, app_name, github_username)
    workspace = File.expand_path('~/workspace')

    begin
      # Step 1: Create bare clone
      log_step 1, "Creating bare clone of template repository"
      bare_clone_cmd = "git clone --bare #{template_repo[:remote_url]}"
      success = execute_cmd_in_dir?(bare_clone_cmd, workspace, description: "Creating bare clone")

      unless success
        log_error "Failed to create bare clone"
        return
      end

      bare_repo_dir = File.join(workspace, "#{template_repo[:name]}.git")
      log_success "Bare clone created: #{bare_repo_dir}"

      # Step 2: Handle private repository creation
      log_step 2, "Creating private repository on GitHub"
      private_repo_url = handle_private_repo_creation(app_name, github_username)

      unless private_repo_url
        log_error "Private repository setup cancelled"
        cleanup_bare_clone(bare_repo_dir)
        return
      end

      # Step 3: Mirror push to private repo
      log_step 3, "Mirroring to private repository"
      mirror_cmd = "git push --mirror #{private_repo_url}"
      success = execute_cmd_in_dir?(mirror_cmd, bare_repo_dir, description: "Mirroring to private repo")

      unless success
        log_error "Failed to mirror to private repository"
        cleanup_bare_clone(bare_repo_dir)
        return
      end

      # Step 4: Clean up bare clone
      log_step 4, "Cleaning up bare clone"
      cleanup_bare_clone(bare_repo_dir)

      # Step 5: Clone private repository
      log_step 5, "Cloning private repository"
      app_dir = File.join(workspace, app_name)
      clone_cmd = "git clone #{private_repo_url} #{app_dir}"
      success = execute_cmd_in_dir?(clone_cmd, workspace, description: "Cloning private repository")

      unless success
        log_error "Failed to clone private repository"
        return
      end

      # Step 6: Add template as upstream remote
      log_step 6, "Adding template as upstream remote"
      upstream_cmd = "git remote add template #{template_repo[:remote_url]}"
      success = execute_cmd_in_dir?(upstream_cmd, app_dir, description: "Adding template remote")

      unless success
        log_warning "Failed to add template remote (you can add it manually later)"
      end

      # Step 7: Verify setup
      log_step 7, "Verifying repository setup"
      verify_cmd = "git remote -v"
      execute_cmd_in_dir?(verify_cmd, app_dir, description: "Showing remotes")

      puts
      log_success "✅ Template setup completed successfully!"
      log_info "Your new app is ready at: #{app_dir}"
      puts
      show_workflow_summary

    rescue StandardError => e
      log_error "Setup failed: #{e.message}"
    end
  end

  def handle_private_repo_creation(app_name, github_username)
    private_repo_url = "git@github.com:#{github_username}/#{app_name}.git"

    if command_exists?('gh')
      log_success "GitHub CLI detected! Creating private repository automatically..."

      create_cmd = "gh repo create #{github_username}/#{app_name} --private"
      success = execute_cmd?(create_cmd, description: "Creating private GitHub repository")

      if success
        log_success "Private repository created on GitHub"
        return private_repo_url
      else
        log_warning "Failed to create repository with GitHub CLI, falling back to manual setup"
      end
    end

    # Manual setup instructions
    log_warning "Please create the private repository manually:"
    puts
    puts "1. Go to: https://github.com/new"
    puts "2. Repository name: #{app_name}"
    puts "3. Set to Private"
    puts "4. Don't initialize with README, gitignore, or license"
    puts "5. Click 'Create repository'"
    puts
    puts "After creating the repository, your clone URL will be:"
    puts "  #{private_repo_url}"
    puts

    return nil unless ask_yes_no("Have you created the private repository?", default: true)

    private_repo_url
  end

  def cleanup_bare_clone(bare_repo_dir)
    if Dir.exist?(bare_repo_dir)
      log_info "Removing bare clone: #{bare_repo_dir}"
      FileUtils.rm_rf(bare_repo_dir)
    end
  end

  def command_exists?(command)
    system("which #{command} >/dev/null 2>&1")
  end

  def log_step(step_number, description)
    log_progress "Step #{step_number}: #{description}"
  end

  def show_workflow_guide
    log_section "Daily Workflow Guide"
    puts <<~WORKFLOW

      Normal Development (90% of your time)
      ──────────────────────────────────
      # Just work in master as usual
      git checkout master
      # ... make changes ...
      git add .
      git commit -m "Add private feature"
      git push origin master  # Goes to your private repo

      Contributing Back to Template (when you want)
      ──────────────────────────────────────────────

      Option A: Cherry-pick specific commits
      ──────────────────────────────────
      git checkout -b template/feature-name
      git cherry-pick <commit-hash>  # Pick the commit you want to share
      git push template template/feature-name
      # Create PR on GitHub from this branch

      Option B: Create feature branch from scratch
      ───────────────────────────────────────────
      git checkout master
      git checkout -b template/improvement
      # ... make ONLY the changes for template ...
      git commit -m "Add: template improvement"
      git push template template/improvement
      # Create PR on GitHub

      Syncing Template Updates into Your Private Repo
      ──────────────────────────────────────────────────

      # Pull updates from public template
      git fetch template
      git checkout master
      git merge template/master  # Or rebase if you prefer
      git push origin master

      Key Points
      ──────────
      ✅ Your master = your main branch - commit everything here, stays private
      ✅ Feature branches only for contributions - create when ready to share
      ✅ Cherry-pick is your friend - select specific improvements to contribute
      ✅ Two remotes:
         - origin → private repo (your daily work)
         - template → public template (pull updates, push contributions)

    WORKFLOW
  end

  def execute_cmd_in_dir?(command, directory, description: nil)
    # Execute command in specific directory without changing current working directory
    full_command = "cd #{directory} && #{command}"
    execute_cmd?(full_command, description: description)
  end

  def show_workflow_summary
    log_section "Quick Workflow Summary"
    puts "🔄 To pull template updates:"
    puts "   git fetch template && git merge template/master"
    puts
    puts "🤝 To contribute back:"
    puts "   git checkout -b template/your-feature"
    puts "   # make changes, then:"
    puts "   git push template template/your-feature"
    puts "   # Create PR on GitHub"
    puts
    puts "📚 For full workflow guide, run: #{script_name} --workflow"

    # Exit interactive mode after showing completion
    exit_interactive_mode
  end

  def list_repositories
    repositories = find_git_repositories

    if repositories.empty?
      log_warning "No git repositories found"
      return
    end

    log_section "Git Repositories"
    puts
    repositories.each_with_index do |repo, index|
      puts "#{(index + 1).to_s.rjust(3)}. #{repo[:name]}"
      puts "     Path: #{repo[:path]}"
      puts "     Remote: #{repo[:remote_url]}"
      puts "     Branch: #{repo[:branch]}"
      puts "     Modified: #{repo[:last_modified].strftime('%Y-%m-%d %H:%M')}"
      puts
    end
  end

  def show_help
    log_section "Help - Git Template Manager"
    puts <<~HELP

      #{script_title} - #{script_description}

      Usage: #{script_name} [OPTIONS]

      OPTIONS:
        -l, --list              List all git repositories in workspace
        -d, --depth NUMBER      Search depth for repositories (default: unlimited)
        -w, --workspace PATH    Workspace path (default: ~/workspace)
        --workflow              Show daily workflow guide
        --help                  Show this help message

      EXAMPLES:
        #{script_name}                          # Interactive mode
        #{script_name} --list                   # List all repositories
        #{script_name} --depth 2                # Search 2 levels deep
        #{script_name} --workflow               # Show workflow guide
        #{script_name} --workspace ~/projects    # Use different workspace

      WORKFLOW:
        1. Select a template repository from your workspace
        2. Enter your new app name and GitHub username
        3. Script creates private repo and sets up remotes automatically
        4. Start developing in your new private repository!

      The script preserves your SSH keys and handles GitHub CLI automatically
      when available, with clear fallback instructions when not.

    HELP
  end
end

# Execute with proper error handling
GitTemplate.execute if __FILE__ == $0