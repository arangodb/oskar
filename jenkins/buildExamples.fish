#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and enterprise
and rocksdb
and asanOff
and maintainerOff
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and showConfig
and buildExamples

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
