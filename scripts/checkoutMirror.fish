#!/usr/bin/env fish
cd /mirror
and mkdir -p mirror
and cd mirror
and if test ! -d ArangoDB.git
  git clone --mirror ssh://git@github.com/arangodb/ArangoDB.git
  or exit 1
else
  pushd ArangoDB.git
  and git remote update
  or exit 1
  popd
end
and if test ! -d enterprise.git
  git clone --mirror ssh://git@github.com/arangodb/enterprise.git
  or exit 1
else
  pushd enterprise.git
  and git remote update
  or exit 1
  popd
end
and if test ! -d upgrade-data-tests.git
  git clone --mirror ssh://git@github.com/arangodb/upgrade-data-tests.git
  or exit 1
else
  pushd upgrade-data-tests.git
  and git remote update
  or exit 1
  popd
end
