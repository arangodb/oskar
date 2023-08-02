#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and ccacheOff
and releaseBuildRepoInfo
and makeEnterpriseRelease

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
