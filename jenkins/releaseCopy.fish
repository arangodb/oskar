#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

set -xg SRC .
set -xg DST /mnt/buildfiles/stage1/$RELEASE_TAG

if test (uname) = "Darwin"
  if test (sw_vers -productVersion | cut -d. -f1 -f2) -ge 10.15
    echo "Use 10.15+ specific stage2 mount to /Users/$USER/buildfiles"
    if not test -d /System/Volumes/Data/Users/$USER/buildfiles
      mkdir -p /System/Volumes/Data/Users/$USER/buildfiles
    end
    if not test (mount | grep -c -e "nas01.arangodb.biz:/volume1/buildfiles on /Users/$USER/buildfiles") = 1
      mount -t nfs -o "nodev,noowners,nosuid,rw,nolockd,hard,bg,intr,tcp,nfc" nas01.arangodb.biz:/volume1/buildfiles /System/Volumes/Data/Users/$USER/buildfiles
      or exit 1
    end
    set -xg DST /System/Volumes/Data/Users/$USER/buildfiles/stage1/$RELEASE_TAG
  end
end

umask 000
mkdir -p $DST/release/snippets
mkdir -p $DST/release/source
and for e in Community Enterprise
  for d in Linux Windows MacOSX
    mkdir -p $DST/release/packages/$e/$d
  end
end

set -g s 0

for pattern in "arangodb3_*.deb" "arangodb3-*.deb" "arangodb3-*.rpm" "arangodb3-linux-*.tar.gz" "arangodb3-client-linux-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Community/Linux ; or set -g s 1
  end
end

for pattern in "arangodb3-*.dmg" "arangodb3-macos*-*.tar.gz" "arangodb3-client-macos*-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Community/MacOSX ; or set -g s 1
  end
end

for pattern in "ArangoDB3-*.exe" "ArangoDB3-*.zip"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Community/Windows ; or set -g s 1
  end
end

for pattern in "arangodb3e_*.deb" "arangodb3e-*.deb" "arangodb3e-*.rpm" "arangodb3e-linux-*.tar.gz" "arangodb3e-client-linux-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Enterprise/Linux ; or set -g s 1
  end
end

for pattern in "arangodb3e-*.dmg" "arangodb3e-macos*-*.tar.gz" "arangodb3e-client-macos*-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    rm -f $DST/release/packages/Enterprise/MacOSX/$file
    cp -a $SRC/$file $DST/release/packages/Enterprise/MacOSX ; or set -g s 1
  end
end

for pattern in "ArangoDB3e-*.exe" "ArangoDB3e-*.zip"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Enterprise/Windows ; or set -g s 1
  end
end

for pattern in "ArangoDB-*.tar.gz" "ArangoDB-*.tar.gz.asc" "ArangoDB-*.tar.bz2" "ArangoDB-*.tar.bz2.asc" "ArangoDB-*.zip" "ArangoDB-*.zip.asc"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/source ; or set -g s 1
  end
end

for pattern in "*.html"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/snippets ; or set -g s 1
  end
end

exit $s
