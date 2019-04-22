#!/usr/bin/env fish
source jenkins/helper.jenkins.fish
and prepareOskar; and lockDirectory; and updateOskar; and clearResults
and enterprise; and rocksdb; and asanOff; and maintainerOff

if test $status -ne 0
    echo "failed to prepare environement"
    exit 1
end

showConfig

echo Working on branch $ARANGODB_BRANCH of main repository and
echo on branch $ENTERPRISE_BRANCH of enterprise repository.

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and buildExamples

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
