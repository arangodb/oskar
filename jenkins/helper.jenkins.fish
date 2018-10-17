#!/usr/bin/env fish

function prepareOskar
  set -xg OSKAR oskar

  if test "$OSKAR_BRANCH" = ""
    set -xg OSKAR_BRANCH "master"
  end

  mkdir -p "$HOME/$NODE_NAME" ; cd "$HOME/$NODE_NAME"
  if not cd $OSKAR ^ /dev/null 
    git clone -b $OSKAR_BRANCH https://github.com/arangodb/oskar $OSKAR ; and cd $OSKAR
  else
    git fetch ; and git reset --hard ; and git checkout $OSKAR_BRANCH ; and git reset --hard origin/$OSKAR_BRANCH
  end
  and source helper.fish
  if test $status -ne 0 ; echo Did not find oskar and helpers ; exit 1 ; end
end
