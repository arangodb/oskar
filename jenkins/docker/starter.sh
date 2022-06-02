#!/bin/bash

agentstarted=

if test -z "$SSH_AUTH_SOCK"; then
  sudo killall --older-than 8h ssh-agent 2>&1 > /dev/null
  eval `ssh-agent` > /dev/null

  for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_deploy; do
    if test -f $key; then
      ssh-add $key
    fi
  done

  agentstarted=1
fi

docker run -v $HOME/.ssh:/root/.ssh arangodb/ssh-client ssh -o StrictHostKeyChecking=no -T git@github.com

docker run \
       -e "PDOCKER=`getent group docker | cut -d: -f3`" \
       -e "PGID=`id -g`" \
       -e "PHOME=$HOME" \
       -e "PPWD=`pwd`" \
       -e "PUID=`id -u`" \
       -e "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" \
       \
       -e "ARANGODB_BRANCH=$ARANGODB_BRANCH" \
       -e "BASE_VERSION=$BASE_VERSION" \
       -e "EDITION=$EDITION" \
       -e "ENTERPRISE_BRANCH=$ENTERPRISE_BRANCH" \
       -e "NODE_NAME=$NODE_NAME" \
       -e "OSKAR_BRANCH=$OSKAR_BRANCH" \
       -e "STORAGE_ENGINE=$STORAGE_ENGINE" \
       -e "TEST_SUITE=$TEST_SUITE" \
       \
       -v "$HOME:$HOME" \
       -v "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK" \
       -v "/var/run/docker.sock:/var/run/docker.sock" \
       -v "/mnt/buildfiles:/mnt/buildfiles" \
       arangodb/oskar $*

result=$?

if test -n "$agentstarted"; then
  ssh-agent -k > /dev/null
  unset -v SSH_AUTH_SOCK
  unset -v SSH_AGENT_PID
fi

exit $result
