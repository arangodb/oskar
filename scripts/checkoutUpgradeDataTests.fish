#!/usr/bin/env fish
cd $INNERWORKDIR/ArangoDB
and if test ! -d upgrade-data-tests
  git clone ssh://git@github.com/arangodb/upgrade-data-tests
else if test -d upgrade-data-tests/.git
  rm -rf upgrade-data-tests
  git clone ssh://git@github.com/arangodb/upgrade-data-tests
end
