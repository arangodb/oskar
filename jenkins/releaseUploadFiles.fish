#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test -z "$ENTERPRISE_DOWNLOAD_KEY"
  echo "ENTERPRISE_DOWNLOAD_KEY required"
  exit 1
end

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

function upload
  cd /mnt/buildfiles/stage2
  and gsutil rsync -r 3.4/source gs://download.arangodb.com/Source
  and gsutil rsync -r 3.4/packages/Community gs://download.arangodb.com/$ARANGODB_REPO/Community
  and gsutil rsync -r 3.4/repositories/Community/Debian gs://download.arangodb.com/$ARANGODB_REPO/DEBIAN
  and gsutil rsync -r 3.4/repositories/Community/RPM gs://download.arangodb.com/$ARANGODB_REPO/RPM
  and gsutil rsync -r 3.4/packages/Enterprise gs://download.arangodb.com/$ENTERPRISE_DOWNLOAD_KEY/$ARANGODB_REPO/Enterprise
  and gsutil rsync -r 3.4/repositories/Enterprise/Debian gs://download.arangodb.com/$ENTERPRISE_DOWNLOAD_KEY/$ARANGODB_REPO/DEBIAN
  and gsutil rsync -r 3.4/repositories/Enterprise/RPM gs://download.arangodb.com/$ENTERPRISE_DOWNLOAD_KEY/$ARANGODB_REPO/RPM
end

# there might be internet hickups
upload
or upload
or upload
or upload

set -l s $status
unlockDirectory
exit $s
