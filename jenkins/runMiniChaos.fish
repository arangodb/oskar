#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and enterprise
and makeTestPackageLinux
and runMiniChaos (getTestPackageLinuxName)

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
