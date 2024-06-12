#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test -z "$EDITION"
  echo "EDITION required"
  exit 1
end

cleanPrepareLockUpdateClear
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and set -xg RELEASE_TYPE "preview"
and if test "$EDITION" = "All"; or test "$EDITION" = "Community"
      community
      makeDockerMultiarch "$DOCKER_TAG"
    end
and if test "$EDITION" = "All"; or test "$EDITION" = "Enterprise"
      enterprise
      makeDockerMultiarch "$DOCKER_TAG"
    end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
