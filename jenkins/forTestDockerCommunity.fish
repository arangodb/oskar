#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
end

if test "$USE_ARM" = "On"
  switch "$ARCH"
    case "x86_64"
      set archSuffix "-amd64"
    case '*'
      if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
      set archSuffix "-arm64v8"
    else
      echo "fatal, unknown architecture $ARCH for docker"
      exit 1
    end
  end
end

set TAG $DOCKER_TAG$archSuffix
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
