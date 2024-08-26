function setupCcacheBinPath
  set -xg CCACHETYPE $argv[1]

  if test "$USE_CCACHE" = "Off"
    return 0
  else if test "$USE_CCACHE" = "sccache"
    switch $CCACHETYPE
      case macos
          set -xg CCACHEBINPATH $SCRIPTSDIR/tools
          set -xg SCCACHEBINPATH $SCRIPTSDIR/tools
      case alpine
          set -xg CCACHEBINPATH /tools
      case ubuntu
          set -xg CCACHEBINPATH /tools
      case '*'
          echo "fatal, unknown CCACHETYPE $CCACHETYPE"
          exit
    end

    return 0
  else if test "$USE_CCACHE" = "On"
    switch $CCACHETYPE
      case macos
          switch "$ARCH"
              case "arm64"
                  set -xg CCACHEBINPATH /opt/homebrew/opt/ccache/libexec
              case "x86_64"
                  set -xg CCACHEBINPATH /usr/local/opt/ccache/libexec
              case '*'
                  echo "fatal, unknown CCACHEBINPATH for $ARCH of $CCACHETYPE"
                  exit
          end
      case alpine
          set -xg CCACHEBINPATH /usr/lib/ccache/bin
      case ubuntu
          set -xg CCACHEBINPATH /usr/lib/ccache
      case '*'
          echo "fatal, unknown CCACHETYPE $CCACHETYPE"
          exit
    end

    return 0
  end
end

function setupCcache
  set -xg CCACHETYPE $argv[1]

  if test "$USE_CCACHE" = "Off"
    set -xg CCACHE_DISABLE true
    echo "ccache is DISABLED"
  else if test "$USE_CCACHE" = "sccache"
    if test "$CCACHEBINPATH" = ""
      echo "fatal, CCACHEBINPATH not set"
      exit 1
    end

    if test "$CCACHE_MAXSIZE" = ""
      set -xg SCCACHE_CACHE_SIZE 200G
    else
      set -xg SCCACHE_CACHE_SIZE $CCACHE_MAXSIZE
    end

    if test "$SCCACHE_BUCKET" != "" -a "$AWS_ACCESS_KEY_ID" != ""
      echo "using sccache at S3 ($SCCACHE_BUCKET)"
      set -e SCCACHE_DIR
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_GCS_KEY_PATH
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

    pushd $INNERWORKDIR
    and begin eval $SCCACHEBINPATH"/sccache --stop-server 2>> $INNERWORKDIR/sccache.err.log"; or true; end
    and eval $SCCACHEBINPATH"/sccache --start-server"
    and popd
    or begin
      echo "warning: cannot start sccache"
      set -e SCCACHE_DIR
      set -e SCCACHE_BUCKET
      set -e SCCACHE_DIR
      set -e SCCACHE_GCS_BUCKET
      set -e SCCACHE_MEMCACHED
      set -e SCCACHE_REDIS
    end
  else
    set -xg CCACHE_DIR $INNERWORKDIR/.ccache.$CCACHETYPE
    if test "$CCACHEBINPATH" = ""
      echo "fatal, CCACHEBINPATH not set" 
      exit 1
    end
    if test "$CCACHE_MAXSIZE" = ""
      set -xg CCACHE_MAXSIZE 50G
    end

    echo "using ccache at $CCACHE_DIR ($CCACHE_MAXSIZE)"

    pushd $INNERWORKDIR
    and mkdir -p .ccache.$CCACHETYPE
    and rm -f .ccache.log
    and ccache -M $CCACHE_MAXSIZE
    and ccache --zero-stats
    and popd
    or begin echo "fatal, cannot start ccache"; exit 1; end
  end
  return 0
end

function cmakeCcache
  if test "$USE_CCACHE" = "Off"
    set -g FULLARGS $FULLARGS \
      -DUSE_CCACHE=Off
  else
    # USE_CACHE is not used because the compiler is already ccache
    set -g FULLARGS $FULLARGS \
     -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/$CXX_NAME \
     -DCMAKE_C_COMPILER=$CCACHEBINPATH/$CC_NAME \
     -DUSE_CCACHE=Off
  end
  return 0
end

function shutdownCcache
  if test "$USE_CCACHE" = "On"
    ccache --show-stats
  else if test "$USE_CCACHE" = "sccache"
    eval $SCCACHEBINPATH"sccache --stop-server 2>> $INNERWORKDIR/sccache.err.log"; or echo "warning: cannot stop sccache. See $INNERWORKDIR/sccache.err.log"
  end
  return 0
end

function selectArchitecture
  if begin test "$USE_ARM" = "On";and test (string match -ir '^arm64$|^aarch64$' "$ARCH"); end
    echo "using architecture ARM"
    set -g FULLARGS $FULLARGS \
      -DCMAKE_SYSTEM_PROCESSOR="aarch64" -DASM_OPTIMIZATIONS=Off
  else
    if test "$DEFAULT_ARCHITECTURE" != ""
      echo "using architecture '$DEFAULT_ARCHITECTURE'"
      set -g FULLARGS $FULLARGS \
        -DTARGET_ARCHITECTURE=$DEFAULT_ARCHITECTURE
    else
      echo "using provided architecture '"$argv"'"
      set -g FULLARGS $FULLARGS \
        -DTARGET_ARCHITECTURE=$argv
    end
  end
  return 0
end

function selectMaintainer
  if test "$MAINTAINER" != "On"
    set -g FULLARGS $FULLARGS \
      -DUSE_CATCH_TESTS=Off \
      -DUSE_GOOGLE_TESTS=Off
  end
  return 0
end

function cleanBuildDirectory
  pushd $INNERWORKDIR/ArangoDB
  and if test -z "$NO_RM_BUILD"
    echo "Cleaning build directory"
    rm -rf build
  end
  and mkdir -p build
  and cd build
  and rm -rf install
  and mkdir install
  and popd
  or begin popd ; return 1 ; end
end

function runCmake
  echo cmake $FULLARGS

  if test "$SHOW_DETAILS" = "On"
    echo "cmake $FULLARGS -DVERBOSE=On .. 2>&1"
    cmake $FULLARGS -DVERBOSE=On .. 2>&1
  else
    echo "cmake $FULLARGS -DVERBOSE=On .. > $INNERWORKDIR/cmakeArangoDB.log 2>&1"
    echo cmake output in $INNERWORKDIR/cmakeArangoDB.log
    cmake $FULLARGS -DVERBOSE=On .. > $INNERWORKDIR/cmakeArangoDB.log 2>&1
  end
end

function runMake
  set -g MAKEFLAGS -j$PARALLELISM 
  if test "$VERBOSEBUILD" = "On"
    echo "Building verbosely"
    set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
  end

  if test "$SHOW_DETAILS" = "On"
    make $MAKEFLAGS $argv[1] 2>&1
    or exit $status
  else
    echo make output in work/buildArangoDB.log
    set -l ep ""

    if test "$SHOW_DETAILS" = "Ping"
      fish -c "while true; sleep 60; echo == (date) ==; test -f $INNERWORKDIR/buildArangoDB.log; and tail -2 $INNERWORKDIR/buildArangoDB.log; end" &
      set ep (jobs -p | tail -1)
    end

    if test "$argv[1]" = "install"
      nice make $MAKEFLAGS > $INNERWORKDIR/buildArangoDB.log 2>&1
    end
    and nice make $MAKEFLAGS $argv[1] >> $INNERWORKDIR/buildArangoDB.log 2>&1
    or begin
      if test -n "$ep"
        kill $ep
      end

      exit 1
    end

    echo == (date) ==
    echo "compilation finished"

    if test -n "$ep"
      kill $ep
    end
  end
end

function installTargets
  pushd install
  and if test -z "$NOSTRIP"
    echo Stripping executables...
    strip \
      usr/sbin/arangod \
      usr/bin/arangoimport \
      usr/bin/arangosh \
      usr/bin/arangovpack \
      usr/bin/arangoexport \
      usr/bin/arangobench \
      usr/bin/arangodump \
      usr/bin/arangorestore

    and if test -f usr/bin/arangobackup
      strip usr/bin/arangobackup
    end
  end
end

function TT_init
  echo "Starting build at "(date)" on "(hostname)
  and set -g TT_t0 (date "+%Y%m%d")
  and set -g TT_t1 (date -u +%s)

  rm -f $INNERWORKDIR/buildTimes.csv
end

function TT_cmake
  set -g TT_t2 (date -u +%s)
  and echo $TT_t0,cmake,(expr $TT_t2 - $TT_t1) >> $INNERWORKDIR/buildTimes.csv
end

function TT_make
  set -g TT_t3 (date -u +%s)
  and echo $TT_t0,make,(expr $TT_t3 - $TT_t2) >> $INNERWORKDIR/buildTimes.csv
end

function TT_strip
  set -g TT_t4 (date -u +%s)
  and echo $TT_t0,strip,(expr $TT_t4 - $TT_t3) >> $INNERWORKDIR/buildTimes.csv
end

function generateJsSha1Sum
  set -l jsdir $INNERWORKDIR/$argv[1]
  if test -d $jsdir
    pushd $jsdir
    and rm -f JS_FILES.txt JS_SHA1SUM.txt
    and begin
      find . -type f | sort | xargs sha1sum > JS_FILES.txt
    end
    and sha1sum JS_FILES.txt > JS_SHA1SUM.txt
    and rm -f JS_FILES.txt
  end
  or begin popd ; return 1 ; end
  popd
end
