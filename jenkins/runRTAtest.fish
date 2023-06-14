#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
TT_init

eval $EDITION
eval $TEST_SUITE
skipGrey
setAllLogsToWorkspace
echo "1 $status"
switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
echo "2 $status"
updateDockerBuildImage
echo "3 $status"
pingDetails
echo "4 $status"
echo "santoeuhsanoteuhxxxx"
TT_setup
echo "5 $status"
oskarCompile
echo "6 $status"
TT_compile
echo "santoeuhsanoteuh"

downloadStarter
cp work/ArangoDB/build/install/usr/bin/arangodb work/ArangoDB/build/bin/
cp /work/ArangoDB/build/install/usr/bin/arangodb work/ArangoDB/build/bin/
#       work/ArangoDB/build/install/usr/bin/arangodb
set RTA_EDITION C
if test "$ENTERPRISEEDITION" = "On"
   set RTA_EDITION EP

   downloadSyncer
   cp work/ArangoDB/build/install/usr/sbin/arangosync work/ArangoDB/build/bin/
   copyRclone linux
end
pwd
find work/

checkoutRTA

pwd
cd work/release-test-automation/
git checkout feature/mixed-source-zip-upgrade
chmod a+x ./jenkins/oskar_tar.sh
bash -x ./jenkins/oskar_tar.sh --edition $RTA_EDITION
# cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
