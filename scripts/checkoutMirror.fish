#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@$ARANGODB_GIT_HOST
if test "$ENTERPRISEEDITION" = "On"; ssh -o StrictHostKeyChecking=no -T git@$ENTERPRISE_GIT_HOST; end

cd /mirror
and mkdir -p mirror
and cd mirror
and git config --global http.postBuffer 524288000
and git config --global https.postBuffer 524288000
and git config --global pull.rebase true
and if test ! -d ArangoDB.git
  git clone --progress --mirror ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/ArangoDB.git
  or exit 1
else
  pushd ArangoDB.git
  and git remote update
  or exit 1
  popd
end
and if test ! -d enterprise.git
  git clone --progress --mirror ssh://git@$ENTERPRISE_GIT_HOST/$ENTERPRISE_GIT_ORGA/enterprise.git
  or exit 1
else
  pushd enterprise.git
  and git remote update
  or exit 1
  popd
end
