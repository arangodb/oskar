#!/usr/bin/env fish
if test -z "$CLOUD_URL"
  echo "missing CLOUD_URL"
  exit 1
end

if test -f totalTimes.csv
  awk -F, '{print($1 ",\"" $2 "\"," $3)}' totalTimes.csv \
    | sed -e 's~\(.*\)~[\1]~' \
    | sed -e 'N;s~\n~,~' \
    | sed -e 's~\(.*\)~[\1]~' \
    > totalTimes.json
end

echo "copying statistics for job $USE_BUILD_URL"
curl --user "$USER:$PASSWORD" --insecure -o build.json "$USE_BUILD_URL//api/json?pretty=true&depth=100"

set -l output result.json

echo '{' > $output
set -l sep ''

for name in build totalTimes
  if test -f $$name.json
    begin
      echo $sep
      echo \""$name\": "
      cat $$name.json
      set sep ','
    end >> $output
  end
end

for name in USE_BUILD_URL USE_JOB_NAME USE_NODE_NAME EDITION STORAGE_ENGINE TEST_SUITE
  if test ! -z "$$name"
    echo $sep
    echo -n "\"$name\": \"$$name\""
    set set ','
  end >> $output
end

echo '}' >> $output

echo "to collection 'times'"
curl --user "$USER:$PASSWORD" --insecure --header 'accept: application/json' --data-binary "@$output" --dump - -X POST "$CLOUD_URL/_api/document/times"
