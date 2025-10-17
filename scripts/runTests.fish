#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

set ENTERPRISE_ARG "--no-enterprise"
if test "$ENTERPRISEEDITION" = "On"
   set ENTERPRISE_ARG "--enterprise"
end

if test -f "$INNERWORKDIR/ArangoDB/tests/test-definitions.yml"
   echo yaml
   set -xg TD_TYPE yml
else
   set -xg TD_TYPE txt
end

################################################################################
## Single tests: runtime,command
################################################################################

function launchSingleTests
  echo "Using test definitions from arangodb repo"
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.$TD_TYPE" -f launch "$ENTERPRISE_ARG"
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
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.$TD_TYPE" -f launch --gtest "$ENTERPRISE_ARG"
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
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.$TD_TYPE" -f launch --cluster "$ENTERPRISE_ARG"
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
  python3 -u "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.$TD_TYPE" -f launch --single_cluster "$ENTERPRISE_ARG"
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

if test "$SAN" = "On"
     $INNERWORKDIR/ArangoDB/utils/llvm-symbolizer-server.py > $INNERWORKDIR/symbolizer.log  2>&1 &
end

switch $TESTSUITE
  case "cluster"
    resetLaunch 4
    set -xg timeLimit 4200
    set suiteRunner "launchClusterTests"
  case "single_cluster"
    resetLaunch 4
    set -xg timeLimit 10100
    set suiteRunner "launchSingleClusterTests"
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
      set timeLimit (math $timeLimit \* 14)
    case "AULSan"
      set timeLimit (math $timeLimit \* 8)
    case "*"
      echo Unknown SAN mode $SAN_MODE
      set -g result BAD
      exit 1
  end
end

eval "$suiteRunner"

if test "$SAN" = "On"
   jobs
   kill %1
end
echo "RESULT: $result"

if test $result = GOOD
  exit 0
else
  exit 1
end
