#!/usr/bin/env fish

echo Directory (pwd)

if test -z "$IS_JENKINS" ; set -xg IS_JENKINS "true"
else ; set -gx IS_JENKINS $IS_JENKINS ; end

# set -xg GIT_TRACE_PACKET 1
# set -xg GIT_TRACE 1
# set -xg GIT_CURL_VERBOSE 1

function prepareOskar
  set -xg OSKAR oskar

  if test "$OSKAR_BRANCH" = ""
    set -xg OSKAR_BRANCH "master"
  end

  mkdir -p "$HOME/$NODE_NAME" ; cd "$HOME/$NODE_NAME"

  git config --global http.postBuffer 524288000
  and git config --global https.postBuffer 524288000
  and if not cd $OSKAR > /dev/null
    echo clone --progress  -b $OSKAR_BRANCH ssh://git@github.com/arangodb/oskar $OSKAR
    git clone --progress  -b $OSKAR_BRANCH ssh://git@github.com/arangodb/oskar $OSKAR ; and cd $OSKAR
  else
    echo git checkout -f $OSKAR_BRANCH
    git fetch --tags -f ; and git fetch --force ; and git reset --hard ; and git checkout -f $OSKAR_BRANCH ; and git reset --hard origin/$OSKAR_BRANCH
  end
  and echo "oskar updated"
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

  mkdir -p work;
  #pushd work; and find . -not -name 'ArangoDB' -delete; popd
  begin test -f $HOME/.gcs-credentials; and cp $HOME/.gcs-credentials work/.gcs-credentials; end; or true
end

function clearMachine
  python3 jenkins/helper/clear_machine.py
end

function cleanBranchName
  echo $argv[1] | sed -e 's:[^-a-zA-Z0-9_/#.+]::g'
end

function cleanJenkinsParameter
  set -l cleaned (cleanBranchName $ARANGODB_BRANCH);   set -xg ARANGODB_BRANCH   $cleaned
  set -l cleaned (cleanBranchName $ENTERPRISE_BRANCH); set -xg ENTERPRISE_BRANCH $cleaned
  set -l cleaned (cleanBranchName $OSKAR_BRANCH);      set -xg OSKAR_BRANCH      $cleaned
  set -l cleaned (cleanBranchName $RELEASE_TAG);       set -xg RELEASE_TAG       $cleaned
end

function cleanPrepareLockUpdateClear
  if test "$IS_JENKINS" = "true"
    cleanJenkinsParameter
    and prepareOskar
    and lockDirectory
    and updateOskar
    and clearResults
    and clearMachine
  else
    source helper.fish
  end
end

function cleanPrepareLockUpdateClear2
  if test "$IS_JENKINS" = "true"
    cleanJenkinsParameter
    and prepareOskar
    and lockDirectory
    and updateOskarOnly
    and clearResults
    and clearMachine
  else
    source helper.fish
  end
end

function TT_init
  set -g TT_filename work/totalTimes.csv
  and set -g TT_date (date +%Y%m%d)
  and set -g TT_t1 (date +%s)
  and rm -f $TT_filename
end

function TT_setup
  set -g TT_t2 (date +%s)
  and echo "$TT_date,setup,"(expr $TT_t2 - $TT_t1) >> $TT_filename
end

function TT_compile
  set -g TT_t3 (date +%s)
  and if test -f work/buildTimes.csv
    awk -F, "{print \"$TT_date,\" \$2 \",\" \$3}" < work/buildTimes.csv >> $TT_filename
    and rm -f work/buildTimes.csv
  end
end

function TT_tests
  set -g TT_t4 (date +%s)
  and echo "$TT_date,tests,"(expr $TT_t4 - $TT_t3) >> $TT_filename
end
