#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
else
  set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG"
end

set archSuffix ""

function setArchSuffix
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
end

cleanPrepareLockUpdateClear
and set -xg NOSTRIP 1
and packageStripNone
and rm -rf $WORKSPACE/imagenames.log
and enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB
and downloadStarter
and downloadSyncer
and downloadRclone
and setArchSuffix
and set -xg HUB_ENTERPRISE "arangodb/enterprise-test:$DOCKER_TAG_JENKINS$archSuffix"
and buildDockerImage $HUB_ENTERPRISE
and validateDockerImageIfNeeded $HUB_ENTERPRISE
and "$DOCKER" push $HUB_ENTERPRISE
and "$DOCKER" tag $HUB_ENTERPRISE $GCR_REG_PREFIX$HUB_ENTERPRISE
and "$DOCKER" push $GCR_REG_PREFIX$HUB_ENTERPRISE
and echo $HUB_ENTERPRISE >> $WORKSPACE/imagenames.log
and echo $GCR_REG_PREFIX$HUB_ENTERPRISE >> $WORKSPACE/imagenames.log

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
