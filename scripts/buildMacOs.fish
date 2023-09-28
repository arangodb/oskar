#!/usr/bin/env fish
source ./scripts/lib/build.fish

if test "$PARALLELISM" = ""
  set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

switch "$ARCH"
  case "arm64"
    set -xg BASE_NAME /opt/homebrew/opt
  case "x86_64"
    set -xg BASE_NAME /usr/local/opt
  case '*'
    echo "fatal, unknown ARCH $ARCH"
    exit
end

set -xg PATH "$BASE_NAME/llvm@$COMPILER_VERSION/bin:$CURRENT_PATH"

set -xg CC_NAME clang
set -xg CXX_NAME clang++

set -xg CC $CC_NAME
set -xg CXX $CXX_NAME

set -xg LDFLAGS "-L$BASE_NAME/llvm@$COMPILER_VERSION/lib -Wl,-rpath,$BASE_NAME/llvm@$COMPILER_VERSION/lib"
set -xg CPPFLAGS "-I$BASE_NAME/llvm@$COMPILER_VERSION/include"

if test "$SAN" = "On"
  echo "SAN is not support in this environment"
end

set -xg FULLARGS $argv \
 -DCMAKE_BUILD_TYPE=$BUILDMODE \
 -DUSE_MAINTAINER_MODE=$MAINTAINER \
 -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
 -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
 -DCMAKE_SKIP_RPATH=On \
 -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
 -DOPENSSL_USE_STATIC_LIBS=$OPENSSL_USE_STATIC_LIBS \
 -DOPENSSL_ROOT_DIR=$OPENSSL_ROOT_DIR \
 -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET \
 -DUSE_STRICT_OPENSSL_VERSION=$USE_STRICT_OPENSSL \
 -DBUILD_REPO_INFO=$BUILD_REPO_INFO

if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -ge 11
  set -xg MAKE_TARGETS client-tools
else
  set -xg FULLARGS "$FULLARGS -DPACKAGING=Bundle"
end

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
  and runMake $MAKE_TARGETS
  and TT_make
  and echo "Finished at "(date)
  and shutdownCcache
  and TT_strip
end
