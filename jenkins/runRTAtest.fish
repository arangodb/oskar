#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
and TT_init

and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and setAllLogsToWorkspace

and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
and pingDetails
and TT_setup
and oskarCompile
and TT_compile

and downloadStarter
and downloadSyncer
and copyRclone
and checkoutRTA

pwd
cd work/release-test-automation/
./jenkins/oskar_tar.sh
# cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
