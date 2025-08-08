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
export FPATH="$(brew --prefix)/share/zsh-completions:$(brew --prefix)/share/zsh/functions:$FPATH"

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
    rm "$tmp_file"
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
  rm "$tmp_file"
  echo "Done!"
}

join-pdf() {
  "/System/Library/Automator/Combine PDF Pages.action/Contents/Resources/join.py" -o "$@"
}

postgres-reset() {
  local postgres_data="$(brew --prefix)/var/postgres"
  if [[ -d "$postgres_data" ]]; then
    rm -rf "$postgres_data"
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



default-editor() {
  local cursor_id="com.todesktop.230313mzl4w4u92"
  local code_id="com.microsoft.VSCode"
  local extensions=".rb .js .jsx .ts .tsx .html .css .scss .json .md .yml .yaml .graphql"

  if [[ -z "$1" ]]; then
    echo "Usage: default-editor [cursor|code|zed]"
    echo "Available editors: cursor, code, zed"
    return 1
  fi

  case "$1" in
    cursor)
      echo "Setting Cursor as default editor"
      for ext in $extensions; do
        duti -s "$cursor_id" "$ext" all
      done
      ;;
    code)
      echo "Setting VS Code as default editor"
      for ext in $extensions; do
        duti -s "$code_id" "$ext" all
      done
      ;;
    zed)
      echo "Setting Zed as default editor"
      for ext in $extensions; do
        duti -s "dev.zed.Zed" "$ext" all
      done
      ;;
    *)
      echo "Unknown editor: $1"
      echo "Available: cursor, code, zed"
      return 1
      ;;
  esac

  echo "Default editor set successfully"
}
