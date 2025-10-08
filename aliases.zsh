# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# alias definitions which can be edited/modified with 'aedit'
#


alias svg-util=rsvg-convert

export EDITOR="vim"
alias vi="vim"
alias viedit=" $EDITOR $HOME/.vim/vimrc"

#alias man="unset PAGER; man"
alias grep='grep --color=auto'
alias home="cd ~"

##### standard aliases (start with a space to be ignored in history)
# default ls is untouched, except coloring
alias ls=' ls -C -F -h --color=always'
alias ll='ls -l'

alias cd=' cd'
alias ..=' cd ..; ls'
alias ...=' cd ..; cd ..; ls'
alias ....=' cd ..; cd ..; cd ..; ls'
alias cd..='..'
alias cd...='...'
alias cd....='....'
alias bfg='java -jar ~/zshrc/bfg-1.13.2.jar'

# alias to create a next-link in your home to tag the current workingdir
alias linkthis='rmtrash -f ~/next; ln -s $PWD ~/next'

##### global aliases
# zsh buch s.82 (z.B. find / ... NE)
alias -g NE='2>|/dev/null'
alias -g NO='&>|/dev/null'

# http://rayninfo.co.uk/tips/zshtips.html
alias -g G='| grep -'
alias -g P='2>&1 | $PAGER'
alias -g L='| less'
alias -g LA='2>&1 | less'
alias -g M='| most'
alias -g C='| wc -l'

# http://www.commandlinefu.com/commands/view/7284/zsh-suffix-to-inform-you-about-long-command-ending
# zsh suffix to inform you about long command ending make, Just add "R" (without quotes) suffix to it and you can do other things:
# zsh will inform you when you can see the results.
#alias -g R=' &; jobs | tail -1 | read A0 A1 A2 cmd; echo "running $cmd"; fg "$cmd"; zenity --info --text "$cmd done"; unset A0 A1 A2 cmd'

##### suffix aliases (mostly mapped to open which runs the gnome/kde default app)

alias -s Dockerfile="docker build - < "

alias -s tex="rubber --inplace --maxerr -1 --short --force --warn all --pdf"

alias -s 1="man -l"
alias -s 2="man -l"
alias -s 3="man -l"
alias -s 4="man -l"
alias -s 5="man -l"
alias -s 6="man -l"
alias -s 7="man -l"
alias -s epub="open"
alias -s pdf="open"
alias -s PDF="open"
alias -s xoj="xournal"

alias -s md="open"
alias -s markdown="open"
alias -s htm="$BROWSER"
alias -s html="$BROWSER"
alias -s jar="java -jar"
alias -s deb="sudo dpkg -i"
alias -s gpg="gpg"

alias -s iso="vlc"
alias -s avi=" open"
alias -s AVI=" open"
alias -s mov=" open"
alias -s mpg=" open"
alias -s m4v=" open"
alias -s mp4=" open"
alias -s rmvb=" open"
alias -s MP4=" open"
alias -s ogg=" open"
alias -s ogv=" open"
alias -s flv=" open"
alias -s mkv=" open"
alias -s wav=" open"
alias -s mp3=" open"
alias -s webm=" open"

alias -s tif="open"
alias -s tiff="open"
alias -s png="open"
alias -s jpg="open"
alias -s jpeg="open"
alias -s JPG="open"
alias -s gif="open"
alias -s svg="open"
alias -s psd="open"

alias -s com="open"
alias -s de="open"
alias -s org="open"

alias -s rdf="rapper --count"
alias -s owl="rapper --count"
alias -s ttl="rapper -i turtle --count"
alias -s tt="rapper -i turtle --count"
alias -s n3="rapper -i turtle --count"
alias -s nt="rapper -i ntriples --count"
alias -s ntriples="rapper -i ntriples --count"
alias -s ntriple="rapper -i ntriples --count"

alias -s ods="open"
alias -s xls="open"
alias -s xlsx="open"
alias -s csv="open"

alias -s pot="open"
alias -s odt="open"
alias -s doc="open"
alias -s docx="open"
alias -s rtf="open"
alias -s dot="dot -Tpng -O"

alias -s ppt="open"
alias -s pptx="open"
alias -s odp="open"

alias -s plist="plutil"
alias -s log="open"

alias -s sla="open"

alias -s exe="open"

alias -s tjp="tj3"
alias -s asc="gpg"
alias -s pem="openssl x509 -noout -text -in "

alias zshrc="cd ~/zshrc"
alias xcode="open -a Xcode"

alias deploy-sf="ssh deploy@45.55.6.197"

alias workspace="cd ~/workspace"
alias trading="workspace && cd trading"

alias dockerm="docker-machine"

alias rscp='rsync -aP'
alias rsmv='rsync -aP --remove-source-files'

path() {
  find . -iname "*$1*"
}

fix-pep8() {
  echo "Resetting HEAD"
  git reset HEAD
  ruby -le "print '-'*30"
  echo "Running autopep8"
  git diff --name-only --diff-filter=AM | grep .py | xargs autopep8 --select=E1,W1 --in-place
  ruby -le "print '-'*30"
  echo "Adding all files"
  git add -A
}

delete-line() {
  gsed -i "$1 d" $2
}

remove-ssh-key() {
  delete-line $1 ~/.ssh/known_hosts
}

flush-dns-cache() {
  sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder;
}

reload-zsh() {
  source ~/.zshrc
}

latest-dir(){
LATEST_DIR="$(ls -1t | head -1)"
echo -e "${COLOR_GREEN}📂 Going into latest directory: ${COLOR_BOLD}${COLOR_BLUE}$LATEST_DIR${COLOR_NC}"
cd $LATEST_DIR
}

latest-topcoder-dir() {
  cd /Users/hemantv/Dropbox/Programming/Topcoder/Workspace
  latest-dir
}

topcoder-start(){
  watchman -- trigger /Users/hemantv/Dropbox/Programming/Topcoder/Workspace topcoder-html '*.html' -- open
  watchman -- trigger /Users/hemantv/Dropbox/Programming/Topcoder/Workspace topcoder-py '*.py' -- subl
}

topcoder-cleanup() {
  watchman trigger-del /Users/hemantv/Dropbox/Programming/Topcoder/Workspace topcoder-html
  watchman trigger-del /Users/hemantv/Dropbox/Programming/Topcoder/Workspace topcoder-py
}

# only show hidden files
hidden() { \ls -a "$@" | grep '^\.'; }
# function cd() { builtin cd "$*" }

# function pwd() { builtin pwd && ls -l; }

function start-calibre-server() {
  calibre-server --with-library="~/Dropbox/Calibre Library"
}

function restart-dynamo-db() {
    brew services stop dynamodb-local
    rmtrash /usr/local/var/data/dynamodb-local/*
    brew services start dynamodb-local
}

function mount-ssh() {
  echo "Mounting $1:/home/hemantv on ~/mnt/$1"
  mkdir -p ~/mnt/$1
  sshfs -o transform_symlinks $1:/home/hemantv ~/mnt/$1
  cp -R ~/zshrc/postmates/* ~/mnt/$1
  cd ~/mnt/$1
}

function parallel-commands() {
  for cmd in "$@"; do {
    echo "Process \"$cmd\" started";
    $cmd & pid=$!
    PID_LIST+=" $pid";
  } done

  trap "kill $PID_LIST" SIGINT

  echo "Parallel processes have started";

  wait $PID_LIST

  echo
  echo "All processes have completed";
}

# ALTERNATIVE GREP (AGREP) - Enhanced search with Spotlight integration
# agrep: Alternative grep that combines ripgrep power with Spotlight speed
# Searches current directory content with optional extension filtering
function agrep() {
  local pattern="$1"
  local extensions="$2"
  local current_dir="$(pwd)"

  if [[ -z "$pattern" ]]; then
    log_error "Usage: agrep <pattern> [extensions]"
    log_info "Examples:"
    log_info "  agrep 'function.*auth' js,ts"
    log_info "  agrep 'TODO|FIXME' py,rb"
    log_info "  agrep 'class.*User'"
    return 1
  fi

  log_section "🔍 Smart Search in Current Directory"
  log_info "Directory: $(basename "$current_dir")"
  log_info "Pattern: $pattern"

  if [[ -n "$extensions" ]]; then
    log_info "Extensions: $extensions"

    # Convert comma-separated extensions to ripgrep glob pattern
    local glob_pattern=""
    if [[ "$extensions" == *","* ]]; then
      # Multiple extensions: js,ts,py -> "*.{js,ts,py}"
      local ext_list=$(echo "$extensions" | sed 's/,/,/g')
      glob_pattern="*.{$ext_list}"
    else
      # Single extension: js -> "*.js"
      glob_pattern="*.$extensions"
    fi

    log_progress "Searching with extension filter..."
    rg --color=always --line-number --heading --smart-case --glob "$glob_pattern" "$pattern" "$current_dir" 2>/dev/null
  else
    log_progress "Searching all file types..."
    rg --color=always --line-number --heading --smart-case "$pattern" "$current_dir" 2>/dev/null
  fi

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    log_success "Search completed"
  elif [[ $exit_code -eq 1 ]]; then
    log_warning "No matches found for pattern: $pattern"
  else
    log_error "Search failed with error code: $exit_code"
  fi
}

# Find files by name with optional extension filtering using Spotlight
function find-files() {
  local filename="$1"
  local extensions="$2"
  local current_dir="$(pwd)"

  if [[ -z "$filename" ]]; then
    log_error "Usage: find-files <filename> [extensions]"
    log_info "Examples:"
    log_info "  find-files 'config' js,json"
    log_info "  find-files 'test.*spec' ts"
    log_info "  find-files 'README'"
    return 1
  fi

  log_section "📁 File Search in Current Directory"
  log_info "Directory: $(basename "$current_dir")"
  log_info "Filename: $filename"

  if [[ -n "$extensions" ]]; then
    log_info "Extensions: $extensions"

    # Use mdfind (Spotlight) for fast file searching with extension filter
    if [[ "$extensions" == *","* ]]; then
      # Multiple extensions - need to search each separately and combine
      local ext_array=(${(@s/,/)extensions})
      log_progress "Using Spotlight search with extension filter..."

      for ext in $ext_array; do
        mdfind -onlyin "$current_dir" "kMDItemDisplayName == '*$filename*' && kMDItemFSName == '*.$ext'" 2>/dev/null
      done | sort -u
    else
      # Single extension
      log_progress "Using Spotlight search with extension filter..."
      mdfind -onlyin "$current_dir" "kMDItemDisplayName == '*$filename*' && kMDItemFSName == '*.$extensions'" 2>/dev/null
    fi
  else
    log_progress "Using Spotlight search..."
    mdfind -onlyin "$current_dir" "kMDItemDisplayName == '*$filename*'" 2>/dev/null
  fi

  local matches=$(mdfind -onlyin "$current_dir" "kMDItemDisplayName == '*$filename*'" 2>/dev/null | wc -l)
  if [[ $matches -gt 0 ]]; then
    log_success "Found $matches matching files"
  else
    log_warning "No files found matching: $filename"
  fi
}



# FIND PROCESS
function find-process(){
  ps aux | grep -i $1 | grep -v grep
}

function kill-grep(){
    cnt=$( find-process $1 | wc -l)

    echo ""
    echo -e "${COLOR_BLUE}🔍 Searching for '$1' -- Found ${COLOR_BOLD}${COLOR_YELLOW}$cnt${COLOR_NC}${COLOR_BLUE} Running Processes${COLOR_NC}"
    find-process $1

    echo ""
    log_process_kill "$cnt processes matching '$1'"
    ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}' | xargs kill -9
    log_success "Process termination complete!"
    echo ""

    log_info "Running search again:"
    find-process "$1"
    echo ""
}

function kill-port() {
  cnt=$(lsof -i :$1 | wc -l)

  echo ""
  echo -e "${COLOR_BLUE}🔍 Searching for process on port '${COLOR_BOLD}${COLOR_YELLOW}$1${COLOR_NC}${COLOR_BLUE}' -- Found ${COLOR_BOLD}${COLOR_YELLOW}$cnt${COLOR_NC}${COLOR_BLUE} Running Processes${COLOR_NC}"
  
  if [[ $cnt -gt 0 ]]; then
    log_process_kill "processes on port $1"
    lsof -ti:$1 | xargs -n1 kill -9
    log_success "Port $1 cleared!"
  else
    log_success "No processes found on port $1"
  fi
}

function start-notebook() {
  jupyter notebook --notebook-dir="~/Dropbox/My Backup/Notebooks"
}

function clean-pyc() {
  log_clean "Python bytecode files (.pyc)"
  local count=$(find . -name "*.pyc" | wc -l)
  find . -name "*.pyc" -exec rmtrash -f {} \;
  log_success "Removed $count .pyc files"
}

function only-filenames() {
  find $1 -not -path '*/\.*' -type f -exec basename {} \;
}

# System monitoring shortcuts
cpu() {
  top -l 1 -s 0 | grep "CPU usage" | awk '{print "🚀 CPU: " $3 " user, " $5 " system, " $7 " idle"}'
}

sysmon() {
  echo -e "${COLOR_BOLD}${COLOR_MAGENTA}🖥️  System Performance Monitor${COLOR_NC}"
  echo -e "${COLOR_BOLD}═══════════════════════════════════════════${COLOR_NC}"
  echo

  # CPU Information
  echo -e "${COLOR_BOLD}${COLOR_BLUE}🚀 CPU Usage:${COLOR_NC}"
  echo -e "${COLOR_CYAN}$(top -l 1 -s 0 | grep "CPU usage" | awk '{print "  Current: " $3 " user, " $5 " system, " $7 " idle"}')${COLOR_NC}"
  echo -e "${COLOR_CYAN}$(sysctl -n machdep.cpu.brand_string | sed 's/^/  Processor: /')${COLOR_NC}"
  echo -e "${COLOR_CYAN}$(sysctl -n hw.ncpu | sed 's/^/  Cores: /')${COLOR_NC}"
  echo

  # Memory Information
  echo -e "${COLOR_BOLD}${COLOR_GREEN}💾 Memory Usage:${COLOR_NC}"
  local vm_stat_output=$(vm_stat)
  local page_size=$(vm_stat | head -1 | sed 's/.*page size of \([0-9]*\).*/\1/')
  local pages_free=$(echo "$vm_stat_output" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
  local pages_active=$(echo "$vm_stat_output" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
  local pages_inactive=$(echo "$vm_stat_output" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
  local pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
  
  if [[ -n "$page_size" && -n "$pages_free" ]]; then
    local free_mb=$((pages_free * page_size / 1024 / 1024))
    local active_mb=$((pages_active * page_size / 1024 / 1024))
    local inactive_mb=$((pages_inactive * page_size / 1024 / 1024))
    local wired_mb=$((pages_wired * page_size / 1024 / 1024))
    local total_mb=$((free_mb + active_mb + inactive_mb + wired_mb))
    local used_mb=$((total_mb - free_mb))
    
    echo -e "${COLOR_CYAN}  Total: ${total_mb}MB | Used: ${used_mb}MB | Free: ${free_mb}MB${COLOR_NC}"
    echo -e "${COLOR_CYAN}  Active: ${active_mb}MB | Wired: ${wired_mb}MB | Inactive: ${inactive_mb}MB${COLOR_NC}"
  fi
  echo

  # GPU Information
  echo -e "${COLOR_BOLD}${COLOR_YELLOW}🎮 GPU Information:${COLOR_NC}"
  if command -v powermetrics >/dev/null 2>&1; then
    echo -e "${COLOR_CYAN}$(system_profiler SPDisplaysDataType | grep "Chipset Model:" | head -1 | sed 's/^      /  /')${COLOR_NC}"
    echo -e "${COLOR_CYAN}  Usage: Use 'sudo powermetrics --samplers gpu_power -n 1 -i 1000' for detailed GPU metrics${COLOR_NC}"
  else
    echo -e "${COLOR_CYAN}$(system_profiler SPDisplaysDataType | grep "Chipset Model:" | head -1 | sed 's/^      /  /')${COLOR_NC}"
    echo -e "${COLOR_YELLOW}  Note: Install powermetrics for detailed GPU usage monitoring${COLOR_NC}"
  fi
  echo

  # Top CPU processes
  echo -e "${COLOR_BOLD}${COLOR_RED}🔥 Top 5 CPU Processes:${COLOR_NC}"
  ps -eo pcpu,comm | sort -nr | head -6 | tail -5 | while IFS= read -r line; do
    echo -e "${COLOR_CYAN}  $line${COLOR_NC}"
  done
  echo

  # Load averages
  echo -e "${COLOR_BOLD}${COLOR_BLUE}📊 Load Averages:${COLOR_NC}"
  echo -e "${COLOR_CYAN}$(uptime | sed 's/.*load averages: /  1min: /' | sed 's/ / | 5min: /' | sed 's/ / | 15min: /')${COLOR_NC}"
}


