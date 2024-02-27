#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$DOCKER_TAG"
  echo "DOCKER_TAG required"
  exit 1
else
  set -xg DOCKER_TAG_JENKINS "$DOCKER_TAG-ubi"
end

if test -z "$EDITION"
  echo "EDITION required"
  exit 1
end

set NO_AVX_SUFFIX ""
if test FORCE_NO_AVX = "true"
  set NO_AVX_SUFFIX "-noavx"
end

function forTestDockerMultiarch
  set -l DOCKER_TAG $argv[1]
  set MANIFEST_NAME ""

  if test "$ENTERPRISEEDITION" = "On"
    set MANIFEST_NAME arangodb/enterprise-test$NO_AVX_SUFFIX:$DOCKER_TAG
  else
    set MANIFEST_NAME arangodb/arangodb-test$NO_AVX_SUFFIX:$DOCKER_TAG
  end

  pushDockerManifest $MANIFEST_NAME
  or return 1

  if test "$GCR_REG" = "On"
    pushDockerManifest $GCR_REG_PREFIX$MANIFEST_NAME
    or return 1
  end
end

cleanPrepareLockUpdateClear
and if test "$EDITION" = "All"; or test "$EDITION" = "Community"
      community
      forTestDockerMultiarch "$DOCKER_TAG_JENKINS"
    end
and if test "$EDITION" = "All"; or test "$EDITION" = "Enterprise"
      enterprise
      forTestDockerMultiarch "$DOCKER_TAG_JENKINS"
    end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
