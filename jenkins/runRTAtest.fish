#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
TT_init
set RTA_EDITION "C"
if test "$ENTERPRISEEDITION" = "On"
   set RTA_EDITION "EP"
end

and eval $EDITION
and eval $TEST_SUITE
and setAllLogsToWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
and pingDetails
and TT_setup
and oskarCompile
and TT_compile
and downloadAuxBinariesToBuildBin

and checkoutRTA
and cd work/release-test-automation/
# git checkout $RTA_BRANCH
and bash -x ./jenkins/oskar_tar.sh --edition $RTA_EDITION $ADDITIONAL_PARAMS
exit $s
