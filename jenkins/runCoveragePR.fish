#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set s 0

cleanPrepareLockUpdateClear
and maintainerOn
and asanOff
and coverageOn
and skipGrey
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and set -gx NOSTRIP 1
and begin
  rm -rf $WORKDIR/work/gcov.old
  if test -d $WORKDIR/work/gcov ; mv $WORKDIR/work/gcov $WORKDIR/work/gcov.old ; end

  enterprise
  and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On -DTARGET_ARCHITECTURE=nehalem
  and showConfig

  and begin
    rocksdb
    cluster ; oskar ; or set s $status
    single  ; oskar ; or set s $status
  end

  and community
  and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On -DTARGET_ARCHITECTURE=nehalem
  and showConfig 

  and begin
    mmfiles
    cluster ; oskar ; or set s $status
    single  ; oskar ; or set s $status
  end

  collectCoverage
  or set s $status
end
or set s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
