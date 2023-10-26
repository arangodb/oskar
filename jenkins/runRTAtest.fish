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
if test "$ASAN" = "true"
   echo "San build"
   sanOn
   and buildSanFlags "$WORKDIR/work/ArangoDB"
end
if test "$DEBUG_BUILD = "true"
   echo "switching to debug build"
   debugMode
end
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

set -l matches $WORKDIR/work/release-test-automation/test_dir/*.{asc,testfailures.txt,deb,dmg,rpm,7z,tar.gz,tar.bz2,zip,html,csv,tar,png}
for f in $matches
   echo $f | grep -qv testreport ; and echo "mv $f $WORKSPACE" ; and mv $f $WORKSPACE; or echo "skipping $f"
end

unlockDirectory

exit $s
