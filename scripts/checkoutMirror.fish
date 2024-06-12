#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@github.com

cd /mirror
and mkdir -p mirror
and cd mirror
and git config --global http.postBuffer 524288000
and git config --global https.postBuffer 524288000
and git config --global pull.rebase true
and if test ! -d ArangoDB.git
  git clone --progress --mirror ssh://git@github.com/arangodb/ArangoDB.git
  or exit 1
else
  pushd ArangoDB.git
  and git remote update
  or exit 1
  popd
end
and if test ! -d enterprise.git
  git clone --progress --mirror ssh://git@github.com/arangodb/enterprise.git
  or exit 1
else
  pushd enterprise.git
  and git remote update
  or exit 1
  popd
end
