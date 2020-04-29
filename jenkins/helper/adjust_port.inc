test ! -v ARANGO_MODE && ARANGO_MODE="singleserver"

case "$ARANGO_MODE" in
  "cluster")
    ports=(`./oskar/jenkins/helper/port.sh --cluster`)
    export ARANGO_PORTS="${ports[1]} ${ports[5]} ${ports[9]}"
  ;;
  "activefailover")
    ports=(`./oskar/jenkins/helper/port.sh --activefailover`)
    export ARANGO_PORTS="${ports[1]} ${ports[4]} ${ports[7]}"
  ;;
  "singleserver")
    ports=(`./oskar/jenkins/helper/port.sh --singleserver`)
    export ARANGO_PORTS="${ports[1]}"
  ;;
esac

trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g")./oskar/jenkins/helper/port.sh --clean ${ports[*]}" EXIT
echo "Using ports ${ports[*]}"
export ARANGO_STARTER_PORT="${ports[0]}"
export ARANGO_PORT="${ports[1]}"
