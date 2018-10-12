set -gx SCRIPTSDIR $WORKDIR/scripts
set -gx PLATFORM darwin
set -gx UID (id -u)
set -gx GID (id -g)
set -gx INNERWORKDIR $WORKDIR/work
set -gx THIRDPARTY_BIN $INNERWORKDIR/third_party/bin
set -gx THIRDPARTY_SBIN $INNERWORKDIR/third_party/sbin
set -gx CCACHEBINPATH /usr/local/opt/ccache/libexec
set -gx CMAKE_INSTALL_PREFIX /opt/arangodb

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

function oskarLimited
  checkoutIfNeeded
  runLocal $SCRIPTSDIR/runLimitedTests.fish
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
  mkdir -p $THIRDPARTY_BIN
  runLocal $SCRIPTSDIR/downloadStarter.fish $THIRDPARTY_BIN $argv
end

function downloadSyncer
  mkdir -p $THIRDPARTY_SBIN
  runLocal $SCRIPTSDIR/downloadSyncer.fish $THIRDPARTY_SBIN $argv
end

function buildPackage
  # This assumes that a build has already happened
  # Must have set ARANGODB_DARWIN_UPSTREAM and ARANGODB_DARWIN_REVISION,
  # for example by running findArangoDBVersion.
  if test -z "$ARANGODB_DARWIN_REVISION"
    set v "$ARANGODB_DARWIN_UPSTREAM"
  else  
    set v "$ARANGODB_DARWIN_UPSTREAM-$ARANGODB_DARWIN_REVISION"
  end

  if test "$ENTERPRISEEDITION" = "On"
    echo Building enterprise edition MacOs bundle...
  else
    echo Building community edition MacOs bundle...
  end

  runLocal $SCRIPTSDIR/buildMacOsPackage.fish
  and buildTarGzPackage
end

function cleanupThirdParty
  rm -rf $THIRDPARTY_BIN
  rm -rf $THIRDPARTY_SBIN
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
  and buildArangoDB \
      -DTARGET_ARCHITECTURE=nehalem \
      -DPACKAGING=Bundle \
      -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
      -DTHIRDPARTY_SBIN=$THIRDPARTY_SBIN/arangosync \
      -DTHIRDPARTY_BIN=$THIRDPARTY_BIN/arangodb \
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
      -DTHIRDPARTY_BIN=$THIRDPARTY_BIN/arangodb \
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

function transformBundleSnippet
  pushd $WORKDIR
  set -l BUNDLE_NAME_SERVER "$argv[1]-$argv[2].x86_64.dmg"
  set -l DOWNLOAD_LINK "$argv[4]"

  if test "$ENTERPRISEEDITION" = "On"
    set DOWNLOAD_EDITION "Enterprise"
  else
    set DOWNLOAD_EDITION "Community"
  end

  if test ! -f "work/$BUNDLE_NAME_SERVER"; echo "DMG package '$BUNDLE_NAME_SERVER' is missing"; return 1; end

  set -l BUNDLE_SIZE_SERVER (expr (wc -c < work/$BUNDLE_NAME_SERVER | tr -d " ") / 1024 / 1024)
  set -l BUNDLE_SHA256_SERVER (shasum -a 256 -b < work/$BUNDLE_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_SERVER "$argv[1]-macosx-$argv[3].tar.gz"

  if test ! -f "work/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < work/$TARGZ_NAME_SERVER | tr -d " ") / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < work/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l n "work/download-$argv[1]-macosx.html"

  sed -e "s|@BUNDLE_NAME_SERVER@|$BUNDLE_NAME_SERVER|g" \
      -e "s|@BUNDLE_SIZE_SERVER@|$BUNDLE_SIZE_SERVER|g" \
      -e "s|@BUNDLE_SHA256_SERVER@|$BUNDLE_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@DOWNLOAD_EDITION@|$DOWNLOAD_EDITION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/macosx.html.in > $n

  echo "MacOSX Bundle Snippet: $n"
  popd
end

function buildBundleSnippet
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_SNIPPETS, for example by running findArangoDBVersion.
  if test -z "$ARANGODB_DARWIN_REVISION"
    set n "$ARANGODB_DARWIN_UPSTREAM"
  else
    set n "$ARANGODB_DARWIN_UPSTREAM-$ARANGODB_DARWIN_REVISION"
  end

  if test "$ENTERPRISEEDITION" = "On"
    if test -z "$ENTERPRISE_DOWNLOAD_LINK"
      echo "you need to set the variable ENTERPRISE_DOWNLOAD_LINK"
      return 1
    end

    transformBundleSnippet "arangodb3e" "$n" "$ARANGODB_TGZ_UPSTREAM" "$ENTERPRISE_DOWNLOAD_LINK"
    or return 1
  else
    if test -z "$COMMUNITY_DOWNLOAD_LINK"
      echo "you need to set the variable COMMUNITY_DOWNLOAD_LINK"
      return 1
    end

    transformBundleSnippet "arangodb3" "$n" "$ARANGODB_TGZ_UPSTREAM" "$COMMUNITY_DOWNLOAD_LINK"
    or return 1
  end
end

function makeSnippets
  if test -z "$ENTERPRISE_DOWNLOAD_LINK"
    echo "you need to set the variable ENTERPRISE_DOWNLOAD_LINK"
    return 1
  end

  if test -z "$COMMUNITY_DOWNLOAD_LINK"
    echo "you need to set the variable COMMUNITY_DOWNLOAD_LINK"
    return 1
  end

  community
  and buildBundleSnippet
  and enterprise
  and buildBundleSnippet
end

parallelism 8
