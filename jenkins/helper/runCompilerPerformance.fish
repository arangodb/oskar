set -xg date (date +%Y%m%d)
set -xg datetime (date +%Y%m%d%H%M)

mkdir -p $dest
and cleanPrepareLockUpdateClear
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

echo "branch,os,date,step,runtime" > $filename
awk -F, "{print \"$ARANGODB_BRANCH,$OS,$date,\" \$2 \",\" \$3}" \
  < work/buildTimes.csv \
  >> $filename
