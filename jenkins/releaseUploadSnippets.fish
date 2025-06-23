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

set META kmajv4agbby8qytdoqnqxeb904vbd5zk1mpq.arangodb.com

rm -f /tmp/index.html
echo "<html><body></body></html>" > /tmp/index.html

function uploadMeta
  cd /mnt/buildfiles/stage2
  and if test "$ARANGODB_VERSION_MAJOR" -eq 3
        if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
          gsutil cp $ARANGODB_PACKAGES/snippets/Community/meta.json gs://$META/wpv0cu548xhrw6h5carxr7s0rt8an71388mvx05znw/meta-community-$ARANGODB_PACKAGES.json
        end
      end
  and gsutil cp $ARANGODB_PACKAGES/snippets/Enterprise/meta.json gs://$META/wpv0cu548xhrw6h5carxr7s0rt8an71388mvx05znw/meta-enterprise-$ARANGODB_PACKAGES.json
  and gsutil cp /tmp/index.html gs://$META/index.html
end

# there might be internet hickups
uploadMeta

set -l s $status
unlockDirectory
exit $s
