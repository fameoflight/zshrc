XDG_CONFIG_HOME=${HOME}/.config
XDG_CACHE_HOME=${HOME}/.cache
ZSH_CONFIG=${XDG_CONFIG_HOME}/zsh
ZSH_CACHE=${XDG_CACHE_HOME}/zsh
ZSH_LOCAL=${HOME}/.local
USER_BIN=${HOME}/bin
UNAME=$(shell uname)

#using home
ZSH=${HOME}/zshrc
SETTINGS=${ZSH}/Settings

all:
ifeq ($(UNAME), Darwin)
	@echo "Detected mac running mac setup"
	@$(MAKE) mac
endif

ifeq ($(UNAME), Linux)
	@echo "Detected mac running mac setup"
	@$(MAKE) linux
endif

mac: requirements common mac-settings mac-helpers mac-applications more

linux: common linux-packages linux-settings

common: install github-setup

requirements:
	@if ! [ -d "${HOME}/Dropbox" ]; then echo "Dropbox does not exists"; exit 1; fi

update:
	@echo "Updating Repo and Sub Modules"
	@git pull
	@git submodule foreach git checkout master
	@git submodule foreach git pull

mac-settings:
	@bash osx.sh

brew:
	@echo "Installing Homebrew"
	@ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	@echo "Updating brew"
	-@brew update
	-@brew cleanup
	-@brew cask cleanup

certs:
	wget -O /usr/local/etc/openssl/certs/cacert.pem http://curl.haxx.se/ca/cacert.pem

mac-helpers: brew
	@echo "Install Railway"	
	-@brew tap railwayapp/railway
	-@brew install duti
	-@brew install fz
	-@brew install monitorcontrol
	
	-@brew install visual-studio-code
	@echo "Installing Tree"
	-@brew install tree
	@echo "Installing SSH Copy"
	-@brew install ssh-copy-id
	@echo "Installing Wget"
	-@brew install wget
	-@brew install rmtrash
	-@brew install zsh
	-@brew install watch
	-@brew install pidof
	-@brew install fswatch

mac-editor:
	-@brew install ctags
	@mkdir -p ${HOME}/.local/bin
	@ln -sf ${SETTINGS}/ctags_for_ruby ${HOME}/.local/bin
	@chmod +x ${HOME}/.local/bin/ctags_for_ruby

python:
	-@brew install pyenv

postgres:
	-@brew install postgres

ruby:
	\curl -sSL https://get.rvm.io | bash -s stable --rails
	@ln -sf ${SETTINGS}/irbrc ${HOME}/.irbrc
	@ln -sf ${SETTINGS}/gemrc ${HOME}/.gemrc
	-@brew install v8-315

	-@gem install libv8 -v '3.16.14.13' -- --with-system-v8
	-@gem install therubyracer -- --with-v8-dir=/usr/local/opt/v8@3.15

github:
	-@brew install github-desktop
	-@brew install hub
	-@brew install git-lfs

mac-applications: github mac-editor python ruby postgres
	-@brew install iterm2
	-@brew install sizeup
	-@brew install todoist
	-@brew install smoothmouse
	-@brew install ngrok
	-@brew install librsvg

linux-settings:
	sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100

github-setup:
	# better editor for rebase
	@npm install -g rebase-editor
	@duti -s com.microsoft.VSCode .rb all

	@echo "Setting up Git Name Hemant Verma"
	@git config --global user.name "Hemant Verma"
	@echo "Setting up Git Email fameoflight@gmail.com"
	@git config --global user.email "fameoflight@gmail.com"
	@git config push.recurseSubmodules on-demand

	@echo "Better Git Logging Use git lg / git lg -p"
	@git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
	@git config --global alias.cp "cherry-pick"
	@git config --global alias.ri "rebase --interactive"
	@git config --global alias.rc "rebase --continue"
	@git config --global alias.rb "rebase --abort"
	@git config --global alias.url "remote show origin"
	@git config --global --add alias.root '!pwd'
	@git config --global alias.pushf "push --force-with-lease"
	@git config --global alias.co "checkout"
	@git config --global alias.master "checkout master"
	@git config --global alias.st "status"
	@git config --global url."git@github.com:".insteadOf "https://github.com/"
	@git config --global core.editor "vim"
	@git config --global sequence.editor "rebase-editor"

	@git config --global alias.sshow "!f() { git stash show stash^{/$*} -p; }; f"
	@git config --global alias.sapply "!f() { git stash apply stash^{/$*}; }; f"

	@echo "Setup Git Push Default to current"
	@git config --global push.default current

	@git config --global core.excludesfile ${SETTINGS}/.git_ignore

install: install-externals install-zsh install-bash

install-bash:
	@!(ls ${HOME}/.bashrc > /dev/null 2> /dev/null) || mv ${HOME}/.bashrc ${PWD}/bashrc.bak # Make backup of -bashrc if necessary
	@rm -rf "${HOME}/.bashrc"
	@echo "Creating .bashrc in your home directory..."
	@ln -s ${PWD}/bashrc ${HOME}/.bashrc # update the link to .bashrc

install-zsh:
	@echo "Core install tasks."
	@rm -rf "${HOME}/.zshrc"
	@echo "Creating .zshrc in your home directory..."
	@ln -s ${HOME}/zshrc/zshrc ${HOME}/.zshrc # update the link to .zshrc
	@echo "Creating directories..."
	@mkdir -p ${XDG_CONFIG_HOME}
	@mkdir -p ${ZSH_CACHE}
	@mkdir -p ${ZSH_LOCAL}/bin
	@mkdir -p ${ZSH_LOCAL}/share
	@echo "Creating zsh directory in your .config directory iff neccessary..."
	@(ls ${ZSH_CONFIG} > /dev/null 2> /dev/null) || ln -s ${PWD} ${ZSH_CONFIG} # Create zsh dir link if not existin
	@echo "Creating functions.d directory iff neccessary (for autocompletion files)..."
	@mkdir -p functions.d # folder for autocompletion files
	@echo "Creating autojump link"
	@(ls ${ZSH_LOCAL}/bin/autojump  > /dev/null 2> /dev/null) || ln -s ${PWD}/autojump/autojump ${ZSH_LOCAL}/bin/autojump
	@echo "Creating custom user files iff neccessary..."
	@touch private.zsh # create custom files for users
	@echo "DONE with core install tasks."

rvm:
	@\curl -sSL https://get.rvm.io | bash -s stable

ifdef ZSH_VERSION
	@source ${HOME}/.zshrc
endif
	@echo "Installing bash alias"
	@rm -rf "${HOME}/.profile"
	@ln -s ${PWD}/profile ${HOME}/.profile # update the link to .zshrc

install-externals:
	git submodule update --init

more:
	@echo "If you have problem with brew you can remove make remove-brew or fix-brew"
	@echo "If you want to restore last dock defaults import Settings/dock.plist"

remove-brew:
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"

fix-brew-permissions:
	# make brew accessible to all admin user
	@sudo chmod -R o-w /usr/local

	@sudo chgrp -R admin /usr/local
	@sudo chgrp -R admin /opt/homebrew-cask

	@sudo chown -R `whoami` /usr/local
	@sudo chown -R `whoami` /Library/Caches/Homebrew
	@sudo chown -R `whoami` /opt/homebrew-cask

	@sudo chmod -R g=u /usr/local
	@sudo chmod -R o-w /usr/local

fix-brew: fix-brew-cask fix-brew-permissions
	@compaudit | xargs chmod g-w
	-@brew update
	-@brew upgrade brew-cask
	-@brew cleanup
	-@brew cask cleanup

# Re-usable target for yes no prompt. Usage: make .prompt-yesno message="Is it yes or no?"
# Will exit with error if not yes
.prompt-yesno:
	@exec 9<&0 0</dev/tty
	echo "$(message) [Y]:"
	[[ -z $$FOUNDATION_NO_WAIT ]] && read -rs -t5 -n 1 yn;
	exec 0<&9 9<&-
	[[ -z $$yn ]] || [[ $$yn == [yY] ]] && echo Y >&2 || (echo N >&2 && exit 1)
