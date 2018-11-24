#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

eval $EDITION ; eval $STORAGE_ENGINE ; eval $TEST_SUITE ; skipGrey

if test -z "$PARALLELISM_FULL_TEST"
  set -g PARALLELISM_FULL_TEST 20
end

parallelism "$PARALLELISM_FULL_TEST"

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and oskar1Limited

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

