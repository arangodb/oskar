#!/usr/bin/env fish
if test "$PARALLELISM" = ""
    set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

cd $INNERWORKDIR
mkdir -p .ccache.mac
set -x CCACHE_DIR $INNERWORKDIR/.ccache.mac
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache
end
ccache -M 100G
#ccache -o log_file=$INNERWORKDIR/.ccache.mac.log
ccache -o cache_dir_levels=1
cd $INNERWORKDIR/ArangoDB

if test -z "$NO_RM_BUILD"
  echo "Cleaning build directory"
  rm -rf build
end

echo "Starting build at "(date)" on "(hostname)
test -f $INNERWORKDIR/.ccache.mac.log 
and mv $INNERWORKDIR/.ccache.mac.log $INNERWORKDIR/.ccache.mac.log.old
ccache --zero-stats

rm -rf build
mkdir -p build
cd build

set -g FULLARGS $argv \
      -DCMAKE_BUILD_TYPE=$BUILDMODE \
      -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/g++ \
      -DCMAKE_C_COMPILER=$CCACHEBINPATH/gcc \
      -DUSE_MAINTAINER_MODE=$MAINTAINER \
      -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
      -DUSE_JEMALLOC=$JEMALLOC_OSKAR \
      -DCMAKE_SKIP_RPATH=On \
      -DPACKAGING=Bundle \
      -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
      -DOPENSSL_USE_STATIC_LIBS=On

if test "$ASAN" = "On"
  echo "ASAN is not support in this environment"
end

echo cmake $FULLARGS ..
echo cmake output in $INNERWORKDIR/cmakeArangoDB.log

cmake $FULLARGS .. ^&1 > $INNERWORKDIR/cmakeArangoDB.log
or exit $status

echo "Finished cmake at "(date)", now starting build"

set -g MAKEFLAGS -j$PARALLELISM 
if test "$VERBOSEBUILD" = "On"
  echo "Building verbosely"
  set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
end

echo Running make, output in $INNERWORKDIR/buildArangoDB.log
and nice make $MAKEFALGS > $INNERWORKDIR/buildArangoDB.log ^&1 
and echo "Finished at "(date)
and ccache --show-stats
