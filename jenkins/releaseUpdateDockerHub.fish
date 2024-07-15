#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test "$RELEASE_TYPE" = "stable"
  echo "build a stable version, updating docker hub"
else if test "$RELEASE_TYPE" = "preview"
  echo "building an preview, not updating docker hub"
  exit 0
else
  echo "unknown RELEASE_TYPE '$RELEASE_TYPE'"
  exit 1
end

set REGCTL_PATH "/tmp/regctl-linux-amd64"

function downloadLatestRegctl
  set -l meta (curl -s -L "https://api.github.com/repos/regclient/regclient/releases/latest")
  or begin ; echo "Finding download asset failed for latest regctl" ; exit 1 ; end
  set REGCTL_VER (echo $meta | jq -r ".name")
  or begin ; echo "Could not parse downloaded JSON" ; exit 1 ; end
  rm -rf /tmp/regctl-linux-amd64
  curl -s -L -o "$REGCTL_PATH" "https://github.com/regclient/regclient/releases/download/$REGCTL_VER/regctl-linux-amd64"
  and chmod 755 "$REGCTL_PATH"
  or begin ; echo "Failed to download regctl $REGCTL_VER" ; exit 1 ; end
end

function updateDockerHub
  set -l to $argv[1]
  set -l from $to-preview
  set -l tag $argv[2]
  set -l suffix $argv[3]

  set -l REGCTL_COPY "$REGCTL_PATH image copy"
  echo "Copying $from to $to"

  eval "$REGCTL_COPY arangodb/$from:$tag$suffix arangodb/$to:$tag$suffix"
  and eval "$REGCTL_COPY arangodb/$from:$tag$suffix arangodb/$to:$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR$suffix"
  and if test "$RELEASE_IS_HEAD" = "true"
        eval "$REGCTL_COPY arangodb/$from:$tag$suffix arangodb/$to:latest$suffix"
      end
  and if test "$GCR_REG" = "On"
        eval "$REGCTL_COPY arangodb/$to:$tag$suffix $GCR_REG_PREFIX""arangodb/$to:$tag$suffix"
        and eval "$REGCTL_COPY arangodb/$to:$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR$suffix $GCR_REG_PREFIX""arangodb/$to:$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR$suffix"
        and if test "$RELEASE_IS_HEAD" = "true"
              eval "$REGCTL_COPY arangodb/$to:latest$suffix $GCR_REG_PREFIX""arangodb/$to:latest$suffix"
            end
      end
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and downloadLatestRegctl
and if test "$UPDATE_COMMUNITY" = "true"
      updateDockerHub arangodb $DOCKER_TAG
    end
and if test "$UPDATE_ENTERPRISE" = "true"
      updateDockerHub enterprise $DOCKER_TAG
    end
and if test "$UPDATE_UBI" = "true"
      updateDockerHub enterprise $DOCKER_TAG "-ubi"
    end
and if test "$UPDATE_DEB" = "true"
      updateDockerHub enterprise $DOCKER_TAG "-deb"
    end

set -l s $status
unlockDirectory
exit $s
