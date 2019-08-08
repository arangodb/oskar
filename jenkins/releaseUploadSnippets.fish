#!/usr/bin/env fish
source jenkins/helper/jenkins.fish 

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test "$RELEASE_TYPE" != "preview" -a "$RELEASE_IS_HEAD" != "true"
  echo "building an older release, not updating snippets"
  exit 0
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

function upload
  cd /mnt/buildfiles/stage2
  set -l HOST live.9c5a08db-bfdf-42bc-9393-00c9fdf4c90f@appserver.live.9c5a08db-bfdf-42bc-9393-00c9fdf4c90f.drush.in
  set -l SSL "ssh -o StrictHostkeyChecking=false -i $HOME/.ssh/pantheon -p 2222"

  if test "$RELEASE_TYPE" = "preview"
    rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Community/ $HOST:files/d/download-technical-preview/
    and rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Enterprise/ $HOST:files/d/download-technical-preview-enterprise/
  else
    rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Community/ $HOST:files/d/download-current/
    and rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Enterprise/ $HOST:files/d/download-enterprise/
  end
end

# there might be internet hickups
upload

set -l s $status
unlockDirectory
exit $s
