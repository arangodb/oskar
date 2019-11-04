#!/usr/bin/env fish
cd $INNERWORKDIR
and if test ! -d ArangoDB
  git clone ssh://git@github.com/arangodb/ArangoDB
else if test ! -d ArangoDB/.git
  rm -rf ArangoDB
  git clone ssh://git@github.com/arangodb/ArangoDB
end
