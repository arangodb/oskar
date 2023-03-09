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

if test -z "$MODE"
  echo "MODE required"
  exit 1
else
  if test "$MODE" = "DEBUG"
    set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG_JENKINS-debug"
  end
end

cleanPrepareLockUpdateClear
and set -xg RELEASE_TYPE "preview"
if test "$EDITION" = "All"; or test "$EDITION" = "Community"
  community
  makeDockerMultiarch "$DOCKER_TAG_JENKINS"
end
if test "$EDITION" = "All"; or test "$EDITION" = "Entreprise"
  enterprise
  makeDockerMultiarch "$DOCKER_TAG_JENKINS"
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
