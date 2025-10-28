# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# functions and key bindings

# SAFE RM FUNCTION - Always uses rmtrash instead of rm
# This function prevents permanent deletion and moves files to trash
rm() {
  # Check if rmtrash is available
  if ! command -v rmtrash >/dev/null 2>&1; then
    echo -e "${COLOR_BOLD}${COLOR_RED}⚠️  rmtrash not found! Please install with: brew install rmtrash${COLOR_NC}"
    echo -e "${COLOR_YELLOW}Falling back to standard rm - USE WITH CAUTION!${COLOR_NC}"
    command rm "$@"
    return $?
  fi

  # Parse rm arguments and convert them to rmtrash format
  local args=()
  local recursive=false
  local force=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--recursive)
        recursive=true
        shift
        ;;
      -f|--force)
        force=true
        shift
        ;;
      -rf|-fr)
        recursive=true
        force=true
        shift
        ;;
      -r*f|-f*r)
        recursive=true
        force=true
        shift
        ;;
      -v|--verbose)
        args+=(--verbose)
        shift
        ;;
      --help)
        command rm --help
        return 0
        ;;
      *)
        break
        ;;
    esac
  done

  # Build rmtrash command
  local rmtrash_args=()
  [[ "$recursive" == true ]] && rmtrash_args+=(--recursive)
  [[ "$force" == true ]] && rmtrash_args+=(--force)
  rmtrash_args+=("${args[@]}")
  rmtrash_args+=("$@")

  # Validate we have files to remove
  if [[ $# -eq 0 ]]; then
    echo -e "${COLOR_RED}❌ No files specified for removal${COLOR_NC}"
    return 1
  fi

  # Log the operation for safety
  echo -e "${COLOR_BOLD}${COLOR_YELLOW}🗑️  Moving to trash instead of permanent deletion:${COLOR_NC}"
  echo -e "${COLOR_CYAN}Files: $@${COLOR_NC}"

  # Use rmtrash with translated arguments
  rmtrash "${rmtrash_args[@]}"
}

# Key bindings
# Ctrl+X,S adds sudo to the line
run-with-sudo() { LBUFFER="sudo $LBUFFER" }
zle -N run-with-sudo
bindkey '^Xs' run-with-sudo

# System utilities
# Top memory processes (macOS compatible)
memtop() {
  echo -e "${COLOR_BOLD}${COLOR_BLUE}💾 Top 10 Memory-Consuming Processes:${COLOR_NC}"
  echo "─────────────────────────────────────────"
  ps -eo rss,comm | sort -nr | head -10 | while IFS= read -r line; do
    echo -e "${COLOR_CYAN}$line${COLOR_NC}"
  done
}

# tmux utility - open new window in current directory
tmux-neww-in-cwd() {
  if [[ -n "$TMUX" ]]; then
    log_success "Opening new tmux window in: $(pwd)"
    tmux new-window -c "$(pwd)"
  else
    log_error "Not in a tmux session"
  fi
}

# File utilities
# Safe tar extraction - prevents tarbombs
etb() {
  if [[ -z "$1" ]]; then
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}📦 Usage: etb <tarfile>${COLOR_NC}"
    return 1
  fi
  
  log_archive_extract "$1"
  local files=$(tar tf "$1")
  local first_dir=$(echo "$files" | head -1 | cut -d'/' -f1)
  
  if [[ $(echo "$files" | grep -v "^$first_dir" | wc -l) -eq 0 ]]; then
    log_success "Safe extraction (single directory)"
    tar xf "$1"
  else
    local dirname="${1%%.tar*}"
    log_warning "Creating container directory: $dirname"
    mkdir -p "$dirname" && tar xf "$1" -C "$dirname"
  fi
  log_complete "Extraction"
}

# Show newest files (macOS compatible)
newest() {
  echo -e "${COLOR_BOLD}${COLOR_BLUE}📅 20 Most Recently Modified Files:${COLOR_NC}"
  log_separator
  find . -type f -not -path '*/\.*' -not -path '*/cache/*' -not -path '*/.git/*' -not -path '*/.hg/*' -print0 |
  xargs -0 stat -f "%m %N" | sort -nr | head -20 | while read timestamp file; do
    echo -e "${COLOR_CYAN}$(date -r $timestamp '+%Y-%m-%d %H:%M:%S')${COLOR_NC} ${COLOR_GREEN}$file${COLOR_NC}"
  done
}

# Backup file with timestamp
buf() {
  if [[ -z "$1" ]]; then
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}💾 Usage: buf <filename>${COLOR_NC}"
    return 1
  fi
  
  local oldname="$1"
  local datepart=$(date +%Y-%m-%d-%H%M%S)
  local extension="${oldname##*.}"
  local basename="${oldname%.*}"
  
  if [[ "$oldname" == "$basename" ]]; then
    # No extension
    local newname="${oldname}.${datepart}"
  else
    local newname="${basename}.${datepart}.${extension}"
  fi
  
  log_info "Creating backup..."
  cp -R "$oldname" "$newname"
  log_file_backed_up "$newname"
}

# Create bz2 archive
dobz2() {
  if [[ -z "$1" ]]; then
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}📦 Usage: dobz2 <file/directory>${COLOR_NC}"
    return 1
  fi
  log_archive_create "$1.tar.bz2"
  tar cjf "$1.tar.bz2" "$1"
  log_success "Archive created successfully!"
}

# ZSH utilities
printHookFunctions() {
  print -C 1 ":::pwd_functions:" $chpwd_functions
  print -C 1 ":::periodic_functions:" $periodic_functions
  print -C 1 ":::precmd_functions:" $precmd_functions
  print -C 1 ":::preexec_functions:" $preexec_functions
  print -C 1 ":::zshaddhistory_functions:" $zshaddhistory_functions
  print -C 1 ":::zshexit_functions:" $zshexit_functions
}

# Reload all custom functions
r() {
  local f
  f=("$ZSH_CONFIG"/functions.d/*(.N))
  if [[ ${#f[@]} -gt 0 ]]; then
    unfunction $f:t 2>/dev/null
    autoload -U $f:t
    echo "Reloaded ${#f[@]} functions"
  else
    echo "No functions found in $ZSH_CONFIG/functions.d/"
  fi
}

# File operations
# Activate zmv for advanced file renaming
autoload zmv
# Mass move - no need to quote arguments
alias mmv='noglob zmv -W'

# Interactive file renaming
massmove() {
  if [[ ! -t 0 ]]; then
    echo "This function requires an interactive terminal"
    return 1
  fi
  
  local temp_ls="$(mktemp)"
  local temp_ren="$(mktemp)"
  
  ls > "$temp_ls"
  paste "$temp_ls" "$temp_ls" > "$temp_ren"
  
  "${EDITOR:-vim}" "$temp_ren"
  
  if [[ -s "$temp_ren" ]]; then
    echo "Executing renames..."
    sed 's/^/mv "/' "$temp_ren" | sed 's/\t/" "/' | sed 's/$/"/' | bash
  fi
  
  rmtrash -f "$temp_ls" "$temp_ren"
}

# Display utilities
# Console clock in top right corner
clock() {
  local pid_file="/tmp/zsh_clock_$$"
  
  if [[ -f "$pid_file" ]]; then
    echo "Clock already running (PID: $(cat "$pid_file"))"
    return 1
  fi
  
  {
    while sleep 1; do
      tput sc
      tput cup 0 $(($(tput cols)-29))
      date
      tput rc
    done
  } &
  
  echo $! > "$pid_file"
  echo "Clock started (PID: $!). Use 'kill $(cat "$pid_file")' to stop."
}

# Development utilities
# Create executable script with shebang
shebang() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: shebang <interpreter> <filename>"
    echo "Example: shebang python myscript.py"
    return 1
  fi
  
  local interpreter="$1"
  local filename="$2"
  
  if ! command -v "$interpreter" >/dev/null 2>&1; then
    echo "Error: '$interpreter' not found in PATH"
    return 1
  fi
  
  if [[ -f "$filename" ]]; then
    echo "Warning: '$filename' already exists"
    read -q "REPLY?Overwrite? (y/n): "
    echo
    [[ "$REPLY" != "y" ]] && return 1
  fi
  
  printf '#!/usr/bin/env %s\n\n' "$interpreter" > "$filename"
  chmod 755 "$filename"
  "${EDITOR:-vim}" + "$filename"
  chmod 755 "$filename"  # Ensure it's still executable
  rehash
  
  echo "Created executable script: $filename"
}

# Git utilities
# Show outgoing commits
git-out() {
  local remote="${1:-origin}"
  local branch="$(git branch --show-current)"
  
  if ! git rev-parse --verify "$remote/$branch" >/dev/null 2>&1; then
    echo "Remote branch '$remote/$branch' not found"
    return 1
  fi
  
  git log --oneline "$remote/$branch"..HEAD
}

# Go to VCS root directory
gr() {
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]] || [[ -d "$dir/.hg" ]] || [[ -d "$dir/.svn" ]]; then
      echo "VCS root: $dir"
      cd "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "Not in a VCS repository"
  return 1
}

# Web utilities
# Query Wikipedia via DNS
wp() {
  if [[ -z "$1" ]]; then
    echo "Usage: wp <search_term>"
    return 1
  fi
  dig +short txt "${1}.wp.dg.cx"
}

# Network utilities
# Download files with wget
download-files() {
  local download_dir="${HOME}/Downloads"
  [[ ! -d "$download_dir" ]] && mkdir -p "$download_dir"
  
  cd "$download_dir" || return 1
  wget -r -l 2 -nd -nH -A "$@"
  cd - >/dev/null
}