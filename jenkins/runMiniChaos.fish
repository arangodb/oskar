#!/usr/bin/env fish
source (dirname (status --current-filename))/helper/jenkins.fish

if test -z "$MINI_CHAOS_DURATION" \
   -o (string length (echo (string match -r '[0-9]+' "$MINI_CHAOS_DURATION"))) -ne (string length "$MINI_CHAOS_DURATION") \
   -o "$MINI_CHAOS_DURATION" -lt 1
  echo 'MINI_CHAOS_DURATION (positive number, minutes) required'
  exit 1
end

cleanPrepareLockUpdateClear
and begin
  if test -z "$USE_MAINTAINER_MODE" -o "$USE_MAINTAINER_MODE" != "On"
    echo 'Disable maintainer mode (default)'
    maintainerOff
  else
    echo 'Use maintainer mode'
    maintainerOn
  end
end
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and enterprise
and makeTestPackageLinux
and runMiniChaos (getTestPackageLinuxName) "$MINI_CHAOS_DURATION"

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
