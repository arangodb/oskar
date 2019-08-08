#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and rm -f work/test.log
and jslint > work/test.log

set -l s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
