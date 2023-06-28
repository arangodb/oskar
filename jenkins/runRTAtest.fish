#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
TT_init
set RTA_EDITION "C"

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
if test "$ENTERPRISEEDITION" = "On"
   set RTA_EDITION "EP"
end
and bash -x ./jenkins/oskar_tar.sh --edition $RTA_EDITION $argv

set -l s $status

# compiling results:
moveResultsToWorkspace
# RTA leaves its results here:
cd test_dir
set wd "$WORKDIR"
set set -gx WORKDIR (pwd)
moveResultsToWorkspace
set WORKDIR "$wd"
unlockDirectory

exit $s
