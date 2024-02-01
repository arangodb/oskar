set -gx SCRIPTSDIR $WORKDIR/scripts
set -gx PLATFORM darwin
set -gx UID (id -u)
set -gx GID (id -g)
set -gx INNERWORKDIR $WORKDIR/work
set -gx THIRDPARTY_BIN third_party/bin
set -gx THIRDPARTY_SBIN third_party/sbin
set -gx CCACHEBINPATH /usr/local/opt/ccache/libexec
set -gx CMAKE_INSTALL_PREFIX /opt/arangodb
set -gx CURRENT_PATH $PATH
set -xg IONICE ""
set -gx ARCH (uname -m)
set -gx DUMPDEVICE "lo0"

if test "$ARCH" = "arm64"
  set CCACHEBINPATH /opt/homebrew/opt/ccache/libexec
end

rm -f $SCRIPTSDIR/tools/sccache
ln -s $SCRIPTSDIR/tools/sccache-apple-darwin-$ARCH $SCRIPTSDIR/tools/sccache

function defaultMacOSXDeploymentTarget
  set -xg MACOSX_DEPLOYMENT_TARGET 10.14
  if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
    set -xg MACOSX_DEPLOYMENT_TARGET 11.0
  end
end

if test -z "$MACOSX_DEPLOYMENT_TARGET"
  defaultMacOSXDeploymentTarget
end

set -gx SYSTEM_IS_MACOSX true

## #############################################################################
## config
## #############################################################################

# disable JEMALLOC for now in oskar on MacOSX, since we never tried it:
jemallocOff

# disable strange TAR feature from MacOSX
set -xg COPYFILE_DISABLE 1

function minMacOS
  set -l min $argv[1]

  if test "$min" = ""
    set -e MACOSX_DEPLOYMENT_TARGET
    return 0
  end

  switch $min
    case '10.12'
      set -gx MACOSX_DEPLOYMENT_TARGET $min

    case '10.13'
      set -gx MACOSX_DEPLOYMENT_TARGET $min

    case '10.14'
      set -gx MACOSX_DEPLOYMENT_TARGET $min

    case '10.15'
      set -gx MACOSX_DEPLOYMENT_TARGET $min

    case '*'
      echo "unknown macOS version $min"
  end
end

function findRequiredMinMacOS
  set -l f $WORKDIR/work/ArangoDB/VERSIONS

  test -f $f
  or begin
    echo "Cannot find $f; make sure source is checked out"
    return 1
  end

  set -l v (fgrep MACOS_MIN $f | awk '{print $2}' | tr -d '"' | tr -d "'")

  if test "$v" = ""
    defaultMacOSXDeploymentTarget
    echo "$f: no MACOS_MIN specified, using $MACOSX_DEPLOYMENT_TARGET"
    minMacOS $MACOSX_DEPLOYMENT_TARGET
  else
    if test "$USE_ARM" = "On"
      if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
        echo "Using MACOS_MIN version '11.0' instead of '$v' from '$f' for ARM!"
        set v "11.0"
      end
    else
      echo "Using MACOS_MIN version '$v' from '$f'"
    end
    minMacOS $v
  end
end

function compiler
  set -l cversion $argv[1]

  if test "$cversion" = ""
    set -e COMPILER_VERSION
    return 0
  end

  switch $cversion
    case 12
      set -gx COMPILER_VERSION $cversion

    case 13
      set -gx COMPILER_VERSION $cversion

    case 14
      set -gx COMPILER_VERSION $cversion

    case '*'
      echo "unknown compiler version $cversion"
  end
end

function opensslVersion
  set -gx OPENSSL_VERSION $argv[1]
end

function downloadOpenSSL
  findRequiredOpenSSL
  set -l directory $WORKDIR/work/openssl
  set -l url https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz  
  mkdir -p $directory
  pushd $directory
  echo "Downloading sources to $directory from URL: $url"
  curl -LO $url
  rm -rf openssl-$OPENSSL_VERSION
  tar -xzvf openssl-$OPENSSL_VERSION.tar.gz
  set -xg OPENSSL_SOURCE_DIR "$directory/openssl-$OPENSSL_VERSION"
  popd
end

function buildOpenSSL
  if test "$OPENSSL_SOURCE_DIR" = ""; or ! test -d $OPENSSL_SOURCE_DIR
    echo "Please download OpenSSL source with `downloadOpenSSL` function before building it!"
    return 1
  else if checkOskarOpenSSL
    echo "OpenSSL was already built! No need to rebuild it."
    return
  end
  mkdir -p $OPENSSL_SOURCE_DIR/build
  
  if test -z "$ARCH"
    echo "ARCH is not set! Can't decide wether to build OpenSSL for arm64 or x86_64."
    return 1
  end

  if test "$ARCH" = "x86_64"
    set -xg OPENSSL_PLATFORM darwin64-x86_64-cc
  else if test "$ARCH" = "arm64"
    set -xg OPENSSL_PLATFORM darwin64-arm64-cc
  else
    echo "Unsupported architecture: $ARCH. OpenSSL oskar build is supported for x86_64 or arm64!"
    return 1
  end

  pushd $OPENSSL_SOURCE_DIR
  for type in shared no-shared
    for mode in debug release
      set -l cmd "perl ./Configure --prefix=$OPENSSL_SOURCE_DIR/build/$mode/$type --openssldir=$OPENSSL_SOURCE_DIR/build/$mode/$type/openssl --$mode $type $OPENSSL_PLATFORM"
      echo "Executing: $cmd"
      eval $cmd
      make
      make install_dev
    end
  end
  popd
end

function findOpenSSLPath
  set -gx OPENSSL_SOURCE_DIR $WORKDIR/work/openssl/openssl-$OPENSSL_VERSION
  set -xg OPENSSL_ROOT $OPENSSL_SOURCE_DIR/build  

  switch $BUILDMODE
    case "Debug"
      set mode debug
    case "Release" "RelWithDebInfo" "MinSizeRel"
      set mode release
    case '*'
      echo "Unknown BUILDMODE value: $BUILDMODE! Please, use `releaseMode` or `debugMode` oskar functions to set it."
      return 1
  end
    
  set -gx OPENSSL_USE_STATIC_LIBS "On"
  set -gx OPENSSL_PATH "$OPENSSL_ROOT/$mode/no-shared"
end

set -xg OPENSSL_ROOT_HOMEBREW ""

function checkBrewOpenSSL
  set -xg OPENSSL_ROOT_HOMEBREW ""
  if which -s brew
    set -l prefix (brew --prefix)
    if count $prefix/Cellar/openssl*/* > /dev/null
      set -l matcher "[0-9]\.[0-9]\.[0-9]"
      set -l sslVersion ""
      set -l sslPath ""
      findRequiredOpenSSL
      if test "$USE_STRICT_OPENSSL" = "On"
        set matcher $matcher"[a-z]"
        set sslVersion (echo "$OPENSSL_VERSION" | grep -o $matcher)
        set sslPath (realpath $prefix/Cellar/openssl*/* | grep -m 1 $sslVersion)
      else
        set sslVersion (echo "$OPENSSL_VERSION" | grep -o $matcher)'*'
        set sslPath (realpath $prefix/Cellar/openssl*/* | grep -m 1 $sslVersion)
    end

      if test "$sslPath" != ""; and test -e $sslPath/bin/openssl > /dev/null; and count $sslPath/lib/* > /dev/null
        set -l executable "$sslPath/bin/openssl"
        set -l cmd "$executable version | grep -o $matcher"
        set -l output (eval "arch -$ARCH $cmd")
        if test "$output" = (echo "$OPENSSL_VERSION" | grep -o $matcher)
          echo "Found matching OpenSSL $sslPath installed by Homebrew."
          set -xg OPENSSL_ROOT_HOMEBREW $sslPath
          return  
        end
      end
    end
  end
  echo "Couldn't find matching OpenSSL version installed by Homebrew! Please, try `brew install openssl` prior to check."
  return 1
end

function checkOskarOpenSSL
  findOpenSSLPath
  set -l executable "$OPENSSL_SOURCE_DIR/apps/openssl"
  if ! test -f "$executable"
    echo "Couldn't find OpenSSL $OPENSSL_VERSION at $OPENSSL_SOURCE_DIR!"
    false
    return 1
  end
  set -l cmd "$executable version | grep -m 1 -o \"[0-9]\.[0-9]\.[0-9]*[a-z]*\" | head -1"
  set -l output (eval "arch -$ARCH $cmd")
  if test "$output" = "$OPENSSL_VERSION"
    echo "Found OpenSSL $OPENSSL_VERSION"
    true
    return
  else
    echo "Couldn't find OpenSSL $OPENSSL_VERSION!"
    false
    return 1
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

  set -l v (fgrep LLVM_CLANG_MACOS $f | awk '{print $2}' | tr -d '"' | tr -d "'")

  if test "$v" = ""
    echo "$f: no LLVM_CLANG_MACOS specified, using 13"
    compiler 13
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

  set -l v (fgrep OPENSSL_MACOS $f | awk '{print $2}' | tr -d '"' | tr -d "'" | grep -E -o "[0-9]\.[0-9]\.[0-9]*[a-z]?")

  if test "$v" = ""
    echo "$f: no OPENSSL_MACOS specified, using 1.1.1t"
    opensslVersion 1.1.1t
  else
    echo "Using OpenSSL version '$v' from '$f'"
    opensslVersion $v
  end
end

function oskarOpenSSL
  set -xg USE_OSKAR_OPENSSL "On"
end

function ownOpenSSL
  set -xg USE_OSKAR_OPENSSL "Off"
end

if test -z "$USE_OSKAR_OPENSSL"
  if test "$IS_JENKINS" = "true"
    oskarOpenSSL
  else
    ownOpenSSL
  end
else
  set -gx USE_OSKAR_OPENSSL $USE_OSKAR_OPENSSL
end

function prepareOpenSSL
  if test "$USE_OSKAR_OPENSSL" = "On"
    findRequiredOpenSSL
    echo "Use OpenSSL within oskar: build $OPENSSL_VERSION if not present"

    if not checkOskarOpenSSL
      downloadOpenSSL
      and buildOpenSSL
      or return 1
    end

    echo "Set OPENSSL_ROOT_DIR via environment variable to $OPENSSL_PATH"
    set -xg OPENSSL_ROOT_DIR $OPENSSL_PATH
  else
    if checkBrewOpenSSL
      echo "Use local OpenSSL installed by Homebrew and set OPENSSL_ROOT_DIR environment variable to "
      set -xg OPENSSL_ROOT_DIR $OPENSSL_ROOT_HOMEBREW
    else
      echo "Use local OpenSSL: expect OPENSSL_ROOT_DIR environment variable"
      if test -z $OPENSSL_ROOT_DIR
        echo "Need OPENSSL_ROOT_DIR global variable!"
        return 1
      end
    end 
  end
end

## #############################################################################
## run without docker
## #############################################################################

function runLocal
  if test -z "$SSH_AUTH_SOCK"
    eval (ssh-agent -c) > /dev/null
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519
      if test -f $key
        ssh-add $key
      end
    end
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
  and convertSItoJSON
  and set -gx MINIMAL_DEBUG_INFO (findMinimalDebugInfo)
  and findDefaultArchitecture
  and findRequiredCompiler
  and findUseARM
  and findArangoDBVersion
end

function clearWorkdir
  runLocal $SCRIPTSDIR/clearWorkdir.fish
end

function buildArangoDB
  checkoutIfNeeded
  and findDefaultArchitecture
  and findRequiredCompiler
  and findUseARM
  and findRequiredMinMacOS
  and prepareOpenSSL
  and runLocal $SCRIPTSDIR/buildMacOs.fish $argv
  set -l s $status
  if test $s -ne 0
    echo Build error!
    return $s
  end
end

function makeArangoDB
  findDefaultArchitecture
  and findRequiredCompiler
  and findUseARM
  and findRequiredMinMacOS
  and prepareOpenSSL
  and runLocal $SCRIPTSDIR/makeArangoDB.fish $argv
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
  and findRequiredCompiler
  and runLocal $SCRIPTSDIR/runTests.fish
end

function oskarFull
  checkoutIfNeeded
  and findRequiredCompiler
  and runLocal $SCRIPTSDIR/runFullTests.fish
end

function rlogTests
  checkoutIfNeeded
  and findRequiredCompiler
  and runLocal $SCRIPTSDIR/rlog/pr.fish $argv
end

function pushOskar
  pushd $WORKDIR
  and source helper.fish
  and git push
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
end

function updateDockerBuildImage
end

function downloadStarter
  mkdir -p $WORKDIR/work/$THIRDPARTY_BIN
  and runLocal $SCRIPTSDIR/downloadStarter.fish $INNERWORKDIR/$THIRDPARTY_BIN $argv
  and convertSItoJSON
end

function downloadSyncer
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  and runLocal $SCRIPTSDIR/downloadSyncer.fish $INNERWORKDIR/$THIRDPARTY_SBIN $argv
  and convertSItoJSON
end

function setupComponents
  cleanupThirdParty
  if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10
    downloadStarter
    if test "$ENTERPRISEEDITION" = "On"
      if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -lt 12
        set -gx THIRDPARTY_SBIN_LIST $WORKDIR/work/$THIRDPARTY_SBIN/arangosync
      end
      and downloadSyncer
      if test "$USE_RCLONE" = "true"
        copyRclone "macos"
      end
    end
  else
    set -xg USE_RCLONE false
  end

  return 0
end

function setupPackaging
  if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10
    set -xg PACKAGING_OPTIONS "-DPACKAGING=Bundle -DPACKAGE_TARGET_DIR=$INNERWORKDIR -DTHIRDPARTY_BIN=$WORKDIR/work/$THIRDPARTY_BIN/arangodb"
    if test "$ENTERPRISEEDITION" = "On"
      if test "$USE_RCLONE" = "true"
        set -gx THIRDPARTY_SBIN_LIST "$THIRDPARTY_SBIN_LIST\;$WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb"
      end
      set -xg PACKAGING_OPTIONS "$PACKAGING_OPTIONS -DTHIRDPARTY_SBIN=$THIRDPARTY_SBIN_LIST"
    end
  else
    set -xg PACKAGING_OPTIONS ""
  end

  return 0
end

function buildPackage
  # This assumes that a build has already happened

  if test "$ENTERPRISEEDITION" = "On"
    echo Building enterprise edition macOs bundle...
  else
    echo Building community edition macOs bundle...
  end

  if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10
    runLocal $SCRIPTSDIR/buildMacOsPackage.fish $ARANGODB_PACKAGES
    and buildTarGzPackage
  else
    buildTarGzPackage
  end
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
  sanOff
  and maintainerOff
  and releaseMode
  and enterprise
  and set -xg NOSTRIP 1
  and setupComponents
  and setupPackaging
  and buildArangoDB $PACKAGING_OPTIONS -DCMAKE_INSTALL_PREFIX=$CMAKE_INSTALL_PREFIX
  and buildPackage

  if test $status != 0
    echo Building enterprise release failed, stopping.
    return 1
  end
end

function buildCommunityPackage
  # Must have set ARANGODB_VERSION and ARANGODB_PACKAGE_REVISION and
  # ARANGODB_FULL_VERSION, for example by running findArangoDBVersion.
  sanOff
  and maintainerOff
  and releaseMode
  and community
  and set -xg NOSTRIP 1
  and setupComponents
  and setupPackaging
  and buildArangoDB $PACKAGING_OPTIONS -DCMAKE_INSTALL_PREFIX=$CMAKE_INSTALL_PREFIX
  and buildPackage

  if test $status != 0
    echo Building community release failed.
    return 1
  end
end

function buildTarGzPackage
  if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -ge 11
    set -xg MAKE_INSTALL_COMPONENTS '-C client-tools'
  else
    set -xg MAKE_INSTALL_COMPONENTS ""
  end
  pushd $INNERWORKDIR/ArangoDB/build
  echo (pwd)
  echo (ls -l client-tools)
  and rm -rf install
  and echo "make $MAKE_INSTALL_COMPONENTS install DESTDIR="(pwd)"/install"
  and eval make $MAKE_INSTALL_COMPONENTS install VERBOSE=1 DESTDIR=(pwd)/install
  and makeJsSha1Sum (pwd)/install/opt/arangodb/share/arangodb3/js
  and if test "$ENTERPRISEEDITION" = "On"
        if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10
          pushd install/opt/arangodb/bin
          ln -s ../sbin/arangosync
          popd
        end
      end
  and mkdir -p install/usr
  and mv install/opt/arangodb/bin install/usr
  and if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10
        mv install/opt/arangodb/sbin install/usr
      end
  and mv install/opt/arangodb/share install/usr
  and mv install/opt/arangodb/etc install
  and rm -rf install/opt
  and buildTarGzPackageHelper "macos"
  or begin ; popd ; return 1 ; end
  popd
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

## #############################################################################
## set PARALLELISM in a sensible way
## #############################################################################

parallelism (sysctl -n hw.logicalcpu)
