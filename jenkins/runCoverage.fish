#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set s 0

cleanPrepareLockUpdateClear
and enterprise
and coverageOn
and skipGrey
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On
and begin
  set -x NOSTRIP 1
  rm -rf $WORKDIR/work/gcov.old
  if test -d $WORKDIR/work/gcov ; mv $WORKDIR/work/gcov $WORKDIR/work/gcov.old ; end

  rocksdb
  # cluster ; oskar ; or set s $status
  # single  ; oskar ; or set s $status

  mmfiles
  # cluster ; oskar ; or set s $status
  single  ; oskar ; or set s $status

  collectCoverage
  or set s $status
end
or set s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
