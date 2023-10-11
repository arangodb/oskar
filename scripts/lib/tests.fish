#!/usr/bin/env false

if test -z "$PARALLELISM"
  set -g PARALLELISM 64
end

if test "$ENTERPRISEEDITION" = "On"
   set -xg EncryptionAtRest "--encryptionAtRest true"
else
   set -xg EncryptionAtRest ""
end

# Turn off internal crash handler for tests that don''t specify it explicitly
# Meaningful for ArangoDB 3.7+ versions only
# set -xg ARANGODB_OVERRIDE_CRASH_HANDLER "Off"

# Clear sanitizers options
set -e ASAN_OPTIONS
set -e LSAN_OPTIONS
set -e UBSAN_OPTIONS
set -e TSAN_OPTIONS  

# Enable full SAN mode
# This also has to be in runRTAtest.fish
if not test -z $SAN; and test $SAN = "On"
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
else
  echo "Don't use SAN mode"
end

set -xg GCOV_PREFIX /work/gcov
set -xg GCOV_PREFIX_STRIP 3

function hasLDAPHOST
  test ! -z "$LDAPHOST"
  return $status
end

function isENTERPRISE
  test "$ENTERPRISEEDITION" = "On"
  return $status
end

set -g repoState ""
set -g repoStateEnterprise ""

function getRepoState
  set -g repoState (git rev-parse HEAD) (git status -b -s | grep -v "^[?]")
  if test $ENTERPRISEEDITION = On 
    cd enterprise
    set -g repoStateEnterprise (git rev-parse HEAD) (git status -b -s | grep -v "^[?]")
    cd ..
  else
    set -g repoStateEnterprise ""
  end
end

function noteStartAndRepoState
  getRepoState
  rm -f testProtocol.txt
  set -l d (date -u +%F_%H.%M.%SZ)
  echo $d >> testProtocol.txt
  echo "========== Status of main repository:" >> testProtocol.txt
  echo "========== Status of main repository:"
  for l in $repoState ; echo "  $l" >> testProtocol.txt ; echo "  $l" ; end
  if test $ENTERPRISEEDITION = On
    echo "Status of enterprise repository:" >> testProtocol.txt
    echo "Status of enterprise repository:"
    for l in $repoStateEnterprise
      echo "  $l" >> testProtocol.txt ; echo "  $l"
    end
  end
end

function resetLaunch
  noteStartAndRepoState
  set -g launchFactor $argv[1]
  set -g portBase 10000
  set -g launchCount 0
  if test $launchFactor -gt 1 -a $PARALLELISM -lt (math "$launchFactor*2")
    set -g $PARALLELISM (math "$PARALLELISM*2")
    echo "Extend small parallelism for launchFactor > 1: $PARALLELISM"
  end
  echo Launching tests...
end

function waitForProcesses
  set i $argv[1]
  set launcher $argv[2]
  set start (date -u +%s)
  while true
    # Launch if necessary:
    while test (math (count (jobs -p))"*$launchFactor") -lt "$PARALLELISM"
      if test -z "$launcher" ; break ; end
      if eval "$launcher" ; break ; end
      sleep 30
    end

    # Check subprocesses:
    if test (count (jobs -p)) -eq 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 1
    end

    echo (date) (count (jobs -p)) jobs still running, remaining $i "seconds..."
    echo (begin \
            begin \
              test (count /work/tmp/*.out/started) -gt 0; and ls -1 /work/tmp/*.out/started; \
            end; \
            begin \
              test (count /work/tmp/*.out/stopped) -gt 0; and ls -1 /work/tmp/*.out/stopped; \
            end; \
          end | awk -F/ '{print $4}' | sort | uniq -c | awk '$1 == 1 { print substr($2,1,length($2) - 4) }')

    set i (math $i - 5)
    if test $i -lt 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 0
    end

    sleep 5
  end
end

function waitOrKill
  set timeout $argv[1]
  set launcher $argv[2]
  echo Controlling subprocesses...
  if waitForProcesses $timeout $launcher
    echo (date) timeout after $timeout
    set -l ids (jobs -p)
    if test (count $ids) -gt 0
      kill -9 $ids
      if waitForProcesses 30 ""
        set -l ids (jobs -p)
        if test (count $ids) -gt 0
          kill -9 $ids
          waitForProcesses 60 ""   # give jobs some time to finish
        end
      end
    end
    return 1
  end
  return 0
end

function log
  for l in $argv
    echo $l
    echo $l >> $INNERWORKDIR/test.log
  end
end

function setupTmp
  pushd $INNERWORKDIR
  and rm -rf tmp
  and mkdir tmp
  and set -xg TMPDIR $INNERWORKDIR/tmp
  and cd $INNERWORKDIR/ArangoDB
  and for f in *.log ; rm -f -- $f ; end
  and popd
  or begin popd; return 1; end
end
