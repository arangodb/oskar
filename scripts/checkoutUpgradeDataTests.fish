#!/usr/bin/env fish
set -l mirror

if test -d /mirror/upgrade-data-tests.git
  set mirror --reference-if-able /mirror/upgrade-data-tests.git
end

cd $INNERWORKDIR/ArangoDB
and if test ! -d upgrade-data-tests/.git
  rm -rf upgrade-data-tests
end
and if test ! -d upgrade-data-tests
  echo == (date) == started clone 'upgrade-data-tests'
  and git clone $mirror ssh://git@github.com/arangodb/upgrade-data-tests
  and echo == (date) == finished clone 'upgrade-data-tests'
  and if test -d /mirror/upgrade-data-tests.git
    cd upgrade-data-tests
    and git repack -a
  end
end
