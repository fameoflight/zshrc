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
alias linkthis='rm -f ~/next; ln -s $PWD ~/next'

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
echo "going into $LATEST_DIR"
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


# FIND PROCESS
function find-process(){
  ps aux | grep -i $1 | grep -v grep
}

function kill-grep(){
    cnt=$( find-process $1 | wc -l)

    echo -e "\nSearching for '$1' -- Found" $cnt "Running Processes .. "
    find-process $1

    echo -e '\nTerminating' $cnt 'processes .. '
    ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}' | xargs kill -9
    echo -e "Done!\n"

    echo "Running search again:"
    find-process "$1"
    echo -e "\n"
}

function kill-port() {
  cnt=$(lsof -i :$1 | wc -l)

  echo -e "\nSearching for process on port '$1' -- Found" $cnt "Running Processes .. "
  
  lsof -ti:$1 | xargs -n1 kill -9
}

function start-notebook() {
  jupyter notebook --notebook-dir="~/Dropbox/My Backup/Notebooks"
}

function clean-pyc() {
  find . -name "*.pyc" -exec rm -f {} \;
}

function only-filenames() {
  find $1 -not -path '*/\.*' -type f -exec basename {} \;
}

alias python="python3"


function salient-inbound() {
  cd ~/salient/taylor
  source .venv/bin/activate
  python telephony_inbound.py dev
}
