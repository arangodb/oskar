set -gx SCRIPTSDIR $WORKDIR/scripts
set -gx PLATFORM darwin
set -gx UID (id -u)
set -gx GID (id -g)
set -gx INNERWORKDIR $WORKDIR/work
set -gx THIRDPARTY_BIN third_party/bin
set -gx THIRDPARTY_SBIN third_party/sbin
set -gx CCACHEBINPATH /usr/local/opt/ccache/libexec
set -gx CMAKE_INSTALL_PREFIX /opt/arangodb
set -xg IONICE ""
set -xg MACOSX_DEPLOYMENT_TARGET 10.12

set -gx SYSTEM_IS_MACOSX true

# disable JEMALLOC for now in oskar on MacOSX, since we never tried it:
jemallocOff

# disable strange TAR feature from MacOSX
set -xg COPYFILE_DISABLE 1

function runLocal
  if test -z "$SSH_AUTH_SOCK"
    eval (ssh-agent -c) > /dev/null
    ssh-add ~/.ssh/id_rsa
    set -l agentstarted 1
  else
    set -l agentstarted ""
  end
  set -xg GIT_SSH_COMMAND "ssh -o StrictHostKeyChecking=no"
  set s 1
  begin
    pushd $WORKDIR
    eval $argv
    set s $status
    popd
  end
  if test -n "$agentstarted"
    ssh-agent -k > /dev/null
    set -e SSH_AUTH_SOCK
    set -e SSH_AGENT_PID
  end
  return $s
end

function checkoutUpgradeDataTests
  runLocal $SCRIPTSDIR/checkoutUpgradeDataTests.fish
  or return $status
end

function checkoutArangoDB
  runLocal $SCRIPTSDIR/checkoutArangoDB.fish
  or return $status
  community
end

function checkoutEnterprise
  runLocal $SCRIPTSDIR/checkoutEnterprise.fish
  or return $status
  enterprise
end

function switchBranches
  checkoutIfNeeded
  runLocal $SCRIPTSDIR/switchBranches.fish $argv
end

function clearWorkdir
  runLocal $SCRIPTSDIR/clearWorkdir.fish
end

function buildArangoDB
  checkoutIfNeeded
  runLocal $SCRIPTSDIR/buildMacOs.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeArangoDB
  runLocal $SCRIPTSDIR/makeArangoDB.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function buildStaticArangoDB
  buildArangoDB $argv
end

function makeStaticArangoDB
  makeArangoDB $argv
end

function oskar
  checkoutIfNeeded
  runLocal $SCRIPTSDIR/runTests.fish
end

function oskarFull
  checkoutIfNeeded
  runLocal $SCRIPTSDIR/runFullTests.fish
end

function pushOskar
  pushd $WORKDIR
  and source helper.fish
  and git push
  or begin ; popd ; return 1 ; end
  popd
end

function updateOskar
  pushd $WORKDIR
  and git checkout -- .
  and git pull
  and source helper.fish
  or begin ; popd ; return 1 ; end
  popd
end

function downloadStarter
  mkdir -p $WORKDIR/work/$THIRDPARTY_BIN
  runLocal $SCRIPTSDIR/downloadStarter.fish $INNERWORKDIR/$THIRDPARTY_BIN $argv
end

function downloadSyncer
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  runLocal $SCRIPTSDIR/downloadSyncer.fish $INNERWORKDIR/$THIRDPARTY_SBIN $argv
end

function copyRclone
  echo Copying rclone from rclone/rclone-arangodb-osx to $WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb ...
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  cp rclone/rclone-arangodb-osx $WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb
end

function buildPackage
  # This assumes that a build has already happened
  # Must have set ARANGODB_DARWIN_UPSTREAM and ARANGODB_DARWIN_REVISION,
  # for example by running findArangoDBVersion.
  set v "$ARANGODB_DARWIN_UPSTREAM"

  if test "$ENTERPRISEEDITION" = "On"
    echo Building enterprise edition MacOs bundle...
  else
    echo Building community edition MacOs bundle...
  end

  runLocal $SCRIPTSDIR/buildMacOsPackage.fish
  and buildTarGzPackage
end

function cleanupThirdParty
  rm -rf $WORKDIR/work/$THIRDPARTY_BIN
  rm -rf $WORKDIR/work/$THIRDPARTY_SBIN
end

function buildEnterprisePackage
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end
 
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_FULL_VERSION, for example by running findArangoDBVersion.
  asanOff
  and maintainerOff
  and releaseMode
  and enterprise
  and set -xg NOSTRIP dont
  and cleanupThirdParty
  and downloadStarter
  and downloadSyncer
  and copyRclone
  and buildArangoDB \
      -DTARGET_ARCHITECTURE=nehalem \
      -DPACKAGING=Bundle \
      -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
      -DTHIRDPARTY_SBIN=$WORKDIR/work/$THIRDPARTY_SBIN/arangosync \
      -DTHIRDPARTY_BIN=$WORKDIR/work/$THIRDPARTY_BIN/arangodb \
      -DCMAKE_INSTALL_PREFIX=$CMAKE_INSTALL_PREFIX
  and buildPackage

  if test $status != 0
    echo Building enterprise release failed, stopping.
    return 1
  end
end

function buildCommunityPackage
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_FULL_VERSION, for example by running findArangoDBVersion.
  asanOff
  and maintainerOff
  and releaseMode
  and community
  and set -xg NOSTRIP dont
  and cleanupThirdParty
  and downloadStarter
  and buildArangoDB \
      -DTARGET_ARCHITECTURE=nehalem \
      -DPACKAGING=Bundle \
      -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
      -DTHIRDPARTY_BIN=$WORKDIR/work/$THIRDPARTY_BIN/arangodb \
      -DCMAKE_INSTALL_PREFIX=$CMAKE_INSTALL_PREFIX
  and buildPackage

  if test $status != 0
    echo Building community release failed.
    return 1
  end
end

function buildTarGzPackage
  pushd $INNERWORKDIR/ArangoDB/build
  and rm -rf install
  and make install DESTDIR=install
  and mkdir install/usr
  and mv install/opt/arangodb/bin install/usr
  and mv install/opt/arangodb/sbin install/usr
  and mv install/opt/arangodb/share install/usr
  and mv install/opt/arangodb/etc install
  and rm -rf install/opt
  and buildTarGzPackageHelper "macosx"
  or begin ; popd ; return 1 ; end
  popd
end

## #############################################################################
## helper functions
## #############################################################################

function findCompilerVersion
  gcc -v ^| tail -1 | awk '{print $3}'
end

parallelism (sysctl -n hw.logicalcpu)
