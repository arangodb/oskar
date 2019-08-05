#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and includeGrey
and includeNondeterministic
and includeTimeCritical
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and showConfig
and compiler "$COMPILER_VERSION"
and oskar1Full

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; setAllLogsToWorkspace ; moveResultsToWorkspace ; unlockDirectory 
exit $s

