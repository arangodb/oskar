set -gx INNERWORKDIR /work
set -gx THIRDPARTY_BIN $INNERWORKDIR/ArangoDB/build/install/usr/bin
set -gx THIRDPARTY_SBIN $INNERWORKDIR/ArangoDB/build/install/usr/sbin
set -gx SCRIPTSDIR /scripts
set -gx PLATFORM linux
set -gx ARCH (uname -m)

set -gx UBUNTUBUILDIMAGE arangodb/ubuntubuildarangodb-$ARCH
set -gx UBUNTUPACKAGINGIMAGE arangodb/ubuntupackagearangodb-$ARCH
set -gx ALPINEBUILDIMAGE arangodb/alpinebuildarangodb-$ARCH
set -gx CENTOSPACKAGINGIMAGE arangodb/centospackagearangodb-$ARCH
set -gx DOCIMAGE arangodb/arangodb-documentation

function compiler
  set -l version $argv[1]

  switch $version
    case 6.4.0
      set -gx COMPILER_VERSION $version

    case 7.3.0
      set -gx COMPILER_VERSION $version

    case 8.2.0
      set -gx COMPILER_VERSION $version

    case '*'
      echo "unknown compiler version $version"
  end
end

function buildUbuntuBuildImage
  pushd $WORKDIR
  and cp -a scripts/{makeArangoDB,buildArangoDB,checkoutArangoDB,checkoutEnterprise,clearWorkDir,downloadStarter,downloadSyncer,runTests,runFullTests,switchBranches,recursiveChown}.fish containers/buildUbuntu.docker/scripts
  and cd $WORKDIR/containers/buildUbuntu.docker
  and docker build -t $UBUNTUBUILDIMAGE .
  and rm -f $WORKDIR/containers/buildUbuntu.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushUbuntuBuildImage ; docker push $UBUNTUBUILDIMAGE ; end

function pullUbuntuBuildImage ; docker pull $UBUNTUBUILDIMAGE ; end

function buildUbuntuPackagingImage
  pushd $WORKDIR
  and cp -a scripts/buildDebianPackage.fish containers/buildUbuntuPackaging.docker/scripts
  and cd $WORKDIR/containers/buildUbuntuPackaging.docker
  and docker build -t $UBUNTUPACKAGINGIMAGE .
  and rm -f $WORKDIR/containers/buildUbuntuPackaging.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushUbuntuPackagingImage ; docker push $UBUNTUPACKAGINGIMAGE ; end

function pullUbuntuPackagingImage ; docker pull $UBUNTUPACKAGINGIMAGE ; end

function buildAlpineBuildImage
  pushd $WORKDIR
  and cp -a scripts/makeAlpine.fish scripts/buildAlpine.fish containers/buildAlpine.docker/scripts
  and cd $WORKDIR/containers/buildAlpine.docker
  and docker build -t $ALPINEBUILDIMAGE .
  and rm -f $WORKDIR/containers/buildAlpine.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineBuildImage ; docker push $ALPINEBUILDIMAGE ; end

function pullAlpineBuildImage ; docker pull $ALPINEBUILDIMAGE ; end

function buildCentosPackagingImage
  pushd $WORKDIR
  and cp -a scripts/buildRPMPackage.fish containers/buildCentos7Packaging.docker/scripts
  and cd $WORKDIR/containers/buildCentos7Packaging.docker
  and docker build -t $CENTOSPACKAGINGIMAGE .
  and rm -f $WORKDIR/containers/buildCentos7Packaging.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushCentosPackagingImage ; docker push $CENTOSPACKAGINGIMAGE ; end

function pullCentosPackagingImage ; docker pull $CENTOSPACKAGINGIMAGE ; end

function buildDocumentationImage
    eval "$WORKDIR/scripts/buildContainerDocumentation" "$DOCIMAGE"
end
function pushDocumentationImage ; docker push $DOCIMAGE ; end
function pullDocumentationImage ; docker pull $DOCIMAGE ; end

function remakeImages
  set -l s 0

  buildUbuntuBuildImage ; or set -l s 1
  pushUbuntuBuildImage ; or set -l s 1
  buildAlpineBuildImage ; or set -l s 1
  pushAlpineBuildImage ; or set -l s 1
  buildUbuntuPackagingImage ; or set -l s 1
  pushUbuntuPackagingImage ; or set -l s 1
  buildCentosPackagingImage ; or set -l s 1
  pushCentosPackagingImage ; or set -l s 1
  buildDocumentationImage ; or set -l s 1

  return $s
end

function runInContainer
  if test -z "$SSH_AUTH_SOCK"
    eval (ssh-agent -c) > /dev/null
    ssh-add ~/.ssh/id_rsa
    set -l agentstarted 1
  else
    set -l agentstarted ""
  end

  # Run script in container in background, but print output and react to
  # a TERM signal to the shell or to a foreground subcommand. Note that the
  # container process itself will run as root and will be immune to SIGTERM
  # from a regular user. Therefore we have to do some Eiertanz to stop it
  # if we receive a TERM outside the container. Note that this does not
  # cover SIGINT, since this will directly abort the whole function.
  set c (docker run -d \
             -v $WORKDIR/work:$INNERWORKDIR \
             -v $SSH_AUTH_SOCK:/ssh-agent \
	     -v "$WORKDIR/scripts":"/scripts" \
             -e ASAN="$ASAN" \
             -e BUILDMODE="$BUILDMODE" \
             -e COMPILER_VERSION="$COMPILER_VERSION" \
             -e CCACHEBINPATH="$CCACHEBINPATH" \
             -e ENTERPRISEEDITION="$ENTERPRISEEDITION" \
             -e GID=(id -g) \
             -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
             -e INNERWORKDIR="$INNERWORKDIR" \
             -e MAINTAINER="$MAINTAINER" \
             -e NOSTRIP="$NOSTRIP" \
             -e NO_RM_BUILD="$NO_RM_BUILD" \
             -e PARALLELISM="$PARALLELISM" \
             -e PLATFORM="$PLATFORM" \
             -e SCRIPTSDIR="$SCRIPTSDIR" \
             -e SSH_AUTH_SOCK=/ssh-agent \
             -e STORAGEENGINE="$STORAGEENGINE" \
             -e TESTSUITE="$TESTSUITE" \
             -e UID=(id -u) \
             -e VERBOSEBUILD="$VERBOSEBUILD" \
             -e VERBOSEOSKAR="$VERBOSEOSKAR" \
             -e JEMALLOC_OSKAR="$JEMALLOC_OSKAR" \
             -e SKIPGREY="$SKIPGREY" \
             $argv)
  function termhandler --on-signal TERM --inherit-variable c
    if test -n "$c" ; docker stop $c >/dev/null ; end
  end
  docker logs -f $c          # print output to stdout
  docker stop $c >/dev/null  # happens when the previous command gets a SIGTERM
  set s (docker inspect $c --format "{{.State.ExitCode}}")
  docker rm $c >/dev/null
  functions -e termhandler
  # Cleanup ownership:
  docker run \
      -v $WORKDIR/work:$INNERWORKDIR \
      -e UID=(id -u) \
      -e GID=(id -g) \
      -e INNERWORKDIR=$INNERWORKDIR \
      $UBUNTUBUILDIMAGE $SCRIPTSDIR/recursiveChown.fish

  if test -n "$agentstarted"
    ssh-agent -k > /dev/null
    set -e SSH_AUTH_SOCK
    set -e SSH_AGENT_PID
  end
  return $s
end

function buildDocumentation
    runInContainer -e "ARANGO_SPIN=$ARANGO_SPIN" \
                   -e "ARANGO_NO_COLOR=$ARANGO_IN_JENKINS" \
                   -e "ARANGO_BUILD_DOC=/oskar/work" \
                   --user "$UID" \
                   -v "$WORKDIR:/oskar" \
                   -it "$DOCIMAGE" \
                   -- "$argv"
end

function buildDocumentationForRelease
    buildDocumentation --all-formats
end


function checkoutArangoDB
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/checkoutArangoDB.fish
  or return $status
  community
end

function checkoutEnterprise
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/checkoutEnterprise.fish
  or return $status
  enterprise
end

function switchBranches
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/switchBranches.fish $argv
end

function clearWorkDir
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/clearWorkDir.fish
end

function buildArangoDB
  #TODO FIXME - do not change the current directory so people
  #             have to do a 'cd' for a subsequent call.
  #             Fix by not relying on relative locations in other functions
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/buildArangoDB.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeArangoDB
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/makeArangoDB.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function buildStaticArangoDB
  checkoutIfNeeded
  runInContainer $ALPINEBUILDIMAGE $SCRIPTSDIR/buildAlpine.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeStaticArangoDB
  runInContainer $ALPINEBUILDIMAGE $SCRIPTSDIR/makeAlpine.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function buildDebianPackage
  if test ! -d $WORKDIR/work/ArangoDB/build
    echo buildRPMPackage: build directory does not exist
    return 1
  end

  set -l pd "default"

  if test -d $WORKDIR/rpm/$ARANGODB_PACKAGES
    set pd "$ARANGODB_PACKAGES"
  end

  # This assumes that a static build has already happened
  # Must have set ARANGODB_DEBIAN_UPSTREAM and ARANGODB_DEBIAN_REVISION,
  # for example by running findArangoDBVersion.
  set -l v "$ARANGODB_DEBIAN_UPSTREAM-$ARANGODB_DEBIAN_REVISION"
  set -l ch $WORKDIR/work/debian/changelog
  set -l SOURCE $WORKDIR/debian/$pd
  set -l TARGET $WORKDIR/work/debian
  set -l EDITION arangodb3
  set -l EDITIONFOLDER $SOURCE/community

  if test "$ENTERPRISEEDITION" = "On"
    echo Building enterprise edition debian package...
    set EDITION arangodb3e
    set EDITIONFOLDER $SOURCE/enterprise
  else
    echo Building community edition debian package...
  end

  rm -rf $TARGET
  and cp -a $EDITIONFOLDER $TARGET
  and for f in arangodb3.init arangodb3.service compat config templates preinst prerm postinst postrm rules
    cp $SOURCE/common/$f $TARGET/$f
    sed -e "s/@EDITION@/$EDITION/g" -i $TARGET/$f
  end
  and echo -n "$EDITION " > $ch
  and cp -a $SOURCE/common/source $TARGET
  and echo "($v) UNRELEASED; urgency=medium" >> $ch
  and echo >> $ch
  and echo "  * New version." >> $ch
  and echo >> $ch
  and echo -n " -- ArangoDB <hackers@arangodb.com>  " >> $ch
  and date -R >> $ch
  and runInContainer $UBUNTUPACKAGINGIMAGE $SCRIPTSDIR/buildDebianPackage.fish
  set -l s $status
  if test $s -ne 0
    echo Error when building a debian package
    return $s
  end
end

function transformSpec
  if test (count $argv) != 2
    echo transformSpec: wrong number of arguments
    return 1
  end
  and cp "$argv[1]" "$argv[2]"
  and sed -i -e "s/@PACKAGE_VERSION@/$ARANGODB_RPM_UPSTREAM/" "$argv[2]"
  and sed -i -e "s/@PACKAGE_REVISION@/$ARANGODB_RPM_REVISION/" "$argv[2]"
  and sed -i -e "s~@JS_DIR@~~" "$argv[2]"

  # in case of version number inside JS directory
  # and if test "(" "$ARANGODB_VERSION_MAJOR" -eq "3" ")" -a "(" "$ARANGODB_VERSION_MINOR" -le "3" ")"
  #  sed -i -e "s~@JS_DIR@~~" "$argv[2]"
  # else
  #  sed -i -e "s~@JS_DIR@~/$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH~" "$argv[2]"
  # end
end

function buildRPMPackage
  if test ! -d $WORKDIR/work/ArangoDB/build
    echo buildRPMPackage: build directory does not exist
    return 1
  end

  set -l pd "default"

  if test -d $WORKDIR/rpm/$ARANGODB_PACKAGES
    set pd "$ARANGODB_PACKAGES"
  end

  # This assumes that a static build has already happened
  # Must have set ARANGODB_RPM_UPSTREAM and ARANGODB_RPM_REVISION,
  # for example by running findArangoDBVersion.
  if test "$ENTERPRISEEDITION" = "On"
    transformSpec "$WORKDIR/rpm/$pd/arangodb3e.spec.in" "$WORKDIR/work/arangodb3.spec"
  else
    transformSpec "$WORKDIR/rpm/$pd/arangodb3.spec.in" "$WORKDIR/work/arangodb3.spec"
  end
  and cp $WORKDIR/rpm/$pd/arangodb3.initd $WORKDIR/work
  and cp $WORKDIR/rpm/$pd/arangodb3.service $WORKDIR/work
  and cp $WORKDIR/rpm/$pd/arangodb3.logrotate $WORKDIR/work
  and runInContainer $CENTOSPACKAGINGIMAGE $SCRIPTSDIR/buildRPMPackage.fish
end

function buildTarGzPackage
  if test ! -d $WORKDIR/work/ArangoDB/build
    echo buildRPMPackage: build directory does not exist
    return 1
  end

  buildTarGzPackageHelper "linux"
end

function interactiveContainer
  docker run -it -v $WORKDIR/work:$INNERWORKDIR --rm \
             -v $SSH_AUTH_SOCK:/ssh-agent \
             -e SSH_AUTH_SOCK=/ssh-agent \
             -e UID=(id -u) \
             -e GID=(id -g) \
             -e NOSTRIP="$NOSTRIP" \
             -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
             -e INNERWORKDIR=$INNERWORKDIR \
             -e MAINTAINER=$MAINTAINER \
             -e BUILDMODE=$BUILDMODE \
             -e PARALLELISM=$PARALLELISM \
             -e STORAGEENGINE=$STORAGEENGINE \
             -e TESTSUITE=$TESTSUITE \
             -e VERBOSEOSKAR=$VERBOSEOSKAR \
             -e ENTERPRISEEDITION=$ENTERPRISEEDITION \
             -e SCRIPTSDIR=$SCRIPTSDIR \
             -e PLATFORM=$PLATFORM \
             --privileged \
             $argv
end

function shellInUbuntuContainer
  interactiveContainer $UBUNTUBUILDIMAGE fish
end

function shellInAlpineContainer
  interactiveContainer $ALPINEBUILDIMAGE fish
end

function oskar
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/runTests.fish
end

function oskarFull
  checkoutIfNeeded
  launchLdapServer
  and runInContainer --net="$LDAPNETWORK" $UBUNTUBUILDIMAGE $SCRIPTSDIR/runFullTests.fish
  set -l res $status
  stopLdapServer
  return $res
end

function oskarLimited
  checkoutIfNeeded
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/runLimitedTests.fish
end

function pushOskar
  pushd $WORKDIR
  and source helper.fish
  and git push
  and buildUbuntuBuildImage
  and pushUbuntuBuildImage
  and buildAlpineBuildImage
  and pushAlpineBuildImage
  and buildUbuntuPackagingImage
  and pushUbuntuPackagingImage
  and buildCentosPackagingImage
  and pushCentosPackagingImage
  and buildDocumentationImage
  and pushDocumentationImage
  or begin ; popd ; return 1 ; end
  popd
end

function updateOskar
  pushd $WORKDIR
  and git checkout -- .
  and git pull
  and source helper.fish
  and pullUbuntuBuildImage
  and pullAlpineBuildImage
  and pullUbuntuPackagingImage
  and pullCentosPackagingImage
  and pullDocumentationImage
  or begin ; popd ; return 1 ; end
  popd
end

function downloadStarter
  mkdir -p $WORKDIR$THIRDPARTY_BIN
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/downloadStarter.fish $THIRDPARTY_BIN $argv
end

function downloadSyncer
  mkdir -p $WORKDIR$THIRDPARTY_SBIN
  rm -f $WORKDIR/work/ArangoDB/build/install/usr/sbin/arangosync $WORKDIR/work/ArangoDB/build/install/usr/bin/arangosync
  runInContainer -e DOWNLOAD_SYNC_USER=$DOWNLOAD_SYNC_USER $UBUNTUBUILDIMAGE $SCRIPTSDIR/downloadSyncer.fish $THIRDPARTY_SBIN $argv
  ln -s ../sbin/arangosync $WORKDIR/work/ArangoDB/build/install/usr/bin/arangosync
end

function buildPackage
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_FULL_VERSION, for example by running findArangoDBVersion.
  buildDebianPackage
  and buildRPMPackage
  and buildTarGzPackage
  and buildDebianSnippet
  and buildRPMSnippet
  and buildTarGzSnippet
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
  and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
  and downloadStarter
  and downloadSyncer
  and buildPackage

  if test $status -ne 0
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
  and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
  and downloadStarter
  and buildPackage

  if test $status -ne 0
    echo Building community release failed.
    return 1
  end
end

function transformDebianSnippet
  pushd $WORKDIR
  
  set -l DEBIAN_VERSION "$argv[2]"
  set -l DEBIAN_NAME_CLIENT "$argv[1]-client_$DEBIAN_VERSION""_amd64.deb"
  set -l DEBIAN_NAME_SERVER "$argv[1]_$DEBIAN_VERSION""_amd64.deb"
  set -l DEBIAN_NAME_DEBUG_SYMBOLS "$argv[1]-dbg_$DEBIAN_VERSION""_amd64.deb"
  set -l DOWNLOAD_LINK "$argv[4]"

  if test "$ENTERPRISEEDITION" = "On"
    set DOWNLOAD_EDITION "Enterprise"
  else
    set DOWNLOAD_EDITION "Community"
  end

  if test ! -f "work/$DEBIAN_NAME_SERVER"; echo "Debian package '$DEBIAN_NAME_SERVER' is missing"; return 1; end
  if test ! -f "work/$DEBIAN_NAME_CLIENT"; echo "Debian package '$DEBIAN_NAME_CLIENT' is missing"; return 1; end
  if test ! -f "work/$DEBIAN_NAME_DEBUG_SYMBOLS"; echo "Debian package '$DEBIAN_NAME_DEBUG_SYMBOLS' is missing"; return 1; end

  set -l DEBIAN_SIZE_SERVER (expr (wc -c < work/$DEBIAN_NAME_SERVER) / 1024 / 1024)
  set -l DEBIAN_SIZE_CLIENT (expr (wc -c < work/$DEBIAN_NAME_CLIENT) / 1024 / 1024)
  set -l DEBIAN_SIZE_DEBUG_SYMBOLS (expr (wc -c < work/$DEBIAN_NAME_DEBUG_SYMBOLS) / 1024 / 1024)

  set -l DEBIAN_SHA256_SERVER (shasum -a 256 -b < work/$DEBIAN_NAME_SERVER | awk '{print $1}')
  set -l DEBIAN_SHA256_CLIENT (shasum -a 256 -b < work/$DEBIAN_NAME_CLIENT | awk '{print $1}')
  set -l DEBIAN_SHA256_DEBUG_SYMBOLS (shasum -a 256 -b < work/$DEBIAN_NAME_DEBUG_SYMBOLS | awk '{print $1}')

  set -l TARGZ_NAME_SERVER "$argv[1]-linux-$argv[3].tar.gz"

  if test ! -f "work/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < work/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < work/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l n "work/download-$argv[1]-debian.html"

  sed -e "s|@DEBIAN_NAME_SERVER@|$DEBIAN_NAME_SERVER|g" \
      -e "s|@DEBIAN_NAME_CLIENT@|$DEBIAN_NAME_CLIENT|g" \
      -e "s|@DEBIAN_NAME_DEBUG_SYMBOLS@|$DEBIAN_NAME_DEBUG_SYMBOLS|g" \
      -e "s|@DEBIAN_SIZE_SERVER@|$DEBIAN_SIZE_SERVER|g" \
      -e "s|@DEBIAN_SIZE_CLIENT@|$DEBIAN_SIZE_CLIENT|g" \
      -e "s|@DEBIAN_SIZE_DEBUG_SYMBOLS@|$DEBIAN_SIZE_DEBUG_SYMBOLS|g" \
      -e "s|@DEBIAN_SHA256_SERVER@|$DEBIAN_SHA256_SERVER|g" \
      -e "s|@DEBIAN_SHA256_CLIENT@|$DEBIAN_SHA256_CLIENT|g" \
      -e "s|@DEBIAN_SHA256_DEBUG_SYMBOLS@|$DEBIAN_SHA256_DEBUG_SYMBOLS|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@DOWNLOAD_EDITION@|$DOWNLOAD_EDITION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@DEBIAN_VERSION@|$DEBIAN_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/debian.html.in > $n

  echo "Debian Snippet: $n"
  popd
end

function buildDebianSnippet
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_SNIPPETS, for example by running findArangoDBVersion.
  if test "$ENTERPRISEEDITION" = "On"
    if test -z "$ENTERPRISE_DOWNLOAD_LINK"
      echo "you need to set the variable ENTERPRISE_DOWNLOAD_LINK"
      return 1
    end

    transformDebianSnippet "arangodb3e" "$ARANGODB_DEBIAN_UPSTREAM-$ARANGODB_DEBIAN_REVISION" "$ARANGODB_TGZ_UPSTREAM" "$ENTERPRISE_DOWNLOAD_LINK"
    or return 1
  else
    if test -z "$COMMUNITY_DOWNLOAD_LINK"
      echo "you need to set the variable COMMUNITY_DOWNLOAD_LINK"
      return 1
    end

    transformDebianSnippet "arangodb3" "$ARANGODB_DEBIAN_UPSTREAM-$ARANGODB_DEBIAN_REVISION" "$ARANGODB_TGZ_UPSTREAM" "$COMMUNITY_DOWNLOAD_LINK"
    or return 1
  end
end

function transformRPMSnippet
  pushd $WORKDIR

  set -l RPM_NAME_CLIENT "$argv[1]-client-$argv[2].x86_64.rpm"
  set -l RPM_NAME_SERVER "$argv[1]-$argv[2].x86_64.rpm"
  set -l RPM_NAME_DEBUG_SYMBOLS "$argv[1]-debuginfo-$argv[2].x86_64.rpm"
  set -l DOWNLOAD_LINK "$argv[4]"

  if test "$ENTERPRISEEDITION" = "On"
    set DOWNLOAD_EDITION "Enterprise"
  else
    set DOWNLOAD_EDITION "Community"
  end

  if test ! -f "work/$RPM_NAME_SERVER"; echo "RPM package '$RPM_NAME_SERVER' is missing"; return 1; end
  if test ! -f "work/$RPM_NAME_CLIENT"; echo "RPM package '$RPM_NAME_CLIENT' is missing"; return 1; end
  if test ! -f "work/$RPM_NAME_DEBUG_SYMBOLS"; echo "RPM package '$RPM_NAME_DEBUG_SYMBOLS' is missing"; return 1; end

  set -l RPM_SIZE_SERVER (expr (wc -c < work/$RPM_NAME_SERVER) / 1024 / 1024)
  set -l RPM_SIZE_CLIENT (expr (wc -c < work/$RPM_NAME_CLIENT) / 1024 / 1024)
  set -l RPM_SIZE_DEBUG_SYMBOLS (expr (wc -c < work/$RPM_NAME_DEBUG_SYMBOLS) / 1024 / 1024)

  set -l RPM_SHA256_SERVER (shasum -a 256 -b < work/$RPM_NAME_SERVER | awk '{print $1}')
  set -l RPM_SHA256_CLIENT (shasum -a 256 -b < work/$RPM_NAME_CLIENT | awk '{print $1}')
  set -l RPM_SHA256_DEBUG_SYMBOLS (shasum -a 256 -b < work/$RPM_NAME_DEBUG_SYMBOLS | awk '{print $1}')

  set -l TARGZ_NAME_SERVER "$argv[1]-linux-$argv[3].tar.gz"

  if test ! -f "work/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < work/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < work/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l n "work/download-$argv[1]-rpm.html"

  sed -e "s|@RPM_NAME_SERVER@|$RPM_NAME_SERVER|g" \
      -e "s|@RPM_NAME_CLIENT@|$RPM_NAME_CLIENT|g" \
      -e "s|@RPM_NAME_DEBUG_SYMBOLS@|$RPM_NAME_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SIZE_SERVER@|$RPM_SIZE_SERVER|g" \
      -e "s|@RPM_SIZE_CLIENT@|$RPM_SIZE_CLIENT|g" \
      -e "s|@RPM_SIZE_DEBUG_SYMBOLS@|$RPM_SIZE_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SHA256_SERVER@|$RPM_SHA256_SERVER|g" \
      -e "s|@RPM_SHA256_CLIENT@|$RPM_SHA256_CLIENT|g" \
      -e "s|@RPM_SHA256_DEBUG_SYMBOLS@|$RPM_SHA256_DEBUG_SYMBOLS|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@DOWNLOAD_EDITION@|$DOWNLOAD_EDITION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/rpm.html.in > $n

  set -l n "work/download-$argv[1]-suse.html"

  sed -e "s|@RPM_NAME_SERVER@|$RPM_NAME_SERVER|g" \
      -e "s|@RPM_NAME_CLIENT@|$RPM_NAME_CLIENT|g" \
      -e "s|@RPM_NAME_DEBUG_SYMBOLS@|$RPM_NAME_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SIZE_SERVER@|$RPM_SIZE_SERVER|g" \
      -e "s|@RPM_SIZE_CLIENT@|$RPM_SIZE_CLIENT|g" \
      -e "s|@RPM_SIZE_DEBUG_SYMBOLS@|$RPM_SIZE_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SHA256_SERVER@|$RPM_SHA256_SERVER|g" \
      -e "s|@RPM_SHA256_CLIENT@|$RPM_SHA256_CLIENT|g" \
      -e "s|@RPM_SHA256_DEBUG_SYMBOLS@|$RPM_SHA256_DEBUG_SYMBOLS|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@DOWNLOAD_EDITION@|$DOWNLOAD_EDITION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/suse.html.in > $n

  echo "RPM Snippet: $n"
  popd
end

function buildRPMSnippet
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_SNIPPETS, for example by running findArangoDBVersion.
  if test "$ENTERPRISEEDITION" = "On"
    if test -z "$ENTERPRISE_DOWNLOAD_LINK"
      echo "you need to set the variable ENTERPRISE_DOWNLOAD_LINK"
      return 1
    end

    transformRPMSnippet "arangodb3e" "$ARANGODB_RPM_UPSTREAM-$ARANGODB_RPM_REVISION" "$ARANGODB_TGZ_UPSTREAM" "$ENTERPRISE_DOWNLOAD_LINK"
    or return 1
  else
    if test -z "$COMMUNITY_DOWNLOAD_LINK"
      echo "you need to set the variable COMMUNITY_DOWNLOAD_LINK"
      return 1
    end

    transformRPMSnippet "arangodb3" "$ARANGODB_RPM_UPSTREAM-$ARANGODB_RPM_REVISION" "$ARANGODB_TGZ_UPSTREAM" "$COMMUNITY_DOWNLOAD_LINK"
    or return 1
  end
end

function transformTarGzSnippet
  pushd $WORKDIR

  set -l TARGZ_NAME_SERVER "$argv[1]-linux-$argv[2].tar.gz"
  set -l DOWNLOAD_LINK "$argv[3]"

  if test "$ENTERPRISEEDITION" = "On"
    set DOWNLOAD_EDITION "Enterprise"
  else
    set DOWNLOAD_EDITION "Community"
  end

  if test ! -f "work/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < work/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < work/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l n "work/download-$argv[1]-linux.html"

  sed -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@DOWNLOAD_EDITION@|$DOWNLOAD_EDITION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/linux.html.in > $n

  echo "TarGZ Snippet: $n"
  popd
end

function buildTarGzSnippet
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_SNIPPETS, for example by running findArangoDBVersion.
  if test "$ENTERPRISEEDITION" = "On"
    if test -z "$ENTERPRISE_DOWNLOAD_LINK"
      echo "you need to set the variable ENTERPRISE_DOWNLOAD_LINK"
      return 1
    end

    transformTarGzSnippet "arangodb3e" "$ARANGODB_TGZ_UPSTREAM" "$ENTERPRISE_DOWNLOAD_LINK"
    or return 1
  else
    if test -z "$COMMUNITY_DOWNLOAD_LINK"
      echo "you need to set the variable COMMUNITY_DOWNLOAD_LINK"
      return 1
    end

    transformTarGzSnippet "arangodb3" "$ARANGODB_TGZ_UPSTREAM" "$COMMUNITY_DOWNLOAD_LINK"
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
  and buildDebianSnippet
  and buildRPMSnippet
  and buildTarGzSnippet
  and enterprise
  and buildDebianSnippet
  and buildRPMSnippet
  and buildTarGzSnippet
end

## #############################################################################
## docker release
## #############################################################################

function makeDockerRelease
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  set -l DOCKER_TAG ""

  if test (count $argv) -lt 1
    findArangoDBVersion ; or return 1

    set DOCKER_TAG $ARANGODB_VERSION
  else
    set DOCKER_TAG $argv[1]
    findArangoDBVersion
  end

  community
  and buildDockerRelease $DOCKER_TAG
  and buildDockerSnippet
  and enterprise
  and buildDockerRelease $DOCKER_TAG
  and buildDockerSnippet
end

function buildDockerRelease
  set -l DOCKER_TAG $argv[1]

  # build tag
  set -l IMAGE_NAME1 ""

  # snippet content
  set -l IMAGE_NAME2 ""

  # push tag
  set -l IMAGE_NAME3 ""

  if test -z "$ENTERPRISE_DOCKER_KEY"
    set -xg ENTERPRISE_DOCKER_KEY "enterprise-docker-key"
  end

  if test "$ENTERPRISEEDITION" = "On"
    if test "$RELEASETYPE" = "stable"
      set IMAGE_NAME1 arangodb/enterprise:$DOCKER_TAG
      set IMAGE_NAME2 arangodb/enterprise:$DOCKER_TAG
      set IMAGE_NAME3 arangodb/enterprise:$DOCKER_TAG
    else if test "$RELEASETYPE" = "stablePreview"
      set IMAGE_NAME1 arangodb/enterprise:$DOCKER_TAG
      set IMAGE_NAME2 arangodb/enterprise:$DOCKER_TAG
      set IMAGE_NAME3 arangodb/enterprise-preview:$DOCKER_TAG
    else
      set IMAGE_NAME1 arangodb/enterprise-preview:$DOCKER_TAG
      set IMAGE_NAME2 arangodb/enterprise-preview:$DOCKER_TAG
      set IMAGE_NAME3 arangodb/enterprise-preview:$DOCKER_TAG
    end
  else
    if test "$RELEASETYPE" = "stable"
      set IMAGE_NAME1 arangodb/arangodb:$DOCKER_TAG
      set IMAGE_NAME2 arangodb/arangodb:$DOCKER_TAG
      set IMAGE_NAME3 arangodb/arangodb:$DOCKER_TAG
    else if test "$RELEASETYPE" = "stablePreview"
      set IMAGE_NAME1 arangodb/arangodb:$DOCKER_TAG
      set IMAGE_NAME2 arangodb/arangodb:$DOCKER_TAG
      set IMAGE_NAME3 arangodb/arangodb-preview:$DOCKER_TAG
    else
      set IMAGE_NAME1 arangodb/arangodb-preview:$DOCKER_TAG
      set IMAGE_NAME2 arangodb/arangodb-preview:$DOCKER_TAG
      set IMAGE_NAME3 arangodb/arangodb-preview:$DOCKER_TAG
    end
  end

  echo "building docker image"
  and asanOff
  and maintainerOff
  and releaseMode
  and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
  and downloadStarter
  and if test "$ENTERPRISEEDITION" = "On"
    downloadSyncer
  end
  and buildDockerImage $IMAGE_NAME1
  and if test "$IMAGE_NAME1" != "$IMAGE_NAME3"
    docker tag $IMAGE_NAME1 $IMAGE_NAME3
  end
  and docker push $IMAGE_NAME3
  and if test "$ENTERPRISEEDITION" = "On"
    echo $IMAGE_NAME2 > $WORKDIR/work/arangodb3e.docker
  else
    echo $IMAGE_NAME2 > $WORKDIR/work/arangodb3.docker
  end
end

function buildDockerImage
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  if test (count $argv) -eq 0
    echo Must give image name as argument
    return 1
  end

  set -l imagename $argv[1]

  pushd $WORKDIR/work/ArangoDB/build/install
  and tar czf $WORKDIR/containers/arangodb.docker/install.tar.gz *
  if test $status -ne 0
    echo Could not create install tarball!
    popd
    return 1
  end
  popd

  pushd $WORKDIR/containers/arangodb.docker
  and docker build -t $imagename .
  or begin ; popd ; return 1 ; end
  popd
end

function buildDockerSnippet
  set -l name arangodb3.docker
  set -l edition community

  if test "$ENTERPRISEEDITION" = "On"
    set name arangodb3e.docker
    set edition enterprise
  end

  if test ! -f $WORKDIR/work/$name
    echo "docker image name file '$name' not found"
    exit 1
  end

  set -l DOCKER_IMAGE (cat $WORKDIR/work/$name)
  transformDockerSnippet $edition $DOCKER_IMAGE
  and transformK8SSnippet $edition $DOCKER_IMAGE
end

function transformDockerSnippet
  pushd $WORKDIR
  
  set -l edition "$argv[1]"
  set -l DOCKER_IMAGE "$argv[2]"
  set -l ARANGODB_LICENSE_KEY_BASE64 (echo -n "$ARANGODB_LICENSE_KEY" | base64 -w 0)

  set -l n "work/download-docker-$edition.html"

  sed -e "s|@DOCKER_IMAGE@|$DOCKER_IMAGE|g" \
      -e "s|@ARANGODB_LICENSE_KEY@|$ARANGODB_LICENSE_KEY|g" \
      -e "s|@ARANGODB_LICENSE_KEY_BASE64@|$ARANGODB_LICENSE_KEY_BASE64|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/docker.$edition.html.in > $n

  echo "Docker Snippet: $n"
  popd
end

function transformK8SSnippet
  pushd $WORKDIR
  
  set -l edition "$argv[1]"
  set -l DOCKER_IMAGE "$argv[2]"
  set -l ARANGODB_LICENSE_KEY_BASE64 (echo -n "$ARANGODB_LICENSE_KEY" | base64 -w 0)

  set -l n "work/download-k8s-$edition.html"

  sed -e "s|@DOCKER_IMAGE@|$DOCKER_IMAGE|g" \
      -e "s|@ARANGODB_LICENSE_KEY@|$ARANGODB_LICENSE_KEY|g" \
      -e "s|@ARANGODB_LICENSE_KEY_BASE64@|$ARANGODB_LICENSE_KEY_BASE64|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      < snippets/$ARANGODB_SNIPPETS/k8s.$edition.html.in > $n

  echo "Docker Snippet: $n"
  popd
end

## #############################################################################
## create repos
## #############################################################################

function createRepositories
  pushd $WORKDIR
  runInContainer \
      -e ARANGO_SIGN_PASSWD="$ARANGO_SIGN_PASSWD" \
      -v $HOME/.gnupg2:/root/.gnupg \
      -v /mnt/buildfiles/release/3.4/packages:/packages \
      -v /mnt/buildfiles/release/3.4/repositories:/repositories \
      $UBUNTUPACKAGINGIMAGE $SCRIPTSDIR/createAll
  popd
end

## #############################################################################
## set PARALLELISM in a sensible way
## #############################################################################

parallelism (math (grep processor /proc/cpuinfo | wc -l) "*" 2)
