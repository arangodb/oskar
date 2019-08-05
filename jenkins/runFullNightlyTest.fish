#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and compiler "$COMPILER_VERSION"
and showConfig
and oskar1Full

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; setAllLogsToWorkspace ; moveResultsToWorkspace ; unlockDirectory 
exit $s

