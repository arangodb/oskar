#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and rocksdb
and cluster
and maintainerOn
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and showConfig
and buildStaticArangoDB

set -l s $status
if test $s -ne 0
  echo Build failure with maintainer mode on in $EDITION.
end
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
