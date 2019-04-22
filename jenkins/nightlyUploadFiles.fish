#!/usr/bin/env fish
if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

set -xg PACKAGES "$ARANGODB_PACKAGES"

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

function createIndex
  pushd $WORKSPACE/file-browser
  and echo "Creating INDEX"
  and rm -rf file-browser.out root-dir program2.py
  and mkdir root-dir
  and cp -rs /mnt/buildfiles/stage2/nightly root-dir/
  and find root-dir -name "*3e*" -exec "{}" ";"
  and sed -e 's/os\.walk(root)/os\.walk(root,followlinks=True)/' program.py > program2.py
  and python program2.py root-dir > file-browser.out 2>&1
  or begin popd; return 1; end

  popd
end

function upload
  cd /mnt/buildfiles/stage2/nightly
  and echo "Copying NIGHTLY"
  and gsutil rsync -d -r $PACKAGES gs://download.arangodb.com/nightly/$PACKAGES
end

switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and createIndex
and begin
  # there might be internet hickups
  upload
  or upload
  or upload
  or upload
end

set -l s $status
unlockDirectory
exit $s
