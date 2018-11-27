#!/usr/bin/env fish
cd $INNERWORKDIR
if test ! -d ArangoDB
  git clone ssh://git@github.com/arangodb/ArangoDB
end
