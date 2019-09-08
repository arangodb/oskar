#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and setNightlyRelease
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and downloadSyncer
and buildDockerImage $IMAGE_NAME

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

