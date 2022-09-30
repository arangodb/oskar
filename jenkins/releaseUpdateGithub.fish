#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

if test "$RELEASE_TYPE" = "stable"
  set -g GIT_BRANCH main
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

set -xg GIT_SSH_COMMAND "ssh -i ~/.ssh/id_rsa" 

function updateRepository
  set -l cid (git rev-parse HEAD)
  and git reset --hard
  and git fetch origin $GIT_BRANCH
  and git checkout -f $GIT_BRANCH
  and git clean -fdx
  and git reset --hard $cid
  and echo "FORCING UPDATE $GIT_BRANCH @ " (pwd)
  and git push --force origin $GIT_BRANCH
  or begin git merge --abort ; and return 1 ; end
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
and cd $WORKDIR/work/ArangoDB
and updateRepository
and cd $WORKDIR/work/ArangoDB/enterprise
and updateRepository

set -l s $status
unlockDirectory
exit $s
