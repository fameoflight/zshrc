# Git configuration and utility functions

# Branch utilities
git-check-branch() {
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local expected_branch="${1:-master}"

  if [[ "$current_branch" != "$expected_branch" ]]; then
    echo -e "${COLOR_RED}❌ Error: You are on '${COLOR_BOLD}${COLOR_YELLOW}$current_branch${COLOR_NC}${COLOR_RED}' branch, expected '${COLOR_BOLD}${COLOR_GREEN}$expected_branch${COLOR_NC}${COLOR_RED}'${COLOR_NC}"
    return 1
  fi
  log_success "On expected branch: $expected_branch"
}

git-setup-branch() {
  local branch=$(git rev-parse --abbrev-ref HEAD)
  git branch --set-upstream-to="origin/$branch" "$branch"
}

# Push/Pull utilities
git-push() {
  git-check-branch master || return 1
  git push origin
}

git-push-remote() {
  git-setup-branch
  local branch=$(git rev-parse --abbrev-ref HEAD)
  log_git_push "$branch to origin"
  git push --set-upstream origin "$branch" "$@"
  log_success "Push completed!"
}

git-pull-remote() {
  git-setup-branch
  local branch=$(git rev-parse --abbrev-ref HEAD)
  log_git_pull "$branch from origin"
  git pull origin "$branch" "$@"
  log_success "Pull completed!"
}

# File operations
git-move-file() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: git-move-file <destination_branch> <file>"
    echo "Move file from current branch to another branch"
    return 1
  fi

  local branch="$1"
  local file="$2"
  local temp_dir="/tmp/movefiles"
  local temp_file="$temp_dir/$(date +%s).tmp"
  local current_branch=$(git rev-parse --abbrev-ref HEAD)

  if [[ ! -f "$file" ]]; then
    echo "Error: File '$file' does not exist"
    return 1
  fi

  mkdir -p "$temp_dir"
  cp "$file" "$temp_file"

  git checkout "$branch" 2>/dev/null || git checkout -b "$branch"
  cp "$temp_file" "$file"

  git add "$file"
  git commit -m "Move $file from $current_branch to $branch"
  git checkout "$current_branch"
  
  rmtrash -f "$temp_file"
  echo "File '$file' moved to branch '$branch'"
}

# Update operations
git-update-master() {
  local branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"

  git add -A .

  if [[ "$branch" != "master" ]]; then
    echo "Switching to master..."
    git checkout master
  fi

  echo "Fetching latest master..."
  git pull --rebase

  if [[ "$branch" != "master" ]]; then
    echo "Switching back to $branch..."
    git checkout "$branch"
  fi
}

git-update() {
  git pull && git submodule init && git submodule update && git submodule status
}

# Branch management
git-branch-by-commit() {
  git for-each-ref --format='%(committerdate) %09 %(refname:short)' refs/remotes | sort -k1,1 -k2,2
}

git-delete() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: git-delete <branch1> [branch2] ..."
    return 1
  fi

  for branch in "$@"; do
    echo "Deleting branch '$branch'..."
    git push origin ":$branch"
    git branch -D "$branch"
  done
}

git-clean-local-branches() {
  local repo_name=$(basename "$(git rev-parse --show-toplevel)")

  echo "Remove all local branches in '$repo_name' (except master)?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes)
        git branch | grep -v "master" | xargs -r git branch -D
        break
        ;;
      No)
        return 0
        ;;
    esac
  done
}

# Merge operations
git-merge() {
  if [[ $# -gt 2 ]]; then
    echo "Usage: git-merge [source_branch] [destination_branch]"
    echo "Defaults: source=current, destination=master"
    return 1
  fi

  if ! git diff-index --quiet HEAD --; then
    echo "Error: You have uncommitted changes"
    return 1
  fi

  local source_branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
  local dest_branch="${2:-master}"

  echo "Merging '$source_branch' into '$dest_branch' (squash merge)..."

  git checkout "$dest_branch"
  git pull
  git merge --squash "$source_branch"
  git add --all
  git branch -D "$source_branch"

  echo "Ready to commit. Run: git commit"
  echo "To delete remote branch: git push origin :$source_branch"
}

# Status and checks
git-check() {
  local pre_commit_hook="$(git rev-parse --show-toplevel)/.git/hooks/pre-commit"

  if [[ ! -f "$pre_commit_hook" ]]; then
    echo "No pre-commit hook found"
  else
    git add --all "$(git rev-parse --show-toplevel)"
    "$pre_commit_hook"
  fi
}

git-status() {
  git status
  git submodule foreach 'git status'
}

git-push-with-submodules() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: git-push-with-submodules <commit message>"
    return 1
  fi

  git submodule foreach "git commit -am '$*'"
  git commit -am "$*"
  git submodule foreach 'git push'
  git push
}

# Utilities
require_clean_work_tree() {
  git update-index -q --ignore-submodules --refresh
  local err=0

  if ! git diff-files --quiet --ignore-submodules --; then
    echo >&2 "Error: You have unstaged changes"
    git diff-files --name-status -r --ignore-submodules -- >&2
    err=1
  fi

  if ! git diff-index --cached --quiet HEAD --ignore-submodules --; then
    echo >&2 "Error: Your index contains uncommitted changes"
    git diff-index --cached --name-status -r --ignore-submodules HEAD -- >&2
    err=1
  fi

  if [[ $err -eq 1 ]]; then
    echo >&2 "Please commit or stash them"
    return 1
  fi
}

git-clean-repo() {
  if [[ -d .git ]]; then
    log_clean "repository (keeping .git)"
    find . -path ./.git -prune -o -type f -exec rmtrash -f {} \; 2>/dev/null
    find . -path ./.git -prune -o -type d -empty -exec rmdir {} \; 2>/dev/null
    log_success "Repository cleaned (keeping .git)"
  else
    log_error "Not in a git repository"
    return 1
  fi
}

git-root() {
  local git_root=$(git rev-parse --show-toplevel)
  if [[ -n "$git_root" ]]; then
    cd "$git_root"
  else
    echo "Error: Not in a git repository"
    return 1
  fi
}