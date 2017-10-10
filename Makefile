XDG_CONFIG_HOME=$(HOME)/.config
XDG_CACHE_HOME=$(HOME)/.cache
ZSH_CONFIG=$(XDG_CONFIG_HOME)/zsh
ZSH_CACHE=$(XDG_CACHE_HOME)/zsh
ZSH_LOCAL=$(HOME)/.local

update:
	git submodule foreach git pull

mac: brew install-externals install-core github-setup

brew: brew-setup brew-packages

brew-setup:
	@echo "Installing Homebrew"
	@ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	-@brew tap caskroom/versions
	-@brew tap homebrew/services
	-@brew tap homebrew/dupes
	-@brew tap caskroom/fonts
	-@brew update
	-@brew upgrade brew-cask
	-@brew cleanup
	-@brew cask cleanup

brew-packages:
	-@brew install zsh
	sudo dscl . -create /Users/$USER UserShell /usr/local/bin/zsh

	@echo "Installing Go lang"
	-@brew install go
	@ echo "Installing Elixir"
	-@brew install elixir
	@echo "Installing Tree"
	-@brew install tree
	@echo "Installing SSH Copy"
	-@brew install ssh-copy-id
	@echo "Installing Wget"
	-@brew install wget
	-@brew install rmtrash
	-@brew install zsh
	-@brew install watch
	-@brew install byobu
	-@brew install pidof
	-@brew install fswatch
	-@brew install watchman
	-@brew install parallel
	-@brew install https://raw.githubusercontent.com/kadwanev/bigboybrew/master/Library/Formula/sshpass.rb

	-@brew cask install github-desktop
	-@brew cask install hub
	-@brew install git-lfs

	-@brew cask install dropbox
	-@brew cask install flux
	-@brew cask install flash
	-@brew cask install skype
	-@brew cask install calibre
	-@brew cask install google-hangouts
	-@brew cask install spotify
	-@brew cask install beardedspice
	-@brew cask install evernote
	-@brew cask install simplefloatingclock
	-@brew cask install virtualbox
	-@brew cask install mou
	-@brew cask install rescuetime
	-@brew cask install flycut
	-@brew cask install airmail-beta
	-@brew cask install iterm2-nightly
	-@brew cask install sizeup
	-@brew cask install todoist
	-@brew cask install smoothmouse
	-@brew cask install ngrok
	-@brew install librsvg

	wget -O /usr/local/etc/openssl/certs/cacert.pem http://curl.haxx.se/ca/cacert.pem
	

install-core:
	@echo "Core install tasks."
	@echo "Backing up your .zshrc iff neccessary..."
	@!(ls $(HOME)/.zshrc > /dev/null 2> /dev/null) || mv $(HOME)/.zshrc $(PWD)/zshrc.bak # Make backup of -zshrc if necessary
	@echo "Creating .zshrc in your home directory..."
	@ln -s $(PWD)/zshrc $(HOME)/.zshrc # update the link to .zshrc
	@echo "Creating directories..."
	@mkdir -p $(XDG_CONFIG_HOME)
	@mkdir -p $(ZSH_CACHE)
	@mkdir -p $(ZSH_LOCAL)/bin
	@mkdir -p $(ZSH_LOCAL)/share
	@echo "Creating zsh directory in your .config directory iff neccessary..."
	@(ls $(ZSH_CONFIG) > /dev/null 2> /dev/null) || ln -s $(PWD) $(ZSH_CONFIG) # Create zsh dir link if not existin
	@echo "Creating functions.d directory iff neccessary (for autocompletion files)..."
	@mkdir -p functions.d # folder for autocompletion files
	@echo "Creating autojump link"
	@(ls $(ZSH_LOCAL)/bin/autojump  > /dev/null 2> /dev/null) || ln -s $(PWD)/autojump/autojump $(ZSH_LOCAL)/bin/autojump
	@echo "Creating custom user files iff neccessary..."
	@touch private.zsh # create custom files for users
	@echo "DONE with core install tasks."

install-externals:
	git submodule update --init


github-setup:
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
	@git config --global alias.st "status"
	@git config --global url."git@github.com:".insteadOf "https://github.com/"

	@git config --global alias.sshow "!f() { git stash show stash^{/$*} -p; }; f"
	@git config --global alias.sapply "!f() { git stash apply stash^{/$*}; }; f"

	@echo "Setup Git Push Default to current"
	@git config --global push.default current

	@git config --global core.excludesfile ${SETTINGS}/.git_ignore