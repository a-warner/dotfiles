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

xcode-select --print-path &> /dev/null
if [ ["$?" -ne "0"] -a [! -f "/Developer/Library/uninstall-devtools"] ]; then
  read -p "Please install Xcode and re-run this script"
  exit 0
fi

if [ -n "$WORKSPACE_DIR" ]; then
  # don't let them change it if it's already set
  DEFAULT_WORKING_DIRECTORY=$WORKSPACE_DIR
else
  DEFAULT_WORKING_DIRECTORY=$HOME/workspace
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

echo "Checking java installation; please follow any prompts to install"
java 2>&1 > /dev/null
# I'm pretty sure this just installs java if it's not installed
# TODO: fix this if it doesn't work on a new machine

if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
  echo "Please enter your email: "
  read email
  ssh-keygen -t rsa -C "$email"
  cat $HOME/.ssh/id_rsa.pub
fi

cat $HOME/.ssh/id_rsa.pub | pbcopy
read -p "Your public ssh key is in your pasteboard. Add it to github.com if it's not already there and hit Return"

grep "streams=no" $HOME/Library/Preferences/nsmb.conf > /dev/null
if [[ "$?" -ne "0" ]]; then
  echo "Fixing samba streams on OS X"
  echo "[default]" >  $HOME/Library/Preferences/nsmb.conf
  echo "streams=no" >> $HOME/Library/Preferences/nsmb.conf
fi

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
  sudo mkdir /usr/local > /dev/null
  sudo chown -R `whoami` /usr/local
  curl -L https://github.com/mxcl/homebrew/tarball/master | tar xz --strip 1 -C /usr/local
fi

echo "Homebrew is standard packages..."
for app in ack ctags-exuberant imagemagick macvim markdown proctools wget grep hub ngrep git node tree; do
  brew list $app > /dev/null
  if [[ "$?" -eq "1" ]]; then
    brew install $app
  fi
done

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

if [ ! -d $HOME/.rvm ]; then
  echo "Building rvm"
  curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer -o rvm-installer
  chmod +x rvm-installer
  ./rvm-installer --version head
  rm rvm-installer
  source "$HOME/.rvm/scripts/rvm"
fi

chmod +x $HOME/.rvm/hooks/after_cd_bundler

echo "Declare global gems"
GLOBAL_GEM_FILE=$HOME/.rvm/gemsets/global.gems
test -f $GLOBAL_GEM_FILE || touch $GLOBAL_GEM_FILE
for gem in hitch dirty github; do
  grep $gem $GLOBAL_GEM_FILE > /dev/null
  if [[ "$?" -ne "0" ]]; then
    echo "$gem" >> $GLOBAL_GEM_FILE
  fi
done

rvm list strings | grep ruby-1.9.3 > /dev/null
if [[ "$?" -ne "0" ]]; then
  echo "rvm is installing ruby 1.9.3"
  rvm install 1.9.3 -C --enable-shared=yes
  rvm use 1.9.3 --default
fi

echo "Writing .gemrc"
cat > $HOME/.gemrc <<GEMRC
---
:benchmark: false
gem: --no-ri --no-rdoc
:update_sources: true
:bulk_threshold: 1000
:verbose: true
:sources:
- http://rubygems.org
:backtrace: false
GEMRC

brew list postgresql > /dev/null
if [[ "$?" -eq "1" ]]; then
  echo "Installing PostgreSQL"
  brew install postgresql
  brew cleanup; brew prune
  POSTGRESQL_VERSION=$(brew list postgresql | awk -F/ '{print $6}' | head -n 1)
  test -d /usr/local/var/postgres || initdb /usr/local/var/postgres
  test -d $HOME/Library/LaunchAgents || mkdir -p $HOME/Library/LaunchAgents
  test -f $HOME/Library/LaunchAgents/org.postgresql.postgres.plist &&
    launchctl unload -w $HOME/Library/LaunchAgents/org.postgresql.postgres.plist
  cp -f /usr/local/Cellar/postgresql/$POSTGRESQL_VERSION/org.postgresql.postgres.plist $HOME/Library/LaunchAgents/
  launchctl load -w $HOME/Library/LaunchAgents/org.postgresql.postgres.plist
else
  echo "PostgreSQL already installed"
fi

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
