#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

set -g DOCKER_TAG $RELEASE_TAG

if test (string sub --length 1 "$RELEASE_TAG") = "v"
  set -g DOCKER_TAG (string sub --start 2 "$RELEASE_TAG")
end

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and showRepository
and makeDockerRelease

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

