#!/usr/bin/env fish

echo Directory (pwd)

function prepareOskar
  set -xg OSKAR oskar

  if test "$OSKAR_BRANCH" = ""
    set -xg OSKAR_BRANCH "master"
  end

  mkdir -p "$HOME/$NODE_NAME" ; cd "$HOME/$NODE_NAME"

  if not cd $OSKAR ^ /dev/null 
    git clone -b $OSKAR_BRANCH https://github.com/arangodb/oskar $OSKAR ; and cd $OSKAR
  else
    git fetch --tags ; and git fetch ; and git reset --hard ; and git checkout $OSKAR_BRANCH ; and git reset --hard origin/$OSKAR_BRANCH
  end
  and source helper.fish
  if test $status -ne 0 ; echo Did not find oskar and helpers ; exit 1 ; end

  set -l lockfile (pwd)/work/ArangoDB/.git/index.lock

  echo "Checking for lock file $lockfile"

  if test -f $lockfile
    echo "Warning: lock file $lockfile exist"

    sudo lsof -V $lockfile | fgrep -q "no file use"

    if test $status -eq 0
      echo "Removing stale lock file $lockfile"
      rm -f $lockfile
    end
  end
end
