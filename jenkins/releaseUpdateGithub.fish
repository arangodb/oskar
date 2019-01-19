#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test "$RELEASE_TYPE" = "stable"
  set -g GIT_BRANCH master
else if test "$RELEASE_TYPE" = "preview"
  set -g GIT_BRANCH unstable
else
  echo "unknown RELEASE_TYPE '$RELEASE_TYPE'"
  exit 1
end

if test "$RELEASE_IS_HEAD" != "true"
  echo "building an older release, not updating github"
  exit 0
end

source jenkins/helper.jenkins.fish ; prepareOskar

function updateRepository
  set -l cid (git rev-parse HEAD)
  and git fetch origin $GIT_BRANCH
  and git checkout $GIT_BRANCH
  git pull origin $GIT_BRANCH
  and git reset --hard $cid
  and echo "FORCING UPDATE $GIT_BRANCH"
  and git push --force origin $GIT_BRANCH
end

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and cd $WORKDIR/work/ArangoDB
and updateRepository
and cd $WORKDIR/work/ArangoDB/enterprise
and updateRepository

set -l s $status
unlockDirectory
exit $s
