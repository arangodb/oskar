#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
and TT_init

and eval $EDITION
and catchtest
and pingDetails
and setAllLogsToWorkspace

and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
and TT_setup
and oskarCompile
and TT_compile
and oskar

set -l s $status
TT_tests

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

