#!/usr/bin/env fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

set -xg SRC .
set -xg DST /mnt/buildfiles/stage1/$RELEASE_TAG

umask 000
not test -d $DST/release/snippets; and mkdir -p $DST/release/snippets
not test -d $DST/release/source; and mkdir -p $DST/release/source
for e in Community Enterprise
  not test -d $DST/release/packages/$e/Linux; and mkdir -p $DST/release/packages/$e/Linux
end

set -g s 0

for pattern in "arangodb3_*.deb" "arangodb3-*.deb" "arangodb3-*.rpm" "arangodb3-linux-*.tar.gz" "arangodb3-client-linux-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Community/Linux ; or set -g s 1
  end
end

for pattern in "arangodb3e_*.deb" "arangodb3e-*.deb" "arangodb3e-*.rpm" "arangodb3e-linux-*.tar.gz" "arangodb3e-client-linux-*.tar.gz"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/packages/Enterprise/Linux ; or set -g s 1
  end
end

for pattern in "*.html"
  set files (pushd $SRC ; and find . -maxdepth 1 -type f -name "$pattern" ; and popd)
  for file in $files
    cp -a $SRC/$file $DST/release/snippets ; or set -g s 1
  end
end

set -l s $status
exit $s
