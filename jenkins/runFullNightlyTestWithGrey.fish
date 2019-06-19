#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

eval $EDITION ; eval $STORAGE_ENGINE ; eval $TEST_SUITE ; includeGrey; includeNondeterministic; includeTimeCritical

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and compiler "$COMPILER_VERSION"
and oskar1Full

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; setAllLogsToWorkspace ; moveResultsToWorkspace ; unlockDirectory 
exit $s

