#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
TT_init

and eval $EDITION
and eval $TEST_SUITE
and setAllLogsToWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
and pingDetails
and TT_setup
and oskarCompile
and TT_compile
and downloadStarter
cp work/ArangoDB/build/install/usr/bin/arangodb work/ArangoDB/build/bin/
cp /work/ArangoDB/build/install/usr/bin/arangodb work/ArangoDB/build/bin/
#       work/ArangoDB/build/install/usr/bin/arangodb
set RTA_EDITION "C"
if test "$ENTERPRISEEDITION" = "On"
   set RTA_EDITION "EP"
   copyRclone linux
   cp work/ArangoDB/build/install/usr/bin/rclone-arangodb work/ArangoDB/build/bin/
   downloadSyncer
   cp work/ArangoDB/build/install/usr/sbin/arangosync work/ArangoDB/build/bin/
end

checkoutRTA
cd work/release-test-automation/
bash -x ./jenkins/oskar_tar.sh --edition $RTA_EDITION
exit $s