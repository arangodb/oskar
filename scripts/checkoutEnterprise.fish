#!/usr/bin/env fish
eval $SCRIPTSDIR/checkoutArangoDB.fish
and cd $INNERWORKDIR/ArangoDB
and if test ! -d enterprise
  git clone ssh://git@github.com/arangodb/enterprise
else if test ! -d enterprise/.git
  rm -rf enterprise
  git clone ssh://git@github.com/arangodb/enterprise
end
