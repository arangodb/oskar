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
  set -l tag $argv[2]

  echo "Copying $from to $to"

  docker pull arangodb/$from:$tag
  and docker tag arangodb/$from:$tag arangodb/$to:$tag
  and docker push arangodb/$to:$tag
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and if test -z "$UPDATE_COMMUNITY"; or test "$UPDATE_COMMUNITY" = "true"
  updateDockerHub arangodb "$DOCKER_TAG-noavx"
end
and if test -z "$UPDATE_ENTERPRISE"; or test "$UPDATE_ENTERPRISE" = "true"
  updateDockerHub enterprise "$DOCKER_TAG-noavx"
end
and if test -z "$UPDATE_UBI"; or test "$UPDATE_UBI" = "true"
  updateDockerHub enterprise "$DOCKER_TAG-ubi-noavx"
end

set -l s $status
unlockDirectory
exit $s
