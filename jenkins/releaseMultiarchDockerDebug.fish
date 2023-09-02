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
and if test "$EDITION" = "All"; or test "$EDITION" = "Community"
      community
      makeDockerMultiarchDebug "$DOCKER_TAG"
    end
and if test "$EDITION" = "All"; or test "$EDITION" = "Enterprise"
      enterprise
      makeDockerMultiarchDebug "$DOCKER_TAG"
    end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
