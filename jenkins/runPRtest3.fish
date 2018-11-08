#!/usr/bin/env fish
source jenkins/helper.jenkins.fish;

and prepareOskar; and lockDirectory ; and updateOskar ; and clearResults
and eval $EDITION ; and eval $STORAGE_ENGINE ; and eval $TEST_SUITE
and skipGrey

if $status -ne 0; return $status ; end

showConfig

echo "Working on branch $ARANGODB_BRANCH of main repository and"
echo "on branch $ENTERPRISE_BRANCH of enterprise repository."

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and oskar1
and buildDocumentationInPR

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
