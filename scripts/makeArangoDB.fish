#!/usr/bin/env fish
cd $INNERWORKDIR
mkdir -p .ccache.ubuntu
set -x CCACHE_DIR $INNERWORKDIR/.ccache.ubuntu
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache
end
if test "$CCACHE_MAXSIZE" = ""
  set -xg CCACHE_MAXSIZE 30G
end
ccache -M $CCACHE_MAXSIZE
cd $INNERWORKDIR/ArangoDB/build
or exit $status

if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -ge 11; test "$PLATFORM" = "darwin"
  set -xg MAKE_TARGETS client-tools
end

set -l GOLD
if test "$PLATFORM" = "linux"
  set GOLD = -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold  -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=gold
end

nice make -j$PARALLELISM $MAKE_TARGETS $argv VERBOSE=1 V=1
