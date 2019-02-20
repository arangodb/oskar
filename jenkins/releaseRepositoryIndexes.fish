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
and python program.py /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/Community 2>&1 | tee file-browser.out

set -l s $status

if fgrep -q Errno
  set s 1
end

unlockDirectory
exit $s
