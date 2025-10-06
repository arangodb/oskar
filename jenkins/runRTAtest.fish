#!/usr/bin/env fish
set -l fish_trace on
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
and TT_init
and set -xg RTA_EDITION "C,Cr2"
and maintainerOn
and eval $EDITION
if test "$ENTERPRISEEDITION" = "On"
   set -xg RTA_EDITION "EP,EPr2"
end
and setAllLogsToWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
or exit 1

if test -n "$SAN_MODE"
  echo "Setting additional sanitizer flags"
  # https://stackoverflow.com/questions/56104472/why-would-setting-export-openblas-num-threads-1-impair-the-performance
  set -xg OPENBLAS_NUM_THREADS 1
end

if test "$ASAN" = "true"
   echo "San build"
   sanOn
   and buildSanFlags "$WORKDIR/work/ArangoDB"
end
if test "$COVERAGE" = "true"
   echo "Coverage build"
   coverageOn
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

and setAllLogsToWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
and begin
end
and pingDetails
and TT_setup
and oskarCompile
and TT_compile
and downloadAuxBinariesToBuildBin
and checkoutRTA
and cd work/release-test-automation/
and eval "bash -x ./jenkins/oskar_tar.sh $argv"

set -l s $status

# compiling results:
moveResultsToWorkspace

set -l matches $WORKDIR/work/release-test-automation/test_dir/*.{asc,testfailures.txt,deb,dmg,rpm,7z,tar.gz,tar.bz2,zip,html,csv,tar,png}
for f in $matches
   echo $f | grep -qv testreport ; and echo "mv $f $WORKSPACE" ; and mv $f $WORKSPACE; or echo "skipping $f"
end

if test "$COVERAGE" = "true"
  collectCoverage
end

unlockDirectory

exit $s
