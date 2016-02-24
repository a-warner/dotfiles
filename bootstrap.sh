#!/usr/bin/env sh

# Development script for OS X
# Origin Author: Rogelio J. Samour from https://gist.github.com/1347350
# Modifications by Andrew Warner
# - Customizes it slightly
# - Allows it to be re-run to standardize and environment
# Warning:
#   While it is unlikely any code below might damage your system,
#   it’s always a good idea to back up everything that matters to you
#   before running this script! Just in case. I am not responsible for
#   anything that may result from running this script. Proceed at
#   your own risk.
# License: See below

xcode-select -p &> /dev/null
if [ ["$?" -ne "0"] -a [! -f "/Developer/Library/uninstall-devtools"] ]; then
  read -p "Please install Xcode and re-run this script"
  exit 0
fi

sudo xcodebuild -license

if [ -n "$WORKSPACE_DIR" ]; then
  # don't let them change it if it's already set
  DEFAULT_WORKING_DIRECTORY=$WORKSPACE_DIR
else
  DEFAULT_WORKING_DIRECTORY=$HOME/src
  echo "Please enter your local working directory (or hit Return to stick with '$DEFAULT_WORKING_DIRECTORY')"
  read working_dir
fi

if [ -n "$working_dir" ]; then
  export WORKSPACE_DIR=$working_dir
else
  export WORKSPACE_DIR=$DEFAULT_WORKING_DIRECTORY
fi

echo "Creating $WORKSPACE_DIR"
mkdir -p $WORKSPACE_DIR

export HASHROCKET_DIR=$WORKSPACE_DIR # needed for dotmatrix

grep -v WORKSPACE_DIR $HOME/.bash_profile | grep -v HASHROCKET_DIR | tee $HOME/.bash_profile.tmp > /dev/null

printf "export WORKSPACE_DIR=$WORKSPACE_DIR\n"'export HASHROCKET_DIR=$WORKSPACE_DIR\n' | cat - $HOME/.bash_profile.tmp | tee $HOME/.bash_profile > /dev/null
rm $HOME/.bash_profile.tmp

echo "Please enter a host name (or hit Return to stay with '$HOSTNAME'): "
read computername

if [ -n "$computername" ]; then
  if [[ $computername =~ \.local$ ]]; then
    newhostname=$computername
  else
    newhostname="$computername.local"
  fi
  echo "Changing host name to $computername"
  scutil --set ComputerName $computername
  scutil --set LocalHostName $computername
  scutil --set HostName $newhostname
else
  echo "Not changing host name"
fi

if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
  echo "Please enter your email: "
  read email
  ssh-keygen -t rsa -C "$email"
  cat $HOME/.ssh/id_rsa.pub
fi

cat $HOME/.ssh/id_rsa.pub | pbcopy
read -p "Your public ssh key is in your pasteboard. Add it to github.com if it's not already there and hit Return"

echo "Removing system gems"
sudo -i 'gem update --system'
sudo -i 'gem clean'

grep '. "$HOME/.bashrc"' $HOME/.bash_profile > /dev/null
if [[ "$?" -ne "0" ]]; then
  echo "Making .bash_profile source .bashrc"
  echo '. "$HOME/.bashrc"' >> $HOME/.bash_profile
fi

if ! command -v brew > /dev/null; then
  echo "Installing homebrew"
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew update

echo "Homebrew is installing standard packages..."
for app in ack ctags-exuberant imagemagick macvim markdown proctools wget grep hub ngrep git node tree caskroom/cask/brew-cask postgresql redis memcached rbenv ruby-build rbenv-bundler icu4c nginx watchman colordiff diff-so-fancy; do
  brew list $app > /dev/null
  if [[ "$?" -eq "1" ]]; then
    brew install $app
  fi
done

brew list homebrew/dupes/grep
if [[ "$?" -eq "1"]]; then
  brew install homebrew/dupes/grep --with-default-names
fi

echo "Homebrew cask is installing standard packages..."
for app in java slack dropbox sizeup jing flux clipmenu spotify skype vlc virtualbox evernote heroku-toolbelt firefox google-chrome; do
  brew cask list $app > /dev/null
  if [[ "$?" -eq "1" ]]; then
    brew cask install $app
  fi
done

echo "Installing latest ruby..."
git clone https://github.com/sstephenson/rbenv-gem-rehash.git $HOME/.rbenv/plugins/rbenv-gem-rehash

rbenv versions | grep -q 2.2.3
if [ "$?" -ne "0" ]; then
  rbenv install 2.2.3
fi
rbenv global 2.2.3

echo "Preparing system for dotfiles"

cd $WORKSPACE_DIR
if [ ! -d "$WORKSPACE_DIR/dotfiles" ]; then
  git clone git@github.com:a-warner/dotfiles.git
  cd dotfiles
else
  cd dotfiles
  git pull --rebase
fi

git submodule init
git submodule update

DOTMATRIX_LOCATION=$WORKSPACE_DIR/dotmatrix
readlink $DOTMATRIX_LOCATION > /dev/null
if [[ "$?" -ne "0" ]]; then
  ln -s "$WORKSPACE_DIR/dotfiles/dotmatrix" $DOTMATRIX_LOCATION
fi

echo "Symlinking dotmatrix dotfiles"

for dotfile in .bashrc .vim .vimrc .hashrc .inputrc .screenrc; do
  if [ "$(readlink $HOME/$dotfile)" != "$DOTMATRIX_LOCATION/$dotfile" ]; then
    test -d $HOME/$dotfile && mv $HOME/$dotfile{,.bak}
    test -f $HOME/$dotfile && mv $HOME/$dotfile{,.bak}
    test -L $HOME/$dotfile && rm $HOME/$dotfile
    ln -nfs $DOTMATRIX_LOCATION/$dotfile $HOME/
  fi
done

for dotfile in .bashrc.local .vimrc.local .rvmrc.local .irbrc .pryrc .railsrc .rdebugrc; do
  if [ "$(readlink $HOME/$dotfile)" != "$WORKSPACE_DIR/dotfiles/$dotfile" ]; then
    test -f $HOME/$dotfile && mv $HOME/$dotfile{,.bak}
    test -L $HOME/$dotfile && rm $HOME/$dotfile
    ln -nfs $WORKSPACE_DIR/dotfiles/$dotfile $HOME/
  fi
done

echo "Installing vimbundles..."
sh $DOTMATRIX_LOCATION/bin/vimbundles.sh

echo "Writing .gemrc"
cat > $HOME/.gemrc <<GEMRC
---
:benchmark: false
gem: --no-ri --no-rdoc
:update_sources: true
:bulk_threshold: 1000
:verbose: true
:sources:
- https://rubygems.org
:backtrace: false
GEMRC

echo "Starting datastores now and ensuring they start by default..."
ln -sfv /usr/local/opt/postgresql/*.plist ~/Library/LaunchAgents &> /dev/null
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.memcached.plist &> /dev/null
ln -sfv /usr/local/opt/redis/*.plist ~/Library/LaunchAgents &> /dev/null
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.redis.plist &> /dev/null
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist &> /dev/null
ln -sfv /usr/local/opt/memcached/*.plist ~/Library/LaunchAgents &> /dev/null

echo "Setting a shorter Delay until key repeat..."
defaults write NSGlobalDomain InitialKeyRepeat -int 12

echo "Setting a blazingly fast keyboard repeat rate..."
defaults write NSGlobalDomain KeyRepeat -int 0

echo "Setting up git diff-so-fancy"
git config --global pager.diff "diff-so-fancy | less --tabs=1,5 -RFX"
git config --global pager.show "diff-so-fancy | less --tabs=1,5 -RFX"

source $HOME/.bash_profile
echo "Finished."

# Copyright (c) 2011 Rogelio J. Samour

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
