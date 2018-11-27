#!/usr/bin/env fish
cd $INNERWORKDIR
if test ! -d ArangoDB
  git clone ssh://git@github.com/arangodb/ArangoDB
end
cd $INNERWORKDIR/ArangoDB
and if test ! -d upgrade-data-tests
  git clone ssh://git@github.com/arangodb/upgrade-data-tests
end
