#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test "$RELEASE_TYPE" = "stable"
  set -g GIT_BRANCH master
else if test "$RELEASE_TYPE" = "preview"
  echo "building an preview, not updating docker hub"
  exit 0
else
  echo "unknown RELEASE_TYPE '$RELEASE_TYPE'"
  exit 1
end

source jenkins/helper.jenkins.fish ; prepareOskar

function updateDockerHub
  set -l image argv[1]

  docker pull arangodb/$image-preview:$ARANGODB_VERSION
  and docker tag arangodb/$image-preview:$ARANGODB_VERSION arangodb/$image:$ARANGODB_VERSION
  and docker push arangodb/$image:$ARANGODB_VERSION
  and if test "$RELEASE_IS_HEAD" = "true"
    docker tag arangodb/$image-preview:$ARANGODB_VERSION arangodb/$image:latest
    docker push arangodb/$image:latest
  end
end

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and updateDockerHub arangodb
and updateDockerHub enterprise

set -l s $status
unlockDirectory
exit $s
