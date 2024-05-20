# @author     Philipp Frischmuth <frischmuth@informatik.uni-leipzig.de>
# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# darwin specific fixes / alignments

# Darwin ls command does not support --color option.
# alias ls=' ls'
#alias myls=' ls'
# use gnu ls instead of bsd ls
alias ls='ls -C -F -h'
alias ll='ls -C -F -h -l'

# The OSX way for ls colors.
export CLICOLOR=1
export LSCOLORS="gxfxcxdxbxegedabagacad"

export EDITOR='code --wait'
# brew install zsh-completions
export FPATH=/usr/local/share/zsh-completions:/usr/local/share/zsh/functions:$FPATH
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

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


alias influxdb-default='influxdb -config=/usr/local/etc/influxdb.conf'


dmginstall(){
# Downloads and install a .dmg from a URL
#
# Usage
# $ dmginstall [url]
#
# For example, for installing alfred.app
# $ dmginstall http://cachefly.alfredapp.com/alfred_1.3.1_261.dmg
#
# TODO
# - currently only handles .dmg with .app folders, not .pkg files
# - handle .zip files as well


if [[ $# -lt 1 ]]; then
  echo "Usage: dmginstall [url] [mount-name]"
  return
fi

url=$1
mount_name=$2

# Generate a random file name
tmp_file=/tmp/`openssl rand -base64 10 | tr -dc '[:alnum:]'`.dmg
apps_folder='/Applications'

# Download file
echo "Downloading $url in $tmp_file..."
curl -L -o "$tmp_file" "$url"

echo "Unmounting all images on $mount_name"

find "/Volumes" -iname "$mount_name" -maxdepth 1 -type d -exec hdiutil unmount "{}" \;
echo "Mounting image..."
hdiutil attach $tmp_file
mount_point=`find "/Volumes" -iname "$mount_name" -maxdepth 1 -type d`

echo "Mounted on $mount_point..."

# Locate .app folder and move to /Applications
app=`find "$mount_point" -name "*.app" -maxdepth 1`
cp -r "$app" "$apps_folder"

# Unmount mount_point, delete temporal file
echo "Cleaning up..."
hdiutil unmount "$mount_point" -quiet
rm "$tmp_file"

echo "Done!"
}

join-pdf() {
  "/System/Library/Automator/Combine PDF Pages.action/Contents/Resources/join.py" -o $*
}

postgres-reset() {
  rmtrash /usr/local/var/postgres
  initdb -D /usr/local/var/postgres
  brew services start postgresql
  brew services restart postgresql
}

postgres-reinstall() {
  brew remove postgres
  brew update
  rm ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist
  brew install postgres
  rmtrash /usr/local/var/postgres
  initdb -D /usr/local/var/postgres
  brew services start postgresql
  brew services restart postgresql
}

ssh-mycloud() {
  sshpass -p welc0me ssh root@10.0.1.2
}

start-notebook() {
  source ~/theta/ipy-jupyter-venv3/bin/activate
  cd /Users/hemantv/theta/jupyter
  jupyter-notebook
}
