#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and if test "$USE_EXISTING_BUILD" = "On"
      unpackBuildFilesOn ; packBuildFilesOff
      moveResultsFromWorkspace
    end
and if test $IS_NIGHTLY_BUILD = true; setNightlyVersion; end
and switch $EDITION
      case community
        makeCommunityRelease $PACKAGES
      case enterprise
        makeEnterpriseRelease $PACKAGES
    end

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
