#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and pingDetails
and oskar1

set -l s $status

if test -f work/buildTimes.csv
  set -l resultname (echo $ARANGODB_BRANCH | tr "/" "_")
  set -l filename work/compile-times-$resultname-$datetime.csv

  echo "storing compile times in $resultname"
  awk -F, "{print \"$ARANGODB_BRANCH,$date,\" \$2 \",\" \$3}" \
    < work/buildTimes.csv \
    > $filename
end

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
