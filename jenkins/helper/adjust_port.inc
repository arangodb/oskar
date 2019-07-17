if [[ -v ARANGO_MODE && $ARANGO_MODE == "cluster" ]]
then
  ports=(`./oskar/jenkins/helper/port.sh --cluster`)
  trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g")./oskar/jenkins/helper/port.sh --clean ${ports[*]}" EXIT

  echo "using ports ${ports[*]}"
  export ARANGO_PORT=${ports[0]}
  export ARANGO_PORTS=("${ports[*]}")
else
  port=`./oskar/jenkins/helper/port.sh --type `
  trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g")./oskar/jenkins/helper/port.sh --clean $port" EXIT

  echo "using port $port"
  export ARANGO_PORT=$port
fi
