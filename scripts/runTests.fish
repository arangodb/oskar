#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

################################################################################
## Single tests: runtime,command
################################################################################

set -l ST
echo "Using test definitions from arangodb repo"

function launchSingleTests
  python3 "$WORKSPACE/jenkins/helper/generate_jenkins_scripts.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f launch
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
echo "Using test definitions from arangodb repo"

function launchClusterTests
  python3 "$WORKSPACE/jenkins/helper/generate_jenkins_scripts.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f launch --cluster
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
    set timeLimit 4200
    set suiteRunner "launchClusterTests"
  case "single"
    resetLaunch 1
    set timeLimit 3900
    set suiteRunner "launchSingleTests"
  case "catchtest"
    resetLaunch 1
    set timeLimit 1800
    set suiteRunner "launchCatchTest"
  case "resilience"
    resetLaunch 4
    set timeLimit 3600
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

set evalCmd "waitOrKill $timeLimit $suiteRunner"
eval $evalCmd
set timeout $status

echo "RESULT: $result"
echo "TIMEOUT: $timeout"

if test $result = GOOD -a $timeout = 0
  exit 0
else
  exit 1
end
