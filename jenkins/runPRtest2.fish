#!/usr/bin/env fish
set -l t1 (date +%s)
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and pingDetails
and set -l t2 (date +%s)
and oskar1

set -l s $status

set -l resultname (echo $ARANGODB_BRANCH | tr "/" "_")
set -l filename work/compile-times-$resultname-$datetime.csv

if test -f work/buildTimes.csv
  echo "storing compile times in $resultname"
  awk -F, "{print \"$ARANGODB_BRANCH,$date,\" \$2 \",\" \$3}" \
    < work/buildTimes.csv \
    > $filename
end

echo $date,setup,(expr $t2 - $t1) >> $filename
echo $date,total,(expr (date +%s) - $t1) >> $filename

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
