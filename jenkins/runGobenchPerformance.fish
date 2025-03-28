#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set -xg simple (pwd)/performance
set -xg gobenchdir (pwd)/gobench
set -xg date (date +%Y%m%d)
set -xg datetime (date +%Y%m%d%H%M)
set -l s 0

cleanPrepareLockUpdateClear
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and if echo "$ARANGODB_BRANCH" | grep -q "^v"
  pushd work/ArangoDB
  set -xg date (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-8)
  set -xg datetime (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-12)
  echo "==== date $datetime ===="
  popd
end
and enterprise
and maintainerOff
and releaseMode
and showConfig
and buildStaticArangoDB

# make gobench
and pushd $gobenchdir
and make
and popd

and sudo rm -rf work/database $simple/results.csv
and echo "==== starting performance run ===="
and echo "$DOCKER run  -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY  -v (pwd)/work/ArangoDB:/ArangoDB  -v (pwd)/work:/data  -v $simple:/performance  -v $gobenchdir:/gobench"

and for protocol in VST HTTP
  echo "Protocol: " $protocol
  "$DOCKER" run \
    --cap-add SYS_NICE \
    -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY \
    -e ARANGO_BRANCH=$ARANGODB_BRANCH \
    -v (pwd)/work/ArangoDB:/ArangoDB \
    -v (pwd)/work:/data \
    -v $simple:/performance \
    -v $gobenchdir:/gobench \
    arangodb/arangodb \
    sh -c "
      wait_for_arango() {
        echo '...waiting for curl -s http://127.0.0.1:8529/_api/version'
        while ! wget -q http://127.0.0.1:8529/_api/version 2>/dev/null
        do
          sleep 1
        done
      };
      cd /performance && \
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
        echo 'Waiting for ArangoDB' && \
        wait_for_arango && \
        echo 'Now executing go bench suite' && \
        cd /gobench && \
        ./gobench \
          -auth.user root \
          -testcase all \
          -nrRequests 1000000 \
          -nrConnections 12 \
          -parallelism 12 \
          -protocol $protocol \
          -endpoint http://127.0.0.1:8529 \
          -outputFormat=csv > /performance/results.csv"

  if test $status -gt 0
    set s 1
  else
    echo "storing results in /mnt/buildfiles/performance/Linux/Gobench/RAW/results-$protocol-$ARANGODB_BRANCH-$datetime.csv"
    awk "{print \"$ARANGODB_BRANCH,$date,\" \$0 \"$protocol\"}" \
      < $simple/results.csv \
      > "/mnt/buildfiles/performance/Linux/Gobench/RAW/results-$protocol-$ARANGODB_BRANCH-$datetime.csv"
    sudo rm -rf work/database
  end
end

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
