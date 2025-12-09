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


git-common() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a git repository"
    return 1
  fi

  local other_branch="$1"
  if [[ -z "$other_branch" ]]; then
    echo "Usage: git-common <other-branch>"
    return 1
  fi

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1

  # Resolve branch existence (local or remote)
  if ! git rev-parse --verify --quiet "$other_branch" >/dev/null 2>&1; then
    if git rev-parse --verify --quiet "origin/$other_branch" >/dev/null 2>&1; then
      other_branch="origin/$other_branch"
    else
      echo "Error: Branch '$other_branch' not found (local or origin)"
      return 1
    fi
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local repo_name
  repo_name=$(basename "$repo_root")

  local cur_sha other_sha
  cur_sha=$(git rev-parse --short HEAD 2>/dev/null)
  other_sha=$(git rev-parse --short "$other_branch" 2>/dev/null)

  local cur_head_info other_head_info
  cur_head_info=$(git log -1 --pretty=format:'%h %ci %an %s' HEAD)
  other_head_info=$(git log -1 --pretty=format:'%h %ci %an %s' "$other_branch")

  local merge_base
  merge_base=$(git merge-base "$current_branch" "$other_branch" 2>/dev/null)
  local merge_base_short merge_base_info
  if [[ -n "$merge_base" ]]; then
    merge_base_short=$(git rev-parse --short "$merge_base")
    merge_base_info=$(git log -1 --pretty=format:'%h %ci %an %s' "$merge_base")
  else
    merge_base_short="(none)"
    merge_base_info="(no common ancestor)"
  fi

  local counts
  counts=$(git rev-list --left-right --count "$current_branch...$other_branch" 2>/dev/null || echo "0 0")
  local ahead behind
  ahead=$(echo "$counts" | awk '{print $1}')
  behind=$(echo "$counts" | awk '{print $2}')

  local files_changed
  files_changed=$(git diff --name-only "$other_branch" "$current_branch" | wc -l | tr -d ' ')
  local diffstat
  diffstat=$(git --no-pager diff --stat --minimal "$other_branch" "$current_branch" | sed -n '1,6p')

  local upstream_current upstream_other
  upstream_current=$(git rev-parse --abbrev-ref --symbolic-full-name "$current_branch@{u}" 2>/dev/null || echo "none")
  upstream_other=$(git rev-parse --abbrev-ref --symbolic-full-name "$other_branch@{u}" 2>/dev/null || echo "none")

  local wt_clean
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    wt_clean="dirty"
  else
    wt_clean="clean"
  fi

  echo "Repository: $repo_name ($repo_root)"
  echo "Current branch: $current_branch ($cur_sha)   upstream: $upstream_current"
  echo "Other branch:   $other_branch ($other_sha)   upstream: $upstream_other"
  echo "Working tree: $wt_clean"
  echo
  echo "Common ancestor (merge-base): $merge_base_short"
  echo "  -> $merge_base_info"
  echo
  echo "Last commit on $current_branch: $cur_head_info"
  echo "Last commit on $other_branch:   $other_head_info"
  echo
  echo "Commits ahead/behind (current...other):"
  echo "  $current_branch is ahead by: $ahead commit(s)"
  echo "  $other_branch is ahead by:   $behind commit(s)"
  echo
  echo "Files changed between tips: $files_changed"
  echo
  echo "Recent commits on $current_branch:"
  git --no-pager log --oneline -n 5 --decorate --graph HEAD
  echo
  echo "Recent commits on $other_branch:"
  git --no-pager log --oneline -n 5 --decorate --graph "$other_branch"
  echo
  echo "Diffstat (top lines):"
  if [[ -n "$diffstat" ]]; then
    echo "$diffstat"
  else
    echo "  No differences."
  fi
  echo
  echo "Unmerged / cherry info (commits in $current_branch not in $other_branch):"
  git --no-pager cherry -v "$other_branch" "$current_branch" | sed -n '1,20p'

  return 0
}
