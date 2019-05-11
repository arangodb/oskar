port=`./oskar/jenkins/helper/port.sh`
trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g")./oskar/jenkins/helper/port.sh --clean $port" EXIT

echo "using port $port"
export ARANGO_PORT=$port
