#!/usr/bin/env fish
cd $INNERWORKDIR/ArangoDB
and if test ! -d upgrade-data-tests
  git clone ssh://git@github.com/arangodb/upgrade-data-tests
end
