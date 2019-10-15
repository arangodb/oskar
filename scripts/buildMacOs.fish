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
      echo "unknown openssl version $OPENSSL_VERSION"
end
echo "Using openssl version $OPENSSL_VERSION and path $OPENSSL_PATH"

if test "$USE_CCACHE" = "Off"
  set -xg CCACHE_DISABLE true
  echo "ccache is DISABLED"
else
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
end

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
set -g t1 (date -u +%s)
set -g t0 (date "+%Y%m%d")
rm -f $INNERWORKDIR/buildTimes.csv
rm -f $INNERWORKDIR/.ccache.mac.log
ccache --zero-stats

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
 -DOPENSSL_ROOT_DIR=$OPENSSL_PATH

if test "$USE_CCACHE" != "Off"
  set -g FULLARGS $FULLARGS \
   -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/g++ \
   -DCMAKE_C_COMPILER=$CCACHEBINPATH/gcc \
end

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

set -g t2 (date -u +%s)
and echo $t0,cmake,(expr $t2 - $t1) >> $INNERWORKDIR/buildTimes.csv

if test "$SKIP_MAKE" = "On"
  echo "Finished cmake at "(date)", skipping build"
else
  echo "Finished cmake at "(date)", now starting build"

  set -g MAKEFLAGS -j$PARALLELISM 
  if test "$VERBOSEBUILD" = "On"
    echo "Building verbosely"
    set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
  end

  if test "$SHOW_DETAILS" = "On"
    make $MAKEFLAGS ^&1
    or exit $status
  else
    echo make output in work/buildArangoDB.log
    set -l ep ""

    if test "$SHOW_DETAILS" = "Ping"
      fish -c "while true; sleep 60; echo == (date) ==; test -f $INNERWORKDIR/buildArangoDB.log; and tail -2 $INNERWORKDIR/buildArangoDB.log; end" &
      set ep (jobs -p | tail -1)
    end

    nice make $MAKEFLAGS > $INNERWORKDIR/buildArangoDB.log ^&1
    or begin
      if test -n "$ep"
	kill $ep
      end

      exit 1
    end

    if test -n "$ep"
      kill $ep
    end
  end
  and set -g t3 (date -u +%s)
  and echo $t0,make,(expr $t3 - $t2) >> $INNERWORKDIR/buildTimes.csv
  or exit 1

  and echo "Finished at "(date)
  and if test "$USE_CCACHE" != "Off"
    ccache --show-stats
  end
  and set -g t4 (date -u +%s)
  and echo $t0,strip,(expr $t4 - $t3) >> $INNERWORKDIR/buildTimes.csv
end
