#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set s 0

cleanPrepareLockUpdateClear
and enterprise
and maintainerOn
and sanOff
and coverageOn
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and set -gx NOSTRIP 1
and showConfig
and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On
and keepBuild
and eval "\"$WORKDIR/work/ArangoDB/build/bin/arangod\" --version" > "$WORKDIR/work/version.txt"
and begin
  rm -rf "$WORKDIR/work/gcov.old"
  if test -d "$WORKDIR/work/gcov" ; mv "$WORKDIR/work/gcov" "$WORKDIR/work/gcov.old" ; end
  buildExamples
  and collectCoverage
  and mv "$WORKDIR/work/version.txt" "$WORKDIR/work/coverage/version.txt"
  or set s $status
end
or set s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
