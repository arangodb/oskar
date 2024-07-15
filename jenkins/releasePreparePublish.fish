#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test (count $argv) -lt 1
  echo usage: (status current-filename) "<destination>"
  exit 1
end

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

umask 000

cleanPrepareLockUpdateClear
and cleanWorkspace

and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion

and set -xg SRC $argv[1]/stage1/$RELEASE_TAG
and set -xg DST $argv[1]/stage2/$ARANGODB_PACKAGES

and set -g SP_PACKAGES $DST
and set -g SP_SOURCE $DST/source
and set -g WS_PACKAGES $SRC/release/packages
and set -g WS_SOURCE $SRC/release/source

and echo "checking packages source directory '$WS_PACKAGES'"
and test -d $WS_PACKAGES
and echo "checking source source directory '$WS_SOURCE'"
and test -d $WS_SOURCE
and echo "creating destination directory '$DST'"
and mkdir -p $DST
and echo "creating source destination directory '$SP_SOURCE'"
and mkdir -p $SP_SOURCE

and echo "========== COPYING PACKAGES =========="
and tar -C $SRC/release -c -f - packages | tar -C $DST -x -v -f -
and echo "========== COPYING PACKAGES To gcr-for-rta =========="
and gsutil -m rsync -c -r $SRC/release gs://gcr-for-rta/$DST
and echo "========== COPYING SOURCE =========="
and tar -C $WS_SOURCE -c -f - . | tar -C $SP_SOURCE -x -v -f -

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; unlockDirectory
exit $s
