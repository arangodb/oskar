#!/usr/bin/env fish
source ./scripts/lib/build.fish

if test "$PARALLELISM" = ""
  set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

set -xg CC_NAME gcc
set -xg CXX_NAME g++

if test "$OPENSSL_VERSION" = ""
  set -xg OPENSSL_VERSION 1.0.2
end
switch $OPENSSL_VERSION
  case '1.0.2'
      set -xg OPENSSL_PATH (set last (brew --prefix)/Cellar/openssl/{$OPENSSL_VERSION}*;and echo $last[-1])

  case '1.1.1'
      set -xg OPENSSL_PATH (set last (brew --prefix)/Cellar/openssl@1.1/{$OPENSSL_VERSION}*;and echo $last[-1])

  case '*'
      echo "unknown openssl version $OPENSSL_VERSION"
end
echo "Using openssl version $OPENSSL_VERSION and path $OPENSSL_PATH"

if test "$ASAN" = "On"
  echo "ASAN is not support in this environment"
end

set -g FULLARGS $argv \
 -DCMAKE_BUILD_TYPE=$BUILDMODE \
 -DUSE_MAINTAINER_MODE=$MAINTAINER \
 -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
 -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
 -DCMAKE_SKIP_RPATH=On \
 -DPACKAGING=Bundle \
 -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
 -DOPENSSL_USE_STATIC_LIBS=On \
 -DCMAKE_LIBRARY_PATH=$OPENSSL_PATH/lib \
 -DOPENSSL_ROOT_DIR=$OPENSSL_PATH \
 -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET \
 -DUSE_STRICT_OPENSSL_VERSION=$USE_STRICT_OPENSSL

setupCcacheBinPath macos
and setupCcache macos
and cleanBuildDirectory
and cd $INNERWORKDIR/ArangoDB/build
and TT_init
and cmakeCcache
and selectArchitecture
and selectMaintainer
and runCmake
and TT_cmake
and if test "$SKIP_MAKE" = "On"
  echo "Finished cmake at "(date)", skipping build"
else
  echo "Finished cmake at "(date)", now starting build"
  and runMake
  and TT_make
  and echo "Finished at "(date)
  and shutdownCcache
  and TT_strip
end
