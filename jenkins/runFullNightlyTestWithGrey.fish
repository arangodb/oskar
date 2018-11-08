#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

eval $EDITION ; eval $STORAGE_ENGINE ; eval $TEST_SUITE ; includeGrey

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and parallelism 20
and compiler "$COMPILER_VERSION"
and oskar1Full

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

