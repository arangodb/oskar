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
  and if test "$ARANGODB_VERSION_MAJOR" -eq 3
        if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
          echo "Copying COMMUNITY"
          and gsutil -m rsync -c -x 'index\.html' -r $ARANGODB_PACKAGES/packages/Community gs://download.arangodb.com/$ARANGODB_REPO/Community
        else
          echo "Copying only COMMUNITY (part) SOURCE for 3.12.5+ EE!"
        end
      end
  and gsutil -m rsync -c -x 'index\.html' -r $ARANGODB_PACKAGES/source gs://download.arangodb.com/Source
  and echo "Copying ENTERPRISE"
  and gsutil -m rsync -c -x 'index\.html' -r $ARANGODB_PACKAGES/packages/Enterprise gs://download.arangodb.com/$ENTERPRISE_DOWNLOAD_KEY/$ARANGODB_REPO/Enterprise
end

function uploadWindowsSymbols
  ssh root@symbol.arangodb.biz "cd /script/ && python program.py /mnt/symsrv_arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR"
  and ssh root@symbol.arangodb.biz "gsutil -m rsync -r /mnt/symsrv_arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR gs://download.arangodb.com/symsrv_arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR"
end

# there might be internet hickups
upload
or upload
or upload
or upload

# there might be internet hickups
#uploadWindowsSymbols
#or uploadWindowsSymbols

set -l s $status
unlockDirectory
exit $s
