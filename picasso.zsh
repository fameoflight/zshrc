STABLE_API=~/workspace/stable/stable-api
STABLE_WEB=~/workspace/stable/stable-web

function main() {
  cd $STABLE_API
}

function web() {
  cd $STABLE_WEB
}

function railway-shell() {
  cd $STABLE_API
  railway run rails c
}

function main-fix() {
  cd $STABLE_API

  autofix
}

function web-fix() {
  cd $STABLE_WEB

  yarn exec eslint . --fix
}


PABLO_DIR=~/workspace/pablo
PABLO_API=$PABLO_DIR/pablo-api

function pablo-main() {
  cd $PABLO_API
}