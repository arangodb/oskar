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
buildSanFlags "$INNERWORKDIR/ArangoDB"
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
