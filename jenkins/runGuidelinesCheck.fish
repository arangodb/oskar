#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and echo ARANGODB_BRANCH: "<$ARANGODB_BRANCH>"
and echo ENTERPRISE_BRANCH: "<$ENTERPRISE_BRANCH>"
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and rm -f work/test.log
and checkLogId > work/test.log
and checkMacros >> work/test.log
and checkMetrics >> work/test.log

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
