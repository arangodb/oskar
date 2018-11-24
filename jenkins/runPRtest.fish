#!/usr/bin/env fish
source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults

eval $EDITION ; eval $STORAGE_ENGINE ; eval $TEST_SUITE ; skipGrey

if test -z "$PARALLELISM_PR_TEST"
  set -g PARALLELISM_PR_TEST 20
end

parallelism "$PARALLELISM_PR_TEST"

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and oskar1

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s

