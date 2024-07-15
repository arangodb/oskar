#!/usr/bin/env fish
set -g SCRIPTS (dirname (dirname (status -f)))
source $SCRIPTS/lib/tests.fish

set -xg ADDITIONAL_OPTIONS $argv

################################################################################
## Cluster tests
################################################################################

function launchClusterTests
  echo "Using rlog test definitions from arangodb repo"
  python3 "$WORKSPACE/jenkins/helper/test_launch_controller.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions-rlog.txt" -f launch --cluster --full
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

resetLaunch 4
set timeLimit 4200
set suiteRunner "launchClusterTests"

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

if test $result = GOOD -a $timeout = 0
  exit 0
else
  exit 1
end
