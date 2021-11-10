#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
end

set -xg TAG "$DOCKER_TAG"

set -xg HUB_COMMUNITY "arangodb/arangodb-test:$TAG"

cleanPrepareLockUpdateClear
and rm -rf $WORKSPACE/imagenames.log
and community
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB
and downloadStarter
and buildDockerImage $HUB_COMMUNITY
and docker push $HUB_COMMUNITY
and docker tag $HUB_COMMUNITY $GCR_REG_PREFIX$HUB_COMMUNITY
and docker push $GCR_REG_PREFIX$HUB_COMMUNITY
and echo $HUB_COMMUNITY >> $WORKSPACE/imagenames.log
and echo $GCR_REG_PREFIX$HUB_COMMUNITY >> $WORKSPACE/imagenames.log

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
