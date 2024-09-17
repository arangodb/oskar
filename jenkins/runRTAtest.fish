#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
TT_init
set -xg RTA_EDITION "C,Cr2"

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
if test "$BUILD_MODE" = "debug"
   echo "switching to debug build"
   debugMode
end
if test "$BUILD_MODE" = "release"
   echo "switching to release build"
   releaseMode
end
and pingDetails
and TT_setup
and oskarCompile
and TT_compile
and downloadAuxBinariesToBuildBin

if test "$SAN" = "On"
     $INNERWORKDIR/ArangoDB/utils/llvm-symbolizer-server.py > $INNERWORKDIR/symbolizer.log  2>&1 &
end


and checkoutRTA
and cd work/release-test-automation/
if test "$ENTERPRISEEDITION" = "On"
   set -xg RTA_EDITION "EP,EPr2"
end
and bash -x ./jenkins/oskar_tar.sh $argv

if test "$SAN" = "On"
   jobs
   kill %1
end

set -l s $status

# compiling results:
moveResultsToWorkspace

set -l matches $WORKDIR/work/release-test-automation/test_dir/*.{asc,testfailures.txt,deb,dmg,rpm,7z,tar.gz,tar.bz2,zip,html,csv,tar,png}
for f in $matches
   echo $f | grep -qv testreport ; and echo "mv $f $WORKSPACE" ; and mv $f $WORKSPACE; or echo "skipping $f"
end

unlockDirectory

exit $s
