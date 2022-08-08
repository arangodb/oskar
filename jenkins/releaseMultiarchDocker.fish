#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
else
  set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG"
end

if test -z "$EDITION"
  echo "EDITION required"
  exit 1
end

cleanPrepareLockUpdateClear
and set -xg RELEASE_TYPE "preview"
and if test "$EDITION" = "All"; or test "$EDITION" = "Community"
      community
      makeDockerMultiarch "$DOCKER_TAG_JENKINS"
    end
and if test "$EDITION" = "All"; or test "$EDITION" = "Entreprise"
      enterprise
      makeDockerMultiarch "$DOCKER_TAG_JENKINS"
    end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
