#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

community

switchBranches devel devel true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and buildDockerImage arangodb/arangodb-preview:devel
and docker push arangodb/arangodb-preview:devel
and docker tag arangodb/arangodb-preview:devel registry.arangodb.biz:5000/arangodb/linux-community-maintainer:devel
and docker push registry.arangodb.biz:5000/arangodb/linux-community-maintainer:devel

if test $status -ne 0
  echo Production of community image failed, giving up...
  cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
  exit 1
end

enterprise

switchBranches devel devel true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and downloadSyncer
and buildDockerImage registry.arangodb.biz:5000/arangodb/arangodb-preview:devel-$KEY
and docker push registry.arangodb.biz:5000/arangodb/arangodb-preview:devel-$KEY
and docker tag registry.arangodb.biz:5000/arangodb/arangodb-preview:devel-$KEY registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:devel
and docker push registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:devel

and begin
  rm -rf $WORKSPACE/imagenames.log
  echo arangodb/arangodb-preview:devel >> $WORKSPACE/imagenames.log
  echo registry.arangodb.biz:5000/arangodb/linux-community-maintainer:devel >> $WORKSPACE/imagenames.log
  echo registry.arangodb.biz:5000/arangodb/arangodb-preview:devel-$KEY >> $WORKSPACE/imagenames.log
  echo registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:devel >> $WORKSPACE/imagenames.log
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

