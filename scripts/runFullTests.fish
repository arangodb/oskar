#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

set -xg ADDITIONAL_OPTIONS $argv

################################################################################
## Single tests: runtime,command
################################################################################

set -l ST
echo "Using test definitions from arangodb repo"
python3 "$WORKSPACE/jenkins/helper/generate_jenkins_scripts.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f fish --full | source

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
echo "Using test definitions from arangodb repo"
python3 "$WORKSPACE/jenkins/helper/generate_jenkins_scripts.py" "$INNERWORKDIR/ArangoDB/tests/test-definitions.txt" -f fish --full --cluster | source

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
    set timeLimit 16200
    set suiteRunner "launchClusterTests"
  case "single"
    resetLaunch 1
    set timeLimit 9000
    set suiteRunner "launchSingleTests"
  case "catchtest"
    resetLaunch 1
    set timeLimit 1800
    set suiteRunner "launchCatchTest"
  case "resilience"
    resetLaunch 4
    set timeLimit 10800
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

createReport

if test $result = GOOD -a $timeout = 0
  exit 0
else
  exit 1
end
