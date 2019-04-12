#!/usr/bin/env fish
if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

set -xg PACKAGES "$ARANGODB_PACKAGES"

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

function upload
  cd /mnt/buildfiles/stage2/nightly
  and echo "Copying NIGHTLY"
  and gsutil rsync -d -r $PACKAGES gs://download.arangodb.com/nightly/$PACKAGES
end

# there might be internet hickups
upload
or upload
or upload
or upload

set -l s $status
unlockDirectory
exit $s
