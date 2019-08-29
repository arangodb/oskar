#!/usr/bin/env fish
if test "$PARALLELISM" = ""
  set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

if test "$OPENSSL_VERSION" = ""
  set -xg OPENSSL_VERSION 1.0.2
end
switch $OPENSSL_VERSION
  case '1.0.2'
      set -xg OPENSSL_PATH (brew --prefix)/opt/openssl

  case '1.1.1'
      set -xg OPENSSL_PATH (brew --prefix)/opt/openssl@1.1

  case '*'
      echo "unknown compiler version $cversion"
end
echo "Using openssl version $OPENSSL_VERSION and path $OPENSSL_PATH"

cd $INNERWORKDIR
mkdir -p .ccache.mac
set -x CCACHE_DIR $INNERWORKDIR/.ccache.mac
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache
end
if test "$CCACHESIZE" = ""
  set -xg CCACHESIZE 100G
end
ccache -M $CCACHESIZE
ccache -o cache_dir_levels=1
cd $INNERWORKDIR/ArangoDB

if test -z "$NO_RM_BUILD"
  echo "Cleaning build directory"
  rm -rf build
end

echo "Starting build at "(date)" on "(hostname)
rm -f $INNERWORKDIR/.ccache.mac.log
ccache --zero-stats

rm -rf build
and mkdir -p build
and cd build

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
 -DOPENSSL_USE_STATIC_LIBS=On \
 -DCMAKE_LIBRARY_PATH=$OPENSSL_PATH/lib \
 -DOPENSSL_ROOT_DIR=$OPENSSL_PATH

if test "$argv" = ""
  echo "using default architecture 'nehalem'"
  set -g FULLARGS $FULLARGS \
    -DTARGET_ARCHITECTURE=nehalem
end

if test "$MAINTAINER" != "On"
  set -g FULLARGS $FULLARGS \
    -DUSE_CATCH_TESTS=Off \
    -DUSE_GOOGLE_TESTS=Off
end

if test "$ASAN" = "On"
  echo "ASAN is not support in this environment"
end

echo cmake $FULLARGS ..

if test "$SHOW_DETAILS" = "On"
  cmake $FULLARGS .. ^&1
else
  echo cmake output in $INNERWORKDIR/cmakeArangoDB.log
  cmake $FULLARGS .. ^&1 > $INNERWORKDIR/cmakeArangoDB.log
end
or exit $status

echo "Finished cmake at "(date)", now starting build"

set -g MAKEFLAGS -j$PARALLELISM 
if test "$VERBOSEBUILD" = "On"
  echo "Building verbosely"
  set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
end

echo Running make, output in $INNERWORKDIR/buildArangoDB.log
and nice make $MAKEFLAGS > $INNERWORKDIR/buildArangoDB.log ^&1 
and echo "Finished at "(date)
and ccache --show-stats
