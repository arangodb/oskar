#!/bin/bash

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew tap caskroom/versions
brew update

brew install ccache
brew install fish
brew install cmake
brew install htop
brew install node
brew install python@2
brew install ruby
brew install jq
brew install git
brew install zabbix --without-server-proxy
brew install moreutils --without-parallel

brew cask install java8

sudo gem install rspec
sudo gem install httparty
sudo gem install persistent_httparty

brew upgrade
brew link --overwrite python@2

sudo  /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -configure -allowAccessFor -allUsers -configure -restart -agent -privs -all

echo import .p12 manually
#security unlock-keychain -p $PASSWD
#security import ./MacBuildCertificates.p12 -P $PASSWD
 