set -xg date (date +%Y%m%d)
set -xg datetime (date +%Y%m%d%H%M)

cleanPrepareLockUpdateClear
and enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and if echo "$ARANGODB_BRANCH" | grep -q "^v"
  pushd work/ArangoDB
  set -xg date (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-8)
  set -xg datetime (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-12)
  echo "==== date $datetime ===="
  popd
end
and pingDetails
and ccacheOff
and showConfig
and buildStaticArangoDB

set -l s $status
set -l filename work/compiler.csv
set -l iso (echo $datetime | awk '{print substr($0,1,4) "-" substr($0,5,2) "-" substr($0,7,2) "T" substr($0,9,2) ":" substr($0,11,2) ":00" }')

echo "branch,os,date,step,runtime" > $filename
awk -F, "{print \"$ARANGODB_BRANCH,$OS,$iso,\" \$2 \",\" \$3}" \
  < work/buildTimes.csv \
  >> $filename
