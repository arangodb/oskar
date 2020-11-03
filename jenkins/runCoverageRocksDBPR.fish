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
  and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On -DTARGET_ARCHITECTURE=westmere
  and $WORKDIR/work/ArangoDB/build/bin/arangod --version > $WORKDIR/work/version-enterprise.txt
  and showConfig

  and begin
    rocksdb
    cluster ; oskar ; or set s $status
    single  ; oskar ; or set s $status
  end

  and community
  and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On -DTARGET_ARCHITECTURE=westmere
  and $WORKDIR/work/ArangoDB/build/bin/arangod --version > $WORKDIR/work/version-community.txt
  and showConfig 

  and begin
    rocksdb
    cluster ; oskar ; or set s $status
    single  ; oskar ; or set s $status
  end

  collectCoverage
  and mv $WORKDIR/work/version-enterprise.txt $WORKDIR/work/coverage/version-enterprise.txt
  and mv $WORKDIR/work/version-community.txt $WORKDIR/work/coverage/version-community.txt
  or set s $status
end
or set s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
