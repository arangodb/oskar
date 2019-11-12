#!/usr/bin/env fish
if test -z "$CLOUD_URL"
  echo "missing CLOUD_URL"
  exit 1
end

rm -f totalTimes.json

if test -s totalTimes.csv
  begin
    awk -F, 'BEGIN {print("[")} END {print("]")} {if (1 < NR) print(","); print("[" $1 ",\"" $2 "\"," $3 "]")}' totalTimes.csv \
      | tr -d "\n"
  end > totalTimes.json
end

rm -f testRuns.json

if test -s testRuns.csv
  begin
    awk -F, 'BEGIN {print("[")} END {print("]")} {if (1 < NR) print(","); print("[\"" $1 "\"," $2 ",\"" $3 "\"]")}' testRuns.csv \
      | tr -d "\n"
  end > testRuns.json
end

echo "copying statistics for job $USE_BUILD_URL"
curl --user "$USER:$PASSWORD" --insecure -o build.json "$USE_BUILD_URL//api/json?pretty=true&depth=100"

set -l output result.json

echo '{' > $output
set -l sep ''

for name in build totalTimes testRuns
  echo "testing file $name"
  if test -s $name.json
    begin
      echo $sep
      echo -n \""$name\": "
      cat $name.json
    end >> $output
    set sep ','
  end
end

set -l timestamp (date -u +%s)

for name in USE_BUILD_URL USE_JOB_NAME USE_NODE_NAME EDITION STORAGE_ENGINE TEST_SUITE ARANGODB_BRANCH timestamp
  echo "testing env variable $name"
  if test ! -z "$$name"
    echo $sep
    echo -n "\"$name\": \"$$name\""
  end >> $output
  set set ','
end

echo '}' >> $output

echo "to collection 'times'"
curl --user "$USER:$PASSWORD" --insecure --header 'accept: application/json' --data-binary "@$output" --dump - -X POST "$CLOUD_URL/_api/document/times"
or exit 1
