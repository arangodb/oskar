#!/usr/bin/env fish
if test "$PARALLELISM" = ""
    set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

if test "$COMPILER_VERSION" = ""
    set -xg COMPILER_VERSION 6.4.0
end
echo "Using compiler version $COMPILER_VERSION"

if test "$COMPILER_VERSION" = "6.4.0"
    set -xg CC_NAME gcc
    set -xg CXX_NAME g++
else
    set -xg CC_NAME gcc-$COMPILER_VERSION
    set -xg CXX_NAME g++-$COMPILER_VERSION
end


cd $INNERWORKDIR
mkdir -p .ccache.alpine
set -x CCACHE_DIR $INNERWORKDIR/.ccache.alpine
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache/bin
end
ccache -M 50G
cd $INNERWORKDIR/ArangoDB

if test -z "$NO_RM_BUILD"
  echo "Cleaning build directory"
  rm -rf build
end
mkdir -p build
cd build
rm -rf install
and mkdir install

echo "Starting build at "(date)" on "(hostname)
rm -f $INNERWORKDIR/.ccache.log
ccache --zero-stats

set -g FULLARGS $argv \
 -DCMAKE_BUILD_TYPE=$BUILDMODE \
 -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/$CXX_NAME \
 -DCMAKE_CXX_FLAGS=-fno-stack-protector \
 -DCMAKE_C_COMPILER=$CCACHEBINPATH/$CC_NAME \
 -DCMAKE_C_FLAGS=-fno-stack-protector \
 -DCMAKE_EXE_LINKER_FLAGS="-Wl,--build-id -no-pie"\
 -DCMAKE_INSTALL_PREFIX=/ \
 -DSTATIC_EXECUTABLES=On \
 -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
 -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
 -DUSE_MAINTAINER_MODE=$MAINTAINER

if test "$ASAN" = "On"
  echo "ASAN is not support in this environment"
end

echo cmake $FULLARGS ..
echo cmake output in $INNERWORKDIR/cmakeArangoDB.log

cmake $FULLARGS .. > $INNERWORKDIR/cmakeArangoDB.log ^&1
or exit $status

echo "Finished cmake at "(date)", now starting build"

set -g MAKEFLAGS -j$PARALLELISM 
if test "$VERBOSEBUILD" = "On"
  echo "Building verbosely"
  set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
end

set -x DESTDIR (pwd)/install
echo Running make $MAKEFLAGS for static build, output in work/buildArangoDB.log
nice make $MAKEFLAGS install > $INNERWORKDIR/buildArangoDB.log ^&1
and cd install
and if test -z "$NOSTRIP"
  echo Stripping executables...
  strip usr/sbin/arangod usr/bin/arangoimp usr/bin/arangosh usr/bin/arangovpack usr/bin/arangoexport usr/bin/arangobench usr/bin/arangodump usr/bin/arangorestore
end

and echo "Finished at "(date)
and ccache --show-stats
