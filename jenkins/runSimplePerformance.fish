#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set -xg simple (pwd)/performance
set -xg date (date +%Y%m%d)
set -xg datetime (date +%Y%m%d%H%M)

if test -z "$ARANGODB_TEST_CONFIG"
  set -xg ARANGODB_TEST_CONFIG run-small-edges.js
end

cleanPrepareLockUpdateClear2
and if test -z "$DOCKER_IMAGE"
  enterprise
  and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
  and updateDockerBuildImage
  and maintainerOff
  and releaseMode
  and pingDetails
  and showConfig
  and buildStaticArangoDB
end

and sudo rm -rf work/database $simple/results.csv
and echo "==== starting performance run ===="
and if test -z "$DOCKER_IMAGE"
  docker run \
    -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY \
    -v (pwd)/work/ArangoDB:/ArangoDB \
    -v (pwd)/work:/data \
    -v $simple:/performance \
    arangodb/arangodb \
    sh -c "cd /performance && \
    /ArangoDB/build/install/usr/sbin/arangod \
    -c none \
    --javascript.app-path /tmp/app \
    --javascript.startup-directory /ArangoDB/js \
    --server.rest-server false \
    --javascript.module-directory `pwd` \
    --log.foreground-tty \
    /data/database \
    --javascript.script simple/$ARANGODB_TEST_CONFIG"
else
  docker run \
    -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY \
    -v (pwd)/work:/data \
    -v $simple:/performance \
    $DOCKER_IMAGE \
    sh -c "cd /performance && \
    /usr/sbin/arangod \
    --javascript.app-path /tmp/app \
    --server.rest-server false \
    --javascript.module-directory `pwd` \
    --log.foreground-tty \
    /data/database \
    --javascript.script simple/$ARANGODB_TEST_CONFIG"
end

set -l s $status
set -l resultname (echo $ARANGODB_BRANCH | tr "/" "_")
set -l localname work/results.csv

echo "storing results in $localname"
awk "{print \"$ARANGODB_BRANCH,$datetime,\" \$0}" \
  < $simple/results.csv \
  > $localname

sudo rm -rf work/database

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
