#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareOskarLockUpdateClear
and eval $EDITION
and catchtest
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and showConfig
and oskar1

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

