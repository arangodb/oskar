#!/usr/bin/env fish
if test "$PARALLELISM" = ""
    set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

cd $INNERWORKDIR
mkdir -p .ccache.ubuntu
set -x CCACHE_DIR $INNERWORKDIR/.ccache.ubuntu
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache
end
ccache -M 30G
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
 -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/g++ \
 -DCMAKE_C_COMPILER=$CCACHEBINPATH/gcc \
 -DCMAKE_INSTALL_PREFIX=/ \
 -DSTATIC_EXECUTABLES=On \
 -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
 -DUSE_MAINTAINER_MODE=$MAINTAINER

if test "$PLATFORM" = "linux"
  set -g FULLARGS $FULLARGS \
   -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold \
   -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=gold
end

if test "$ASAN" = "On"
  echo "Building with ASAN"
  set -g FULLARGS $FULLARGS \
   -DUSE_JEMALLOC=Off \
   -DCMAKE_C_FLAGS="-fsanitize=address -fsanitize=undefined -fsanitize=leak -fno-sanitize=alignment" \
   -DCMAKE_CXX_FLAGS=-"fsanitize=address -fsanitize=undefined -fsanitize=leak -fno-sanitize=vptr -fno-sanitize=alignment"
else
  set -g FULLARGS $FULLARGS \
   -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
   -DCMAKE_C_FLAGS=-fno-stack-protector \
   -DCMAKE_CXX_FLAGS=-fno-stack-protector
end

echo cmake $FULLARGS ..
echo cmake output in $INNERWORKDIR/cmakeArangoDB.log

cmake $FULLARGS .. > $INNERWORKDIR/cmakeArangoDB.log ^&1
and echo "configure done"  >> $INNERWORKDIR/cmakeArangoDB.log
or exit $status

echo "Finished cmake at "(date)", now starting build"

set -g MAKEFLAGS -j$PARALLELISM 
if test "$VERBOSEBUILD" = "On"
  echo "Building verbosely"
  set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
end

set -x DESTDIR (pwd)/install
echo Running make for static build, output in work/buildArangoDB.log
nice make $MAKEFLAGS install > $INNERWORKDIR/buildArangoDB.log ^&1
and echo "build and install done"  >> $INNERWORKDIR/buildArangoDB.log
and cd install
and if test -z "$NOSTRIP"
  echo Stripping executables...
  strip usr/sbin/arangod usr/bin/arangoimp usr/bin/arangosh usr/bin/arangovpack usr/bin/arangoexport usr/bin/arangobench usr/bin/arangodump usr/bin/arangorestore
end

and echo "Finished at "(date)
and ccache --show-stats
