#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

function movePackagesToStage2
 findArangoDBVersion

  set -xg SRC work
  set -xg DST /mnt/buildfiles/stage2/nightly/$ARANGODB_PACKAGES

  mkdir -p $DST
  and for d in Linux Windows MacOSX
    mkdir -p $DST/$d
  end
  or return 1

  set -g s 0

  for pattern in "arangodb3_*.deb" "arangodb3-*.deb" "arangodb3-*.rpm" "arangodb3-linux-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      cp -a $SRC/$file $DST/Linux ; or set -g s 1
    end
  end

  for pattern in "arangodb3-*.dmg" "arangodb3-macosx-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      cp -a $SRC/$file $DST/Linux ; or set -g s 1
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

