#!/usr/bin/env fish
#source helper.fish
source jenkins/helper.jenkins.fish
and prepareOskar; and lockDirectory; and updateOskar; and clearResults
and rocksdb; and cluster; and maintainerOff

if test $status -ne 0
    echo "failed to prepare environement"
    exit 1
end

echo "--------------------------------------------------------------------------------"
showConfig

set -xg ARANGO_IN_JENKINS true

echo Working on branch $ARANGODB_BRANCH of main repository
echo on branch $ENTERPRISE_BRANCH of enterprise repository.

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and buildStaticArangoDB
and if test $ALLFORMATS = "true"
    buildDocumentationForRelease
else 
    buildDocumentation
end

set -l status_build $status
if test $status_build -ne 0
  echo Build failure with maintainer mode off in $EDITION.
end

cd "$HOME/$NODE_NAME/$OSKAR"; and moveResultsToWorkspace; and unlockDirectory

set -l status_cleanup $status
if test $status_cleanup -ne 0
    echo "clean up failed"
    if test $status_build -eq 0
        exit $status_cleanup
    end
end

exit $status_build
