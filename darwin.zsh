# @author     Philipp Frischmuth <frischmuth@informatik.uni-leipzig.de>
# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# darwin specific fixes / alignments

# Darwin ls aliases
alias ls='ls -C -F -h'
alias ll='ls -C -F -h -l'

# The OSX way for ls colors
export CLICOLOR=1
export LSCOLORS="gxfxcxdxbxegedabagacad"

export EDITOR='code --wait'

# Homebrew completions (updated for modern Homebrew paths)
# Cache brew prefix for faster startup
BREW_PREFIX_CACHE_FILE="/tmp/brew_prefix_cache"
if [[ -f "$BREW_PREFIX_CACHE_FILE" ]]; then
    BREW_PREFIX=$(cat "$BREW_PREFIX_CACHE_FILE")
else
    BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
    echo "$BREW_PREFIX" > "$BREW_PREFIX_CACHE_FILE"
fi

# Only export FPATH once to avoid duplicate operations
if [[ "$FPATH" != *"$BREW_PREFIX/share/zsh-completions"* ]]; then
    export FPATH="$BREW_PREFIX/share/zsh-completions:$BREW_PREFIX/share/zsh/functions:$FPATH"
fi

# activate gls colors
export ZSH_DIRCOLORS="$ZSH_CONFIG/dircolors-solarized/dircolors.256dark"
if [[ -a $ZSH_DIRCOLORS ]]; then
    if [[ "$TERM" == *256* ]]; then
        which gdircolors > /dev/null && eval "`gdircolors -b $ZSH_DIRCOLORS`"
    else
        # standard colors for non-256-color terms
        which gdircolors > /dev/null && eval "`gdircolors -b`"
    fi
else
    which gdircolors > /dev/null && eval "`gdircolors -b`"
fi


# Utility functions
dmginstall() {
  # Downloads and installs a .dmg from a URL
  # Usage: dmginstall [url] [mount-name]
  
  if [[ $# -lt 1 ]]; then
    echo "Usage: dmginstall [url] [mount-name]"
    return 1
  fi

  local url=$1
  local mount_name=$2
  local tmp_file="/tmp/$(openssl rand -base64 10 | tr -dc '[:alnum:]').dmg"
  local apps_folder='/Applications'

  echo "Downloading $url..."
  curl -L -o "$tmp_file" "$url"

  if [[ -n "$mount_name" ]]; then
    echo "Unmounting existing images for $mount_name"
    find "/Volumes" -iname "$mount_name" -maxdepth 1 -type d -exec hdiutil unmount "{}" \; 2>/dev/null
  fi

  echo "Mounting image..."
  hdiutil attach "$tmp_file"
  
  local mount_point
  if [[ -n "$mount_name" ]]; then
    mount_point=$(find "/Volumes" -iname "$mount_name" -maxdepth 1 -type d | head -1)
  else
    mount_point=$(find "/Volumes" -name "*" -maxdepth 1 -type d | tail -1)
  fi

  if [[ -z "$mount_point" ]]; then
    echo "Failed to find mount point"
    rmtrash "$tmp_file"
    return 1
  fi

  echo "Mounted on $mount_point"

  local app=$(find "$mount_point" -name "*.app" -maxdepth 1 | head -1)
  if [[ -n "$app" ]]; then
    echo "Installing $(basename "$app")..."
    cp -r "$app" "$apps_folder"
  else
    echo "No .app found in mounted image"
  fi

  echo "Cleaning up..."
  hdiutil unmount "$mount_point" -quiet
  rmtrash "$tmp_file"
  echo "Done!"
}

join-pdf() {
  "/System/Library/Automator/Combine PDF Pages.action/Contents/Resources/join.py" -o "$@"
}

postgres-reset() {
  local postgres_data="$(brew --prefix)/var/postgres"
  if [[ -d "$postgres_data" ]]; then
    echo -e "${COLOR_YELLOW}🗑️  Moving PostgreSQL data directory to trash instead of permanent deletion${COLOR_NC}"
    rmtrash -rf "$postgres_data"
  fi
  initdb -D "$postgres_data"
  brew services restart postgresql
}

postgres-reinstall() {
  brew remove postgresql
  brew update
  brew install postgresql
  postgres-reset
}
