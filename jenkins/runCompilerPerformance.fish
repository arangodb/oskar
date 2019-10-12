#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and pingDetails
and ccacheOff
and buildStaticArangoDB

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
