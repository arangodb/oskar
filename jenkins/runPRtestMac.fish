#!/usr/bin/env fish

set -l date (date +%Y%m%d)
set -l t1 (date +%s)
set -l filename work/totalTimes.csv

source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and setAllLogsToWorkspace
and rm -f $filename
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and set -l t2 (date +%s)
and echo "$date,setup,"(expr $t2 - $t1) >> $filename
and pingDetails
and oskarCompile
and set -l t3 (date +%s)
and if test -f work/buildTimes.csv
  awk -F, "{print \"$date,\" \$2 \",\" \$3}" < work/buildTimes.csv >> $filename
  and rm -f work/buildTimes.csv
end
and oskar

set -l s $status

set -l t4 (date +%s)
echo "$date,tests,"(expr $t4 - $t3) >> $filename

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

