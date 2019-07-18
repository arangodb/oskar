#!/usr/bin/env fish
#if test (count $argv) -lt 1
#  echo usage: (status current-filename) "<destination>"
#  exit 1
#end
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

set -xg SRC .
set -xg DST /mnt/buildfiles/stage1/$RELEASE_TAG

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

for pattern in "arangodb3-*.dmg" "arangodb3-macosx-*.tar.gz"
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

for pattern in "arangodb3e-*.dmg" "arangodb3e-macosx-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
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
