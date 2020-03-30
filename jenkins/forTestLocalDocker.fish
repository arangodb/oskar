#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$ARANGODB_BRANCH"
  echo 'ARANGODB_BRANCH required'
  exit 1
end

if test -z "$ENTERPRISE_BRANCH"
  echo 'ENTERPRISE_BRANCH required'
  exit 1
end

rm -rf $WORKSPACE/imagenames.log
and community
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and buildDockerLocal | grep -oP "\"Successfully built \K[0-9a-f].*\"" >> $WORKSPACE/imagenames.log

if test $status -ne 0
  echo Production of Community image failed, giving up...
  exit 1
end

enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
and downloadStarter
and downloadSyncer
and buildDockerLocal | grep -oP "\"Successfully built \K[0-9a-f].*\"" >> $WORKSPACE/imagenames.log

if test $status -ne 0
  echo Production of Enterprise image failed, giving up...
  exit 1
end

