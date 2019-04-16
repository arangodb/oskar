#!/usr/bin/env fish
if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

set -xg PACKAGES "$ARANGODB_PACKAGES"

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

set -xg SRC work
set -xg DST /mnt/buildfiles/stage2/nightly/$PACKAGES

function movePackagesToStage2
  if test "$SYSTEM_IS_LINUX" = "true"
    rm -rf $DST/Linux
    and mkdir -p $DST/Linux
    or return 1
  end

  for pattern in "arangodb3*_*.deb" "arangodb3*-*.deb" "arangodb3*-*.rpm" "arangodb3*-linux-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      mv $SRC/$file $DST/Linux ; or set -g s 1
    end
  end

  if test "$SYSTEM_IS_MACOSX" = "true"
    rm -rf $DST/MacOSX
    and mkdir -p $DST/MacOSX
    and chmod 777 $DST/MacOSX
    or return 1
  end

  for pattern in "arangodb3*-*.dmg" "arangodb3*-macosx-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      mv $SRC/$file $DST/MacOSX ; or set -g s 1
    end
  end

  return $s
end

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and setNightlyRelease
and makeRelease
and movePackagesToStage2

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
