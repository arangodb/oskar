#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
else
  set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG"
end

if test -z "$DOCKER_DISTRO"
  echo "DOCKER_DISTRO required"
  exit 1
else
  if test "$DOCKER_DISTRO" = "ubi"
    set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG_JENKINS-ubi"
  end
  if test "$DOCKER_DISTRO" = "deb"
    set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG_JENKINS-deb"
  end
end

if test -z "$IS_NIGHTLY_BUILD"
  echo "IS_NIGHTLY_BUILD required"
  exit 1
end

cleanPrepareLockUpdateClear
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
and makeDockerEnterpriseDebug "$DOCKER_TAG_JENKINS"

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
