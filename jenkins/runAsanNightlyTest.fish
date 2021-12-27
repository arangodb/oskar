#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and setAllLogsToWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and compiler "$COMPILER_VERSION"
and sanOn
and showConfig
and oskar1

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

