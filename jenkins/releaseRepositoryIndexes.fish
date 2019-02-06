#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

source jenkins/helper.jenkins.fish ; prepareOskar

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and cd file-browser
and python program.py /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/Community

set -l s $status
unlockDirectory
exit $s
