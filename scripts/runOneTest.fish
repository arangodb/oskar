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

if test "$SAN" = "On"
  ulimit -c 0
else
  ulimit -c unlimited
end

set -xg TESTSUITE $argv[1]
set -xg TEST $argv[2]

switch $TESTSUITE
  case "cluster"
    resetLaunch 1
    and echo "Running $TEST in $TESTUITE with args '$argv[3..-1]'"
    and runClusterTest1 $TEST - $argv[3..-1]
    and waitOrKill 120 ""
    createReport
  case "single"
    resetLaunch 1
    and echo "Running $TEST in $TESTUITE with args '$argv[3..-1]'"
    and runSingleTest1 $TEST - $argv[3..-1]
    and waitOrKill 120 ""
    createReport
  case "gtest"
    resetLaunch 1
    and echo "Running $TEST in $TESTUITE with args '$argv[3..-1]'"
    and runGTest1 gtest - $argv[3..-1]
    and waitOrKill 120 ""
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
