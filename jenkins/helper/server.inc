if [ -z "$ARANGO_AUTH" ]; then ARANGO_AUTH="auth"; fi
if [ -z "$ARANGO_BRANCH" ]; then ARANGO_BRANCH="devel"; fi
if [ -z "$ARANGO_DOCKER_REG" ]; then ARANGO_DOCKER_REG="docker.io/arangodb"; fi
if [ -z "$ARANGO_DOCKER_TAG" ]; then ARANGO_DOCKER_TAG="$ARANGO_BRANCH"; fi

if [ "$USE_TEST_DOCKER" == "true" ]
then 
    TEST_DOCKER="-test"
fi

case ${ARANGO_EDITION,,} in
     "enterprise")
          DOCKER_IMAGE="$ARANGO_DOCKER_REG/enterprise$TEST_DOCKER:$ARANGO_DOCKER_TAG"
      ;;
     *)
          DOCKER_IMAGE="$ARANGO_DOCKER_REG/arangodb$TEST_DOCKER:$ARANGO_DOCKER_TAG"
      ;;
esac

for name in ARANGO_DOCKER_NAME ARANGO_PORTS ARANGO_MODE ARANGO_STARTER_PORT ARANGO_STORAGE_ENGINE ARANGO_EDITION ARANGO_AUTH; do
    if [ -z "${!name}" ]; then
        echo "$name missing"
        exit 1
    fi
done

echo "NAME: $ARANGO_DOCKER_NAME"

if [[ -v ARANGO_PORTS ]]; then
  IFS=', ' read -r -a ARANGO_PORTS <<< "$ARANGO_PORTS"
fi
for i in "${ARANGO_PORTS[@]}"; do
  echo "PORT $i to export"
  EXPORT_PORTS="$EXPORT_PORTS -p $i:$i"
done

echo "PORTS: $EXPORT_PORTS"
echo "MODE: $ARANGO_MODE"
echo "ENGINE: $ARANGO_STORAGE_ENGINE"
echo "AUTH: $ARANGO_AUTH"
echo "EDITION: $ARANGO_EDITION"
echo

"$DOCKER" kill $ARANGO_DOCKER_NAME > /dev/null 2>&1 || true
"$DOCKER" rm -fv $ARANGO_DOCKER_NAME > /dev/null 2>&1 || true
"$DOCKER" pull $DOCKER_IMAGE
"$DOCKER" run --rm --cap-add SYS_NICE $DOCKER_IMAGE arangosh --version | tee ./${ARANGO_DOCKER_NAME}.txt
export SERVER_FULL_VERSION=$(cat ./${ARANGO_DOCKER_NAME}.txt | grep -oP '^server-version: \K.*$')

OUTDIR="`pwd`/output"
rm -rf $OUTDIR
mkdir $OUTDIR
DOCKER_AUTH=""
STARTER_AUTH=""
DOCKER_CMD="$DOCKER run --rm --hostname localhost --cap-add SYS_NICE --name $ARANGO_DOCKER_NAME -d $EXPORT_PORTS -v $OUTDIR:/testrun"
#DOCKER_IMAGE="registry.arangodb.biz:5000/arangodb/linux-${ARANGO_EDITION}-maintainer:$ARANGO_BRANCH"
STARTER_CMD="arangodb --starter.address localhost --starter.local --server.storage-engine $ARANGO_STORAGE_ENGINE --starter.data-dir /testrun ${MMFILES_DEPRECATED_OPTION}"
STARTER_MODE=""

if [ "$USE_TEST_DOCKER" == "true" ]
then 
    STARTER_CMD="$STARTER_CMD --all.javascript.allow-admin-execute=true"
fi
    
if [ "$ARANGO_AUTH" == "auth" ]; then
  JWTDIR="`pwd`/jwtsecret"
  rm -rf $JWTDIR
  mkdir $JWTDIR
  echo "geheim" > $JWTDIR/geheim
  DOCKER_AUTH="-v $JWTDIR:/jwtsecret -e ARANGO_ROOT_PASSWORD=$ARANGO_ROOT_PASSWORD -e ARANGODB_DEFAULT_ROOT_PASSWORD=$ARANGO_ROOT_PASSWORD"
  STARTER_AUTH="--auth.jwt-secret /jwtsecret/geheim" 
fi

case "$ARANGO_MODE" in
  "cluster")
    STARTER_MODE="--starter.mode cluster --starter.port ${ARANGO_STARTER_PORT}"
  ;;
  "activefailover")
    STARTER_MODE="--starter.mode activefailover --starter.port ${ARANGO_STARTER_PORT}"
  ;;
  "singleserver")
    STARTER_MODE="--starter.mode single --starter.port ${ARANGO_STARTER_PORT}"
  ;;
  *)
    echo "unknown mode $ARANGO_MODE"
    exit 1
  ;;
esac

cat > $OUTDIR/starter.sh << 'EOF'
#!/bin/sh
cd /testrun
pwd
ulimit -a
$*
EOF
chmod 755 $OUTDIR/starter.sh

echo "Starting the container with the following command:"
command="$DOCKER_CMD $DOCKER_AUTH $DOCKER_IMAGE /testrun/starter.sh $STARTER_CMD $STARTER_MODE $STARTER_AUTH"
echo $command
$command

trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g") "$DOCKER" rm -fv $ARANGO_DOCKER_NAME ; sudo chown jenkins:jenkins -R output ; tar czf arango_data.tar.gz output" EXIT

echo "Waiting until ArangoDB is ready on port ${ARANGO_PORTS[0]}"

if [ "$ARANGO_AUTH" == "auth" ]; then
    CURL_USER="-uroot:$ARANGO_ROOT_PASSWORD"
else
    CURL_USER=""
fi

count=0

while [ "$count" -lt 240 ]; do
  responseCode=`curl -s -I $CURL_USER http://localhost:${ARANGO_PORTS[0]}/_api/version | head -n 1 | cut -d$' ' -f2`
  if [ -n "${responseCode}" ];
  then
    if [ $responseCode -eq 200 ];
    then
          echo "We are finally ready and authenticated."
          break
    fi
  fi

  count=`expr $count + 1`
  echo "waiting ($count)..."
  sleep 2s
done

if [ $count -ge 240 ]; then
    echo "docker logs:"
    "$DOCKER" logs $ARANGO_DOCKER_NAME

    echo
    echo "curl:"
    curl $CURL_USER -v http://localhost:${ARANGO_PORTS[0]}/_api/version

    echo "ArangoDB did not start"
    exit 1
fi

echo "ArangoDB is up"
