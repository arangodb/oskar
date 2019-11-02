#!/usr/bin/env fish
set -l output result.json

echo "copying statistics for job $USE_BUILD_URL"
curl --user "$USER:$PASSWORD" --insecure -o build.json "$USE_BUILD_URL//api/json?pretty=true&depth=100"

echo '{' > $output
set -l sep ''

if test -f build.json
  begin
    echo '"job": '
    cat build.json
    echo $sep
    set sep ','
  end >> $output
end

if test -f totalTimes.csv
  awk -F, '{print($1 ",\"" $2 "\"," $3)}' totalTimes.csv \
    | sed -e 's~\(.*\)~[\1]~' \
    | sed -e 'N;s~\n~,~' \
    | sed -e 's~\(.*\)~[\1]~' \
    > totalTimes.json

  begin
    echo '"times": '
    cat totalTimes.json
    echo $sep
    set sep ','
  end >> $output
end

begin
  echo -n '"node": "'
  if test -z "$NODE_NAME"
    echo -n unkown
  else 
    echo -n $NODE_NAME
  end
  echo '" }'
end >> $output

echo "to collection 'times'"
curl --user "$USER:$PASSWORD" --insecure --header 'accept: application/json' --data-binary "@$output" --dump - -X POST "$CLOUD_URL/_api/document/times"
