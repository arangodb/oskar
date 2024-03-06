#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and eval $EDITION
and set -x NOSTRIP 1
and if test $IS_NIGHTLY_BUILD = true; setNightlyVersion; end
and buildStaticArangoDB

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
