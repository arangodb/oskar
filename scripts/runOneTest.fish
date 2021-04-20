#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

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
else
  ulimit -c unlimited
end

set -xg TESTSUITE $argv[1]

switch $TESTSUITE
  case "cluster"
    resetLaunch 1
    and runClusterTest1 $argv[2] -
    and wait
    createReport
  case "single"
    resetLaunch 1
    and runSingleTest1 $argv[2] -
    and wait
    createReport
  case "catchtest"
    resetLaunch 1
    and runCatchTest1 catch -
    and wait
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
