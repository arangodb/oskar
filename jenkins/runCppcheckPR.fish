#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$BASE_BRANCH"
  echo "BASE_BRANCH required"
  exit 1
end

cleanPrepareLockUpdateClear
switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and cppcheckPR "$BASE_BRANCH"

set -l s $status

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
