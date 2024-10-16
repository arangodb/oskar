#!/usr/bin/env fish
# This is for static gcc13.2.0 and clang16.0.6 builds on Ubuntu
source ./scripts/lib/build.fish

if test "$PARALLELISM" = ""
  set -xg PARALLELISM 64
end

if test "$SAN" = "On"
  set PARALLELISM 10
end

echo "Using parallelism $PARALLELISM"

if test "$COMPILER_VERSION" = ""
  set -xg COMPILER_VERSION clang16.0.6
end
echo "Using compiler version $COMPILER_VERSION"

if test "$COMPILER_VERSION" = "clang16.0.6"
  set -xg CC_NAME clang
  set -xg CXX_NAME clang++
else if test "$COMPILER_VERSION" = "13.2.0"
  set -xg CC_NAME gcc
  set -xg CXX_NAME g++
else
  set -xg CC_NAME gcc-$COMPILER_VERSION
  set -xg CXX_NAME g++-$COMPILER_VERSION
end

if test "$OPENSSL_VERSION" = ""
  set -xg OPENSSL_VERSION 3.3
end
echo "Using openssl version $OPENSSL_VERSION"

if test "$ARCH" = "x86_64" -a (string sub -s 1 -l 1 "$OPENSSLPATH") = "3" 
  set -xg X86_64_SUFFIX "64"
end

set -l pie ""

if test "$STATIC_EXECUTABLES" = ""
  set -xg STATIC_EXECUTABLES On
end

set -g FULLARGS $argv \
 -DCMAKE_BUILD_TYPE=$BUILDMODE \
 -DCMAKE_INSTALL_PREFIX=/ \
 -DSTATIC_EXECUTABLES=$STATIC_EXECUTABLES \
 -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
 -DUSE_MAINTAINER_MODE=$MAINTAINER \
 -DCMAKE_LIBRARY_PATH="/opt/lib$X86_64_SUFFIX;/opt/lib" \
 -DOPENSSL_ROOT_DIR=/opt \
 -DUSE_STRICT_OPENSSL_VERSION=$USE_STRICT_OPENSSL \
 -DBUILD_REPO_INFO=$BUILD_REPO_INFO \
 -DARANGODB_BUILD_DATE="$ARANGODB_BUILD_DATE" \
 -DLAPACK_LIBRARIES="/usr/lib/x86_64-linux-gnu/"

if test "$MAINTAINER" = "On"
  set -g FULLARGS $FULLARGS \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--build-id=sha1 $pie -fno-stack-protector -fuse-ld=lld" \
    -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld"
else
  set -g FULLARGS $FULLARGS \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--build-id=sha1 $pie $inline -fno-stack-protector -fuse-ld=lld " \
    -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" \
    -DUSE_CATCH_TESTS=Off \
    -DUSE_GOOGLE_TESTS=Off
end

if test "$BUILD_SEPP" = "On"
  set -g FULLARGS $FULLARGS -DBUILD_SEPP=ON
end

if test "$SAN" = "On"
  # Suppress leaks detection only during building
  set -gx SAN_OPTIONS "detect_leaks=0"
  set -l SANITIZERS "-fsanitize=address -fsanitize=undefined -fsanitize=float-divide-by-zero -fsanitize=leak -fsanitize-address-use-after-return=never"
  if test "$SAN_MODE" = "TSan"
    set SANITIZERS "-fsanitize=thread"
  end
  set -g FULLARGS $FULLARGS \
   -DUSE_JEMALLOC=Off \
   -DCMAKE_C_FLAGS="-pthread $SANITIZERS -fno-sanitize=alignment" \
   -DCMAKE_CXX_FLAGS="-pthread $SANITIZERS -fno-sanitize=vptr -fno-sanitize=alignment" \
   -DBASE_LIBS="-pthread"
else if test "$COVERAGE" = "On"
  echo "Building with LCOV Coverage"
  set -g FULLARGS $FULLARGS \
    -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
    -DCMAKE_C_FLAGS="$pie -fno-stack-protector -fprofile-instr-generate -fcoverage-mapping -mllvm -runtime-counter-relocation --coverage" \
    -DCMAKE_CXX_FLAGS="$pie -fno-stack-protector -fprofile-instr-generate -fcoverage-mapping -mllvm -runtime-counter-relocation --coverage" \
    -DCMAKE_LD_FLAGS="$pie -fno-stack-protector -fprofile-instr-generate -fcoverage-mapping -mllvm -runtime-counter-relocation --coverage" \
    -DUSE_COVERAGE=ON \
   -DV8_LDFLAGS=--coverage
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

setupCcacheBinPath ubuntu
and setupCcache ubuntu
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
