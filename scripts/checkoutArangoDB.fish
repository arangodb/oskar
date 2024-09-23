#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@$ARANGODB_GIT_HOST
if test "$ENTERPRISEEDITION" = "On"; ssh -o StrictHostKeyChecking=no -T git@$ENTERPRISE_GIT_HOST

set -l mirror

if test -d /mirror/ArangoDB.git
  set mirror --reference-if-able /mirror/ArangoDB.git
end

cd $INNERWORKDIR
and git config --global http.postBuffer 524288000
and git config --global https.postBuffer 524288000
and git config --global pull.rebase true
and if test ! -d ArangoDB/.git
  rm -rf ArangoDB
end
and if test ! -d ArangoDB
  echo == (date) == started clone 'ArangoDB'
  and git clone --progress $mirror ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/ArangoDB
  and echo == (date) == finished clone 'ArangoDB'
  and if test -d /mirror/ArangoDB.git
    cd ArangoDB
    and git repack -a
  end
end
