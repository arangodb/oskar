#!/usr/bin/env fish

function setupSourceInfo
  set -l field $argv[1]
  set -l value $argv[2]
  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"
  sed -i$suffix -E 's/^'"$field"':.*$/'"$field"': '"$value"'/g' $INNERWORKDIR/sourceInfo.log
end

function checkoutRepo
  if test (count $argv) -ne 2
      echo "Checkout needs two parameters branch force"
      return 1
  end
  set -l branch (string trim $argv[1])
  set -l clean $argv[2]

  git checkout -- .
  and git fetch --tags -f
  and git fetch --all -f
  and git submodule deinit --all -f
  and git checkout -f "$branch"
  and if test "$clean" = "true"
    if echo "$branch" | grep -q "^v"
      git checkout -- .
    else
      git fetch --force --all origin
      git reset --hard "$branch"
    end
    and git clean -fdx
  else
    if echo "$branch" | grep -q "^v"
      git checkout --
    else
      git pull
    end
  end
  git submodule update --init --force
  return $status
end

if test "$argv[1]" = "help"
    echo "\

usage: switchBranches <community> <enterprise> [<clean>]

  Checkout the <community> branch of the main repository and the
  <enterprise> branch of the enterprise repository. This will check
  out the branches and do a `git pull` afterwards.


  If <clean> is `true` all local modifications will be deleted.
  "
  exit 0
end    

if test (count $argv) -lt 2
    echo "you did not provide enough arguments"
    exit 1
end

set -l arango $argv[1]
set -l enterprise $argv[2]
set -l force_clean false

if test (count $argv) -eq 3
    set force_clean $argv[3]
end

cd $INNERWORKDIR/ArangoDB
and checkoutRepo $arango $force_clean
if test $status -ne 0
  echo "Failed to checkout community branch"
  setupSourceInfo "VERSION" "N/A"
  setupSourceInfo "Community" "N/A"
  exit 1
else
  setupSourceInfo "VERSION" (cat $INNERWORKDIR/ArangoDB/ARANGO-VERSION)
  setupSourceInfo "Community" (git rev-parse --verify HEAD)
end

if test $ENTERPRISEEDITION = On
  cd enterprise
  and checkoutRepo $enterprise $force_clean
  if test $status -ne 0
    echo "Failed to checkout enterprise branch"
    setupSourceInfo "Enterprise" "N/A"
    exit 1
  else
    setupSourceInfo "Enterprise" (git rev-parse --verify HEAD)
  end
end
