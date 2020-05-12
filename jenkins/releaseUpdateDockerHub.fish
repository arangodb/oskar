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

function updateDockerHub
  set -l to $argv[1]
  set -l from $to-preview
  set -l version $argv[2]

  echo "Copying $from to $to"

  docker pull arangodb/$from:$version
  and docker tag arangodb/$from:$version arangodb/$to:$version
  and docker push arangodb/$to:$version
  and if test "$RELEASE_IS_HEAD" = "true"
    docker tag arangodb/$from:$version arangodb/$to:latest
    docker push arangodb/$to:latest
  end
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and if test -z "$UPDATE_COMMUNITY"; or test "$UPDATE_COMMUNITY" = "true"
  updateDockerHub arangodb $DOCKER_TAG
end
and if test -z "$UPDATE_ENTERPRISE"; or test "$UPDATE_ENTERPRISE" = "true"
  updateDockerHub enterprise $DOCKER_TAG
end
and set -xg RELEASE_IS_HEAD false
and if test -z "$UPDATE_UBI"; or test "$UPDATE_UBI" = "true"
  updateDockerHub enterprise $DOCKER_TAG-ubi
end

set -l s $status
unlockDirectory
exit $s
