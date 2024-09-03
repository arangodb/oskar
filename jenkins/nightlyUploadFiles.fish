#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test -z "$ARANGODB_PACKAGES"
  echo "ARANGODB_PACKAGES required"
  exit 1
end

set -xg PACKAGES "$ARANGODB_PACKAGES"
set -xg SRC "/mnt/buildfiles/stage2/nightly"
set -xg DST "gs://download.arangodb.com/nightly"


function createIndex
  pushd $WORKSPACE/file-browser
  and echo "Creating INDEX"
  and echo "cleaning old files..."
  and rm -rf file-browser.out root-dir program2.py
  and mkdir root-dir
  and echo "create new links..."
  and cp -rs $SRC root-dir/
  and find root-dir -name "*3e*" -exec rm -f "{}" ";"
  and find root-dir -name "index.html" -exec rm -f "{}" ";"
  and echo "creating index.html..."
  and sed -e 's/os\.walk(root)/os\.walk(root,followlinks=True)/' program.py > program2.py
  and python program2.py root-dir > file-browser.out 2>&1
  or begin popd; return 1; end

  pushd $WORKSPACE/file-browser/root-dir
  and echo "copy index.html..."
  and find . -name "index.html" -ls -exec cp "{}" (dirname $SRC)"/{}" ";"
  or begin popd; return 1; end

  popd
end

function upload
  cd $SRC
  and echo "Copying NIGHTLY"
  and gsutil -m rsync -d -r $PACKAGES $DST/$PACKAGES
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and createIndex
and begin
  # there might be internet hickups
  upload
  or upload
  or upload
  or upload
end
and set PACKAGES_DEVEL (find $SRC -lname devel -printf "%f\n")
and gsutil -m rsync -d -r $DST/devel $DST/$PACKAGES_DEVEL
and gsutil cp $SRC/index.html $DST/index.html

function uploadNightlyWindowsSymbols
  ssh root@symbol.arangodb.biz "cd /script/ && python program.py /mnt/symsrv_arangodb_nightly"
  and ssh root@symbol.arangodb.biz "gsutil rsync -r /mnt/symsrv_arangodb_nightly gs://download.arangodb.com/symsrv_arangodb_nightly"
end

# there might be internet hickups
uploadNightlyWindowsSymbols
or uploadNightlyWindowsSymbols

set -l s $status
unlockDirectory
exit $s
