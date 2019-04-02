#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

function upload
  cd /mnt/buildfiles/stage2/nightly
  and echo "Copying NIGHTLY"
  and test "$ARANGODB_PACKAGES" != ""
  and gsutil rsync -n -d -r $ARANGODB_PACKAGES gs://download.arangodb.com/nightly/$ARANGODB_PACKAGES
end

# there might be internet hickups
upload
or upload
or upload
or upload

set -l s $status
unlockDirectory
exit $s
