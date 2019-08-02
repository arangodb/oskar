#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set -xg ARANGO_IN_JENKINS true

cleanPrepareLockUpdateClear
and rocksdb
and cluster
and maintainerOff
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and showConfig
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
