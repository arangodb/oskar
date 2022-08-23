#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

################################################################################
## Single tests: runtime,command
################################################################################

function launchSingleTests
  echo "Using test definitions from arangodb repo"
  python3 "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f launch
  and set -xg result "GOOD"
  or set -xg result "BAD"
end

################################################################################
## Catch tests
################################################################################

function launchGTest
  python3 "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f launch --gtest
  and set -xg result "GOOD"
  or set -xg result "BAD"
end

################################################################################
## Cluster tests: runtime,command
################################################################################

function launchClusterTests
  echo "Using test definitions from arangodb repo"
  python3 "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f launch --cluster
  and set -xg result "GOOD"
  or set -xg result "BAD"
end

################################################################################
## main
################################################################################

# Switch off jemalloc background threads for the tests since this seems
# to overload our systems and is not needed.
set -x MALLOC_CONF background_thread:false

setupTmp
cd $INNERWORKDIR/ArangoDB

if test "$SAN" = "On"
  ulimit -c 0
  ulimit -s 16384
else
  ulimit -c unlimited
end

set -g timeout 0
set -g timeLimit -1
set -g suiteRunner ""

switch $TESTSUITE
  case "cluster"
    resetLaunch 4
    set -xg timeLimit 4200
    set suiteRunner "launchClusterTests"
  case "single"
    resetLaunch 1
    set -xg  timeLimit 3900
    set suiteRunner "launchSingleTests"
  case "gtest"
    resetLaunch 1
    set -xg  timeLimit 1800
    set suiteRunner "launchGTest"
  case "catchtest"
    resetLaunch 1
    set -xg  timeLimit 1800
    set suiteRunner "launchGTest"
  case "resilience"
    resetLaunch 4
    set -xg timeLimit 3600
    set suiteRunner "launchResilienceTests"
  case "*"
    echo Unknown test suite $TESTSUITE
    set -g result BAD
    exit 1
end

if test "$SAN" = "On"
  switch $SAN_MODE
    case "TSan"
      set timeLimit (math $timeLimit \* 8)
    case "AULSan"
      set timeLimit (math $timeLimit \* 4)
    case "*"
      echo Unknown SAN mode $SAN_MODE
      set -g result BAD
      exit 1
  end
end

eval "$suiteRunner"

echo "RESULT: $result"

if test $result = GOOD
  exit 0
else
  exit 1
end
