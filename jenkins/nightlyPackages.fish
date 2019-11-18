#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

set -xg PACKAGES "$ARANGODB_PACKAGES"

set -xg SRC work

function mountStage2
  if test "$SYSTEM_IS_MACOSX" = "true"
    if test (sw_vers -productVersion | cut -d. -f2) -ge 15
      mkdir -p /System/Volumes/Data/Users/Shared/mnt/buildfiles
      if not test -d /System/Volumes/Data/Users/Shared/mnt/buildfiles/stage2
        echo "CATALINA"
        sudo mount -t nfs -o "noowners,nolockd,resvport,hard,bg,intr,rw,tcp,nfc" nas02.arangodb.biz:/volume1/buildfiles /System/Volumes/Data/Users/Shared/mnt/buildfiles
      end
      set -xg DST /System/Volumes/Data/Users/Shared/mnt/buildfiles/stage2/nightly/$PACKAGES
    else
      echo "NON CATALINA"
      set -xg DST /mnt/buildfiles/stage2/nightly/$PACKAGES
    end
  else
    set -xg DST /mnt/buildfiles/stage2/nightly/$PACKAGES
  end
end

mountStage2
echo "$DST"

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

  for pattern in "arangodb3*-*.dmg" "arangodb3*-mac*-*.tar.gz"
    set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
    for file in $files
      mv $SRC/$file $DST/MacOSX ; or set -g s 1
    end
  end

  return $s
end

cleanPrepareLockUpdateClear
and movePackagesToStage2

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
