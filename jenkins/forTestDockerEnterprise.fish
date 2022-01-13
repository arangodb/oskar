#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
end

set -xg TAG "$DOCKER_TAG"

set -xg HUB_ENTERPRISE "arangodb/enterprise-test:$TAG"

cleanPrepareLockUpdateClear
and rm -rf $WORKSPACE/imagenames.log
and enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB
and downloadStarter
and downloadSyncer
and copyRclone "linux"
and buildDockerImage $HUB_ENTERPRISE
and docker push $HUB_ENTERPRISE
and docker tag $HUB_ENTERPRISE $GCR_REG_PREFIX$HUB_ENTERPRISE
and docker push $GCR_REG_PREFIX$HUB_ENTERPRISE
and echo $HUB_ENTERPRISE >> $WORKSPACE/imagenames.log
and echo $GCR_REG_PREFIX$HUB_ENTERPRISE >> $WORKSPACE/imagenames.log

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
