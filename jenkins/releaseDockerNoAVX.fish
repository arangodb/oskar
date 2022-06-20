#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

cleanPrepareLockUpdateClear
and forceDisableAVXOn
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and showRepository
and set -xg RELEASE_IS_HEAD "false"
and makeDockerRelease "$DOCKER_TAG-noavx"
and ubiDockerImage
and findArangoDBVersion
and set -xg RELEASE_IS_HEAD "false"
and makeDockerEnterpriseRelease "$DOCKER_TAG-noavx"

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

