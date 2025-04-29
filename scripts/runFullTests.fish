#!/usr/bin/env fish
set -l fish_trace on

set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

set -xg TEST_DEFINITIONS test-definitions.txt
echo "$argv[1]"
echo "$argv[2]"
if test (count "$argv") -gt 0 -a "$argv[1]" = "--testdefinitions"
    set -xg TEST_DEFINITIONS $argv[2]
    set -e $argv[1]
    set -e $argv[1]
end

set -xg ADDITIONAL_OPTIONS $argv

set ENTERPRISE_ARG "--no-enterprise"
if test "$ENTERPRISEEDITION" = "On"
   set ENTERPRISE_ARG "--enterprise"
end

################################################################################
## Single tests: runtime,command
################################################################################

function launchSingleTests
  echo "Using test definitions from arangodb repo"
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/$TEST_DEFINITIONS" -f launch --full "$ENTERPRISE_ARG"
  set x $status
  if test "$x" = "0" -a -f $INNERWORKDIR/testRuns.html
    set -xg result "GOOD"
  else
    set -xg result "BAD"
    echo "python exited $x"
   end
end

################################################################################
## Catch tests
################################################################################

function launchGTest
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/$TEST_DEFINITIONS" -f launch --gtest "$ENTERPRISE_ARG"
  set x $status
  if test "$x" = "0" -a -f $INNERWORKDIR/testRuns.html
    set -xg result "GOOD"
  else
    set -xg result "BAD"
    echo "python exited $x"
   end
end

################################################################################
## Cluster tests: runtime,command
################################################################################

function launchClusterTests
  echo "Using test definitions from arangodb repo"
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/$TEST_DEFINITIONS" -f launch --cluster --full "$ENTERPRISE_ARG"
  set x $status
  if test "$x" = "0" -a -f $INNERWORKDIR/testRuns.html
    set -xg result "GOOD"
  else
    set -xg result "BAD"
    echo "python exited $x"
   end
end

################################################################################
## single and cluster tests: runtime,command
################################################################################

function launchSingleClusterTests
  echo "Using test definitions from arangodb repo"
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/$TEST_DEFINITIONS" -f launch --single_cluster --full "$ENTERPRISE_ARG"
  set x $status
  if test "$x" = "0" -a -f $INNERWORKDIR/testRuns.html
    set -xg result "GOOD"
  else
    set -xg result "BAD"
    echo "python exited $x"
   end
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
    set -xg timeLimit 16200
    set suiteRunner "launchClusterTests"
  case "single_cluster"
    resetLaunch 4
    set -xg timeLimit 80000
    set suiteRunner "launchSingleClusterTests"
  case "single"
    resetLaunch 1
    set -xg timeLimit 9000
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
  case "resilience"
    resetLaunch 4
    set -xg timeLimit 10800
    set suiteRunner "launchResilienceTests"
  case "*"
    echo Unknown test suite $TESTSUITE
    set -g result BAD
    exit 1
end

if test "$SAN" = "On"
  switch $SAN_MODE
    case "TSan"
      set timeLimit (math $timeLimit \* 12)
    case "AULSan"
      set timeLimit (math $timeLimit \* 8)
    case "*"
      echo Unknown SAN mode $SAN_MODE
      set -g result BAD
      exit 1
  end
end

eval "$suiteRunner"

echo "RESULT: $result"

if test $result = GOOD -a $timeout = 0
  exit 0
else
  exit 1
end
