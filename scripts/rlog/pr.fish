#!/usr/bin/env fish
set -g SCRIPTS (dirname (dirname (status -f)))
source $SCRIPTS/lib/tests.fish

################################################################################
## load tests definition from ArangoDB
################################################################################

echo "Using test definitions from arangodb repo"

ls -l
echo $SCRIPTS
set -l TESTS
source $INNERWORKDIR/ArangoDB/tests/Definition/rlog/pr.fish

################################################################################
## launch a test
################################################################################

set -g STS (echo -e $TESTS | fgrep , | sort -rn | awk -F, '{print $2}')
set -g STL (count $STS)

function launchTests
  set -g launchCount (math $launchCount + 1)

  if test $launchCount -gt $STL
    return 0
  end

  eval $STS[$launchCount]
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

resetLaunch 4
set timeLimit 4200
set suiteRunner "launchTests"

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

echo "RESULT: $result"
echo "TIMEOUT: $timeout"

if test $result = GOOD -a $timeout = 0
  exit 0
else
  exit 1
end
