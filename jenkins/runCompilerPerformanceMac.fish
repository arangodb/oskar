#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set -xg OS MAC
source jenkins/helper/runCompilerPerformance.fish

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
