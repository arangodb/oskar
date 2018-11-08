#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

echo "--------------------------------------------------------------------------------"
showConfig

echo Working on branch $ARANGODB_BRANCH of main repository and
echo on branch $ENTERPRISE_BRANCH of enterprise repository.

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
or begin
  echo switchBranches error, giving up.
  unlockDirectory
  exit 1
end

parallelism 20

enterprise ; rocksdb ; cluster ; skipGrey

oskar1
or begin
  echo Errors in enterprise/rocksdb/cluster, stopping.
  moveResultsToWorkspace
  unlockDirectory
  exit 1
end
  
cd $WORKDIR/work
mv cmakeArangoDB.log cmakeArangoDBEnterprise.log
mv buildArangoDB.log buildArangoDBEnterprise.log
moveResultsToWorkspace

community ; mmfiles ; single ; skipGrey

oskar1

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
