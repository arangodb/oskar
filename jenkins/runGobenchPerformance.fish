#!/usr/bin/env fish
set -xg simple (pwd)/performance
set -xg gobenchdir (pwd)/gobench
set -xg date (date +%Y%m%d)
set -xg datetime (date +%Y%m%d%H%M)

if test -z "$ARANGODB_TEST_CONFIG"
  set -xg ARANGODB_TEST_CONFIG run-small-edges.js
end

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

echo Working on branch $ARANGODB_BRANCH of main repository and
echo on branch $ENTERPRISE_BRANCH of enterprise repository.

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
if echo "$ARANGODB_BRANCH" | grep -q "^v"
  pushd work/ArangoDB
  set -xg date (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-8)
  set -xg datetime (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-12)
  echo "==== date $datetime ===="
  popd
end
and enterprise
and maintainerOff
and releaseMode
nd buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem

# clone gobench
and git clone git@github.com:arangodb/gobench.git
and cd gobench
and make
and cd ..

and rm -rf work/database $simple/results.csv
and echo "==== starting performance run ===="
and echo "docker run  -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY  -v (pwd)/work/ArangoDB:/ArangoDB  -v (pwd)/work:/data  -v $simple:/performance  -v $gobenchdir:/gobench"

and docker run \
  -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY \
  -v (pwd)/work/ArangoDB:/ArangoDB \
  -v (pwd)/work:/data \
  -v $simple:/performance \
  -v $gobenchdir:/gobench \
  arangodb/arangodb \
  sh -c "cd /performance && \
    /ArangoDB/build/bin/arangod \
      -c none \
      --javascript.app-path /tmp/app \
      --javascript.startup-directory /ArangoDB/js \
      --server.rest-server true \
      --server.endpoint tcp://0.0.0.0:8529 \
      --javascript.module-directory `pwd` \
      --server.authentication false \
      --log.foreground-tty \
      /data/database & \
      echo 'Waiting 15s for ArangoDB' && \
      sleep 15 &&
      echo 'Now executing go bench suite' && \
      cd /gobench && \
      ls && \
      ./gobench \
      "

set -l s $status
echo "storing results in /mnt/buildfiles/performance/results-$ARANGODB_BRANCH-$datetime.csv"
awk "{print \"$ARANGODB_BRANCH,$date,\" \$0}" \
  < $simple/results.csv \
  > "/mnt/buildfiles/performance/results-$ARANGODB_BRANCH-$datetime.csv"
rm -rf work/database
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
