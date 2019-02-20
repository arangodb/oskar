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
and python program.py /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/Community > file-browser.out 2>&1

set -l s $status

echo "File-Browser output:"
cat file-browser.out

if fgrep -q Errno file-browser.out
  set s 1
end

unlockDirectory
exit $s
