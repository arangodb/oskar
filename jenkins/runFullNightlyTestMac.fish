#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

eval $EDITION ; eval $STORAGE_ENGINE ; eval $TEST_SUITE ; skipGrey
set logical_cores (sysctl -n hw.ncpu)
parallelism (math "$logical_cores*2")

echo "--------------------------------------------------------------------------------"
showConfig

echo Working on branch $ARANGODB_BRANCH of main repository and
echo on branch $ENTERPRISE_BRANCH of enterprise repository.

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and oskar1Full

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

