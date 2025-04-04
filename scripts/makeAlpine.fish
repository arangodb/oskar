#!/usr/bin/env fish
if test "$PARALLELISM" = ""
    set -xg PARALLELISM 64
end

cd $INNERWORKDIR
mkdir -p .ccache.alpine
set -x CCACHE_DIR $INNERWORKDIR/.ccache.alpine
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache/bin
end
if test "$CCACHE_MAXSIZE" = ""
  set -xg CCACHE_MAXSIZE 30G
end
ccache -M $CCACHE_MAXSIZE

cd $INNERWORKDIR/ArangoDB/build
or exit $status

mkdir -p install
set -x DESTDIR (pwd)/install
nice make -j$PARALLELISM $argv
