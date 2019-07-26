set -gx INNERWORKDIR /work
set -gx THIRDPARTY_BIN ArangoDB/build/install/usr/bin
set -gx THIRDPARTY_SBIN ArangoDB/build/install/usr/sbin
set -gx SCRIPTSDIR /scripts
set -gx PLATFORM linux
set -gx ARCH (uname -m)

set -gx UBUNTUBUILDIMAGE arangodb/ubuntubuildarangodb-$ARCH
set -gx UBUNTUPACKAGINGIMAGE arangodb/ubuntupackagearangodb-$ARCH
set -gx ALPINEBUILDIMAGE arangodb/alpinebuildarangodb-$ARCH
set -gx ALPINEBUILDIMAGE2 arangodb/alpinebuildarangodb2-$ARCH
set -gx CENTOSPACKAGINGIMAGE arangodb/centospackagearangodb-$ARCH
set -gx DOCIMAGE arangodb/arangodb-documentation
set -xg IONICE "ionice -t -n 7"

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
    case 6.4.0
      set -gx COMPILER_VERSION $cversion

    case 8.3.0
      set -gx COMPILER_VERSION $cversion

    case '*'
      echo "unknown compiler version $cversion"
  end
end

function findBuildImage
  if test "$COMPILER_VERSION" = ""
      echo $ALPINEBUILDIMAGE
  else
    switch $COMPILER_VERSION
      case 6.4.0
        echo $ALPINEBUILDIMAGE

      case 8.3.0
        echo $ALPINEBUILDIMAGE2

      case '*'
        echo "unknown compiler version $version"
        return 1
    end
  end
end

function findBuildScript
  if test "$COMPILER_VERSION" = ""
      echo buildAlpine.fish
  else
    switch $COMPILER_VERSION
      case 6.4.0
        echo buildAlpine.fish

      case 8.3.0
        echo buildAlpine2.fish

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

  if test "$COMPILER_VERSION" != ""
    echo "Compiler version already set to '$COMPILER_VERSION'"
    return 0
  end

  set -l v (fgrep GCC_LINUX $f | awk '{print $2}' | tr -d '"' | tr -d "'")

  if test "$v" = ""
    echo "$f: no GCC_LINUX specified, using default"
  else
    echo "Using compiler '$v' from '$f'"
    compiler $v
  end
end

## #############################################################################
## checkout and switch functions
## #############################################################################

function checkoutUpgradeDataTests
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/checkoutUpgradeDataTests.fish
  or return $status
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
  and runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/buildArangoDB.fish $argv
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
  and findRequiredCompiler
  and runInContainer (findBuildImage) $SCRIPTSDIR/(findBuildScript) $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeStaticArangoDB
  runInContainer (findBuildImage) $SCRIPTSDIR/makeAlpine.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function buildExamples
  checkoutIfNeeded
  and if test "$NO_RM_BUILD" != 1
    buildStaticArangoDB
  end
  and runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/buildExamples.fish $argv
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
    runInContainer --cap-add SYS_NICE --cap-add SYS_PTRACE $UBUNTUBUILDIMAGE $SCRIPTSDIR/runTests.fish
  else
    runInContainer --cap-add SYS_NICE $UBUNTUBUILDIMAGE $SCRIPTSDIR/runTests.fish
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
      runInContainer --net="$LDAPNETWORK$LDAPEXT" --cap-add SYS_NICE --cap-add SYS_PTRACE $UBUNTUBUILDIMAGE $SCRIPTSDIR/runFullTests.fish
    else
      runInContainer --net="$LDAPNETWORK$LDAPEXT" --cap-add SYS_NICE $UBUNTUBUILDIMAGE $SCRIPTSDIR/runFullTests.fish
    end
    set s $status
  else
    if test "$ASAN" = "On"
      parallelism 2
      runInContainer --cap-add SYS_NICE --cap-add SYS_PTRACE $UBUNTUBUILDIMAGE $SCRIPTSDIR/runFullTests.fish
    else
      runInContainer --cap-add SYS_NICE $UBUNTUBUILDIMAGE $SCRIPTSDIR/runFullTests.fish
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
## source release
## #############################################################################

function signSourcePackage
  set -l SOURCE_TAG $argv[1]

  pushd $WORKDIR/work
  and runInContainer \
        -e ARANGO_SIGN_PASSWD="$ARANGO_SIGN_PASSWD" \
        -v $HOME/.gnupg3:/root/.gnupg \
	$UBUNTUBUILDIMAGE $SCRIPTSDIR/signFile.fish \
	/work/ArangoDB-$SOURCE_TAG.tar.gz \
	/work/ArangoDB-$SOURCE_TAG.tar.bz2 \
	/work/ArangoDB-$SOURCE_TAG.zip
  and popd
  or begin ; popd ; return 1 ; end
end

function createCompleteTar
  set -l RELEASE_TAG $argv[1]

  pushd $WORKDIR/work
  and runInContainer \
	$UBUNTUBUILDIMAGE $SCRIPTSDIR/createCompleteTar.fish \
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
  and set -xg NOSTRIP dont
  and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
  and downloadStarter
  and downloadSyncer
  and copyRclone
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
## TAR release
## #############################################################################

function buildTarGzPackage
  if test ! -d $WORKDIR/work/ArangoDB/build
    echo buildRPMPackage: build directory does not exist
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
    set DOCKER_TAG $argv[1]
  end

  community
  and buildDockerRelease $DOCKER_TAG
  and enterprise
  and buildDockerRelease $DOCKER_TAG
end

function makeDockerCommunityRelease
  findArangoDBVersion ; or return 1

  if test (count $argv) -ge 1
    set DOCKER_TAG $argv[1]
  end

  community
  and buildDockerRelease $DOCKER_TAG
end

function makeDockerEnterpriseRelease
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  findArangoDBVersion ; or return 1

  if test (count $argv) -ge 1
    set DOCKER_TAG $argv[1]
  end

  enterprise
  and buildDockerRelease $DOCKER_TAG
end

function buildDockerRelease
  set -l DOCKER_TAG $argv[1]

  # build tag
  set -l IMAGE_NAME1 ""

  # push tag
  set -l IMAGE_NAME2 ""

  # latest tag
  set -l IMAGE_NAME3 ""

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

  echo "building docker image"
  and asanOff
  and maintainerOff
  and releaseMode
  and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
  and downloadStarter
  and if test "$ENTERPRISEEDITION" = "On"
    downloadSyncer
    copyRclone
  end
  and buildDockerImage $IMAGE_NAME1
  and if test "$IMAGE_NAME1" != "$IMAGE_NAME2"
    docker tag $IMAGE_NAME1 $IMAGE_NAME2
  end
  and docker push $IMAGE_NAME2
  and if test "$ENTERPRISEEDITION" = "On"
    echo $IMAGE_NAME1 > $WORKDIR/work/arangodb3e.docker
  else
    echo $IMAGE_NAME1 > $WORKDIR/work/arangodb3.docker
  end
  and if test "$IMAGE_NAME3" != ""
    docker tag $IMAGE_NAME1 $IMAGE_NAME3
    and docker push $IMAGE_NAME3
  end
end

function buildDockerImage
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
  and docker build --pull -t $imagename .
  or begin ; popd ; return 1 ; end
  popd
end

## #############################################################################
## documentation release
## #############################################################################

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

function buildUbuntuBuildImage
  pushd $WORKDIR
  and cp -a scripts/{makeArangoDB,buildArangoDB,checkoutArangoDB,checkoutEnterprise,clearWorkDir,downloadStarter,downloadSyncer,runTests,runFullTests,switchBranches,recursiveChown}.fish containers/buildUbuntu.docker/scripts
  and cd $WORKDIR/containers/buildUbuntu.docker
  and docker build --pull -t $UBUNTUBUILDIMAGE .
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
  and docker build --pull -t $UBUNTUPACKAGINGIMAGE .
  and rm -f $WORKDIR/containers/buildUbuntuPackaging.docker/scripts/*.fish
  or begin ; popd ; return 1 ; end
  popd
end

function pushUbuntuPackagingImage ; docker push $UBUNTUPACKAGINGIMAGE ; end

function pullUbuntuPackagingImage ; docker pull $UBUNTUPACKAGINGIMAGE ; end

function buildAlpineBuildImage
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildAlpine.docker
  and docker build --pull -t $ALPINEBUILDIMAGE .
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineBuildImage ; docker push $ALPINEBUILDIMAGE ; end

function pullAlpineBuildImage ; docker pull $ALPINEBUILDIMAGE ; end

function buildAlpineBuildImage2
  pushd $WORKDIR
  and cd $WORKDIR/containers/buildAlpine2.docker
  and docker build --pull -t $ALPINEBUILDIMAGE2 .
  or begin ; popd ; return 1 ; end
  popd
end

function pushAlpineBuildImage2 ; docker push $ALPINEBUILDIMAGE2 ; end

function pullAlpineBuildImage2 ; docker pull $ALPINEBUILDIMAGE2 ; end

function buildCentosPackagingImage
  pushd $WORKDIR
  and cp -a scripts/buildRPMPackage.fish containers/buildCentos7Packaging.docker/scripts
  and cd $WORKDIR/containers/buildCentos7Packaging.docker
  and docker build --pull -t $CENTOSPACKAGINGIMAGE .
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

## #############################################################################
## run commands in container
## #############################################################################

function runInContainer
  if test -z "$SSH_AUTH_SOCK"
    sudo killall --older-than 8h ssh-agent 2>&1 > /dev/null
    eval (ssh-agent -c) > /dev/null
    for key in ~/.ssh/id_rsa ~/.ssh/id_deploy
      if test -f $key
        ssh-add $key
      end
    end
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
             -e ARANGODB_PACKAGES="$ARANGODB_PACKAGES" \
             -e ASAN="$ASAN" \
             -e IONICE="$IONICE" \
             -e BUILDMODE="$BUILDMODE" \
             -e COMPILER_VERSION="$COMPILER_VERSION" \
             -e CCACHEBINPATH="$CCACHEBINPATH" \
             -e ENTERPRISEEDITION="$ENTERPRISEEDITION" \
             -e GID=(id -g) \
             -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
             -e INNERWORKDIR="$INNERWORKDIR" \
             -e SHOW_DETAILS="$SHOW_DETAILS" \
             -e KEYNAME="$KEYNAME" \
             -e LDAPHOST="$LDAPHOST" \
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
             -e SKIPNONDETERMINISTIC="$SKIPNONDETERMINISTIC" \
             -e SKIPTIMECRITICAL="$SKIPTIMECRITICAL" \
             -e SKIPGREY="$SKIPGREY" \
             -e ONLYGREY="$ONLYGREY" \
             -e TEST="$TEST" \
             -e ARANGODB_DOCS_BRANCH="$ARANGODB_DOCS_BRANCH"\
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

function interactiveContainer
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
             -e SSH_AUTH_SOCK=/ssh-agent \
             -e STORAGEENGINE="$STORAGEENGINE" \
             -e TESTSUITE="$TESTSUITE" \
             -e UID=(id -u) \
             -e VERBOSEBUILD="$VERBOSEBUILD" \
             -e VERBOSEOSKAR="$VERBOSEOSKAR" \
             $argv
end

## #############################################################################
## helper functions
## #############################################################################

function findCompilerVersion
  echo $COMPILER_VERSION
end

function clearWorkDir
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/clearWorkDir.fish
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

function shellInUbuntuContainer
  interactiveContainer $UBUNTUBUILDIMAGE fish
end

function shellInAlpineContainer
  interactiveContainer (findBuildImage) fish
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
  and pullAlpineBuildImage2
  and pullUbuntuPackagingImage
  and pullCentosPackagingImage
  and pullDocumentationImage
  or begin ; popd ; return 1 ; end
  popd
end

function downloadStarter
  mkdir -p $WORKDIR/work/$THIRDPARTY_BIN
  runInContainer $UBUNTUBUILDIMAGE $SCRIPTSDIR/downloadStarter.fish $INNERWORKDIR/$THIRDPARTY_BIN $argv
end

function downloadSyncer
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  rm -f $WORKDIR/work/ArangoDB/build/install/usr/sbin/arangosync $WORKDIR/work/ArangoDB/build/install/usr/bin/arangosync
  runInContainer -e DOWNLOAD_SYNC_USER=$DOWNLOAD_SYNC_USER $UBUNTUBUILDIMAGE $SCRIPTSDIR/downloadSyncer.fish $INNERWORKDIR/$THIRDPARTY_SBIN $argv
  ln -s ../sbin/arangosync $WORKDIR/work/ArangoDB/build/install/usr/bin/arangosync
end

function copyRclone
  echo Copying rclone from rclone/rclone-arangodb-linux to $WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb ...
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  cp rclone/rclone-arangodb-linux $WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb
end

## #############################################################################
## set PARALLELISM in a sensible way
## #############################################################################

parallelism (nproc)
