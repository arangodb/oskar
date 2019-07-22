set -gx KEYNAME 115E1684

function lockDirectory
  # Now grab the lock ourselves:
  set -l pid (echo %self)
  if test ! -f LOCK.$pid
    echo $pid > LOCK.$pid
    and while true
      # Remove a stale lock if it is found:
      if set -l pidfound (cat LOCK ^/dev/null)
        if not ps ax -o pid | grep '^ *'"$pidfound"'$' > /dev/null
          rm LOCK LOCK.$pidfound
          and echo Have removed stale lock.
        end
      end
      and if ln LOCK.$pid LOCK ^/dev/null
        break
      end
      and echo -n Directory is locked, waiting...
      and date
      and sleep 15
    end
  end
end

function unlockDirectory
  set -l pid (echo %self)
  if test -f LOCK.$pid
    rm -rf LOCK LOCK.$pid
  end
end

if test -f config/environment.fish
  source config/environment.fish
end

## #############################################################################
## config
## #############################################################################

function single ; set -gx TESTSUITE single ; end
function cluster ; set -gx TESTSUITE cluster ; end
function resilience ; set -gx TESTSUITE resilience ; end
function catchtest ; set -gx TESTSUITE catchtest ; end
if test -z "$TESTSUITE" ; cluster
else ; set -gx TESTSUITE $TESTSUITE ; end

function maintainerOn ; set -gx MAINTAINER On ; end
function maintainerOff ; set -gx MAINTAINER Off ; end
if test -z "$MAINTAINER" ; maintainerOn
else ; set -gx MAINTAINER $MAINTAINER ; end

function asanOn ; set -gx ASAN On ; end
function asanOff ; set -gx ASAN Off ; end
if test -z "$ASAN" ; asanOff
else ; set -gx ASAN $ASAN ; end

function jemallocOn; set -gx JEMALLOC_OSKAR On ; end
function jemallocOff; set -gx JEMALLOC_OSKAR Off ; end
if test -z "$JEMALLOC_OSKAR" ; jemallocOn
else ; set -gx JEMALLOC_OSKAR $JEMALLOC_OSKAR ; end

function debugMode ; set -gx BUILDMODE Debug ; end
function releaseMode ; set -gx BUILDMODE RelWithDebInfo ; end
if test -z "$BUILDMODE" ; releaseMode
else ; set -gx BUILDMODE $BUILDMODE ; end

function community ; set -gx ENTERPRISEEDITION Off ; end
function enterprise ; set -gx ENTERPRISEEDITION On ; end
if test -z "$ENTERPRISEEDITION" ; enterprise
else ; set -gx ENTERPRISEEDITION $ENTERPRISEEDITION ; end

function mmfiles ; set -gx STORAGEENGINE mmfiles ; end
function rocksdb ; set -gx STORAGEENGINE rocksdb ; end
if test -z "$STORAGEENGINE" ; rocksdb
else ; set -gx STORAGEENGINE $STORAGEENGINE ; end

function parallelism ; set -gx PARALLELISM $argv[1] ; end

function verbose ; set -gx VERBOSEOSKAR On ; end
function silent ; set -gx VERBOSEOSKAR Off ; end
if test -z "$VERBOSEOSKAR" ; verbose
else ; set -gx VERBOSEOSKAR $VERBOSEOSKAR ; end

function verboseBuild ; set -gx VERBOSEBUILD On ; end
function silentBuild ; set -gx VERBOSEBUILD Off ; end
if test -z "$VERBOSEBUILD"; silentBuild
else ; set -gx VERBOSEBUILD $VERBOSEBUILD ; end

function showDetails ; set -gx SHOW_DETAILS On ; end
function hideDetails ; set -gx SHOW_DETAILS Off ; end

if test -z "$SHOW_DETAILS"
  if isatty 1
    showDetails
  else
    hideDetails
  end
else
  set -gx SHOW_DETAILS $SHOW_DETAILS
end

function skipNondeterministic ; set -gx SKIPNONDETERMINISTIC true ; end
function includeNondeterministic ; set -gx SKIPNONDETERMINISTIC false ; end
if test -z "$SKIPNONDETERMINISTIC"; skipNondeterministic
else ; set -gx SKIPNONDETERMINISTIC $SKIPNONDETERMINISTIC ; end

function skipTimeCritical ; set -gx SKIPTIMECRITICAL true ; end
function includeTimeCritical ; set -gx SKIPTIMECRITICAL false ; end
if test -z "$SKIPTIMECRITICAL"; skipTimeCritical
else ; set -gx SKIPTIMECRITICAL $SKIPTIMECRITICAL ; end

function skipGrey ; set -gx SKIPGREY true ; end
function includeGrey ; set -gx SKIPGREY false ; end
if test -z "$SKIPGREY"; includeGrey
else ; set -gx SKIPGREY $SKIPGREY ; end

function onlyGreyOn ; set -gx ONLYGREY true ; end
function onlyGreyOff ; set -gx ONLYGREY false ; end
if test -z "$ONLYGREY"; onlyGreyOff
else ; set -gx ONLYGREY $ONLYGREY ; end

function stable ; set -gx RELEASE_TYPE stable ; end
function preview ; set -gx RELEASE_TYPE preview ; end
if test -z "$RELEASE_TYPE"; preview
else ; set -gx RELEASE_TYPE $RELEASE_TYPE ; end

function keepBuild ; set -gx NO_RM_BUILD 1 ; end
function clearBuild ; set -gx NO_RM_BUILD ; end

function setAllLogsToWorkspace ; set -gx WORKSPACE_LOGS "all" ; end
function setOnlyFailLogsToWorkspace ; set -gx WORKSPACE_LOGS "fail"; end
if test -z "$WORKSPACE_LOGS"; setOnlyFailLogsToWorkspace
else ; set -gx WORKSPACE_LOGS $WORKSPACE_LOGS ; end

function addLogLevel ; set -gx LOG_LEVELS $LOG_LEVELS $argv ; end
function clearLogLevel ; set -ge LOG_LEVEL ; end

# main code between function definitions
# WORDIR IS pwd -  at least check if ./scripts and something
# else is available before proceeding
set -gx WORKDIR (pwd)
if test ! -d scripts ; echo "cannot find scripts directory" ; exit 1 ; end
if test ! -d work ; mkdir work ; end

if test -z "$ARANGODB_DOCS_BRANCH" ; set -gx ARANGODB_DOCS_BRANCH "master"
else ; set -gx ARANGODB_DOCS_BRANCH $ARANGODB_DOCS_BRANCH ; end

## #############################################################################
## test
## #############################################################################

function createLogLevelsOverride
  for i in arangod-agency arangod-agent arangod-common arangod-coordinator arangod-dbserver arangod-single arangod
    begin
      echo "[log]"

      for log in $LOG_LEVELS
        echo "level = $log"
      end
    end > $WORKDIR/work/ArangoDB/etc/testing/$i.conf.local
  end
end

function oskar1
  showConfig
  showRepository
  set -x NOSTRIP 1
  if test "$ASAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  end
  oskar
end

function oskar1Full
  showConfig
  showRepository
  set -x NOSTRIP 1
  if test "$ASAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  end
  oskarFull
end

function oskar2
  set -l testsuite $TESTSUITE
  set -x NOSTRIP 1

  showConfig
  showRepository

  if test "$ASAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  end

  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  set -xg TESTSUITE $testsuite
end

function oskar4
  set -l testsuite $TESTSUITE ; set -l storageengine $STORAGEENGINE
  set -x NOSTRIP 1

  showConfig
  showRepository

  if test "$ASAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  end

  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status
  cluster ; rocksdb

  set -xg TESTSUITE $testsuite ; set -xg STORAGEENGINE $storageengine
end

function oskar8
  set -l testsuite $TESTSUITE ; set -l storageengine $STORAGEENGINE ; set -l enterpriseedition $ENTERPRISEEDITION
  set -x NOSTRIP 1

  showConfig
  showRepository

  enterprise

  if test "$ASAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  end
 
  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  community

  if test "$ASAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  end

  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  set -xg TESTSUITE $testsuite ; set -xg STORAGEENGINE $storageengine ; set -l ENTERPRISEEDITION $enterpriseedition
end

## #############################################################################
## set release version variables in CMakeLists.txt
## #############################################################################

function setNightlyRelease
  checkoutIfNeeded
  sed -i -e "s/set(ARANGODB_VERSION_RELEASE_TYPE .*/set(ARANGODB_VERSION_RELEASE_TYPE \"nightly\")/" $WORKDIR/work/ArangoDB/CMakeLists.txt
  sed -i -e "s/set(ARANGODB_VERSION_RELEASE_NUMBER .*/set(ARANGODB_VERSION_RELEASE_NUMBER \""(date +%Y%m%d)"\")/" $WORKDIR/work/ArangoDB/CMakeLists.txt
end

## #############################################################################
## release
## #############################################################################

function makeRelease
  if test "$DOWNLOAD_SYNC_USER" = ""
    echo "Need to set environment variable DOWNLOAD_SYNC_USER."
    return 1
  end

  if test (count $argv) -lt 2
    findArangoDBVersion ; or return 1
  else
    set -xg ARANGODB_VERSION "$argv[1]"
    set -xg ARANGODB_PACKAGE_REVISION "$argv[2]"
    set -xg ARANGODB_FULL_VERSION "$argv[1]-$argv[2]"
  end

  buildEnterprisePackage
  and buildCommunityPackage
end

## #############################################################################
## source release
## #############################################################################

function makeSourceRelease
  set -l SOURCE_TAG "unknown"

  if test (count $argv) -lt 1
    findArangoDBVersion ; or return 1

    set SOURCE_TAG $ARANGODB_VERSION
  else
    set SOURCE_TAG $argv[1]
  end

  buildSourcePackage $SOURCE_TAG
  and signSourcePackage $SOURCE_TAG
end

function buildSourcePackage
  if test (count $argv) -lt 1
    echo "Need source tag as parameter"
    exit 1
  end

  set -l SOURCE_TAG $argv[1]

  pushd $WORKDIR/work
  and rm -rf ArangoDB-$SOURCE_TAG
  and cp -a ArangoDB ArangoDB-$SOURCE_TAG
  and pushd ArangoDB-$SOURCE_TAG
  and find . -maxdepth 1 -name "arangodb-tmp.sock*" -delete
  and rm -rf enterprise upgrade-data-tests
  and git clean -f -d -x
  and rm -rf .git
  and popd
  and echo "creating tar.gz"
  and rm -f ArangoDB-$SOURCE_TAG.tar.gz
  and tar -c -z -f ArangoDB-$SOURCE_TAG.tar.gz ArangoDB-$SOURCE_TAG
  and echo "creating tar.bz2"
  and rm -f ArangoDB-$SOURCE_TAG.tar.bz2
  and tar -c -j -f ArangoDB-$SOURCE_TAG.tar.bz2 ArangoDB-$SOURCE_TAG
  and echo "creating zip"
  and rm -f ArangoDB-$SOURCE_TAG.zip
  and zip -q -r ArangoDB-$SOURCE_TAG.zip ArangoDB-$SOURCE_TAG
  and popd
  or begin ; popd ; return 1 ; end
end

## #############################################################################
## TAR release
## #############################################################################

function buildTarGzPackageHelper
  set -l os "$argv[1]"

  if test -z "$os"
    echo "need operating system as first argument"
    return 1
  end

  # This assumes that a static build has already happened
  # Must have set ARANGODB_TGZ_UPSTREAM
  # for example by running findArangoDBVersion.
  set -l v "$ARANGODB_TGZ_UPSTREAM"
  set -l name

  if test "$ENTERPRISEEDITION" = "On"
    set name arangodb3e
  else
    set name arangodb3
  end

  pushd $WORKDIR/work/ArangoDB/build/install
  and rm -rf bin
  and cp -a $WORKDIR/binForTarGz bin
  and rm -f "bin/*~" "bin/*.bak"
  and mv bin/README .
  and strip usr/sbin/arangod usr/bin/{arangobench,arangodump,arangoexport,arangoimp,arangorestore,arangosh,arangovpack}
  and if test "$ENTERPRISEEDITION" != "On"
    rm -f "bin/arangosync" "usr/bin/arangosync" "usr/sbin/arangosync"
  end
  and cd $WORKDIR/work/ArangoDB/build
  and mv install "$name-$v"
  or begin ; popd ; return 1 ; end

  tar -c -z -f "$WORKDIR/work/$name-$os-$v.tar.gz" --exclude "etc" --exclude "var" "$name-$v"
  set s $status

  if test "$s" -eq 0
    tar -c -z -f "$WORKDIR/work/$name-client-$os-$v.tar.gz" \
      --exclude "etc" \
      --exclude "var" \
      --exclude "*.initd" \
      --exclude "*.services" \
      --exclude "*.logrotate" \
      --exclude "arangodb.8" \
      --exclude "arangod.8" \
      --exclude "arango-dfdb.8" \
      --exclude "rcarangod.8" \
      --exclude "$name-$v/bin/arangodb" \
      --exclude "$name-$v/usr/sbin" \
      --exclude "$name-$v/usr/bin/arangodb" \
      --exclude "$name-$v/usr/share/arangodb3/arangodb-update-db" \
      --exclude "$name-$v/usr/share/arangodb3/js/server" \
      "$name-$v"
    set s $status
  end

  mv "$name-$v" install
  and popd
  and return $s 
end

## #############################################################################
## release snippets
## #############################################################################

function makeSnippets
  if test (count $argv) -lt 2
    echo "usage: makeSnippets <stage2> <stage1>"
    return 1
  end

  findArangoDBVersion

  set IN $argv[1]
  set OUT $argv[2]

  community
  and buildSourceSnippet $IN $OUT
  and buildDebianSnippet $IN $OUT
  and buildRPMSnippet $IN $OUT
  and buildTarGzSnippet $IN $OUT
  and buildBundleSnippet $IN $OUT
  and buildWindowsSnippet $IN $OUT
  and buildDockerSnippet $OUT

  and enterprise
  and buildDebianSnippet $IN $OUT
  and buildRPMSnippet $IN $OUT
  and buildTarGzSnippet $IN $OUT
  and buildBundleSnippet $IN $OUT
  and buildWindowsSnippet $IN $OUT
  and buildDockerSnippet $OUT
end

## #############################################################################
## source snippets
## #############################################################################

function buildSourceSnippet
  set -l SOURCE_TAR_GZ "ArangoDB-$ARANGODB_VERSION.tar.gz"
  set -l SOURCE_TAR_BZ2 "ArangoDB-$ARANGODB_VERSION.tar.bz2"
  set -l SOURCE_ZIP "ArangoDB-$ARANGODB_VERSION.zip"

  set IN $argv[1]/$ARANGODB_PACKAGES/source
  set OUT $argv[2]/release/snippets

  if test ! -f "$IN/$SOURCE_TAR_GZ"; echo "Source package '$SOURCE_TAR_GZ' is missing"; return 1; end
  if test ! -f "$IN/$SOURCE_TAR_BZ2"; echo "Source package '$SOURCE_TAR_BZ2"' is missing"; return 1; end
  if test ! -f "$IN/$SOURCE_ZIP"; echo "Source package '$SOURCE_ZIP"' is missing"; return 1; end

  set -l SOURCE_SIZE_TAR_GZ (expr (wc -c < $IN/$SOURCE_TAR_GZ) / 1024 / 1024)
  set -l SOURCE_SIZE_TAR_BZ2 (expr (wc -c < $IN/$SOURCE_TAR_BZ2) / 1024 / 1024)
  set -l SOURCE_SIZE_ZIP (expr (wc -c < $IN/$SOURCE_ZIP) / 1024 / 1024)

  set -l SOURCE_SHA256_TAR_GZ (shasum -a 256 -b < $IN/$SOURCE_TAR_GZ | awk '{print $1}')
  set -l SOURCE_SHA256_TAR_BZ2 (shasum -a 256 -b < $IN/$SOURCE_TAR_BZ2 | awk '{print $1}')
  set -l SOURCE_SHA256_ZIP (shasum -a 256 -b < $IN/$SOURCE_ZIP | awk '{print $1}')

  set -l n "$OUT/download-source.html"

  sed -e "s|@SOURCE_TAR_GZ@|$SOURCE_TAR_GZ|g" \
      -e "s|@SOURCE_SIZE_TAR_GZ@|$SOURCE_SIZE_TAR_GZ|g" \
      -e "s|@SOURCE_SHA256_TAR_GZ@|$SOURCE_SHA256_TAR_GZ|g" \
      -e "s|@SOURCE_TAR_BZ2@|$SOURCE_TAR_BZ2|g" \
      -e "s|@SOURCE_SIZE_TAR_BZ2@|$SOURCE_SIZE_TAR_BZ2|g" \
      -e "s|@SOURCE_SHA256_TAR_BZ2@|$SOURCE_SHA256_TAR_BZ2|g" \
      -e "s|@SOURCE_ZIP@|$SOURCE_ZIP|g" \
      -e "s|@SOURCE_SIZE_ZIP@|$SOURCE_SIZE_ZIP|g" \
      -e "s|@SOURCE_SHA256_ZIP@|$SOURCE_SHA256_ZIP|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/source.html.in > $n

  and echo "Source Snippet: $n"
end

## #############################################################################
## debian snippets
## #############################################################################

function buildDebianSnippet
  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set DOWNLOAD_LINK ""
  end

  set -l DEBIAN_VERSION "$ARANGODB_DEBIAN_UPSTREAM""-$ARANGODB_DEBIAN_REVISION"
  set -l DEBIAN_NAME_CLIENT "$ARANGODB_PKG_NAME""-client_$DEBIAN_VERSION""_amd64.deb"
  set -l DEBIAN_NAME_SERVER "$ARANGODB_PKG_NAME""_$DEBIAN_VERSION""_amd64.deb"
  set -l DEBIAN_NAME_DEBUG_SYMBOLS "$ARANGODB_PKG_NAME-dbg_$DEBIAN_VERSION""_amd64.deb"

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/Linux/
  set -l OUT $argv[2]/release/snippets

  if test ! -f "$IN/$DEBIAN_NAME_SERVER"; echo "Debian package '$DEBIAN_NAME_SERVER' is missing"; return 1; end
  if test ! -f "$IN/$DEBIAN_NAME_CLIENT"; echo "Debian package '$DEBIAN_NAME_CLIENT' is missing"; return 1; end
  if test ! -f "$IN/$DEBIAN_NAME_DEBUG_SYMBOLS"; echo "Debian package '$DEBIAN_NAME_DEBUG_SYMBOLS' is missing"; return 1; end

  set -l DEBIAN_SIZE_SERVER (expr (wc -c < $IN/$DEBIAN_NAME_SERVER) / 1024 / 1024)
  set -l DEBIAN_SIZE_CLIENT (expr (wc -c < $IN/$DEBIAN_NAME_CLIENT) / 1024 / 1024)
  set -l DEBIAN_SIZE_DEBUG_SYMBOLS (expr (wc -c < $IN/$DEBIAN_NAME_DEBUG_SYMBOLS) / 1024 / 1024)

  set -l DEBIAN_SHA256_SERVER (shasum -a 256 -b < $IN/$DEBIAN_NAME_SERVER | awk '{print $1}')
  set -l DEBIAN_SHA256_CLIENT (shasum -a 256 -b < $IN/$DEBIAN_NAME_CLIENT | awk '{print $1}')
  set -l DEBIAN_SHA256_DEBUG_SYMBOLS (shasum -a 256 -b < $IN/$DEBIAN_NAME_DEBUG_SYMBOLS | awk '{print $1}')

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-linux-$ARANGODB_TGZ_UPSTREAM.tar.gz"

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-debian.html"

  sed -e "s|@DEBIAN_NAME_SERVER@|$DEBIAN_NAME_SERVER|g" \
      -e "s|@DEBIAN_NAME_CLIENT@|$DEBIAN_NAME_CLIENT|g" \
      -e "s|@DEBIAN_NAME_DEBUG_SYMBOLS@|$DEBIAN_NAME_DEBUG_SYMBOLS|g" \
      -e "s|@DEBIAN_SIZE_SERVER@|$DEBIAN_SIZE_SERVER|g" \
      -e "s|@DEBIAN_SIZE_CLIENT@|$DEBIAN_SIZE_CLIENT|g" \
      -e "s|@DEBIAN_SIZE_DEBUG_SYMBOLS@|$DEBIAN_SIZE_DEBUG_SYMBOLS|g" \
      -e "s|@DEBIAN_SHA256_SERVER@|$DEBIAN_SHA256_SERVER|g" \
      -e "s|@DEBIAN_SHA256_CLIENT@|$DEBIAN_SHA256_CLIENT|g" \
      -e "s|@DEBIAN_SHA256_DEBUG_SYMBOLS@|$DEBIAN_SHA256_DEBUG_SYMBOLS|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_CLIENT@|$TARGZ_NAME_CLIENT|g" \
      -e "s|@TARGZ_SIZE_CLIENT@|$TARGZ_SIZE_CLIENT|g" \
      -e "s|@TARGZ_SHA256_CLIENT@|$TARGZ_SHA256_CLIENT|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      -e "s|@DEBIAN_VERSION@|$DEBIAN_VERSION|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/debian.html.in > $n

  and echo "Debian Snippet: $n"
end

## #############################################################################
## RPM snippets
## #############################################################################

function buildRPMSnippet
  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set DOWNLOAD_LINK ""
  end

  set -l RPM_VERSION "$ARANGODB_RPM_UPSTREAM-$ARANGODB_RPM_REVISION"
  set -l RPM_NAME_CLIENT "$ARANGODB_PKG_NAME-client-$RPM_VERSION.x86_64.rpm"
  set -l RPM_NAME_SERVER "$ARANGODB_PKG_NAME-$RPM_VERSION.x86_64.rpm"
  set -l RPM_NAME_DEBUG_SYMBOLS "$ARANGODB_PKG_NAME-debuginfo-$RPM_VERSION.x86_64.rpm"

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/Linux/
  set -l OUT $argv[2]/release/snippets

  if test ! -f "$IN/$RPM_NAME_SERVER"; echo "RPM package '$RPM_NAME_SERVER' is missing"; return 1; end
  if test ! -f "$IN/$RPM_NAME_CLIENT"; echo "RPM package '$RPM_NAME_CLIENT' is missing"; return 1; end
  if test ! -f "$IN/$RPM_NAME_DEBUG_SYMBOLS"; echo "RPM package '$RPM_NAME_DEBUG_SYMBOLS' is missing"; return 1; end

  set -l RPM_SIZE_SERVER (expr (wc -c < $IN/$RPM_NAME_SERVER) / 1024 / 1024)
  set -l RPM_SIZE_CLIENT (expr (wc -c < $IN/$RPM_NAME_CLIENT) / 1024 / 1024)
  set -l RPM_SIZE_DEBUG_SYMBOLS (expr (wc -c < $IN/$RPM_NAME_DEBUG_SYMBOLS) / 1024 / 1024)

  set -l RPM_SHA256_SERVER (shasum -a 256 -b < $IN/$RPM_NAME_SERVER | awk '{print $1}')
  set -l RPM_SHA256_CLIENT (shasum -a 256 -b < $IN/$RPM_NAME_CLIENT | awk '{print $1}')
  set -l RPM_SHA256_DEBUG_SYMBOLS (shasum -a 256 -b < $IN/$RPM_NAME_DEBUG_SYMBOLS | awk '{print $1}')

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-linux-$ARANGODB_TGZ_UPSTREAM.tar.gz"

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-rpm.html"

  sed -e "s|@RPM_NAME_SERVER@|$RPM_NAME_SERVER|g" \
      -e "s|@RPM_NAME_CLIENT@|$RPM_NAME_CLIENT|g" \
      -e "s|@RPM_NAME_DEBUG_SYMBOLS@|$RPM_NAME_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SIZE_SERVER@|$RPM_SIZE_SERVER|g" \
      -e "s|@RPM_SIZE_CLIENT@|$RPM_SIZE_CLIENT|g" \
      -e "s|@RPM_SIZE_DEBUG_SYMBOLS@|$RPM_SIZE_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SHA256_SERVER@|$RPM_SHA256_SERVER|g" \
      -e "s|@RPM_SHA256_CLIENT@|$RPM_SHA256_CLIENT|g" \
      -e "s|@RPM_SHA256_DEBUG_SYMBOLS@|$RPM_SHA256_DEBUG_SYMBOLS|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_CLIENT@|$TARGZ_NAME_CLIENT|g" \
      -e "s|@TARGZ_SIZE_CLIENT@|$TARGZ_SIZE_CLIENT|g" \
      -e "s|@TARGZ_SHA256_CLIENT@|$TARGZ_SHA256_CLIENT|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_RPM_UPSTREAM@|$ARANGODB_RPM_UPSTREAM|g" \
      -e "s|@ARANGODB_RPM_REVISION@|$ARANGODB_RPM_REVISION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/rpm.html.in > $n

  and echo "RPM Snippet: $n"

  and set -l n "$OUT/download-$ARANGODB_PKG_NAME-suse.html"

  and sed -e "s|@RPM_NAME_SERVER@|$RPM_NAME_SERVER|g" \
      -e "s|@RPM_NAME_CLIENT@|$RPM_NAME_CLIENT|g" \
      -e "s|@RPM_NAME_DEBUG_SYMBOLS@|$RPM_NAME_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SIZE_SERVER@|$RPM_SIZE_SERVER|g" \
      -e "s|@RPM_SIZE_CLIENT@|$RPM_SIZE_CLIENT|g" \
      -e "s|@RPM_SIZE_DEBUG_SYMBOLS@|$RPM_SIZE_DEBUG_SYMBOLS|g" \
      -e "s|@RPM_SHA256_SERVER@|$RPM_SHA256_SERVER|g" \
      -e "s|@RPM_SHA256_CLIENT@|$RPM_SHA256_CLIENT|g" \
      -e "s|@RPM_SHA256_DEBUG_SYMBOLS@|$RPM_SHA256_DEBUG_SYMBOLS|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_CLIENT@|$TARGZ_NAME_CLIENT|g" \
      -e "s|@TARGZ_SIZE_CLIENT@|$TARGZ_SIZE_CLIENT|g" \
      -e "s|@TARGZ_SHA256_CLIENT@|$TARGZ_SHA256_CLIENT|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_RPM_UPSTREAM@|$ARANGODB_RPM_UPSTREAM|g" \
      -e "s|@ARANGODB_RPM_REVISION@|$ARANGODB_RPM_REVISION|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/suse.html.in > $n

  and echo "SUSE Snippet: $n"
end

## #############################################################################
## TAR snippets
## #############################################################################

function buildTarGzSnippet
  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set DOWNLOAD_LINK ""
  end

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-linux-$ARANGODB_VERSION.tar.gz"

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/Linux/
  set -l OUT $argv[2]/release/snippets

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-linux.html"

  sed -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_CLIENT@|$TARGZ_NAME_CLIENT|g" \
      -e "s|@TARGZ_SIZE_CLIENT@|$TARGZ_SIZE_CLIENT|g" \
      -e "s|@TARGZ_SHA256_CLIENT@|$TARGZ_SHA256_CLIENT|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/linux.html.in > $n

  and echo "TarGZ Snippet: $n"
end

## #############################################################################
## bundle snippets
## #############################################################################

function buildBundleSnippet
  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set DOWNLOAD_LINK ""
  end

  set -l BUNDLE_NAME_SERVER "$ARANGODB_PKG_NAME-$ARANGODB_DARWIN_UPSTREAM.x86_64.dmg"

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/MacOSX/
  set -l OUT $argv[2]/release/snippets

  if test ! -f "$IN/$BUNDLE_NAME_SERVER"; echo "DMG package '$BUNDLE_NAME_SERVER' is missing"; return 1; end

  set -l BUNDLE_SIZE_SERVER (expr (wc -c < $IN/$BUNDLE_NAME_SERVER | tr -d " ") / 1024 / 1024)
  set -l BUNDLE_SHA256_SERVER (shasum -a 256 -b < $IN/$BUNDLE_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-macosx-$ARANGODB_VERSION.tar.gz"

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER | tr -d " ") / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-macosx.html"

  sed -e "s|@BUNDLE_NAME_SERVER@|$BUNDLE_NAME_SERVER|g" \
      -e "s|@BUNDLE_SIZE_SERVER@|$BUNDLE_SIZE_SERVER|g" \
      -e "s|@BUNDLE_SHA256_SERVER@|$BUNDLE_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_SERVER@|$TARGZ_NAME_SERVER|g" \
      -e "s|@TARGZ_SIZE_SERVER@|$TARGZ_SIZE_SERVER|g" \
      -e "s|@TARGZ_SHA256_SERVER@|$TARGZ_SHA256_SERVER|g" \
      -e "s|@TARGZ_NAME_CLIENT@|$TARGZ_NAME_CLIENT|g" \
      -e "s|@TARGZ_SIZE_CLIENT@|$TARGZ_SIZE_CLIENT|g" \
      -e "s|@TARGZ_SHA256_CLIENT@|$TARGZ_SHA256_CLIENT|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/macosx.html.in > $n

  and echo "MacOSX Bundle Snippet: $n"
end

## #############################################################################
## windows snippets
## #############################################################################

function buildWindowsSnippet
  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_EDITION_LC "enterprise"
    set ARANGODB_PKG_NAME "ArangoDB3e"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_EDITION_LC "community"
    set ARANGODB_PKG_NAME "ArangoDB3"
    set DOWNLOAD_LINK ""
  end

  set -l WINDOWS_NAME_SERVER_EXE "$ARANGODB_PKG_NAME-$ARANGODB_VERSION""_win64.exe"
  set -l WINDOWS_NAME_SERVER_ZIP "$ARANGODB_PKG_NAME-$ARANGODB_VERSION""_win64.zip"
  set -l WINDOWS_NAME_CLIENT_EXE "$ARANGODB_PKG_NAME-client-$ARANGODB_VERSION""_win64.exe"

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/Windows/
  set -l OUT $argv[2]/release/snippets

  if test ! -f "$IN/$WINDOWS_NAME_SERVER_EXE"; echo "Windows server exe package '$WINDOWS_NAME_SERVER_EXE' is missing"; return 1; end
  if test ! -f "$IN/$WINDOWS_NAME_SERVER_ZIP"; echo "Windows server zip package '$WINDOWS_NAME_SERVER_ZIP' is missing"; return 1; end
  if test ! -f "$IN/$WINDOWS_NAME_CLIENT_EXE"; echo "Windows client exe package '$WINDOWS_NAME_CLIENT_EXE' is missing"; return 1; end

  set -l WINDOWS_SIZE_SERVER_EXE (expr (wc -c < $IN/$WINDOWS_NAME_SERVER_EXE | tr -d " ") / 1024 / 1024)
  set -l WINDOWS_SHA256_SERVER_EXE (shasum -a 256 -b < $IN/$WINDOWS_NAME_SERVER_EXE | awk '{print $1}')

  set -l WINDOWS_SIZE_SERVER_ZIP (expr (wc -c < $IN/$WINDOWS_NAME_SERVER_ZIP | tr -d " ") / 1024 / 1024)
  set -l WINDOWS_SHA256_SERVER_ZIP (shasum -a 256 -b < $IN/$WINDOWS_NAME_SERVER_ZIP | awk '{print $1}')

  set -l WINDOWS_SIZE_CLIENT_EXE (expr (wc -c < $IN/$WINDOWS_NAME_CLIENT_EXE | tr -d " ") / 1024 / 1024)
  set -l WINDOWS_SHA256_CLIENT_EXE (shasum -a 256 -b < $IN/$WINDOWS_NAME_CLIENT_EXE | awk '{print $1}')

  set -l n "$OUT/download-windows-$ARANGODB_EDITION_LC.html"

  sed -e "s|@WINDOWS_NAME_SERVER_EXE@|$WINDOWS_NAME_SERVER_EXE|g" \
      -e "s|@WINDOWS_SIZE_SERVER_EXE@|$WINDOWS_SIZE_SERVER_EXE|g" \
      -e "s|@WINDOWS_SHA256_SERVER_EXE@|$WINDOWS_SHA256_SERVER_EXE|g" \
      -e "s|@WINDOWS_NAME_SERVER_ZIP@|$WINDOWS_NAME_SERVER_ZIP|g" \
      -e "s|@WINDOWS_SIZE_SERVER_ZIP@|$WINDOWS_SIZE_SERVER_ZIP|g" \
      -e "s|@WINDOWS_SHA256_SERVER_ZIP@|$WINDOWS_SHA256_SERVER_ZIP|g" \
      -e "s|@WINDOWS_NAME_CLIENT_EXE@|$WINDOWS_NAME_CLIENT_EXE|g" \
      -e "s|@WINDOWS_SIZE_CLIENT_EXE@|$WINDOWS_SIZE_CLIENT_EXE|g" \
      -e "s|@WINDOWS_SHA256_CLIENT_EXE@|$WINDOWS_SHA256_CLIENT_EXE|g" \
      -e "s|@DOWNLOAD_LINK@|$DOWNLOAD_LINK|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/windows.html.in > $n

  and echo "Windows Snippet: $n"
end

## #############################################################################
## docker snippets
## #############################################################################

function buildDockerSnippet
  if test "$ENTERPRISEEDITION" = "On"
    set edition enterprise
    set repo enterprise
  else
    set edition community
    set repo arangodb
  end

  if test "$RELEASE_TYPE" = "stable"
    set DOCKER_IMAGE arangodb/$repo:$DOCKER_TAG
  else
    set DOCKER_IMAGE arangodb/$repo-preview:$DOCKER_TAG
  end

  transformDockerSnippet $edition $DOCKER_IMAGE $argv[1]
  and transformK8SSnippet $edition $DOCKER_IMAGE $argv[1]
end

function transformDockerSnippet
  set -l edition "$argv[1]"
  set -l DOCKER_IMAGE "$argv[2]"
  set -l OUT "$argv[3]/release/snippets"
  set -l ARANGODB_LICENSE_KEY_BASE64 (echo -n "$ARANGODB_LICENSE_KEY" | base64 -w 0)

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3e"
  end

  set -l n "$OUT/download-docker-$edition.html"

  sed -e "s|@DOCKER_IMAGE@|$DOCKER_IMAGE|g" \
      -e "s|@ARANGODB_LICENSE_KEY@|$ARANGODB_LICENSE_KEY|g" \
      -e "s|@ARANGODB_LICENSE_KEY_BASE64@|$ARANGODB_LICENSE_KEY_BASE64|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/docker.$edition.html.in > $n

  and echo "Docker Snippet: $n"
end

function transformK8SSnippet
  set -l edition "$argv[1]"
  set -l DOCKER_IMAGE "$argv[2]"
  set -l OUT "$argv[3]/release/snippets"
  set -l ARANGODB_LICENSE_KEY_BASE64 (echo -n "$ARANGODB_LICENSE_KEY" | base64 -w 0)

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
  end

  set -l n "$OUT/download-k8s-$edition.html"

  sed -e "s|@DOCKER_IMAGE@|$DOCKER_IMAGE|g" \
      -e "s|@ARANGODB_LICENSE_KEY@|$ARANGODB_LICENSE_KEY|g" \
      -e "s|@ARANGODB_LICENSE_KEY_BASE64@|$ARANGODB_LICENSE_KEY_BASE64|g" \
      -e "s|@ARANGODB_EDITION@|$ARANGODB_EDITION|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_PKG_NAME@|$ARANGODB_PKG_NAME|g" \
      -e "s|@ARANGODB_REPO@|$ARANGODB_REPO|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/k8s.$edition.html.in > $n

  and echo "Kubernetes Snippet: $n"
end

## #############################################################################
## show functions
## #############################################################################

function showConfig
  set -l fmt2 '%-20s: %-20s\n'
  set -l fmt3 '%-20s: %-20s %s\n'

  set -l compiler_version $COMPILER_VERSION

  if test -z "$COMPILER_VERSION"
    set compiler_version "["(findCompilerVersion)"]"
  end

  echo '------------------------------------------------------------------------------'
  echo 'Build Configuration'
  printf $fmt3 'ASAN'       $ASAN                '(asanOn/Off)'
  printf $fmt3 'Buildmode'  $BUILDMODE           '(debugMode/releaseMode)'
  printf $fmt3 'Compiler'   "$compiler_version"  '(compiler x.y.z)'
  printf $fmt3 'Enterprise' $ENTERPRISEEDITION   '(community/enterprise)'
  printf $fmt3 'Jemalloc'   $JEMALLOC_OSKAR      '(jemallocOn/jemallocOff)'
  printf $fmt3 'Maintainer' $MAINTAINER          '(maintainerOn/Off)'

  if test -z "$NO_RM_BUILD"
    printf $fmt3 'Clear build' On '(keepBuild/clearBuild)'
  else
    printf $fmt3 'Clear build' Off '(keepBuild/clearBuild)'
  end
  
  echo
  echo 'Test Configuration'
  printf $fmt3 'SkipNondeterministic'       $SKIPNONDETERMINISTIC      '(skipNondeterministic/includeNondeterministic)'
  printf $fmt3 'SkipTimeCritical'       $SKIPTIMECRITICAL      '(skipTimeCritical/includeTimeCritical)'
  printf $fmt3 'SkipGrey'       $SKIPGREY      '(skipGrey/includeGrey)'
  printf $fmt3 'OnlyGrey'       $ONLYGREY      '(onlyGreyOn/onlyGreyOff)'
  printf $fmt3 'Storage engine' $STORAGEENGINE '(mmfiles/rocksdb)'
  printf $fmt3 'Test suite'     $TESTSUITE     '(single/cluster/resilience/catchtest)'
  printf $fmt2 'Log Levels'     (echo $LOG_LEVELS)
  echo
  echo 'Package Configuration'
  printf $fmt3 'Stable/preview' $RELEASE_TYPE  '(stable/preview)'
  echo
  echo 'Internal Configuration'
  printf $fmt3 'Parallelism'   $PARALLELISM  '(parallelism nnn)'
  if test "$CCACHESIZE" != ""
  printf $fmt3 'CCACHE size'   $CCACHESIZE   '(CCACHESIZE)'
  end
  printf $fmt3 'Verbose Build' $VERBOSEBUILD '(verboseBuild/silentBuild)'
  printf $fmt3 'Verbose Oskar' $VERBOSEOSKAR '(verbose/slient)'
  printf $fmt3 'Details during build' $SHOW_DETAILS '(showDetails/hideDetails)'
  printf $fmt3 'Logs preserve' $WORKSPACE_LOGS '(setAllLogsToWorkspace/setOnlyFailLogsToWorkspace)'
  echo
  echo 'Directories'
  printf $fmt2 'Inner workdir' $INNERWORKDIR
  printf $fmt2 'Workdir'       $WORKDIR
  printf $fmt2 'Workspace'     $WORKSPACE
  echo '------------------------------------------------------------------------------'
  echo
end

function showRepository
  set -l fmt3 '%-12s: %-20s %s\n'

  echo '------------------------------------------------------------------------------'

  if test -d $WORKDIR/work/ArangoDB
    echo 'Repositories'
    pushd $WORKDIR
    printf $fmt3 'Oskar' (findBranch)
    popd
    pushd $WORKDIR/work/ArangoDB
    printf $fmt3 'Community' (findBranch)
    if test "$ENTERPRISEEDITION" = "On"
      if test -d $WORKDIR/work/ArangoDB/enterprise
        pushd enterprise
        printf $fmt3 'Enterprise' (findBranch)
        popd
      else
        printf $fmt3 'Enterprise' 'missing'
      end
    else
      printf $fmt3 'Enterprise' 'not configured'
    end
    if test -d $WORKDIR/work/ArangoDB/upgrade-data-tests
      pushd upgrade-data-tests
      printf $fmt3 'Test Data' (findBranch)
      popd
    else
      printf $fmt3 'Test Data' 'missing'
    end
    popd
  else
    printf $fmt3 'Community' 'missing'
  end

  echo '------------------------------------------------------------------------------'
  echo
end

function showLog
  if test -f work/test.log
    less +G work/test.log
  else
    echo "no test log available"
  end
end

function showHelp
  echo '------------------------------------------------------------------------------'
  echo 'showHelp                   show this message'
  echo 'showConfig                 show configuration'
  echo 'showRepository             show status of the checkout repositories'
  echo 'showLog                    show test log'
  echo '------------------------------------------------------------------------------'
  echo
end

## #############################################################################
## calculate versions
## #############################################################################

function findArangoDBVersion
  set -l CMAKELIST "$WORKDIR/work/ArangoDB/CMakeLists.txt"
  set -l AV "set(ARANGODB_VERSION"
  set -l APR "set(ARANGODB_PACKAGE_REVISION"

  set -l SEDFIX 's/.*"\([0-9a-zA-Z]*\)".*$/\1/'

  set -xg ARANGODB_VERSION_MAJOR (grep "$AV""_MAJOR" $CMAKELIST | sed -e $SEDFIX)
  set -xg ARANGODB_VERSION_MINOR (grep "$AV""_MINOR" $CMAKELIST | sed -e $SEDFIX)

  set -xg ARANGODB_SNIPPETS "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR"
  set -xg ARANGODB_PACKAGES "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR"

  # old version scheme (upto 3.3.x)
  if grep -q "$APR" $CMAKELIST
    set -l SEDFIX2 's/\([0-9a-zA-Z]*\)\(-\([0-9a-zA-Z]*\)\)*$/\1/'
    set -l SEDFIX3 's/.*"\([0-9a-zA-Z]*\(\.\([0-9a-zA-Z]*\)\)*\)".*$/\1/'
    set -l SEDFIX4 's/.*"\([0-9a-zA-Z]*\(-\([0-9a-zA-Z]*\)\)*\)".*$/\1/'

    set -xg ARANGODB_VERSION_PATCH (grep "$AV""_REVISION" $CMAKELIST | sed -e $SEDFIX4)
    set -g  ARANGODB_PACKAGE_REVISION (grep "$APR" $CMAKELIST | sed -e $SEDFIX3)

    set -xg ARANGODB_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"

    set -l avp (echo $ARANGODB_VERSION_PATCH | tr "-" ".")
    set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$avp"
    set -xg ARANGODB_DEBIAN_REVISION "1"

    set -l avp (echo $ARANGODB_VERSION_PATCH | sed -e $SEDFIX2)
    set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$avp"
    set -xg ARANGODB_RPM_REVISION "$ARANGODB_PACKAGE_REVISION"

    set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
    set -xg ARANGODB_DARWIN_REVISION "$ARANGODB_PACKAGE_REVISION"

    set -xg ARANGODB_TGZ_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"

    set -xg ARANGODB_REPO "arangodb""$ARANGODB_VERSION_MAJOR""$ARANGODB_VERSION_MINOR"

    set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR"

  # new version scheme (from 3.4.x)  
  else
    set -xg ARANGODB_VERSION_PATCH (grep "$AV""_PATCH" $CMAKELIST | grep -v unset | sed -e $SEDFIX)
    set -g  ARANGODB_VERSION_RELEASE_TYPE (grep "$AV""_RELEASE_TYPE" $CMAKELIST | grep -v unset | sed -e $SEDFIX)
    set -g  ARANGODB_VERSION_RELEASE_NUMBER (grep "$AV""_RELEASE_NUMBER" $CMAKELIST | grep -v unset | sed -e $SEDFIX)

    # stable release
    if test "$ARANGODB_VERSION_RELEASE_TYPE" = ""
      set -xg ARANGODB_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"

      set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_DARWIN_REVISION ""

      set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_DEBIAN_REVISION "1"

      set -xg ARANGODB_TGZ_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"

      set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_RPM_REVISION "1.0"

      set -xg ARANGODB_REPO "arangodb""$ARANGODB_VERSION_MAJOR""$ARANGODB_VERSION_MINOR"

      set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"

    # devel or nightly
    else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "devel" \
              -o "$ARANGODB_VERSION_RELEASE_TYPE" = "nightly"
      set -xg ARANGODB_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH.$ARANGODB_VERSION_RELEASE_TYPE"
      set -xg ARANGODB_DARWIN_REVISION "$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH~~$ARANGODB_VERSION_RELEASE_TYPE"
      set -xg ARANGODB_DEBIAN_REVISION "1"

      set -xg ARANGODB_TGZ_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE"

      if test "$ARANGODB_VERSION_RELEASE_TYPE" = "devel"
        set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
        set -xg ARANGODB_RPM_REVISION "0.1"
        set -xg ARANGODB_REPO nightly
      else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "nightly"
        set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
        set -xg ARANGODB_RPM_REVISION "0.2"
        set -xg ARANGODB_REPO nightly
      end

    # unstable release, devel or nightly
    else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "alpha" \
              -o "$ARANGODB_VERSION_RELEASE_TYPE" = "beta" \
              -o "$ARANGODB_VERSION_RELEASE_TYPE" = "milestone" \
              -o "$ARANGODB_VERSION_RELEASE_TYPE" = "preview" \
              -o "$ARANGODB_VERSION_RELEASE_TYPE" = "rc"
      if test "$ARANGODB_VERSION_RELEASE_NUMBER" = ""
        echo "ERROR: missing ARANGODB_VERSION_RELEASE_NUMBER for type $ARANGODB_VERSION_RELEASE_TYPE"
        return
      end

      if test "$ARANGODB_VERSION_RELEASE_TYPE" = "alpha"
        set N 100
      else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "beta"
        set N 200
      else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "milestone"
        set N 300
      else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "preview"
        set N 400
      else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "rc"
        set N 500
      end

      set -xg ARANGODB_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"

      set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH~$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"
      set -xg ARANGODB_DEBIAN_REVISION "1"

      set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_RPM_REVISION "0."(expr $N + $ARANGODB_VERSION_RELEASE_NUMBER)".$ARANGODB_VERSION_RELEASE_TYPE$ARANGODB_VERSION_RELEASE_NUMBER"

      set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"
      set -xg ARANGODB_DARWIN_REVISION ""

      set -xg ARANGODB_TGZ_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"

      set -xg ARANGODB_REPO "arangodb""$ARANGODB_VERSION_MAJOR""$ARANGODB_VERSION_MINOR-$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"

      set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"

    # hot-fix
    else
      if test "$ARANGODB_VERSION_RELEASE_NUMBER" != ""
        echo "ERROR: ARANGODB_VERSION_RELEASE_NUMBER ($ARANGODB_VERSION_RELEASE_NUMBER) must be empty for type $ARANGODB_VERSION_RELEASE_TYPE"
        return
      end

      set -xg ARANGODB_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH.$ARANGODB_VERSION_RELEASE_TYPE"
      set -xg ARANGODB_DEBIAN_REVISION "1"

      set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_RPM_REVISION "1.$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH.$ARANGODB_VERSION_RELEASE_TYPE"
      set -xg ARANGODB_DARWIN_REVISION ""

      set -xg ARANGODB_TGZ_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg ARANGODB_REPO "arangodb""$ARANGODB_VERSION_MAJOR""$ARANGODB_VERSION_MINOR"

      set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
    end
  end

  echo '------------------------------------------------------------------------------'
  echo "ARANGODB_VERSION:                  $ARANGODB_VERSION"
  echo
  echo "ARANGODB_VERSION_MAJOR:            $ARANGODB_VERSION_MAJOR"
  echo "ARANGODB_VERSION_MINOR:            $ARANGODB_VERSION_MINOR"
  echo "ARANGODB_VERSION_PATCH:            $ARANGODB_VERSION_PATCH"
  echo "ARANGODB_VERSION_RELEASE_TYPE:     $ARANGODB_VERSION_RELEASE_TYPE"
  echo "ARANGODB_VERSION_RELEASE_NUMBER:   $ARANGODB_VERSION_RELEASE_NUMBER"
  echo
  echo "ARANGODB_DARWIN_UPSTREAM/REVISION: $ARANGODB_DARWIN_UPSTREAM / $ARANGODB_DARWIN_REVISION"
  echo "ARANGODB_DEBIAN_UPSTREAM/REVISION: $ARANGODB_DEBIAN_UPSTREAM / $ARANGODB_DEBIAN_REVISION"
  echo "ARANGODB_PACKAGES:                 $ARANGODB_PACKAGES"
  echo "ARANGODB_REPO:                     $ARANGODB_REPO"
  echo "ARANGODB_RPM_UPDATREAM/REVISION:   $ARANGODB_RPM_UPSTREAM / $ARANGODB_RPM_REVISION"
  echo "ARANGODB_SNIPPETS:                 $ARANGODB_SNIPPETS"
  echo "ARANGODB_TGZ_UPSTREAM:             $ARANGODB_TGZ_UPSTREAM"
  echo "DOCKER_TAG:                        $DOCKER_TAG"
  echo '------------------------------------------------------------------------------'
  echo
end

## #############################################################################
## LOG ID
## #############################################################################

function checkLogId
  checkoutIfNeeded
  and pushd $WORKDIR/work/ArangoDB
  or begin popd; return 1; end

  set -l ids (find lib arangod arangosh enterprise -name "*.cpp" -o -name "*.h" \
    | xargs grep -h 'LOG_\(TOPIC\|TRX\|TOPIC_IF\)("[a-f0-9]*"' \
    | sed -e 's:^.*LOG_[^(]*("\([a-f0-9]*\)".*:\1:')

  set -l duplicate (echo $ids | tr " " "\n" | sort | uniq -d)

  set -l s 0

  if test "$duplicate" != ""
    echo "Duplicates: $duplicate"
    set s 1
  else
    echo "Duplicates: NONE"
  end

  set -l wrong (echo $ids | tr " " "\n" | grep -v '^[a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9]$')

  if test "$wrong" != ""
    echo "Wrong formats: $wrong"
    set s 1
  else
    echo "Wrong formats: NONE"
  end

  popd
  return $s
end

## #############################################################################
## helper functions
## #############################################################################

function findBranch
  set -l v (git config --get remote.origin.url)
  set -l w (git status -s -b | head -1)

  if echo $w | grep -q "no branch"
    set w (git status | head -1)
  end

  echo "$v $w"
end

function checkoutIfNeeded
  if test ! -d $WORKDIR/ArangoDB
    if test "$ENTERPRISEEDITION" = "On"
      checkoutEnterprise
    else
      checkoutArangoDB
    end
  end
  if test ! -d $WORKDIR/ArangoDB/upgrade-data-tests
    checkoutUpgradeDataTests
  end
end

function clearResults
  if test -d /cores
    set -l cores /cores/core.*
    if test (count $cores) -ne 0
      rm -f $cores
    end
  end

  pushd $WORKDIR/work
  and for f in testreport* ; rm -f $f ; end
  and rm -f test.log buildArangoDB.log cmakeArangoDB.log
  or begin ; popd ; return 1 ; end
  popd
end

function cleanWorkspace
  if test -d $WORKDIR/work
    pushd $WORKDIR/work
    and find . -maxdepth 1 '!' "(" -name ArangoDB -o -name . -o -name .. -o -name ".cc*" ")" -exec rm -rf "{}" ";"
    and popd
  end
end

function moveResultsToWorkspace
  if test ! -z "$WORKSPACE"
    # Used in jenkins test
    echo Moving reports and logs to $WORKSPACE ...
    if test -f $WORKDIR/work/test.log
      if head -1 $WORKDIR/work/test.log | grep BAD > /dev/null; or test $WORKSPACE_LOGS = "all"
        for f in $WORKDIR/work/testreport* ; echo "mv $f" ; mv $f $WORKSPACE ; end
      else
        for f in $WORKDIR/work/testreport* ; echo "rm $f" ; rm $f ; end
      end
      mv $WORKDIR/work/test.log $WORKSPACE
      if test -f $WORKDIR/work/testProtocol.txt
        mv $WORKDIR/work/testProtocol.txt $WORKSPACE/protocol.log
      end
    end
    for x in buildArangoDB.log cmakeArangoDB.log
      if test -f "$WORKDIR/work/$x" ; mv $WORKDIR/work/$x $WORKSPACE ; end
    end

    set -l matches $WORKDIR/work/*.{asc,deb,dmg,rpm,tar.gz,tar.bz2,zip,html}
    for f in $matches
      echo $f | grep -v testreport ; and echo "mv $f" ; and mv $f $WORKSPACE; or echo "skipping $f"      
    end
    for f in $WORKDIR/work/asan.log.* ; echo "mv $f" ; mv $f $WORKSPACE/(basename $f).log ; end

    if test -f $WORKDIR/work/testfailures.txt
      if grep -q -v '^[ \t]*$' $WORKDIR/work/testfailures.txt
        echo "mv $WORKDIR/work/testfailures.txt" ; mv $WORKDIR/work/testfailures.txt $WORKSPACE
      end
    end

    if test -d $WORKDIR/work/Documentation
      mv $WORKDIR/work/Documentation $WORKSPACE/Documentation.generated
    end

    if test -f $WORKDIR/work/testRuns.txt
      echo "mv $WORKDIR/work/testRuns.txt"
      mv $WORKDIR/work/testRuns.txt $WORKSPACE
    end
  end
end

## #############################################################################
## include the specifics for the platform
## #############################################################################

switch (uname)
  case Darwin ; source helper.mac.fish
  case Windows ; source helper.windows.fish
  case '*' ; source helper.linux.fish
end

if isatty 1
  showHelp
end
