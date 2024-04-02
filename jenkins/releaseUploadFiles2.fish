#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test -z "$ENTERPRISE_DOWNLOAD_KEY"
  echo "ENTERPRISE_DOWNLOAD_KEY required"
  exit 1
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

function upload
  cd /mnt/buildfiles/stage2
  and echo "Copying COMMUNITY"
  and gsutil -m rsync -c -x 'index\.html|Packages.*|Release.*' -r $ARANGODB_PACKAGES/repositories/Community/Debian gs://download.arangodb.com/$ARANGODB_REPO/DEBIAN
  and echo "Copying ENTERPRISE"
  and gsutil -m rsync -c -x 'index\.html|Packages.*|Release.*' -r $ARANGODB_PACKAGES/repositories/Enterprise/Debian gs://download.arangodb.com/$ENTERPRISE_DOWNLOAD_KEY/$ARANGODB_REPO/DEBIAN
end

# there might be internet hickups
upload
or upload
or upload
or upload

set -l s $status
unlockDirectory
exit $s
