#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

community
and maintainerOff
and releaseMode
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and makeDockerImage arangodb/arangodb-preview:$RELEASE_TAG
and docker push arangodb/arangodb-preview:$RELEASE_TAG

if test $status -ne 0
  echo Production of community image failed, giving up...
  cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
  exit 1
end

enterprise
and maintainerOff
and releaseMode
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and downloadSyncer
and makeDockerImage registry.arangodb.biz:5000/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY
and docker push registry.arangodb.biz:5000/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY
and docker tag registry.arangodb.biz:5000/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:$RELEASE_TAG
and docker push registry.arangodb.biz:5000/arangodb/linux-enterprise-maintainer:$RELEASE_TAG
and docker tag registry.arangodb.biz:5000/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY registry-upload.arangodb.info/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY
and docker push registry-upload.arangodb.info/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY
and begin
  rm -rf $WORKSPACE/*.docker
  echo arangodb/arangodb-preview:$RELEASE_TAG > $WORKSPACE/arangodb3.docker
  echo registry.arangodb.biz:5000/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY > $WORKSPACE/arangodb3e.docker
  echo registry-upload.arangodb.info/arangodb/arangodb-preview:$RELEASE_TAG-$ENTERPRISE_DOCKER_KEY >> $WORKSPACE/arangodb3e.docker
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

