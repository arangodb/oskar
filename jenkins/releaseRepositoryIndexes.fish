#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

cleanJenkinsParameter
and prepareOskar
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
if test "$ARANGODB_VERSION_MAJOR" -eq 3
  if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
    cd $WORKSPACE/file-browser
    and rm -f file-browser.out
    and rm -rf root-dir
    and mkdir -p root-dir/$ARANGODB_REPO
    and ln -s /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/packages/Community root-dir/$ARANGODB_REPO/Community
    and ln -s /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/Community/Debian root-dir/$ARANGODB_REPO/DEBIAN
    and ln -s /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories/Community/RPM root-dir/$ARANGODB_REPO/RPM
    and rm -f program2.py
    and sed -e 's/os\.walk(root)/os\.walk(root,followlinks=True)/' program.py > program2.py
    and python program2.py root-dir > file-browser.out 2>&1
    and cp ../snippets/$ARANGODB_PACKAGES/download-index.html /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/index.html
  
    set -l s $status
  
    echo "File-Browser output:"
    cat file-browser.out
  
    if fgrep -q Errno file-browser.out
      set s 1
    end
  end
end

unlockDirectory
exit $s
