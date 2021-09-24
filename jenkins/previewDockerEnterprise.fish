#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
else
  set -xg DOCKER_TAG "$DOCKER_TAG"
end

if test -z "$IS_NIGHTLY_BUILD"
  echo "IS_NIGHTLY_BUILD required"
  exit 1
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and showRepository
and if test $IS_NIGHTLY_BUILD = true; setNightlyRelease; end
and set -xg RELEASE_TYPE "preview"
and makeDockerEnterpriseRelease "$DOCKER_TAG"

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
