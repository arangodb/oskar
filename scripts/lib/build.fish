function setupCcache
  if test "$USE_CCACHE" = "Off"
    set -xg CCACHE_DISABLE true
    echo "ccache is DISABLED"
  else if test "$USE_CCACHE" = "sccache"
    if test "$CCACHEBINPATH" = ""
      set -xg CCACHEBINPATH /tools
    end
    if test "$CCACHESIZE" = ""
      set -xg SCCACHE_CACHE_SIZE 200G
    else
      set -xg SCCACHE_CACHE_SIZE $CCACHESIZE
    end
    if test "$SCCACHE_REDIS" != ""
      echo "using sccache at redis ($SCCACHE_REDIS)"
      set -e SCCACHE_MEMCACHED
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_DIR
    else if test "$SCCACHE_MEMCACHED" != ""
      echo "using sccache at memcached ($SCCACHE_MEMCACHED)"
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_DIR
    else if test "$SCCACHE_GCS_BUCKET" != ""
      echo "using sccache at GCS ($SCCACHE_GCS_BUCKET)"
      set -e SCCACHE_MEMCACHED
      set -xg SCCACHE_GCS_RW_MODE READ_WRITE
      set -e SCCACHE_DIR
    else
     set -xg SCCACHE_DIR $INNERWORKDIR/.sccache.alpine3
     echo "using sccache at $SCCACHE_DIR ($SCCACHE_CACHE_SIZE)"
    end

    pushd $INNERWORKDIR; and sccache --start-server; and popd
    or begin echo "fatal, cannot start sccache"; exit 1; end
  else
    set -xg CCACHE_DIR $INNERWORKDIR/.ccache.alpine3
    if test "$CCACHEBINPATH" = ""
      set -xg CCACHEBINPATH /usr/lib/ccache/bin
    end
    if test "$CCACHESIZE" = ""
      set -xg CCACHESIZE 50G
    end

    echo "using ccache at $CCACHE_DIR ($CCACHESIZE)"

    pushd $INNERWORKDIR
    and mkdir -p .ccache.alpine3
    and rm -f .ccache.log
    and ccache -M $CCACHESIZE
    and ccache --zero-stats
    and popd
    or begin echo "fatal, cannot start ccache"; exit 1; end
  end
end

function shutdownCcache
  if test "$USE_CCACHE" = "On"
    ccache --show-stats
  else if test "$USE_CCACHE" = "sccache"
    sccache --stop-server
  end
end
