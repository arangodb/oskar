#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@$ARANGODB_GIT_HOST
if test "$ENTERPRISEEDITION" = "On"; ssh -o StrictHostKeyChecking=no -T git@$ENTERPRISE_GIT_HOST

set -l mirror

if test -d /mirror/mini-chaos.git
  set mirror --reference-if-able /mirror/mini-chaos.git
end

cd $INNERWORKDIR/ArangoDB
and git config --global http.postBuffer 524288000
and git config --global https.postBuffer 524288000
and git config --global pull.rebase true
and if test -d mini-chaos
  cd mini-chaos
  and test -d .git
  and git rev-parse --is-inside-work-tree 1>/dev/null 2>1
  and if test (basename (git remote show -n origin | grep -w Fetch | cut -d: -f2-)) = 'mini-chaos'
    echo == (date) == started fetch 'mini-chaos'
    git remote update
    git checkout -f
    echo == (date) == finished fetch 'mini-chaos'
    if git status -uno | grep -oq "behind"
      echo == (date) == started pull 'mini-chaos'
      git pull --progress
      echo == (date) == finished pull 'mini-chaos'
    end
  end
  or begin; cd .. ; rm -rf mini-chaos; end
end

cd $INNERWORKDIR/ArangoDB
if test ! -d mini-chaos
  echo == (date) == started clone 'mini-chaos'
  and git clone --progress $mirror ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/mini-chaos
  and echo == (date) == finished clone 'mini-chaos'
  and if test -d /mirror/mini-chaos.git
    cd mini-chaos
    and git repack -a
  end
end
