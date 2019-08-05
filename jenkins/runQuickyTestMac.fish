#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
or begin
  echo switchBranches error, giving up.
  unlockDirectory
  exit 1
end

enterprise 
and rocksdb
and cluster
and skipGrey
and showConfig
and oskar1
or begin
  echo Errors in enterprise/rocksdb/cluster, stopping.
  moveResultsToWorkspace
  unlockDirectory
  exit 1
end
  
cd $WORKDIR/work
and mv cmakeArangoDB.log cmakeArangoDBEnterprise.log
and mv buildArangoDB.log buildArangoDBEnterprise.log
and moveResultsToWorkspace

community
and mmfiles
and single
and skipGrey
and showConfig
and oskar1

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
