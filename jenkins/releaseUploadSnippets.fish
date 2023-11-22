#!/usr/bin/env fish
source jenkins/helper/jenkins.fish 

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test -z "$PANTHEON_SITE" -o "$PANTHEON_SITE" != "dev" -a "$PANTHEON_SITE" != "live"
  echo "`dev` or `live` pantheon.io should be chosen!"
  exit 1
end

if test "$RELEASE_TYPE" = "preview" -a "$RELEASE_IS_HEAD" = "true"
  echo "building a preview release can't be head"
  exit 1
end

if test "$RELEASE_TYPE" != "preview" -a "$RELEASE_IS_HEAD" != "true"
  echo "building an older release, updating only Enterprise snippets"
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

function upload
  cd /mnt/buildfiles/stage2
  set -l HOST "$PANTHEON_SITE.9c5a08db-bfdf-42bc-9393-00c9fdf4c90f@appserver.$PANTHEON_SITE.9c5a08db-bfdf-42bc-9393-00c9fdf4c90f.drush.in"
  set -l SSL "ssh -o StrictHostkeyChecking=false -i $HOME/.ssh/pantheon -p 2222"

  if test "$RELEASE_TYPE" = "preview"
    rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Community/ $HOST:files/d/download-technical-preview/
    and rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Enterprise/ $HOST:files/d/download-technical-preview-enterprise/
  else
    if test "$RELEASE_IS_HEAD" = "true"
      rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Community/ $HOST:files/d/download-current/
      and rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Enterprise/ $HOST:files/d/download-enterprise/$ARANGODB_REPO
    else
      rsync --backup --backup-dir=.backup --exclude=.backup --exclude="*~" -rvvz -e $SSL $ARANGODB_PACKAGES/snippets/Enterprise/ $HOST:files/d/download-enterprise/$ARANGODB_REPO
    end    
  end
end

set META kmajv4agbby8qytdoqnqxeb904vbd5zk1mpq.arangodb.com

rm -f /tmp/index.html
echo "<html><body></body></html>" > /tmp/index.html

function uploadMeta
  cd /mnt/buildfiles/stage2
  and if test "$RELEASE_IS_HEAD" = "true"
        echo "Copying COMMUNITY meta.json"
        and gsutil cp $ARANGODB_PACKAGES/snippets/Community/meta.json gs://$META/wpv0cu548xhrw6h5carxr7s0rt8an71388mvx05znw/meta-community.json
      else
        echo "Skipping COMMUNITY meta.json"
      end
  and gsutil cp $ARANGODB_PACKAGES/snippets/Enterprise/meta.json gs://$META/wpv0cu548xhrw6h5carxr7s0rt8an71388mvx05znw/meta-enterprise-$ARANGODB_PACKAGES.json
  and gsutil cp /tmp/index.html gs://$META/index.html
end

# there might be internet hickups
# upload
uploadMeta

set -l s $status
unlockDirectory
exit $s
