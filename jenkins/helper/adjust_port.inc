if [[ -v ARANGO_MODE && $ARANGO_MODE == "cluster" ]]
then
  ports=(`./oskar/jenkins/helper/port.sh --cluster`)
  export ARANGO_PORT="${ports[3]}"
else
  ports=(`./oskar/jenkins/helper/port.sh`)
  export ARANGO_PORT="${ports[1]}"
fi

trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g")./oskar/jenkins/helper/port.sh --clean ${ports[*]}" EXIT
echo "using ports ${ports[*]}"
export ARANGO_PORTS="${ports[*]}"