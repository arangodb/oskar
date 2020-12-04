#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@github.com

set -l mirror

if test -d /mirror/upgrade-data-tests.git
  set mirror --reference-if-able /mirror/upgrade-data-tests.git
end

cd $INNERWORKDIR/ArangoDB
and git config --global http.postBuffer 524288000
and git config --global https.postBuffer 524288000
and git config --global pull.rebase true
and if test -d upgrade-data-tests
  cd upgrade-data-tests
  and test -d .git
  and git rev-parse --is-inside-work-tree 1>/dev/null 2>1
  and if test (basename (git remote show -n origin | grep -w Fetch | cut -d: -f2-)) = 'upgrade-data-tests'
    echo == (date) == started fetch 'upgrade-data-tests'
    git remote update
    git checkout -f
    echo == (date) == finished fetch 'upgrade-data-tests'
    if git status -uno | grep -oq "behind"
      echo == (date) == started pull 'upgrade-data-tests'
      git pull --progress
      echo == (date) == finished pull 'upgrade-data-tests'
    end
  end
  or begin; cd .. ; rm -rf upgrade-data-tests; end
end

cd $INNERWORKDIR/ArangoDB
if test ! -d upgrade-data-tests
  echo == (date) == started clone 'upgrade-data-tests'
  and git clone --progress $mirror ssh://git@github.com/arangodb/upgrade-data-tests
  and echo == (date) == finished clone 'upgrade-data-tests'
  and if test -d /mirror/upgrade-data-tests.git
    cd upgrade-data-tests
    and git repack -a
  end
end
