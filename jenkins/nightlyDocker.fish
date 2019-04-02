#!/usr/bin/env fish
if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
end

set -xg TAG "$DOCKER_TAG"

set -xg HUB_COMMUNITY "arangodb/arangodb-preview:$TAG"
set -xg HUB_ENTERPRISE "arangodb/enterprise-preview:$TAG"

set -xg REG "registry.arangodb.biz:5000/arangodb"
set -xg REG_COMMUNITY "$REG/linux-community-maintainer:$TAG"
set -xg REG_ENTERPRISE1 "$REG/linux-enterprise-maintainer:$TAG"
set -xg REG_ENTERPRISE2 "$REG/arangodb-preview:$TAG-$KEY"

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

rm -rf $WORKSPACE/imagenames.log

community

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and setNightlyRelease
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and buildDockerImage $HUB_COMMUNITY
and docker push $HUB_COMMUNITY
and echo $HUB_COMMUNITY >> $WORKSPACE/imagenames.log
and if test "$USE_PRIVATE_REGISTRY" = "true"
  docker tag $HUB_COMMUNITY $REG_COMMUNITY
  and docker push $REG_COMMUNITY
  and echo $REG_COMMUNITY >> $WORKSPACE/imagenames.log
end

if test $status -ne 0
  echo Production of community image failed, giving up...
  cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
  exit 1
end

enterprise

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and setNightlyRelease
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and downloadSyncer
and buildDockerImage $HUB_ENTERPRISE
and if test "$USE_PRIVATE_REGISTRY" = "true"
  docker tag $HUB_ENTERPRISE $REG_ENTERPRISE2
  and docker push $REG_ENTERPRISE2
  and echo $REG_ENTERPRISE2 >> $WORKSPACE/imagenames.log
  and docker tag $REG_ENTERPRISE2 $REG_ENTERPRISE1
  and docker push $REG_ENTERPRISE1
  and echo $REG_ENTERPRISE1 >> $WORKSPACE/imagenames.log
else
  docker push $HUB_ENTERPRISE
  and echo $HUB_ENTERPRISE >> $WORKSPACE/imagenames.log
end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

