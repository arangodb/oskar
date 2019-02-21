#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

source jenkins/helper.jenkins.fish ; prepareOskar

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and cd $WORKSPACE/file-browser
and rm -f file-browser.out
and rm -rf root-dir
and mkdir root-dir
and ln -s /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/packages/Community root-dir/$ARANGODB_PACKAGES/Community
and ln -s /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/Debian root-dir/$ARANGODB_PACKAGES/Debian
and ln -s /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/RPM root-dir/$ARANGODB_PACKAGES/RPM
and python program.py root-dir > file-browser.out 2>&1
and cp root-dir/index.html /mnt/buildfiles/stage2/$ARANGODB_PACKAGES

set -l s $status

echo "File-Browser output:"
cat file-browser.out

if fgrep -q Errno file-browser.out
  set s 1
end

unlockDirectory
exit $s
