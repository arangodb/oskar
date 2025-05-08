#!/usr/bin/env fish

set -xg TEST_DEFINITIONS test-definitions.txt
if test (count $argv) -gt 0
    set -xg TEST_DEFINITIONS $argv[1]
end

source jenkins/helper/jenkins.fish

set s 0
set exitcode 0
cleanPrepareLockUpdateClear
and enterprise
and maintainerOn
and sanOff
and coverageOn
and skipGrey
and single_cluster
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and set -gx NOSTRIP 1
and showConfig
and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On
and begin
  rm -rf $WORKDIR/work/gcov.old
  if test -d $WORKDIR/work/gcov ; mv $WORKDIR/work/gcov $WORKDIR/work/gcov.old ; end

  oskarFull --testdefinitions $TEST_DEFINITIONS --isAsan true --sanitizer true; or set s $status
  if test "$s" -eq 1
     set exitcode 5
  end
  collectCoverage
end
or set exitcode $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
echo "exiting $exitcode"
exit $exitcode
