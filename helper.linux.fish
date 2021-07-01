set -gx INNERWORKDIR /work
set -gx THIRDPARTY_BIN ArangoDB/build/install/usr/bin
set -gx THIRDPARTY_SBIN ArangoDB/build/install/usr/sbin
set -gx SCRIPTSDIR /scripts
set -gx PLATFORM linux
set -gx ARCH (uname -m)

set -gx UBUNTUBUILDIMAGE3_NAME arangodb/ubuntubuildarangodb3-$ARCH
set -gx UBUNTUBUILDIMAGE3_TAG 8
set -gx UBUNTUBUILDIMAGE3 $UBUNTUBUILDIMAGE3_NAME:$UBUNTUBUILDIMAGE3_TAG

set -gx UBUNTUBUILDIMAGE4_NAME arangodb/ubuntubuildarangodb4-$ARCH
set -gx UBUNTUBUILDIMAGE4_TAG 9
set -gx UBUNTUBUILDIMAGE4 $UBUNTUBUILDIMAGE4_NAME:$UBUNTUBUILDIMAGE4_TAG

set -gx UBUNTUBUILDIMAGE5_NAME arangodb/ubuntubuildarangodb5-$ARCH
set -gx UBUNTUBUILDIMAGE5_TAG 3
set -gx UBUNTUBUILDIMAGE5 $UBUNTUBUILDIMAGE5_NAME:$UBUNTUBUILDIMAGE5_TAG

set -gx UBUNTUPACKAGINGIMAGE arangodb/ubuntupackagearangodb-$ARCH:1

set -gx ALPINEBUILDIMAGE3_NAME arangodb/alpinebuildarangodb3-$ARCH
set -gx ALPINEBUILDIMAGE3_TAG 12
set -gx ALPINEBUILDIMAGE3 $ALPINEBUILDIMAGE3_NAME:$ALPINEBUILDIMAGE3_TAG

set -gx ALPINEBUILDIMAGE4_NAME arangodb/alpinebuildarangodb4-$ARCH
set -gx ALPINEBUILDIMAGE4_TAG 11
set -gx ALPINEBUILDIMAGE4 $ALPINEBUILDIMAGE4_NAME:$ALPINEBUILDIMAGE4_TAG

set -gx ALPINEBUILDIMAGE5_NAME arangodb/alpinebuildarangodb5-$ARCH
set -gx ALPINEBUILDIMAGE5_TAG 3
set -gx ALPINEBUILDIMAGE5 $ALPINEBUILDIMAGE5_NAME:$ALPINEBUILDIMAGE5_TAG

set -gx ALPINEUTILSIMAGE_NAME arangodb/alpineutils-$ARCH
set -gx ALPINEUTILSIMAGE_TAG 4
set -gx ALPINEUTILSIMAGE $ALPINEUTILSIMAGE_NAME:$ALPINEUTILSIMAGE_TAG

set -gx CENTOSPACKAGINGIMAGE_NAME arangodb/centospackagearangodb-$ARCH
set -gx CENTOSPACKAGINGIMAGE_TAG 2
set -gx CENTOSPACKAGINGIMAGE $CENTOSPACKAGINGIMAGE_NAME:$CENTOSPACKAGINGIMAGE_TAG

set -gx CPPCHECKIMAGE_NAME arangodb/cppcheck
set -gx CPPCHECKIMAGE_TAG 4
set -gx CPPCHECKIMAGE $CPPCHECKIMAGE_NAME:$CPPCHECKIMAGE_TAG

set -xg IONICE "ionice -c 3"

set -gx LDAPDOCKERCONTAINERNAME arangodbtestldapserver
set -gx LDAPNETWORK ldaptestnet

set -gx SYSTEM_IS_LINUX true

## #############################################################################
## config
## #############################################################################

function compiler
  set -l cversion $argv[1]

  if test "$cversion" = ""
    set -e COMPILER_VERSION
    return 0
  end

  switch $cversion
    case 9.3.0-r0
      set -gx COMPILER_VERSION $cversion

    case 9.3.0-r2
      set -gx COMPILER_VERSION $cversion

    case 10.2.1_pre1-r3
      set -gx COMPILER_VERSION $cversion

    case '*'
      echo "unknown compiler version $cversion"
  end
end

function opensslVersion
  set -l oversion $argv[1]

  if test "$oversion" = ""
    set -e OPENSSL_VERSION
    return 0
  end

  switch $oversion
    case '1.0.0'
      set -gx OPENSSL_VERSION $oversion

    case '1.1.0'
      set -gx OPENSSL_VERSION $oversion

    case '1.1.1'
      set -gx OPENSSL_VERSION $oversion

    case '*'
      echo "unknown openssl version $oversion"
  end
end

function findBuildImage
  if test "$COMPILER_VERSION" = ""
      echo $UBUNTUBUILDIMAGE
  else
    switch $COMPILER_VERSION
      case 9.3.0-r0
        echo $UBUNTUBUILDIMAGE3

      case 9.3.0-r2
        echo $UBUNTUBUILDIMAGE4

      case 10.2.1_pre1-r3
        echo $UBUNTUBUILDIMAGE5

      case '*'
        echo "unknown compiler version $version"
        return 1
    end
  end
end

function findStaticBuildImage
  if test "$COMPILER_VERSION" = ""
      echo $ALPINEBUILDIMAGE
  else
    switch $COMPILER_VERSION
      case 9.3.0-r0
        echo $ALPINEBUILDIMAGE3

      case 9.3.0-r2
        echo $ALPINEBUILDIMAGE4

      case 10.2.1_pre1-r3
        echo $ALPINEBUILDIMAGE5

      case '*'
        echo "unknown compiler version $version"
        return 1
    end
  end
end

function findBuildScript
  if test "$COMPILER_VERSION" = ""
      echo buildArangoDB3.fish
  else
    switch $COMPILER_VERSION
      case 9.3.0-r0
        echo buildArangoDB3.fish

      case 9.3.0-r2
        echo buildArangoDB4.fish

      case 10.2.1_pre1-r3
        echo buildArangoDB5.fish

      case '*'
        echo "unknown compiler version $version"
        return 1
    end
  end
end

function findStaticBuildScript
  if test "$COMPILER_VERSION" = ""
      echo buildAlpine3.fish
  else
    switch $COMPILER_VERSION
      case 9.3.0-r0
        echo buildAlpine3.fish

      case 9.3.0-r2
        echo buildAlpine4.fish

      case 10.2.1_pre1-r3
        echo buildAlpine5.fish

      case '*'
        echo "unknown compiler version $version"
        return 1
    end
  end
end

function findRequiredCompiler
  set -l f $WORKDIR/work/ArangoDB/VERSIONS

  test -f $f
  or begin
    echo "Cannot find $f; make sure source is checked out"
    return 1
  end

  #if test "$COMPILER_VERSION" != ""
  #  echo "Compiler version already set to '$COMPILER_VERSION'"
  #  return 0
  #end

  set -l v (fgrep GCC_LINUX $f | awk '{print $2}' | tr -d '"' | tr -d "'")

  if test "$v" = ""
    echo "$f: no GCC_LINUX specified, using 9.3.0-r0"
    compiler 9.3.0-r0
  else
    echo "Using compiler '$v' from '$f'"
    compiler $v
  end
end

function findRequiredOpenSSL
  set -l f $WORKDIR/work/ArangoDB/VERSIONS

  test -f $f
  or begin
    echo "Cannot find $f; make sure source is checked out"
    return 1
  end

  #if test "$OPENSSL_VERSION" != ""
  #  echo "OpenSSL version already set to '$OPENSSL_VERSION'"
  #  return 0
  #end

  set -l v (fgrep OPENSSL_LINUX $f | awk '{print $2}' | tr -d '"' | tr -d "'" | grep -o "[0-9]\.[0-9]\.[0-9]")

  if test "$v" = ""
    echo "$f: no OPENSSL_LINUX specified, using 1.1.0"
    opensslVersion 1.1.0
  else
    echo "Using OpenSSL version '$v' from '$f'"
    opensslVersion $v
  end
end

## #############################################################################
## checkout and switch functions
## #############################################################################

function checkoutMirror
  if test (count $argv) -ne 1
    echo "usage: checkoutMirror.fish <DIRECTORY>"
    exit 1
  end

  runInContainer -v $argv[1]:/mirror $ALPINEUTILSIMAGE $SCRIPTSDIR/checkoutMirror.fish
  or return $status
end

function checkoutUpgradeDataTests
  runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/checkoutUpgradeDataTests.fish
  or return $status
end

function checkoutArangoDB
  runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/checkoutArangoDB.fish
  or return $status
  community
end

function checkoutEnterprise
  runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/checkoutEnterprise.fish
  or return $status
  enterprise
end

function checkoutMiniChaos
  runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/checkoutMiniChaos.fish
  or return $status
end

function switchBranches
  set -l force_clean false

  if test (count $argv) -eq 3
    set force_clean $argv[3]
  end

  if test $force_clean = "true"
    if test ! -d $WORKDIR/ArangoDB/.git
      rm -rf $INNERWORKDIR/ArangoDB/.git
      or return $status
    end
  end

  checkoutIfNeeded
  and runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/switchBranches.fish $argv
  and findRequiredCompiler
  and set -gx MINIMAL_DEBUG_INFO (findMinimalDebugInfo)
  and findDefaultArchitecture
end

## #############################################################################
## LDAP
## #############################################################################

set -gx LDAPEXT ""

if test -n "$NODE_NAME"
  set -gx LDAPEXT (echo "$NODE_NAME" | tr -c -d "[:alnum:]")
end

set -gx LDAPHOST "$LDAPDOCKERCONTAINERNAME$LDAPEXT"

function stopLdapServer
  docker stop "$LDAPDOCKERCONTAINERNAME$LDAPEXT"
  docker rm "$LDAPDOCKERCONTAINERNAME$LDAPEXT"
  docker network rm "$LDAPNETWORK$LDAPEXT"
  true
end

function launchLdapServer
  stopLdapServer
  and docker network create "$LDAPNETWORK$LDAPEXT"
  and docker run -d --name "$LDAPHOST" --net="$LDAPNETWORK$LDAPEXT" neunhoef/ldap-alpine
end

## #############################################################################
## build
## #############################################################################

function buildArangoDB
  #TODO FIXME - do not change the current directory so people
  #             have to do a 'cd' for a subsequent call.
  #             Fix by not relying on relative locations in other functions
  checkoutIfNeeded
  and findRequiredCompiler
  and findRequiredOpenSSL
  and findDefaultArchitecture
  and runInContainer (findBuildImage) $SCRIPTSDIR/(findBuildScript) $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeArangoDB
  if test "$COMPILER_VERSION" = ""
    findRequiredCompiler
    and findRequiredOpenSSL
    and findDefaultArchitecture
  end
  and runInContainer (findBuildImage) $SCRIPTSDIR/makeArangoDB.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function buildStaticArangoDB
  checkoutIfNeeded
  and findRequiredCompiler
  and findRequiredOpenSSL
  and findDefaultArchitecture
  and runInContainer (findStaticBuildImage) $SCRIPTSDIR/(findStaticBuildScript) $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeStaticArangoDB
  if test "$COMPILER_VERSION" = ""
    findRequiredCompiler
    and findRequiredOpenSSL
    and findDefaultArchitecture
  end
  and runInContainer (findStaticBuildImage) $SCRIPTSDIR/makeAlpine.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function buildStaticCoverage
  # note: DEBUG_SYNC_REPLICATION is removed from 3.8 onwards an can be removed here too soon 
  coverageOn
  and buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On 
end

function buildExamples
  checkoutIfNeeded
  and if test "$NO_RM_BUILD" != 1
    buildStaticArangoDB "-DUSE_IPO=Off"
  end
  and runInContainer (findStaticBuildImage) $SCRIPTSDIR/buildExamples.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

## #############################################################################
## test
## #############################################################################

function oskar
  set -l s 1
  set -l p $PARALLELISM

  checkoutIfNeeded
  and if test "$ASAN" = "On"
    parallelism 2
    runInContainer --cap-add SYS_NICE --cap-add SYS_PTRACE (findBuildImage) $SCRIPTSDIR/runTests.fish $argv
  else
    runInContainer --cap-add SYS_NICE (findBuildImage) $SCRIPTSDIR/runTests.fish $argv
  end
  set s $status

  parallelism $p
  return $s
end

function oskarFull
  set -l s 1
  set -l p $PARALLELISM

  checkoutIfNeeded
  and if test "$ENTERPRISEEDITION" = "On"
    launchLdapServer
    and if test "$ASAN" = "On"
      parallelism 2
      runInContainer --net="$LDAPNETWORK$LDAPEXT" --cap-add SYS_NICE --cap-add SYS_PTRACE (findBuildImage) $SCRIPTSDIR/runFullTests.fish $argv
    else
      runInContainer --net="$LDAPNETWORK$LDAPEXT" --cap-add SYS_NICE (findBuildImage) $SCRIPTSDIR/runFullTests.fish $argv
    end
    set s $status
  else
    if test "$ASAN" = "On"
      parallelism 2
      runInContainer --cap-add SYS_NICE --cap-add SYS_PTRACE (findBuildImage) $SCRIPTSDIR/runFullTests.fish $argv
    else
      runInContainer --cap-add SYS_NICE (findBuildImage) $SCRIPTSDIR/runFullTests.fish $argv
    end
  end
  set s $status

  if test "$ENTERPRISEEDITION" = "On"
    stopLdapServer
  end

  parallelism $p
  return $s
end

function oskarOneTest
  set -l s 1
  set -l p $PARALLELISM

  checkoutIfNeeded
  and if test "$ENTERPRISEEDITION" = "On"
    launchLdapServer
    and if test "$ASAN" = "On"
      parallelism 2
      runInContainer --net="$LDAPNETWORK$LDAPEXT" --cap-add SYS_NICE --cap-add SYS_PTRACE (findBuildImage) $SCRIPTSDIR/runOneTest.fish $argv
    else
      runInContainer --net="$LDAPNETWORK$LDAPEXT" --cap-add SYS_NICE (findBuildImage) $SCRIPTSDIR/runOneTest.fish $argv
    end
    set s $status
  else
    if test "$ASAN" = "On"
      parallelism 2
      runInContainer --cap-add SYS_NICE --cap-add SYS_PTRACE (findBuildImage) $SCRIPTSDIR/runOneTest.fish $argv
    else
      runInContainer --cap-add SYS_NICE (findBuildImage) $SCRIPTSDIR/runOneTest.fish $argv
    end
  end
  set s $status

  if test "$ENTERPRISEEDITION" = "On"
    stopLdapServer
  end

  parallelism $p
  return $s
end

## #############################################################################
## jslint
## #############################################################################

function jslint
  checkoutIfNeeded
  and pushd $WORKDIR/work/ArangoDB
  or begin popd; return 1; end

  set -l s 0
  runInContainer arangodb/arangodb /scripts/jslint.sh
  set s $status

  popd
  return $s
end

## #############################################################################
## cppcheck
## #############################################################################

function cppcheckArangoDB
  checkoutIfNeeded

  runInContainer $CPPCHECKIMAGE /scripts/cppcheck.sh
  return $status
end

## #############################################################################
## coverage
## #############################################################################

function collectCoverage
  findRequiredCompiler
  and findRequiredOpenSSL
  and runInContainer (findStaticBuildImage) /scripts/coverage.fish
  return $status
end

## #############################################################################
## source release
## #############################################################################

function signSourcePackage
  set -l SOURCE_TAG $argv[1]

  pushd $WORKDIR/work
  and runInContainer \
        -e ARANGO_SIGN_PASSWD="$ARANGO_SIGN_PASSWD" \
        -v $HOME/.gnupg3:/root/.gnupg \
	(findBuildImage) $SCRIPTSDIR/signFile.fish \
	/work/ArangoDB-$SOURCE_TAG.tar.gz \
	/work/ArangoDB-$SOURCE_TAG.tar.bz2 \
	/work/ArangoDB-$SOURCE_TAG.zip
  and popd
  or begin ; popd ; return 1 ; end
end

function createCompleteTar
  set -l RELEASE_TAG $argv[1]

  pushd $WORKDIR/work and runInContainer \
	$ALPINEUTILSIMAGE $SCRIPTSDIR/createCompleteTar.fish \
	$RELEASE_TAG
  and popd
  or begin ; popd ; return 1 ; end
end

## #############################################################################
## linux release
## #############################################################################

function buildPackage
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_FULL_VERSION, for example by running findArangoDBVersion.
  buildDebianPackage
  and buildRPMPackage
  and buildTarGzPackage
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
  and set -xg NOSTRIP 1
  and buildStaticArangoDB
  and downloadStarter
  and downloadSyncer
  and copyRclone "linux"
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
  and set -xg NOSTRIP 1
  and buildStaticArangoDB
  and downloadStarter
  and buildPackage

  if test $status -ne 0
    echo Building community release failed.
    return 1
  end
end

## #############################################################################
## debian release
## #############################################################################

function buildDebianPackage
  if test ! -d $WORKDIR/work/ArangoDB/build
    echo buildDebianPackage: build directory does not exist
    return 1
  end

  set -l pd "default"

  if test -d $WORKDIR/debian/$ARANGODB_PACKAGES
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
    if test $PACKAGE_STRIP = All
      sed -i -e "s/@DEBIAN_STRIP_ALL@//"                 -i $TARGET/$f
      sed -i -e "s/@DEBIAN_STRIP_EXCEPT_ARANGOD@/echo /" -i $TARGET/$f
      sed -i -e "s/@DEBIAN_STRIP_NONE@/echo /"           -i $TARGET/$f
    else if test $PACKAGE_STRIP = ExceptArangod
      sed -i -e "s/@DEBIAN_STRIP_ALL@/echo /"            -i $TARGET/$f
      sed -i -e "s/@DEBIAN_STRIP_EXCEPT_ARANGOD@//"      -i $TARGET/$f
      sed -i -e "s/@DEBIAN_STRIP_NONE@/echo /"           -i $TARGET/$f
    else
      sed -i -e "s/@DEBIAN_STRIP_ALL@/echo /"            -i $TARGET/$f
      sed -i -e "s/@DEBIAN_STRIP_EXCEPT_ARANGOD@/echo /" -i $TARGET/$f
      sed -i -e "s/@DEBIAN_STRIP_NONE@//"                -i $TARGET/$f
    end
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

## #############################################################################
## redhat release
## #############################################################################

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

## #############################################################################
## Mini-Chaos
## #############################################################################

function runMiniChaos
  if test (count $argv) -lt 1
    echo "usage: runMiniChaos <package>"
    return 1
  end

  set -l package "$argv[1]"
  set -l duration "$argv[2]"

  mkdir -p $WORKDIR/work/mini-chaos

  test -e $WORKDIR/work/{$package}.tar.gz
  and rm -rf $WORKDIR/work/mini-chaos/$package
  and mkdir -p $WORKDIR/work/mini-chaos/$package/ArangoDB
  and tar -xf $WORKDIR/work/{$package}.tar.gz --strip-components=1 -C $WORKDIR/work/mini-chaos/$package/ArangoDB
  and checkoutMiniChaos
  and rm -rf "$WORKDIR/work/mini-chaos/$package/output"
  and mkdir -p "$WORKDIR/work/mini-chaos/$package/output"
  runInContainer \
      --pid=host \
      -v $WORKDIR/work/ArangoDB/mini-chaos:/mini-chaos \
      -v $WORKDIR/work/mini-chaos/$package:/$package \
      -e ARANGODB_OVERRIDE_CRASH_HANDLER=0 \
      (findBuildImage) $SCRIPTSDIR/startMiniChaos.fish $package $duration
end


## #############################################################################
## TAR server test
## #############################################################################

function makeTestPackageLinux
  if test "$ENTERPRISEEDITION" = "On" -a "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER for Enterprise package or use Community."
    return 1
  end

  test (findMinimalDebugInfo) = "On"
  and begin
    packageStripExceptArangod
    minimalDebugInfoOn
  end
  or begin
    packageStripAll
    minimalDebugInfoOff
  end
  echo ""

  findArangoDBVersion
  and asanOff
  and releaseMode
  and set -xg NOSTRIP 1
  and buildStaticArangoDB
  and downloadStarter
  and if test "$ENTERPRISEEDITION" = "On"; downloadSyncer; and copyRclone "linux"; end
  and buildTarGzServerLinuxTestPackage

  if test $status -ne 0
    echo Building test package failed, stopping!
    return 1
  end
end

function buildTarGzServerLinuxTestPackage
  # This assumes that a static build has already happened
  # Must have set ARANGODB_TGZ_UPSTREAM
  # for example by running findArangoDBVersion.
  set -l v "$ARANGODB_TGZ_UPSTREAM"
  set -l name

  if test "$ENTERPRISEEDITION" = "On"
    set name arangodb3e
  else
    set name arangodb3
  end

  pushd $WORKDIR/work
  and rm -rf targz
  and mkdir targz
  and cd $WORKDIR/work/ArangoDB/build/install
  and cp -a * $WORKDIR/work/targz
  and cd $WORKDIR/work/targz
  and rm -rf bin
  and cp -a $WORKDIR/binForTarGz bin
  and find bin "(" -name "*.bak" -o -name "*~" ")" -delete
  and mv bin/README .
  and prepareInstall $WORKDIR/work/targz
  and rm -rf "$WORKDIR/work/$name-$v"
  and cp -r $WORKDIR/work/targz "$WORKDIR/work/$name-$v"
  and cd $WORKDIR/work
  or begin ; popd ; return 1 ; end

  rm -rf "$name-linux-$v"
  and ln -s "$name-$v" "$name-linux-$v"
  and tar -c -z -f "$WORKDIR/work/$name-linux-$v.tar.gz" -h --exclude "etc" --exclude "var" "$name-linux-$v"
  and rm -rf "$name-linux-$v"
  set s $status

  popd
  echo "$WORKDIR/work/$name-linux-$v.tar.gz"
  and return $s
  or begin ; popd ; return 1 ; end
end

function getTestPackageLinuxName
  # This assumes that a static build has already happened
  # Must have set ARANGODB_TGZ_UPSTREAM
  # for example by running findArangoDBVersion.
  set -l v "$ARANGODB_TGZ_UPSTREAM"
  set -l name

  if test "$ENTERPRISEEDITION" = "On"
    set name arangodb3e
  else
    set name arangodb3
  end

  echo "$name-linux-$v"
end

## #############################################################################
## TAR release
## #############################################################################

function buildTarGzPackage
  if test ! -d $WORKDIR/work/ArangoDB/build
    echo buildTarGzPackage: build directory does not exist
    return 1
  end

  buildTarGzPackageHelper "linux"
end

## #############################################################################
## docker release
## #############################################################################

function makeDockerRelease
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  findArangoDBVersion ; or return 1

  if test (count $argv) -ge 1
    set CUSTOM_DOCKER_TAG $argv[1]
  end

  community
  and buildDockerRelease $CUSTOM_DOCKER_TAG
  and enterprise
  and buildDockerRelease $CUSTOM_DOCKER_TAG
end

function makeDockerCommunityRelease
  findArangoDBVersion ; or return 1

  test (findMinimalDebugInfo) = "On"
  and begin
    packageStripExceptArangod
    minimalDebugInfoOn
  end
  or begin
    packageStripAll
    minimalDebugInfoOff
  end
  echo ""
  buildCommunityPackage
  and community  
  and if test (count $argv) -ge 1
    buildDockerRelease $argv[1]
  else
    buildDockerRelease $DOCKER_TAG
  end
end

function makeDockerEnterpriseRelease
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  findArangoDBVersion ; or return 1

  test (findMinimalDebugInfo) = "On"
  and begin
    packageStripExceptArangod
    minimalDebugInfoOn
  end
  or begin
    packageStripAll
    minimalDebugInfoOff
  end
  echo ""
  buildEnterprisePackage
  and enterprise
  and if test (count $argv) -ge 1
    buildDockerRelease $argv[1]
  else
    buildDockerRelease $DOCKER_TAG
  end
end

function makeDockerEnterpriseDebug
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  findArangoDBVersion ; or return 1

  packageStripOff
  and minimalDebugInfoOff
  and buildEnterprisePackage
  and enterprise
  and if test (count $argv) -ge 1
    buildDockerRelease $argv[1]-debug
  else
    buildDockerRelease $DOCKER_TAG-debug
  end
end

function buildDockerRelease
  set -l DOCKER_TAG $argv[1]

  # build tag
  set -l IMAGE_NAME1 ""

  # push tag
  set -l IMAGE_NAME2 ""

  # latest tag
  set -l IMAGE_NAME3 ""

  if echo "$DOCKER_TAG" | fgrep -q :
     set IMAGE_NAME1 $DOCKER_TAG
     set IMAGE_NAME2 $DOCKER_TAG
  else
    if test "$ENTERPRISEEDITION" = "On"
      if test "$RELEASE_TYPE" = "stable"
        set IMAGE_NAME1 arangodb/enterprise:$DOCKER_TAG
      else
        set IMAGE_NAME1 arangodb/enterprise-preview:$DOCKER_TAG
      end

      set IMAGE_NAME2 arangodb/enterprise-preview:$DOCKER_TAG

      if test "$RELEASE_IS_HEAD" = "true"
        set IMAGE_NAME3 arangodb/enterprise-preview:latest
      end
    else
      if test "$RELEASE_TYPE" = "stable"
        set IMAGE_NAME1 arangodb/arangodb:$DOCKER_TAG
      else
        set IMAGE_NAME1 arangodb/arangodb-preview:$DOCKER_TAG
      end

      set IMAGE_NAME2 arangodb/arangodb-preview:$DOCKER_TAG

      if test "$RELEASE_IS_HEAD" = "true"
        set IMAGE_NAME3 arangodb/arangodb-preview:latest
      end
    end
  end

  echo "building docker image"
  and asanOff
  and maintainerOff
  and releaseMode
  and buildStaticArangoDB
  and downloadStarter
  and if test "$ENTERPRISEEDITION" = "On"
    downloadSyncer
    copyRclone "linux"
  end
  and buildDockerImage $IMAGE_NAME1
  and if test "$IMAGE_NAME1" != "$IMAGE_NAME2"
    docker tag $IMAGE_NAME1 $IMAGE_NAME2
  else
    if test "$GCR_REG" = "On"
      docker tag $IMAGE_NAME1 $GCR_REG_PREFIX$IMAGE_NAME1
      and pushDockerImage $GCR_REG_PREFIX$IMAGE_NAME1
    end
  end
  and pushDockerImage $IMAGE_NAME2
  and if test "$ENTERPRISEEDITION" = "On"
    echo $IMAGE_NAME1 > $WORKDIR/work/arangodb3e.docker
  else
    echo $IMAGE_NAME1 > $WORKDIR/work/arangodb3.docker
  end
  and if test "$IMAGE_NAME3" != ""
    docker tag $IMAGE_NAME1 $IMAGE_NAME3
    and pushDockerImage $IMAGE_NAME3
    and  if test "$GCR_REG" = "On"
      docker tag $IMAGE_NAME3 $GCR_REG_PREFIX$IMAGE_NAME3
      and pushDockerImage $GCR_REG_PREFIX$IMAGE_NAME3
    end
  end
end

function buildDockerArgs
  if test (count $argv) -eq 0
    echo Must give image distro as argument
    return 1
  end

  set -l imagedistro $argv[1]

  set -l containerpath $WORKDIR/containers/arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR$imagedistro.docker

  if not test -d $containerpath
    set containerpath $WORKDIR/containers/arangodbDevel$imagedistro.docker
  end

  set -l EDITION "Community"
  if test "$ENTERPRISEEDITION" = "On"
    set EDITION "Enterprise"
  end

  set -l BUILD_ARGS ""

  switch $imagedistro
    case ubi
      set BUILD_ARGS $BUILD_ARGS"--build-arg name="(string lower $EDITION)
      set BUILD_ARGS $BUILD_ARGS" --build-arg vendor=ArangoDB"
      set BUILD_ARGS $BUILD_ARGS" --build-arg version="$ARANGODB_VERSION
      set BUILD_ARGS $BUILD_ARGS" --build-arg release="$ARANGODB_VERSION
      set BUILD_ARGS $BUILD_ARGS" --build-arg summary=\"ArangoDB "$EDITION"\""
      set BUILD_ARGS $BUILD_ARGS" --build-arg description=\"ArangoDB "$EDITION"\""
      set BUILD_ARGS $BUILD_ARGS" --build-arg maintainer=redhat@arangodb.com"
  end

  echo "$BUILD_ARGS"
end

function buildDockerAddFiles
  if test (count $argv) -eq 0
    echo Must give image distro as argument
    return 1
  end

  set -l imagedistro $argv[1]

  findArangoDBVersion ; or return 1
  set -l containerpath $WORKDIR/containers/arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR$imagedistro.docker

  if not test -d $containerpath
    set containerpath $WORKDIR/containers/arangodbDevel$imagedistro.docker
  end

  switch $imagedistro
    case ubi
      cp $WORKDIR/work/ArangoDB/LICENSE $containerpath
  end
end

function buildDockerImage
  if test (count $argv) -eq 0
    echo Must give image name as argument
    return 1
  end

  set -l imagename $argv[1]

  findArangoDBVersion ; or return 1
  set -l BUILD_ARGS (buildDockerArgs $DOCKER_DISTRO)
  set -l containerpath $WORKDIR/containers/arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR$DOCKER_DISTRO.docker

  if not test -d $containerpath
    set containerpath $WORKDIR/containers/arangodbDevel$DOCKER_DISTRO.docker
  end

  pushd $WORKDIR/work
  and rm -rf docker
  and mkdir docker
  and cp -a $WORKDIR/work/ArangoDB/build/install/* $WORKDIR/work/docker
  and cd $WORKDIR/work/docker
  and prepareInstall $WORKDIR/work/docker
  and popd
  or begin ; rm -rf $WORKDIR/work/docker ; popd ; return 1 ; end
  
  pushd $WORKDIR/work/docker
  and tar czf $containerpath/install.tar.gz *
  and buildDockerAddFiles $DOCKER_DISTRO
  if test $status -ne 0
    echo Could not create install tarball!
    popd
    return 1
  end
  popd

  pushd $containerpath
  and eval "docker build $BUILD_ARGS --pull --no-cache -t $imagename ."
  or begin ; popd ; return 1 ; end
  popd
end

function pushDockerImage
  if test (count $argv) -eq 0
    echo Must give image name as argument
    return 1
  end

  set -l imagename $argv[1]

  if test (docker images -q $imagename 2> /dev/null) = ""
    echo Given image is not present locally
    return 1
  end

  docker push $imagename
end

function buildDockerLocal
  findArangoDBVersion ; or return 1
  set -l BUILD_ARGS (buildDockerArgs $DOCKER_DISTRO)
  pushd $WORKDIR/work/ArangoDB/build/install

  set -l containerpath $WORKDIR/containers/arangodb$ARANGODB_VERSION_MAJOR$ARANGODB_VERSION_MINOR$DOCKER_DISTRO.docker

  if not test -d $containerpath
    set containerpath $WORKDIR/containers/arangodbDevel$DOCKER_DISTRO.docker
  end
  and tar czf $containerpath/install.tar.gz *
  and buildDockerAddFiles $DOCKER_DISTRO
  if test $status -ne 0
    echo Could not create install tarball!
    popd
    return 1
  end
  popd

  pushd $containerpath
  and eval "docker build --pull ."
  or begin ; popd ; return 1 ; end
  popd
end

## #############################################################################
## create repos
## #############################################################################

function createRepositories
  findArangoDBVersion

  pushd $WORKDIR
  runInContainer \
      -e ARANGO_SIGN_PASSWD="$ARANGO_SIGN_PASSWD" \
      -v $HOME/.gnupg3:/root/.gnupg \
      -v /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/packages:/packages \
      -v /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/repositories:/repositories \
      $UBUNTUPACKAGINGIMAGE $SCRIPTSDIR/createAll
  or begin ; popd ; return 1 ; end
  popd
end

## #############################################################################
## build and packaging images
## #############################################################################

function buildUbuntuBuildImage3
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildUbuntu3.docker
  and docker build --pull -t $UBUNTUBUILDIMAGE3 .
  popd
end

function pushUbuntuBuildImage3
  docker tag $UBUNTUBUILDIMAGE3 $UBUNTUBUILDIMAGE3_NAME:latest
  and docker push $UBUNTUBUILDIMAGE3
  and docker push $UBUNTUBUILDIMAGE3_NAME:latest
end

function pullUbuntuBuildImage3 ; docker pull $UBUNTUBUILDIMAGE3 ; end

function buildUbuntuBuildImage4
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildUbuntu4.docker
  and docker build --pull -t $UBUNTUBUILDIMAGE4 .
  or begin ; popd ; return 1 ; end
  popd
end

function pushUbuntuBuildImage4
  docker tag $UBUNTUBUILDIMAGE4 $UBUNTUBUILDIMAGE4_NAME:latest
  and docker push $UBUNTUBUILDIMAGE4
  and docker push $UBUNTUBUILDIMAGE4_NAME:latest
end

function pullUbuntuBuildImage4 ; docker pull $UBUNTUBUILDIMAGE4 ; end

function buildUbuntuBuildImage5
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildUbuntu5.docker
  and docker build --pull -t $UBUNTUBUILDIMAGE5 .
  or begin ; popd ; return 1 ; end
  popd
end

function pushUbuntuBuildImage5
  docker tag $UBUNTUBUILDIMAGE5 $UBUNTUBUILDIMAGE5_NAME:latest
  and docker push $UBUNTUBUILDIMAGE5
  and docker push $UBUNTUBUILDIMAGE5_NAME:latest
end

function pullUbuntuBuildImage5 ; docker pull $UBUNTUBUILDIMAGE5 ; end

function buildUbuntuPackagingImage
  pushd $WORKDIR
  and cp -a scripts/buildDebianPackage.fish containers/buildUbuntuPackaging.docker/scripts
  and cd $WORKDIR/containers/buildUbuntuPackaging.docker
  and docker build --pull -t $UBUNTUPACKAGINGIMAGE .
  and rm -f $WORKDIR/containers/buildUbuntuPackaging.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushUbuntuPackagingImage ; docker push $UBUNTUPACKAGINGIMAGE ; end

function pullUbuntuPackagingImage ; docker pull $UBUNTUPACKAGINGIMAGE ; end

function buildAlpineBuildImage3
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildAlpine3.docker
  and docker build --pull -t $ALPINEBUILDIMAGE3 .
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineBuildImage3
  docker tag $ALPINEBUILDIMAGE3 $ALPINEBUILDIMAGE3_NAME:latest
  and docker push $ALPINEBUILDIMAGE3
  and docker push $ALPINEBUILDIMAGE3_NAME:latest
end

function pullAlpineBuildImage3 ; docker pull $ALPINEBUILDIMAGE3 ; end

function buildAlpineBuildImage4
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildAlpine4.docker
  and docker build --pull -t $ALPINEBUILDIMAGE4 .
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineBuildImage4
  docker tag $ALPINEBUILDIMAGE4 $ALPINEBUILDIMAGE4_NAME:latest
  and docker push $ALPINEBUILDIMAGE4
  and docker push $ALPINEBUILDIMAGE4_NAME:latest
end

function pullAlpineBuildImage4 ; docker pull $ALPINEBUILDIMAGE4 ; end

function buildAlpineBuildImage5
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildAlpine5.docker
  and docker build --pull -t $ALPINEBUILDIMAGE5 .
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineBuildImage5
  docker tag $ALPINEBUILDIMAGE5 $ALPINEBUILDIMAGE5_NAME:latest
  and docker push $ALPINEBUILDIMAGE5
  and docker push $ALPINEBUILDIMAGE5_NAME:latest
end

function pullAlpineBuildImage5 ; docker pull $ALPINEBUILDIMAGE5 ; end

function buildAlpineUtilsImage
  pushd $WORKDIR
  and cp -a scripts/{checkoutArangoDB,checkoutEnterprise,clearWorkDir,downloadStarter,downloadSyncer,runTests,runFullTests,switchBranches,recursiveChown}.fish containers/buildUtils.docker/scripts
  and cd $WORKDIR/containers/buildUtils.docker
  and docker build --pull -t $ALPINEUTILSIMAGE .
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineUtilsImage
  docker tag $ALPINEUTILSIMAGE $ALPINEUTILSIMAGE_NAME:latest
  and docker push $ALPINEUTILSIMAGE
  and docker push $ALPINEUTILSIMAGE_NAME:latest
end

function pullAlpineUtilsImage ; docker pull $ALPINEUTILSIMAGE ; end

function buildCentosPackagingImage
  pushd $WORKDIR
  and cp -a scripts/buildRPMPackage.fish containers/buildCentos7Packaging.docker/scripts
  and cd $WORKDIR/containers/buildCentos7Packaging.docker
  and docker build --pull -t $CENTOSPACKAGINGIMAGE .
  and rm -f $WORKDIR/containers/buildCentos7Packaging.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushCentosPackagingImage
  docker tag $CENTOSPACKAGINGIMAGE $CENTOSPACKAGINGIMAGE_NAME:latest
  and docker push $CENTOSPACKAGINGIMAGE
  and docker push $CENTOSPACKAGINGIMAGE_NAME:latest
end

function pullCentosPackagingImage ; docker pull $CENTOSPACKAGINGIMAGE ; end

function buildCppcheckImage
  pushd $WORKDIR/containers/cppcheck.docker
  and docker build --pull -t $CPPCHECKIMAGE .
  or begin ; popd ; return 1 ; end
  popd
end
function pushCppcheckImage
  docker tag $CPPCHECKIMAGE $CPPCHECKIMAGE_NAME:latest
  and docker push $CPPCHECKIMAGE
  and docker push $CPPCHECKIMAGE_NAME:latest
end
function pullCppcheckImage ; docker pull $CPPCHECKIMAGE ; end

function remakeImages
  set -l s 0

  buildUbuntuBuildImage ; or set -l s 1
  pushUbuntuBuildImage ; or set -l s 1
  buildUbuntuBuildImage2 ; or set -l s 1
  pushUbuntuBuildImage2 ; or set -l s 1
  buildUbuntuBuildImage3 ; or set -l s 1
  pushUbuntuBuildImage3 ; or set -l s 1
  buildUbuntuBuildImage4 ; or set -l s 1
  pushUbuntuBuildImage4 ; or set -l s 1
  buildAlpineBuildImage ; or set -l s 1
  pushAlpineBuildImage ; or set -l s 1
  buildAlpineBuildImage2 ; or set -l s 1
  pushAlpineBuildImage2 ; or set -l s 1
  buildAlpineBuildImage3 ; or set -l s 1
  pushAlpineBuildImage3 ; or set -l s 1
  buildAlpineBuildImage4 ; or set -l s 1
  pushAlpineBuildImage4 ; or set -l s 1
  buildAlpineUtilsImage ; or set -l s 1
  pushAlpineUtilsImage ; or set -l s 1
  buildUbuntuPackagingImage ; or set -l s 1
  pushUbuntuPackagingImage ; or set -l s 1
  buildCentosPackagingImage ; or set -l s 1
  pushCentosPackagingImage ; or set -l s 1
  buildCppcheckImage ; or set -l s 1

  return $s
end

function remakeBuildImages
  set -l s 0

  buildUbuntuBuildImage ; or set -l s 1
  pushUbuntuBuildImage ; or set -l s 1
  buildUbuntuBuildImage2 ; or set -l s 1
  pushUbuntuBuildImage2 ; or set -l s 1
  buildUbuntuBuildImage3 ; or set -l s 1
  pushUbuntuBuildImage3 ; or set -l s 1
  buildUbuntuBuildImage4 ; or set -l s 1
  pushUbuntuBuildImage4 ; or set -l s 1
  buildAlpineBuildImage ; or set -l s 1
  pushAlpineBuildImage ; or set -l s 1
  buildAlpineBuildImage2 ; or set -l s 1
  pushAlpineBuildImage2 ; or set -l s 1
  buildAlpineBuildImage3 ; or set -l s 1
  pushAlpineBuildImage3 ; or set -l s 1
  buildAlpineBuildImage4 ; or set -l s 1
  pushAlpineBuildImage4 ; or set -l s 1

  return $s
end

## #############################################################################
## run commands in container
## #############################################################################

function runInContainer
  if test -z "$SSH_AUTH_SOCK"
    sudo killall --older-than 8h ssh-agent 2>&1 > /dev/null
    eval (ssh-agent -c) > /dev/null
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_deploy
      if test -f $key
        ssh-add $key
      end
    end
    set -l agentstarted 1
  else
    set -l agentstarted ""
  end

  set -l mirror

  if test -n "$GITHUB_MIRROR" -a -d "$GITHUB_MIRROR/mirror"
    set mirror -v $GITHUB_MIRROR/mirror:/mirror
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
             $mirror \
             -e ARANGODB_DOCS_BRANCH="$ARANGODB_DOCS_BRANCH" \
             -e ARANGODB_PACKAGES="$ARANGODB_PACKAGES" \
             -e ARANGODB_REPO="$ARANGODB_REPO" \
             -e ARANGODB_VERSION="$ARANGODB_VERSION" \
             -e ASAN="$ASAN" \
             -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
             -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
             -e BUILDMODE="$BUILDMODE" \
             -e CCACHEBINPATH="$CCACHEBINPATH" \
             -e COMPILER_VERSION=(echo (string replace -r '[_\-].*$' "" $COMPILER_VERSION)) \
             -e COVERAGE="$COVERAGE" \
	           -e DEFAULT_ARCHITECTURE="$DEFAULT_ARCHITECTURE" \
             -e ENTERPRISEEDITION="$ENTERPRISEEDITION" \
             -e GID=(id -g) \
             -e GIT_CURL_VERBOSE="$GIT_CURL_VERBOSE" \
             -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
             -e GIT_TRACE="$GIT_TRACE" \
             -e GIT_TRACE_PACKET="$GIT_TRACE_PACKET" \
             -e INNERWORKDIR="$INNERWORKDIR" \
             -e IONICE="$IONICE" \
             -e JEMALLOC_OSKAR="$JEMALLOC_OSKAR" \
             -e KEYNAME="$KEYNAME" \
             -e LDAPHOST="$LDAPHOST" \
             -e MAINTAINER="$MAINTAINER" \
             -e MINIMAL_DEBUG_INFO="$MINIMAL_DEBUG_INFO" \
             -e NODE_NAME="$NODE_NAME" \
             -e NOSTRIP="$NOSTRIP" \
             -e NO_RM_BUILD="$NO_RM_BUILD" \
             -e ONLYGREY="$ONLYGREY" \
             -e OPENSSL_VERSION="$OPENSSL_VERSION" \
             -e PACKAGE_STRIP="$PACKAGE_STRIP" \
             -e PARALLELISM="$PARALLELISM" \
             -e PLATFORM="$PLATFORM" \
             -e SCCACHE_BUCKET="$SCCACHE_BUCKET" \
             -e SCCACHE_ENDPOINT="$SCCACHE_ENDPOINT" \
             -e SCCACHE_GCS_BUCKET="$SCCACHE_GCS_BUCKET" \
             -e SCCACHE_GCS_KEY_PATH="$SCCACHE_GCS_KEY_PATH" \
             -e SCCACHE_IDLE_TIMEOUT="$SCCACHE_IDLE_TIMEOUT" \
             -e SCCACHE_MEMCACHED="$SCCACHE_MEMCACHED" \
             -e SCCACHE_REDIS="$SCCACHE_REDIS" \
             -e SCRIPTSDIR="$SCRIPTSDIR" \
             -e SHOW_DETAILS="$SHOW_DETAILS" \
             -e SKIPGREY="$SKIPGREY" \
             -e SKIPNONDETERMINISTIC="$SKIPNONDETERMINISTIC" \
             -e SKIPTIMECRITICAL="$SKIPTIMECRITICAL" \
             -e SKIP_MAKE="$SKIP_MAKE" \
             -e SSH_AUTH_SOCK=/ssh-agent \
             -e STORAGEENGINE="$STORAGEENGINE" \
             -e TEST="$TEST" \
             -e TESTSUITE="$TESTSUITE" \
             -e UID=(id -u) \
             -e USE_CCACHE="$USE_CCACHE" \
             -e USE_STRICT_OPENSSL="$USE_STRICT_OPENSSL" \
             -e VERBOSEBUILD="$VERBOSEBUILD" \
             -e VERBOSEOSKAR="$VERBOSEOSKAR" \
             -e PROMTOOL_PATH="$PROMTOOL_PATH" \
             $argv)
  function termhandler --on-signal TERM --inherit-variable c
    if test -n "$c"
      docker stop $c >/dev/null
      docker rm $c >/dev/null
    end
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
      --rm \
      $ALPINEUTILSIMAGE $SCRIPTSDIR/recursiveChown.fish

  if test -n "$agentstarted"
    ssh-agent -k > /dev/null
    set -e SSH_AUTH_SOCK
    set -e SSH_AGENT_PID
  end
  return $s
end

function interactiveContainer
  if test -z "$SSH_AUTH_SOCK"
    sudo killall --older-than 8h ssh-agent 2>&1 > /dev/null
    eval (ssh-agent -c) > /dev/null
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_deploy
      if test -f $key
        ssh-add $key
      end
    end
    set -l agentstarted 1
  else
    set -l agentstarted ""
  end

  docker run -it --rm \
             -v $WORKDIR/work:$INNERWORKDIR \
             -v $SSH_AUTH_SOCK:/ssh-agent \
             -v "$WORKDIR/scripts":"/scripts" \
             -e ASAN="$ASAN" \
             -e GID=(id -g) \
             -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
             -e INNERWORKDIR="$INNERWORKDIR" \
             -e JEMALLOC_OSKAR="$JEMALLOC_OSKAR" \
             -e KEYNAME="$KEYNAME" \
             -e LDAPHOST="$LDAPHOST" \
             -e MAINTAINER="$MAINTAINER" \
             -e NOSTRIP="$NOSTRIP" \
             -e NO_RM_BUILD="$NO_RM_BUILD" \
             -e PARALLELISM="$PARALLELISM" \
             -e PLATFORM="$PLATFORM" \
             -e SCRIPTSDIR="$SCRIPTSDIR" \
             -e SKIPNONDETERMINISTIC="$SKIPNONDETERMINISTIC" \
             -e SKIPTIMECRITICAL="$SKIPTIMECRITICAL" \
             -e SKIPGREY="$SKIPGREY" \
             -e ONLYGREY="$ONLYGREY" \
             -e SSH_AUTH_SOCK=/ssh-agent \
             -e STORAGEENGINE="$STORAGEENGINE" \
             -e TESTSUITE="$TESTSUITE" \
             -e UID=(id -u) \
             -e VERBOSEBUILD="$VERBOSEBUILD" \
             -e VERBOSEOSKAR="$VERBOSEOSKAR" \
             -e USE_STRICT_OPENSSL="$USE_STRICT_OPENSSL" \
             -e PROMTOOL_PATH="$PROMTOOL_PATH" \
             $argv

  if test -n "$agentstarted"
    ssh-agent -k > /dev/null
    set -e SSH_AUTH_SOCK
    set -e SSH_AGENT_PID
  end
end

## #############################################################################
## build rclone
## #############################################################################

function buildRclone
  pushd $WORKDIR
  if test (count $argv) != 1
    popd
    echo "buildRclone: expecting version (ie, v1.51.0)"
    return 1
  end

  rm -rf rclone/$argv[1]
  mkdir rclone/$argv[1]

  docker run \
    -v (pwd)/scripts:/scripts \
    -v (pwd)/rclone/$argv[1]:/data \
    -e RCLONE_VERSION=$argv[1] \
    -it \
    golang:1.15.2 \
    bash -c /scripts/buildRclone.bash
  and popd
end

## #############################################################################
## helper functions
## #############################################################################

function findCompilerVersion
  echo $COMPILER_VERSION
end

function findOpenSSLVersion
  echo $OPENSSL_VERSION
end

function clearWorkDir
  runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/clearWorkDir.fish
end

function transformSpec
  if test (count $argv) != 2
    echo transformSpec: wrong number of arguments
    return 1
  end

  set -l filename $argv[2]
  and cp "$argv[1]" "$filename"
  and sed -i -e "s/@PACKAGE_VERSION@/$ARANGODB_RPM_UPSTREAM/" "$filename"
  and sed -i -e "s/@PACKAGE_REVISION@/$ARANGODB_RPM_REVISION/" "$filename"
  and if test $PACKAGE_STRIP = All
    sed -i -e "s/@RPM_STRIP_ALL@//"              "$filename"
    sed -i -e "s/@RPM_STRIP_EXCEPT_ARANGOD@/# /" "$filename"
    sed -i -e "s/@RPM_STRIP_NONE@/# /"           "$filename"
  else if test $PACKAGE_STRIP = ExceptArangod
    sed -i -e "s/@RPM_STRIP_ALL@/# /"            "$filename"
    sed -i -e "s/@RPM_STRIP_EXCEPT_ARANGOD@//"   "$filename"
    sed -i -e "s/@RPM_STRIP_NONE@/# /"           "$filename"
  else
    sed -i -e "s/@RPM_STRIP_ALL@/# /"            "$filename"
    sed -i -e "s/@RPM_STRIP_EXCEPT_ARANGOD@/# /" "$filename"
    sed -i -e "s/@RPM_STRIP_NONE@//"             "$filename"
  end
  and sed -i -e "s~@JS_DIR@~~" "$filename"
end

function shellInUbuntuContainer
  interactiveContainer (findBuildImage) fish
end

function shellInAlpineContainer
  interactiveContainer (findStaticBuildImage) fish
end

function pushOskar
  pushd $WORKDIR
  and source helper.fish
  and git push

  and buildUbuntuBuildImage3
  and pushUbuntuBuildImage3

  and buildUbuntuBuildImage4
  and pushUbuntuBuildImage4

  and buildUbuntuBuildImage5
  and pushUbuntuBuildImage5

  and buildAlpineBuildImage3
  and pushAlpineBuildImage3

  and buildAlpineBuildImage4
  and pushAlpineBuildImage4

  and buildAlpineBuildImage5
  and pushAlpineBuildImage5

  and buildAlpineUtilsImage
  and pushAlpineUtilsImage

  and buildUbuntuPackagingImage
  and pushUbuntuPackagingImage

  and buildCentosPackagingImage
  and pushCentosPackagingImage

  and buildCppcheckImage
  and pushCppcheckImage

  or begin ; popd ; return 1 ; end
  popd
end

function updateOskarOnly
  pushd $WORKDIR
  and git checkout -- .
  and git pull
  and source helper.fish
  or begin ; popd ; return 1 ; end
  popd
end

function updateOskar
  updateOskarOnly
  and pullUbuntuBuildImage3
  and pullUbuntuBuildImage4
  and pullUbuntuBuildImage5
  and pullAlpineBuildImage3
  and pullAlpineBuildImage4
  and pullAlpineBuildImage5
  and pullAlpineUtilsImage
  and pullUbuntuPackagingImage
  and pullCentosPackagingImage
  and pullCppcheckImage
end

function updateDockerBuildImage
  checkoutIfNeeded
  and findRequiredCompiler
  and findRequiredOpenSSL
  and docker pull (findBuildImage)
  and docker pull (findStaticBuildImage)
end

function downloadStarter
  mkdir -p $WORKDIR/work/$THIRDPARTY_BIN
  and runInContainer $ALPINEUTILSIMAGE $SCRIPTSDIR/downloadStarter.fish $INNERWORKDIR/$THIRDPARTY_BIN $argv
end

function downloadSyncer
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  and rm -f $WORKDIR/work/ArangoDB/build/install/usr/sbin/arangosync $WORKDIR/work/ArangoDB/build/install/usr/bin/arangosync
  and runInContainer -e DOWNLOAD_SYNC_USER=$DOWNLOAD_SYNC_USER $ALPINEUTILSIMAGE $SCRIPTSDIR/downloadSyncer.fish $INNERWORKDIR/$THIRDPARTY_SBIN $argv
  and ln -s ../sbin/arangosync $WORKDIR/work/ArangoDB/build/install/usr/bin/arangosync
end

## #############################################################################
## set PARALLELISM in a sensible way
## #############################################################################

parallelism (nproc)
