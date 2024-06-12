#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@github.com

cd $INNERWORKDIR
and git config --global http.postBuffer 524288000
and git config --global https.postBuffer 524288000
# and git config --global pull.rebase true
and if test ! -d release-test-automation/.git
  rm -rf release-test-automation
end
and if test ! -d release-test-automation
  echo == (date) == started clone 'RTA'
  and git clone --progress ssh://git@github.com/arangodb/release-test-automation
  and echo == (date) == finished clone 'release test automation'
end
and pushd release-test-automation
and git pull -a
and git repack -a
and git submodule init
and git submodule update
and git checkout $RTA_BRANCH
and git submodule update
and popd