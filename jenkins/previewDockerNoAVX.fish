#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
else
  set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG"
end

if test -z "$IS_NIGHTLY_BUILD"
  echo "IS_NIGHTLY_BUILD required"
  exit 1
end

cleanPrepareLockUpdateClear
and forceDisableAVXOn
and cleanWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and if test "$USE_EXISTING_BUILD" = "On"
      unpackBuildFilesOn ; packBuildFilesOff
      moveResultsFromWorkspace
    end
and if test $IS_NIGHTLY_BUILD = true; setNightlyVersion; end
and set -xg RELEASE_TYPE "preview"
and showRepository
and showConfig
and pingDetails
and set -xg RELEASE_IS_HEAD "false"
and makeDockerRelease "$DOCKER_TAG_JENKINS-noavx"

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
