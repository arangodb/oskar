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
# This also has to be in tests.fish
if test "$ASAN" = "true"
  sanOn
  echo "Use SAN mode: $SAN_MODE"

  set common_options "log_exe_name=true"

  switch "$SAN_MODE"
    case "AULSan"
      # address sanitizer
      set -xg ASAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/aulsan.log:handle_ioctl=true:check_initialization_order=true:detect_container_overflow=true:detect_stack_use_after_return=false:detect_odr_violation=1:strict_init_order=true"

      # leak sanitizer
      set -xg LSAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/aulsan.log"

      # undefined behavior sanitizer
      set -xg UBSAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/aulsan.log:print_stacktrace=1"

      # suppressions
      if test -f $INNERWORKDIR/ArangoDB/asan_arangodb_suppressions.txt
        set ASAN_OPTIONS "$ASAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/asan_arangodb_suppressions.txt:print_suppressions=0"
      end

      if test -f $INNERWORKDIR/ArangoDB/lsan_arangodb_suppressions.txt
        set LSAN_OPTIONS "$LSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/lsan_arangodb_suppressions.txt:print_suppressions=0"
      end

      if test -f $INNERWORKDIR/ArangoDB/ubsan_arangodb_suppressions.txt
        set UBSAN_OPTIONS "$UBSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/ubsan_arangodb_suppressions.txt:print_suppressions=0"
      end

      echo "ASAN: $ASAN_OPTIONS"
      echo "LSAN: $LSAN_OPTIONS"
      echo "UBSAN: $UBSAN_OPTIONS"
    case "TSan"
      # thread sanitizer
      set -xg TSAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/tsan.log:detect_deadlocks=true:second_deadlock_stack=1"

      # suppressions
      if test -f $INNERWORKDIR/ArangoDB/tsan_arangodb_suppressions.txt
        set TSAN_OPTIONS "$TSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/tsan_arangodb_suppressions.txt:print_suppressions=0"
      end

      echo "TSAN: $TSAN_OPTIONS"
    case '*'
      echo "Unknown sanitizer mode: $SAN_MODE"
  end
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
