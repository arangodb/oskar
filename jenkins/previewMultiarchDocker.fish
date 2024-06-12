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

if test -z "$EDITION"
  echo "EDITION required"
  exit 1
end

if test -z "$BUILDMODE"
  echo "BUILDMODE required"
  exit 1
else
  if test "$BUILDMODE" = "Debug"
    set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG_JENKINS-debug"
  end
end

cleanPrepareLockUpdateClear
and set -xg RELEASE_TYPE "preview"
if test (string lower "$EDITION") = "community"; or test (string lower "$EDITION") = "all"
  community
  makeDockerMultiarch "$DOCKER_TAG_JENKINS"
end
if test (string lower "$EDITION") = "enterprise"; or test (string lower "$EDITION") = "all"
  enterprise
  makeDockerMultiarch "$DOCKER_TAG_JENKINS"
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
