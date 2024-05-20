DROPBOX_PATH="${HOME}/Dropbox"

move_to_dropbox() {
if [ ! -d "$DROPBOX_PATH" ]; then
  echo "No dropbox on your machine"
  return
fi
MOVE_DIR=$1
if [[ "$MOVE_DIR" == "" ]]; then
  MOVE_DIR=$(pwd)
fi
MOVE_DIR=`realpath $MOVE_DIR`
BASE_NAME=`basename $MOVE_DIR`

DROPBOX_BACKUP_PATH="${DROPBOX_PATH}/My Backup"
DROPBOX_MOVE_PATH="${DROPBOX_BACKUP_PATH}/${BASE_NAME}"

if [ -d "$DROPBOX_MOVE_PATH" ]; then
  echo "${DROPBOX_MOVE_PATH} already exist"
  return
fi
mkdir -p "$(dirname $DROPBOX_MOVE_PATH)"
mv "$MOVE_DIR" "$DROPBOX_MOVE_PATH"
ln -sfn "$DROPBOX_MOVE_PATH" "$MOVE_DIR"
}
