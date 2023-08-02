#!/usr/bin/env fish
source ./scripts/lib/build.fish

if test "$PARALLELISM" = ""
  set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

if test "$COMPILER_VERSION" = ""
  set -xg COMPILER_VERSION 9.3.0
end
echo "Using compiler version $COMPILER_VERSION"

if test "$COMPILER_VERSION" = "9.3.0"
  set -xg CC_NAME gcc
  set -xg CXX_NAME g++
else
  set -xg CC_NAME gcc-$COMPILER_VERSION
  set -xg CXX_NAME g++-$COMPILER_VERSION
end

if test "$OPENSSL_VERSION" = ""
  set -xg OPENSSL_VERSION 1.1.1
end
echo "Using openssl version $OPENSSL_VERSION"

set -l pie "-fpic -fPIC -fpie -fPIE -static-pie"
set -l inline "--param inline-min-speedup=5 --param inline-unit-growth=100 --param early-inlining-insns=30"

set -g FULLARGS $argv \
 -DCMAKE_BUILD_TYPE=$BUILDMODE \
 -DCMAKE_INSTALL_PREFIX=/ \
 -DSTATIC_EXECUTABLES=On \
 -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
 -DUSE_MAINTAINER_MODE=$MAINTAINER \
 -DCMAKE_LIBRARY_PATH=/opt/openssl-$OPENSSL_VERSION/lib \
 -DOPENSSL_ROOT_DIR=/opt/openssl-$OPENSSL_VERSION \
 -DUSE_STRICT_OPENSSL_VERSION=$USE_STRICT_OPENSSL \
 -DBUILD_REPO_INFO=$BUILD_REPO_INFO

if test "$MAINTAINER" = "On"
  set -g FULLARGS $FULLARGS \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--build-id $pie -fno-stack-protector"
else
  set -g FULLARGS $FULLARGS \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--build-id $pie $inline -fno-stack-protector" \
    -DUSE_CATCH_TESTS=Off \
    -DUSE_GOOGLE_TESTS=Off
end

if test "$BUILD_SEPP" = "On"
  set -g FULLARGS $FULLARGS -DBUILD_SEPP=ON
end

if test "$SAN" = "On"
  echo "SAN is not support in this environment"
  exit 1
else if test "$COVERAGE" = "On"
  echo "Building with Coverage"
  set -g FULLARGS $FULLARGS \
    -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
    -DCMAKE_C_FLAGS="$pie -fno-stack-protector -fprofile-arcs -ftest-coverage" \
    -DCMAKE_CXX_FLAGS="$pie -fno-stack-protector -fprofile-arcs -ftest-coverage" \
    -DUSE_COVERAGE=ON
else
  set -g FULLARGS $FULLARGS \
   -DUSE_JEMALLOC=$JEMALLOC_OSKAR

  if test "$MAINTAINER" = "On"
    set -g FULLARGS $FULLARGS \
     -DCMAKE_C_FLAGS="$pie -fno-stack-protector" \
     -DCMAKE_CXX_FLAGS="$pie -fno-stack-protector"
  else
    set -g FULLARGS $FULLARGS \
     -DCMAKE_C_FLAGS="$pie $inline -fno-stack-protector" \
     -DCMAKE_CXX_FLAGS="$pie $inline -fno-stack-protector"
  end
end

if test "$MINIMAL_DEBUG_INFO" = "On"
  set -g FULLARGS $FULLARGS \
    -DUSE_MINIMAL_DEBUGINFO=On
end

setupCcacheBinPath alpine
and setupCcache alpine
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
  and set -xg DESTDIR (pwd)/install
  and runMake install
  and generateJsSha1Sum ArangoDB/build/install/usr/share/arangodb3/js
  and TT_make
  and installTargets
  and echo "Finished at "(date)
  and shutdownCcache
  and TT_strip
end
