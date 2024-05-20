#! /bin/bash
#
# Install the latest version of calibre for OS X
# Replaces any existing version in /Applications or ~/Applications
#
# Copyright (C) 2012 Faraz Yashar
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

# Note: `set -e` is not included in order to provide custom error failures for
# failed cURL requests; with `set -e`, cURL the script will exit if returns `1`
# with a failed download

#
# Utility functions
#

# Exit with an optional [error message] and [exit status]
error_exit() {
  echo "Calibre install error: ${1:-"Unknown Error"}
You can manually download and install calibre from http://calibre-ebook.com/download_osx" 1>&2; exit "${2:-1}"
}

# GET a <URL> and write the output to <output file>; throw an error if the request fails
download_or_exit(){
  rm -rf $2
  response_code=`curl -L --write-out %{http_code} --silent --output $2 $1`
  [ "$response_code" != "200" ] && error_exit "Failed HTTP request!
Server responded with a $response_code error when requesting \"$1\"
See $2 for the full output of the request"
}

#
# Main script
#

[ `uname` != 'Darwin' ] && error_exit "This installation script is incompatible with `uname` operating systems."

killall calibre

calibre_download_url="https://calibre-ebook.com/dist/osx"

echo "Downloading calibre image from $calibre_download_url..."
dmg="calibre.dmg" # The image filename (e.g. 'calibre-x.x.x.dmg')
download_or_exit $calibre_download_url /tmp/$dmg

hdiutil attach /tmp/$dmg
mount_point=`find /Volumes -name "calibre*" -maxdepth 1 -type d`
echo "Mounted /tmp/$dmg to $mount_point..."
[ -e $mount_point/calibre.app ] || error_exit '"calibre.app" could not be found in the downloaded .dmg'

local_calibre="$HOME/Applications/calibre.app/"
backup_dir="/tmp/calibre-`date +%s`.app.bak"

if [ -e local_calibre ]; then
  echo "Moving current calibre installation in ~/Applications to $backup_dir..."
  mv local_calibre $backup_dir
elif [ -e /Applications/calibre.app ]; then
  echo "Moving current calibre installation in /Applications to $backup_dir..."
  mv /Applications/calibre.app/ $backup_dir
fi

cp -R $mount_point/calibre.app /Applications/calibre.app
hdiutil detach `hdiutil info | grep $mount_point | grep -o "/dev/disk\d*s\d*"`

echo "Done! Launching calibre!"
open "/Applications/calibre.app"
