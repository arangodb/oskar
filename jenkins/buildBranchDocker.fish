#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and if test "$USE_EXISTING_BUILD" = "On"
      unpackBuildFilesOn ; packBuildFilesOff
      moveResultsFromWorkspace
    end
and setNightlyVersion
and findArangoDBVersion
and buildStaticArangoDB
and downloadStarter
and downloadSyncer
and buildDockerImage $IMAGE_NAME

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s

