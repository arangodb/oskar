#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

community

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and buildDockerImage arangodb/arangodb-preview:3.4
and docker push arangodb/arangodb-preview:3.4
and docker tag arangodb/arangodb-preview:3.4 registry.arangodb.biz:5000/arangodb/linux-community-maintainer:3.4
and docker push registry.arangodb.biz:5000/arangodb/linux-community-maintainer:3.4

if test $status -ne 0
  echo Production of community image failed, giving up...
  cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
  exit 1
end

enterprise

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and downloadSyncer
and buildDockerImage arangodb/enterprise-preview:3.4
and docker push arangodb/enterprise-preview:3.4
and docker tag arangodb/enterprise-preview:3.4 registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:3.4
and docker push registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:3.4

and begin
  rm -rf $WORKSPACE/imagenames.log
  echo arangodb/arangodb-preview:3.4 >> $WORKSPACE/imagenames.log
  echo registry.arangodb.biz:5000/arangodb/linux-community-maintainer:3.4 >> $WORKSPACE/imagenames.log
  echo arangodb/enterprise-preview:3.4 >> $WORKSPACE/imagenames.log
  echo registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:3.4 >> $WORKSPACE/imagenames.log
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s