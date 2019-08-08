#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and buildStaticArangoDB
and cppcheckArangoDB

set -l s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
