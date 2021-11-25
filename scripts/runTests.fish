#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

################################################################################
## Single tests: runtime,command
################################################################################

set -l ST

if test -d $INNERWORKDIR/ArangoDB/tests/definition
  source $INNERWORKDIR/ArangoDB/tests/definition/pr-single.inc
else
  echo "Cannot find test definition for PR run & single server"
  exit 1
end

set -g STS (echo -e $ST | fgrep , | sort -rn | awk -F, '{print $2}')
set -g STL (count $STS)

function launchSingleTests
  set -g launchCount (math $launchCount + 1)

  if test $launchCount -gt $STL
    return 0
  end

  set -l test $STS[$launchCount]

  if test -n "$TEST"
    if echo $test | fgrep -q "$TEST"
      echo "Running test '$test' (contains '$TEST')"
    else
      echo "Skipping test '$test' (does not contain '$TEST')"
      return 1
    end
  end

  eval $test
  return 1
end

################################################################################
## Catch tests
################################################################################

function launchCatchTest
  switch $launchCount
    case  0 ; runCatchTest1 catch -
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

################################################################################
## Cluster tests: runtime,command
################################################################################

set -l CT

if test -d $INNERWORKDIR/ArangoDB/tests/definition
  source $INNERWORKDIR/ArangoDB/tests/definition/pr-cluster.inc
else
  echo "Cannot find test definition for PR run & cluster server"
  exit 1
end

set -g CTS (echo -e $CT | fgrep , | sort -rn | awk -F, '{print $2}')
set -g CTL (count $CTS)

function launchClusterTests
  set -g launchCount (math $launchCount + 1)

  if test $launchCount -gt $CTL
    return 0
  end

  eval $CTS[$launchCount]
  return 1
end

################################################################################
## main
################################################################################

# Switch off jemalloc background threads for the tests since this seems
# to overload our systems and is not needed.
set -x MALLOC_CONF background_thread:false

setupTmp
cd $INNERWORKDIR/ArangoDB

if test "$ASAN" = "On"
  ulimit -c 0
  ulimit -s 16384
else
  ulimit -c unlimited
end

switch $TESTSUITE
  case "cluster"
    resetLaunch 4
    and if test "$ASAN" = "On"
      waitOrKill 16800 launchClusterTests
    else
      waitOrKill 4200 launchClusterTests
    end
    createReport
  case "single"
    resetLaunch 1
    and if test "$ASAN" = "On"
      waitOrKill 15600 launchSingleTests
    else
      waitOrKill 3900 launchSingleTests
    end
    createReport
  case "catchtest"
    resetLaunch 1
    and if test "$ASAN" = "On"
      waitOrKill 7200 launchCatchTest
    else
      waitOrKill 1800 launchCatchTest
    end
    createReport
  case "resilience"
    resetLaunch 4
    and if test "$ASAN" = "On"
      waitOrKill 14400 launchResilienceTests
    else
      waitOrKill 3600 launchResilienceTests
    end
    createReport
  case "*"
    echo Unknown test suite $TESTSUITE
    set -g result BAD
end

if test $result = GOOD
  exit 0
else
  exit 1
end
