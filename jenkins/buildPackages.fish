#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

if test -z "$COPY_TO_STAGE2"
  set -xg COPY_TO_STAGE2 false
end

set -xg PACKAGES "$ARANGODB_PACKAGES"

set -xg SRC work
set -xg DST /mnt/buildfiles/stage2/nightly/$PACKAGES

function mountMacCatalinaStage2
  if test (sw_vers -productVersion | cut -d. -f1 -f2) -ge 10.15
    echo "Use 10.15+ specific stage2 mount to /Users/$USER/buildfiles"
    if not test -d /System/Volumes/Data/Users/$USER/buildfiles
      mkdir -p /System/Volumes/Data/Users/$USER/buildfiles
    end
    if not test (mount | grep -c -e "nas02.arangodb.biz:/volume1/buildfiles on /Users/$USER/buildfiles") = 1
      mount -t nfs -o "nodev,noowners,nosuid,rw,nolockd,hard,bg,intr,tcp,nfc" nas02.arangodb.biz:/volume1/buildfiles /System/Volumes/Data/Users/$USER/buildfiles
      or exit 1
    end
    set -xg DST /System/Volumes/Data/Users/$USER/buildfiles/stage2/nightly/$PACKAGES
  end
end

function copyPackagesToStage2
  echo "Moving packages to stage2..."
  umask 000

  if test "$SYSTEM_IS_LINUX" = "true"
    rm -rf $DST/Linux
    and mkdir -p $DST/Linux
    or return 1

    for pattern in "arangodb3*_*.deb" "arangodb3*-*.deb" "arangodb3*-*.rpm" "arangodb3*-linux-*.tar.gz" "sourceInfo.log"
      set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
      for file in $files
        cp $SRC/$file $DST/Linux ; or set -g s 1
      end
    end
  else if test "$SYSTEM_IS_MACOSX" = "true"
    mountMacCatalinaStage2
    and rm -rf $DST/MacOSX
    and mkdir -p $DST/MacOSX
    and chmod 777 $DST/MacOSX
    or return 1

    for pattern in "arangodb3*-*.dmg" "arangodb3*-mac*-*.tar.gz" "sourceInfo.log"
      set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
      for file in $files
        cp $SRC/$file $DST/MacOSX ; or set -g s 1
      end
    end
  else
    echo "Unknown platform!"
    set -g s 1
  end

  return $s
end

cleanPrepareLockUpdateClear
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and makeRelease
and if test "$COPY_TO_STAGE2" = "true"
  copyPackagesToStage2
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
