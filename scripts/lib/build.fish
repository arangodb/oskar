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

    if test "$SCCACHE_BUCKET" != "" -a "$AWS_ACCESS_KEY_ID" != ""
      echo "using sccache at S3 ($SCCACHE_BUCKET)"
echo "SCCACHE_BUCKET $SCCACHE_BUCKET"
echo "SCCACHE_ENDPOINT $SCCACHE_ENDPOINT"
echo "AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID"
      set -e SCCACHE_DIR
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_MEMCACHED
      set -e SCCACHE_REDIS
    else if test "$SCCACHE_GCS_BUCKET" != "" -a -f "/work/.gcs-credentials"
      echo "using sccache at GCS ($SCCACHE_GCS_BUCKET)"
      set -e SCCACHE_BUCKET
      set -e SCCACHE_DIR
      set -e SCCACHE_MEMCACHED
      set -e SCCACHE_REDIS
      set -xg SCCACHE_GCS_RW_MODE READ_WRITE
      set -xg SCCACHE_GCS_KEY_PATH /work/.gcs-credentials
    else if test "$SCCACHE_REDIS" != ""
      echo "using sccache at redis ($SCCACHE_REDIS)"
      set -e SCCACHE_BUCKET
      set -e SCCACHE_DIR
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_MEMCACHED
    else if test "$SCCACHE_MEMCACHED" != ""
      echo "using sccache at memcached ($SCCACHE_MEMCACHED)"
      set -e SCCACHE_BUCKET
      set -e SCCACHE_DIR
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_REDIS
    else
      echo "using sccache at $SCCACHE_DIR ($SCCACHE_CACHE_SIZE)"
      set -xg SCCACHE_DIR $INNERWORKDIR/.sccache.alpine3
      set -e SCCACHE_BUCKET
      set -e SCCACHE_DIR
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_MEMCACHED
      set -e SCCACHE_REDIS
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
