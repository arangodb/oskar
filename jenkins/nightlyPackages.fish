#!/usr/bin/env fish
if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

set -xg PACKAGES "$ARANGODB_PACKAGES"

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

function movePackagesToStage2
 findArangoDBVersion

  set -xg SRC work
  set -xg DST /mnt/buildfiles/stage2/nightly/$PACKAGES

  if test "$SYSTEM_IS_LINUX" = "true"
    rm -rf $DST/Linux
    and mkdir -p $DST/Linux
    or return 1
  end

  for pattern in "arangodb3_*.deb" "arangodb3-*.deb" "arangodb3-*.rpm" "arangodb3-linux-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      mv $SRC/$file $DST/Linux ; or set -g s 1
    end
  end

  if test "$SYSTEM_IS_MACOSX" = "true"
    rm -rf $DST/MacOSX
    and mkdir -p $DST/MacOSX
    or return 1
  end

  for pattern in "arangodb3-*.dmg" "arangodb3-macosx-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      mv $SRC/$file $DST/Linux ; or set -g s 1
    end
  end

  return $s
end

function createIndex
  cd $WORKSPACE/file-browser
  and rm -f file-browser.out
  and rm -rf root-dir
  and mkdir -p root-dir/$PACKAGES
  and ln -s /mnt/buildfiles/stage2/nightly/$PACKAGES root-dir/$PACKAGES
  and rm -f program2.py
  and sed -e 's/os\.walk(root)/os\.walk(root,followlinks=True)/' program.py > program2.py
  and python program2.py root-dir > file-browser.out 2>&1
end

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and setNightlyRelease
and makeRelease
and movePackagesToStage2
and createIndex

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

