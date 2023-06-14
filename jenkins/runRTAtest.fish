#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

cleanPrepareLockUpdateClear2
TT_init

and eval $EDITION
and eval $STORAGE_ENGINE
and eval $TEST_SUITE
and skipGrey
and setAllLogsToWorkspace

and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and updateDockerBuildImage
and pingDetails
echo "santoeuhsanoteuhxxxx"
and TT_setup
# and oskarCompile
and TT_compile
echo "santoeuhsanoteuh"

downloadStarter
pwd
cp work/ArangoDB/build/install/usr/bin/arangodb work/ArangoDB/build/bin/
# and downloadSyncer
# cp work/ArangoDB/build/install/usr/sbin/arangosync work/ArangoDB/build/bin/
# and copyRclone
checkoutRTA

pwd
cd work/release-test-automation/
git checkout feature/mixed-source-zip-upgrade
chmod a+x ./jenkins/oskar_tar.sh
./jenkins/oskar_tar.sh
# cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory
exit $s
