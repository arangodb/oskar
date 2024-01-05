#!/usr/bin/env fish
source (dirname (status --current-filename))/helper/jenkins.fish

if begin test -z $argv[1]; or test "$argv[1]" != "local"; end
  cleanPrepareLockUpdateClear
else
  if test -e (dirname (status --current-filename))/../helper.fish
    pushd (dirname (status --current-filename))/..
    source helper.fish
    popd
  else
    echo "No "(dirname (status --current-filename))/../helper.fish" to source!"
    exit 1
  end
end

if test -z "$ARANGODB_BRANCH"
  echo 'ARANGODB_BRANCH required'
  exit 1
end

if test -z "$ENTERPRISE_BRANCH"
  echo 'ENTERPRISE_BRANCH required'
  exit 1
end

rm -rf $WORKSPACE/imagenames.log
and set -xg NOSTRIP 1
and packageStripNone
and community
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB
and downloadStarter
and set imagename "arangodb/arangodb-local:"(date +%Y%m%d%H%M%S)
and buildDockerLocal $imagename

if test $status -ne 0
  echo Production of Community image failed, giving up...
  moveResultsToWorkspace; exit 1
end
echo $imagename >> $WORKSPACE/imagenames.log

enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and findArangoDBVersion
and buildStaticArangoDB
and downloadStarter
and downloadSyncer
and set imagename "arangodb/enterprise-local:"(date +%Y%m%d%H%M%S)
and buildDockerLocal $imagename

if test $status -ne 0
  echo Production of Enterprise image failed, giving up...
  moveResultsToWorkspace; exit 1
end
echo $imagename >> $WORKSPACE/imagenames.log

