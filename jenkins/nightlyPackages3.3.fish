#!/usr/bin/fish
source jenkins/helper/jenkins.fish

cleanPrepareOskarLockUpdateClear
and switchBranches 3.3 3.3 true
and makeRelease

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

