set -gx KEYNAME 115E1684

function lockDirectory
  # Now grab the lock ourselves:
  set -l pid (echo %self)
  if test ! -f LOCK.$pid
    echo $pid > LOCK.$pid
    and while true
      # Remove a stale lock if it is found:
      if set -l pidfound (cat LOCK > /dev/null)
        if not ps ax -o pid | grep '^ *'"$pidfound"'$' > /dev/null
          rm LOCK LOCK.$pidfound
          and echo Have removed stale lock.
        end
      end
      and if ln LOCK.$pid LOCK > /dev/null
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

function convertSItoJSON
  if test -f $WORKDIR/work/sourceInfo.log
    set -l fields ""
    and begin
      cat $WORKDIR/work/sourceInfo.log | while read -l line
      set -l var (echo $line | cut -f1 -d ':')
      switch "$var"
        case "oskar" "VERSION" "Community" "Starter" "Enterprise" "Syncer" "Rclone"
          set -l val (echo $line | cut -f2 -d ' ')
          if test -n $val
            set fields "$fields  \"$var\":\""(echo $line | cut -f2 -d ' ')\"\n""
          end
        end
      end
      if test -n "$fields"
        echo "convert $WORKDIR/work/sourceInfo.log to $WORKDIR/work/sourceInfo.json"
        printf "{\n"(printf $fields | string join ",\n")"\n}" > $WORKDIR/work/sourceInfo.json
      end
    end
  end
end

function initSourceInfo
  set -l oskarCommit (git rev-parse HEAD)

  pushd $WORKDIR
  if test -f work/sourceInfo.log
    rm -rf work/sourceInfo.log
  end
 
  not test -z "$oskarCommit"
  and echo "oskar: $oskarCommit" > work/sourceInfo.log
  or echo "oskar: N/A" > work/sourceInfo.log
  echo "VERSION: N/A" >> work/sourceInfo.log
  echo "Community: N/A" >> work/sourceInfo.log
  echo "Starter: N/A" >> work/sourceInfo.log
  echo "Enterprise: N/A" >> work/sourceInfo.log
  echo "Syncer: N/A" >> work/sourceInfo.log
  echo "Rclone: N/A" >> work/sourceInfo.log
  
  popd
  convertSItoJSON
end

function setupSourceInfo
  set -l field $argv[1]
  set -l value $argv[2]
  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"
  sed -i$suffix -E 's/^'"$field"':.*$/'"$field"': '"$value"'/g' $WORKDIR/work/sourceInfo.log

  convertSItoJSON
end

## #############################################################################
## config
## #############################################################################

function single ; set -gx TESTSUITE single ; end
function cluster ; set -gx TESTSUITE cluster ; end
function single_cluster ; set -gx TESTSUITE single_cluster ; end
function resilience ; set -gx TESTSUITE resilience ; end
function catchtest ; set -gx TESTSUITE gtest ; end
function gtest ; set -gx TESTSUITE gtest ; end
if test -z "$TESTSUITE" ; cluster
else ; set -gx TESTSUITE $TESTSUITE ; end

function maintainerOn ; set -gx MAINTAINER On ; end
function maintainerOff ; set -gx MAINTAINER Off ; end
if test -z "$MAINTAINER" ; maintainerOn
else ; set -gx MAINTAINER $MAINTAINER ; end

function sanOn ; set -gx SAN On ; end
function sanOff ; set -gx SAN Off ; end
if test -z "$SAN" ; sanOff
else ; set -gx SAN $SAN ; end

function sanModeAULSan ; set -gx SAN_MODE AULSan ; end
function sanModeTSan ; set -gx SAN_MODE TSan ; end
if test -z "$SAN_MODE" ; sanModeAULSan
else ; set -gx SAN_MODE $SAN_MODE ; end

function jemallocOn; set -gx JEMALLOC_OSKAR On ; end
function jemallocOff; set -gx JEMALLOC_OSKAR Off ; end
if test -z "$JEMALLOC_OSKAR" ; jemallocOn
else ; set -gx JEMALLOC_OSKAR $JEMALLOC_OSKAR ; end

function debugMode ; set -gx BUILDMODE Debug ; end
function releaseMode ; set -gx BUILDMODE RelWithDebInfo ; end
if test -z "$BUILDMODE" ; releaseMode
else ; set -gx BUILDMODE $BUILDMODE ; end

function makeOff ; set -gx SKIP_MAKE On  ; end
function makeOn  ; set -gx SKIP_MAKE Off ; end
makeOn

set -xg GCR_REG_PREFIX "gcr.io/gcr-for-testing/"
function gcrRegOff ; set -gx GCR_REG "Off"  ; end
function gcrRegOn  ; set -gx GCR_REG "On"   ; end
gcrRegOn

function packageStripNone          ; set -gx PACKAGE_STRIP None    ; end
function packageStripExceptArangod ; set -gx PACKAGE_STRIP ExceptArangod ; end
function packageStripAll           ; set -gx PACKAGE_STRIP All     ; end
packageStripAll

function forceDisableAVXOn ; set -gx FORCE_DISABLE_AVX On  ; end
function forceDisableAVXOff ; set -gx FORCE_DISABLE_AVX Off ; end
if test -z "$FORCE_DISABLE_AVX" ; forceDisableAVXOff
else ; set -gx FORCE_DISABLE_AVX $FORCE_DISABLE_AVX ; end

function findMinimalDebugInfo
  set -l f "$WORKDIR/work/ArangoDB/VERSIONS"
  set -l MINIMAL_DEBUG_INFO "Off"

  test -f $f
  and begin
    set -l v (fgrep MINIMAL_DEBUG_INFO $f | awk '{print $2}' | tr -d '"' | tr -d "'")

    if test "$v" = "On"
      set MINIMAL_DEBUG_INFO On
    end
  end

  echo $MINIMAL_DEBUG_INFO
end

function minimalDebugInfoOn  ; set -gx MINIMAL_DEBUG_INFO On  ; end
function minimalDebugInfoOff ; set -gx MINIMAL_DEBUG_INFO Off ; end

if test -z "$MINIMAL_DEBUG_INFO"
  set -gx MINIMAL_DEBUG_INFO (findMinimalDebugInfo)
end

function defaultArchitecture
  if test (count $argv) -lt 1
    set -gx DEFAULT_ARCHITECTURE "westmere"
  else
    set -gx DEFAULT_ARCHITECTURE $argv[1]
  end

  return 0
end

function findDefaultArchitecture
  set -l f "$WORKDIR/work/ArangoDB/VERSIONS"
  set -l v ""

  test -f $f
  and begin
    set v (fgrep DEFAULT_ARCHITECTURE $f | awk '{print $2}' | tr -d '"' | tr -d "'")
  end

  defaultArchitecture $v
end

test -z "$DEFAULT_ARCHITECTURE"; and findDefaultArchitecture

function findUseARM
  set -l f "$WORKDIR/work/ArangoDB/VERSIONS"

  test -f $f
  or begin
    #echo "Cannot find $f; make sure source is checked out"
    set -gx USE_ARM "Off"
    return 0
  end

  set -l v (fgrep USE_ARM $f | awk '{print $2}' | tr -d '"' | tr -d "'")

  if test "$v" != "On"
    #echo "$f: no USE_ARM specified, using false"
    set -gx USE_ARM "Off"
  else
    #echo "Using ARM '$v' from '$f'"
    set -gx USE_ARM "$v"
  end

  return 0
end

if test -z "$USE_ARM" ; findUseARM ; end

function isGCE
  switch (hostname)
    case 'gce-*'
      set -gx IS_GCE "true"
    case '*'
      set -gx IS_GCE "false"
  end
end

if test -z "$IS_GCE" ; isGCE
else ; set -gx IS_GCE "false" ; end

function defineSccacheGCE
  if test -z "$SCCACHE_GCS_BUCKET"
    set -gx SCCACHE_GCS_BUCKET "arangodbbuildcache"
  end
  # No S3 for GCE atm
  set -gx SCCACHE_BUCKET ""
  # No redis servers for GCE atm
  set -gx SCCACHE_REDIS ""
  # No memcached servers for GCE atm
  set -gx SCCACHE_MEMCACHED ""
end

function ccacheOn
  set -gx USE_CCACHE On
end

function sccacheOn
  set -gx USE_CCACHE sccache
  if test $IS_GCE = "true"
    defineSccacheGCE
  end
end

function ccacheOff ; set -gx USE_CCACHE Off ; end

if test -z "$USE_CCACHE"
  if test $IS_GCE = "false"
    ccacheOn
  else
    sccacheOn
  end 
else if test $USE_CCACHE = "sccache" -a $IS_GCE = "true"
    defineSccacheGCE
else
  set -gx USE_CCACHE $USE_CCACHE
end

function coverageOn ; set -gx COVERAGE On ; debugMode ; end
function coverageOff ; set -gx COVERAGE Off ; end
if test -z "$COVERAGE" ; coverageOff
else ; set -gx COVERAGE $COVERAGE ; end

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

function buildSeppOn ; set -gx BUILD_SEPP On ; end
function buildSeppOff ; set -gx BUILD_SEPP Off ; end
if test -z "$BUILD_SEPP" ; buildSeppOff
else ; set -gx BUILD_SEPP $BUILD_SEPP ; end

function showDetails ; set -gx SHOW_DETAILS On ; end
function hideDetails ; set -gx SHOW_DETAILS Off ; end
function pingDetails ; set -gx SHOW_DETAILS Ping ; end

if test -z "$PROMTOOL_PATH" ; set -gx PROMTOOL_PATH "/usr/bin/"
else ; set -gx PROMTOOL_PATH $PROMTOOL_PATH ; end

if test -z "$SHOW_DETAILS"
  if isatty 1
    showDetails
  else
    hideDetails
  end
else
  set -gx SHOW_DETAILS $SHOW_DETAILS
end

function ubiDockerImage ; set -gx DOCKER_DISTRO ubi ; end
function alpineDockerImage ; set -gx DOCKER_DISTRO "" ; end
alpineDockerImage

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

function githubMirror   ; set -gx GITHUB_MIRROR $argv[1] ; end
function noGithubMirror ; set -e  GITHUB_MIRROR ; end

function setAllLogsToWorkspace ; set -gx WORKSPACE_LOGS "all" ; end
function setOnlyFailLogsToWorkspace ; set -gx WORKSPACE_LOGS "fail"; end
if test -z "$WORKSPACE_LOGS"; setOnlyFailLogsToWorkspace
else ; set -gx WORKSPACE_LOGS $WORKSPACE_LOGS ; end

function addLogLevel ; set -gx LOG_LEVELS $LOG_LEVELS $argv ; end
function clearLogLevel ; set -ge LOG_LEVEL ; end

function notarizeApp ; set -gx NOTARIZE_APP On ; end
function noNotarizeAppp ; set -gx NOTARIZE_APP Off ; end
if test -z "$NOTARIZE_APP"; noNotarizeAppp
else ; set -gx NOTARIZE_APP $NOTARIZE_APP ; end

function strictOpenSSL; set -gx USE_STRICT_OPENSSL On ; end
function nonStrictOpenSSL ; set -gx USE_STRICT_OPENSSL Off ; end
if test -z "$USE_STRICT_OPENSSL"; and test "$IS_JENKINS" = "true"
  strictOpenSSL
else; set -gx USE_STRICT_OPENSSL $USE_STRICT_OPENSSL; end

# main code between function definitions
# WORDIR IS pwd -  at least check if ./scripts and something
# else is available before proceeding
set -gx WORKDIR (pwd)
if test ! -d scripts ; echo "cannot find scripts directory" ; exit 1 ; end
if test ! -d work ; mkdir work ; end

if test -z "$ARANGODB_DOCS_BRANCH" ; set -gx ARANGODB_DOCS_BRANCH "main"
else ; set -gx ARANGODB_DOCS_BRANCH $ARANGODB_DOCS_BRANCH ; end

function findRcloneVersion
  set -l f "$WORKDIR/work/ArangoDB/VERSIONS"
  set -xg RCLONE_VERSION "1.59.0"

  test -f $f
  and begin
    set -l v (fgrep RCLONE_VERSION $f | awk '{print $2}' | tr -d '"' | tr -d "'")

    if test "$v" != ""
      set -xg RCLONE_VERSION "$v"
    end

    setupSourceInfo "Rclone" "$RCLONE_VERSION"
  end
end

function findUseRclone
  set -l f "$WORKDIR/work/ArangoDB/VERSIONS"

  test -f $f
  or begin
    #echo "Cannot find $f; make sure source is checked out"
    set -gx USE_RCLONE "false"
    return 1
  end

  set -l v (fgrep USE_RCLONE $f | awk '{print $2}' | tr -d '"' | tr -d "'")

  if test "$v" = ""
    #echo "$f: no USE_RCLONE specified, using false"
    set -gx USE_RCLONE "false"
  else
    #echo "Using rclone '$v' from '$f'"
    set -gx USE_RCLONE "$v"
  end
end

if test -z "$USE_RCLONE" ; findUseRclone ; end

function copyRclone
  findUseRclone

  if test "$USE_RCLONE" = "false"
    echo "Not copying rclone since it's not used!"
    return
  end

  set -l os "$argv[1]"

  if test -z "$os"
    echo "need operating system as first argument"
    return 1
  end

  set -l arch ""

  switch "$ARCH"
    case "x86_64"
      set arch "amd64"
    case '*'
      if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
        set arch "arm64"
      else
        echo "fatal, unknown architecture $ARCH for rclone"
        exit 1
      end
  end

  findRcloneVersion

  echo Copying rclone from rclone/v$RCLONE_VERSION/rclone-arangodb-$os-$arch to $WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb ...
  mkdir -p $WORKDIR/work/$THIRDPARTY_SBIN
  cp -L $WORKDIR/rclone/v$RCLONE_VERSION/rclone-arangodb-$os-$arch $WORKDIR/work/$THIRDPARTY_SBIN/rclone-arangodb
end

function defaultBuildRepoInfo
  set -gx BUILD_REPO_INFO "default"
end

function releaseBuildRepoInfo
  set -gx BUILD_REPO_INFO "release" 
end

function nightlyBuildRepoInfo
  set -gx BUILD_REPO_INFO "nightly"
end

if test -z "$BUILD_REPO_INFO"
  defaultBuildRepoInfo
else
  set -gx BUILD_REPO_INFO "$BUILD_REPO_INFO"
end

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

function oskarCompile
  showConfig
  showRepository
  set -x NOSTRIP 1
  
  if test "$SAN" = "On"
    buildArangoDB -DUSE_FAILURE_TESTS=On ; or return $status
  else
    buildStaticArangoDB -DUSE_FAILURE_TESTS=On ; or return $status
  end
end

function rlogCompile
  showConfig
  showRepository
  set -x NOSTRIP 1

  buildStaticArangoDB \
    -DUSE_FAILURE_TESTS=On \
    -DUSE_SEPARATE_REPLICATION2_TESTS_BINARY=On \
    ; or return $status
end

function oskar1
  oskarCompile
  and oskar
end

function oskar1Full
  oskarCompile
  and oskarFull
end

function oskar2
  set -l testsuite $TESTSUITE

  oskarCompile
  and begin
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status
  end

  set -xg TESTSUITE $testsuite
end

function oskar4
  set -l testsuite $TESTSUITE ; set -l storageengine $STORAGEENGINE

  oskarCompile
  and begin

  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status
  cluster ; rocksdb
  end

  set -xg TESTSUITE $testsuite ; set -xg STORAGEENGINE $storageengine
end

function oskar8
  set -l testsuite $TESTSUITE ; set -l storageengine $STORAGEENGINE ; set -l enterpriseedition $ENTERPRISEEDITION

  enterprise
  and oskarCompile
  and begin
 
  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status
  end
  and community
  and oskarCompile
  and begin

  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status
  end

  set -xg TESTSUITE $testsuite ; set -xg STORAGEENGINE $storageengine ; set -l ENTERPRISEEDITION $enterpriseedition
  
end

## #############################################################################
## set release version variables in CMakeLists.txt
## #############################################################################

function setNightlyRelease
  checkoutIfNeeded
  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"
  sed -i$suffix -E "s/set\(ARANGODB_VERSION_RELEASE_TYPE .*/set(ARANGODB_VERSION_RELEASE_TYPE \"nightly\")/" $WORKDIR/work/ArangoDB/CMakeLists.txt
  sed -i$suffix -E "s/set\(ARANGODB_VERSION_RELEASE_NUMBER .*/set(ARANGODB_VERSION_RELEASE_NUMBER \""(date +%Y%m%d)"\")/" $WORKDIR/work/ArangoDB/CMakeLists.txt
  findArangoDBVersion
  and set -l ARANGODB_FULL_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
  and if test -n "$ARANGODB_VERSION_RELEASE_TYPE"; set ARANGODB_FULL_VERSION "$ARANGODB_FULL_VERSION-$ARANGODB_VERSION_RELEASE_TYPE"; end
  and if test -n "$ARANGODB_VERSION_RELEASE_NUMBER"; set ARANGODB_FULL_VERSION "$ARANGODB_FULL_VERSION.$ARANGODB_VERSION_RELEASE_NUMBER"; end
  and echo "$ARANGODB_FULL_VERSION" > $WORKDIR/work/ArangoDB/ARANGO-VERSION
  and test (find $WORKDIR/work -name 'sourceInfo.*' | wc -l) -gt 0
  and setupSourceInfo "VERSION" "$ARANGODB_FULL_VERSION"
  and nightlyBuildRepoInfo
end

## #############################################################################
## release
## #############################################################################

function makeRelease
  makeEnterpriseRelease
  and makeCommunityRelease
end

function makeCommunityRelease
  if test (count $argv) -lt 2
    findArangoDBVersion ; or return 1
  else
    set -xg ARANGODB_VERSION "$argv[1]"
    set -xg ARANGODB_PACKAGE_REVISION "$argv[2]"
    set -xg ARANGODB_FULL_VERSION "$argv[1]-$argv[2]"
  end

  test (findMinimalDebugInfo) = "On"
  and begin
    packageStripExceptArangod
    minimalDebugInfoOn
  end
  or begin
    packageStripAll
    minimalDebugInfoOff
  end
  echo ""
  buildCommunityPackage
end

function makeEnterpriseRelease
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

  test (findMinimalDebugInfo) = "On"
  and begin
    packageStripExceptArangod
    minimalDebugInfoOn
  end
  or begin
    packageStripAll
    minimalDebugInfoOff
  end
  echo ""
  buildEnterprisePackage
end

function makeJsSha1Sum
  if test (count $argv) -lt 1
    set jsdir $WORKDIR/work/ArangoDB/build/install/usr/share/arangodb3/js
  else
    set jsdir $argv[1]
  end

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
  and rm -rf enterprise mini-chaos
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
## PREPARE binaries
## #############################################################################

function prepareInstall
  set -l path "$argv[1]"

  if test -z "$path" -o ! -d "$path"
    echo "need valid path as first argument"
    return 1
  end

  pushd $path
  and if test $PACKAGE_STRIP = All
    strip usr/bin/{arangobench,arangodump,arangoexport,arangoimport,arangorestore,arangosh,arangovpack}
    if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10; and test $PLATFORM = "darwin"; or test $PLATFORM = "linux"
      strip usr/sbin/arangod
    end
  else if test $PACKAGE_STRIP = ExceptArangod
    strip usr/bin/{arangobench,arangodump,arangoexport,arangoimport,arangorestore,arangosh,arangovpack}
  end
  and if test "$ENTERPRISEEDITION" != "On"
    rm -f "bin/arangosync" "usr/bin/arangosync" "usr/sbin/arangosync"
    rm -f "bin/arangobackup" "usr/bin/arangobackup" "usr/sbin/arangobackup"
  else
    if test -f usr/bin/arangobackup -a $PACKAGE_STRIP != None
      strip usr/bin/arangobackup
      if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -ge 11; and test $PLATFORM = "darwin"
        rm -f "bin/arangosync" "usr/bin/arangosync" "usr/sbin/arangosync"
      end
    end
  end
  set s $status

  popd
  and return $s
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

  set -l arch ""

  if test "$USE_ARM" = "On"
    switch "$ARCH"
      case "x86_64"
        set arch "_$ARCH"
      case '*'
        if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
          set arch "_arm64"
        else
          echo "fatal, unknown architecture $ARCH for TGZ"
          exit 1
        end
    end
  end

  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"

  pushd $WORKDIR/work
  and rm -rf targz
  and mkdir targz
  and cd $WORKDIR/work/ArangoDB/build/install
  and cp -a * $WORKDIR/work/targz
  and cd $WORKDIR/work/targz
  and rm -rf bin
  and cp -a $WORKDIR/binForTarGz bin
  and find bin "(" -name "*.bak" -o -name "*~" ")" -delete
  and cp bin/README.$os.server ./README
  and sed -i$suffix -E "s/@ARANGODB_PACKAGE_NAME@/$name-$os-$v$arch/g" README
  and if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -ge 12
        if test "$PLATFORM" = "linux"
          sed -i$suffix -E '/^Active Failover/,/^\Cluster/{{/^\Cluster$/!d}}' README
        else if test "$PLATFORM" = "darwin"
          sed -i$suffix -E '/^Active Failover/,/^\Cluster/{{/^\Cluster$/!d;};}' README
        end
      end
  and rm -rf ./README.bak
  and prepareInstall $WORKDIR/work/targz
  and rm -rf "$WORKDIR/work/$name-$v$arch"
  and cp -a $WORKDIR/work/targz "$WORKDIR/work/$name-$v$arch"
  and cd $WORKDIR/work
  or begin ; popd ; return 1 ; end


  if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10; and test "$PLATFORM" = "darwin"; or test "$PLATFORM" = "linux"
    rm -rf "$name-$os-$v$arch"
    and cp -a "$name-$v$arch" "$name-$os-$v$arch"
    and tar czvf "$WORKDIR/work/$name-$os-$v$arch.tar.gz" --exclude "etc" --exclude "bin/README*" --exclude "var" "$name-$os-$v$arch"
    and rm -rf "$name-$os-$v$arch"
  else
    rm -rf "$name-$os-$v$arch" "$WORKDIR/work/$name-$os-$v$arch.tar.gz"
  end
  set s $status

  if test "$s" -eq 0
    rm -rf "$name-client-$os-$v$arch"
    and cp -a "$name-$v$arch" "$name-client-$os-$v$arch"
    and cp "$name-client-$os-$v$arch/bin/README.$os.client" "$name-client-$os-$v$arch/README"
    and sed -i$suffix -E "s/@ARANGODB_PACKAGE_NAME@/$name-client-$os-$v$arch/g" "$name-client-$os-$v$arch/README"
    and rm -rf "$name-client-$os-$v$arch/README.bak"
    and tar czvf "$WORKDIR/work/$name-client-$os-$v$arch.tar.gz" \
      --exclude "bin/README*" \
      --exclude "etc" \
      --exclude "var" \
      --exclude "*.initd" \
      --exclude "*.services" \
      --exclude "*.logrotate" \
      --exclude "arangodb.8" \
      --exclude "arangod.8" \
      --exclude "arango-dfdb.8" \
      --exclude "rcarangod.8" \
      --exclude "$name-client-$os-$v$arch/sbin" \
      --exclude "$name-client-$os-$v$arch/bin/arangod" \
      --exclude "$name-client-$os-$v$arch/bin/arangodb" \
      --exclude "$name-client-$os-$v$arch/bin/arangosync" \
      --exclude "$name-client-$os-$v$arch/usr/sbin" \
      --exclude "$name-client-$os-$v$arch/usr/bin/arangodb" \
      --exclude "$name-client-$os-$v$arch/usr/bin/arangosync" \
      --exclude "$name-client-$os-$v$arch/usr/share/arangodb3/arangodb-update-db" \
      --exclude "$name-client-$os-$v$arch/usr/share/arangodb3/js/server" \
      "$name-client-$os-$v$arch"
    and rm -rf "$name-client-$os-$v$arch"
    set s $status
  end

  popd
  and return $s
  or begin ; popd ; return 1 ; end
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

  set archSnippets "X86"
  if test "$USE_ARM" = "On"
    set archSnippets "X86" "ARM"
  end

  community
  and buildSourceSnippet $IN $OUT

  for edition in "community" "enterprise"
    eval "$edition"
    and buildDockerSnippet $OUT
    and for arch in $archSnippets
          switch "$arch"
            case "X86"
              buildDebianSnippet $IN $OUT "amd64" "x86_64"
              and buildRPMSnippet $IN $OUT "x86_64" "x86_64"
              and buildTarGzSnippet $IN $OUT "x86_64"
              and buildBundleSnippet $IN $OUT "x86_64"
              and buildWindowsSnippet $IN $OUT "win64"
            case "ARM"
              buildDebianSnippet $IN $OUT "arm64" "arm64"
              and buildRPMSnippet $IN $OUT "aarch64" "arm64"
              and buildTarGzSnippet $IN $OUT "arm64"
              and buildBundleSnippet $IN $OUT "arm64"
          end
        end
  end

  set -l SNIPPETS "$OUT/release/snippets"

  begin
    echo '{'

    if test -f "$SNIPPETS/meta-source.json"
      echo '"source":'
      cat "$SNIPPETS/meta-source.json"
      echo ','
    end

    for edition in "community" "enterprise"
      if test -f "$SNIPPETS/meta-docker-$edition.json"
	echo '"docker-'$edition'":'
	cat "$SNIPPETS/meta-docker-$edition.json"
	echo ','
      end

      and if test -f "$SNIPPETS/meta-k8s-$edition.json"
	echo '"k8s-'$edition'":'
	cat "$SNIPPETS/meta-k8s-$edition.json"
	echo ','
      end

      and for arch in x86_64 amd64 arm64 aarch64 win64
        for type in bundle debian rpm windows
          if test -f "$SNIPPETS/meta-$type-$edition-$arch.json"
            echo '"'$type'-'$edition'-'$arch'":'
            cat "$SNIPPETS/meta-$type-$edition-$arch.json"
            echo ','
	  end
	end
      end
    end

   echo '"serial": "'(date +%s)'"'
   echo '}'
  end | jq . > "$SNIPPETS/meta.json"
end

## #############################################################################
## source snippets
## #############################################################################

function buildSourceSnippet
  set -l SOURCE_TAR_GZ "ArangoDB-$ARANGODB_VERSION.tar.gz"
  set -l SOURCE_TAR_BZ2 "ArangoDB-$ARANGODB_VERSION.tar.bz2"
  set -l SOURCE_ZIP "ArangoDB-$ARANGODB_VERSION.zip"

  set -l SOURCE_TAG "$ARANGODB_VERSION"
  if string match -qr '^[0-9]+$' "$ARANGODB_VERSION_RELEASE_TYPE"
    set SOURCE_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH.$ARANGODB_VERSION_RELEASE_TYPE"
  end

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
  set -l m "$OUT/meta-source.json"

  sed -e "s|@SOURCE_TAG@|$SOURCE_TAG|g" \
      -e "s|@SOURCE_TAR_GZ@|$SOURCE_TAR_GZ|g" \
      -e "s|@SOURCE_SIZE_TAR_GZ@|$SOURCE_SIZE_TAR_GZ|g" \
      -e "s|@SOURCE_SHA256_TAR_GZ@|$SOURCE_SHA256_TAR_GZ|g" \
      -e "s|@SOURCE_TAR_BZ2@|$SOURCE_TAR_BZ2|g" \
      -e "s|@SOURCE_SIZE_TAR_BZ2@|$SOURCE_SIZE_TAR_BZ2|g" \
      -e "s|@SOURCE_SHA256_TAR_BZ2@|$SOURCE_SHA256_TAR_BZ2|g" \
      -e "s|@SOURCE_ZIP@|$SOURCE_ZIP|g" \
      -e "s|@SOURCE_SIZE_ZIP@|$SOURCE_SIZE_ZIP|g" \
      -e "s|@SOURCE_SHA256_ZIP@|$SOURCE_SHA256_ZIP|g" \
      -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
      -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
      -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
      -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/source.html.in > $n

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-source.json.in
      sed -e "s|@SOURCE_TAG@|$SOURCE_TAG|g" \
	  -e "s|@SOURCE_TAR_GZ@|$SOURCE_TAR_GZ|g" \
	  -e "s|@SOURCE_SIZE_TAR_GZ@|$SOURCE_SIZE_TAR_GZ|g" \
	  -e "s|@SOURCE_SHA256_TAR_GZ@|$SOURCE_SHA256_TAR_GZ|g" \
	  -e "s|@SOURCE_TAR_BZ2@|$SOURCE_TAR_BZ2|g" \
	  -e "s|@SOURCE_SIZE_TAR_BZ2@|$SOURCE_SIZE_TAR_BZ2|g" \
	  -e "s|@SOURCE_SHA256_TAR_BZ2@|$SOURCE_SHA256_TAR_BZ2|g" \
	  -e "s|@SOURCE_ZIP@|$SOURCE_ZIP|g" \
	  -e "s|@SOURCE_SIZE_ZIP@|$SOURCE_SIZE_ZIP|g" \
	  -e "s|@SOURCE_SHA256_ZIP@|$SOURCE_SHA256_ZIP|g" \
	  -e "s|@ARANGODB_PACKAGES@|$ARANGODB_PACKAGES|g" \
	  -e "s|@ARANGODB_DOWNLOAD_WARNING@|$ARANGODB_DOWNLOAD_WARNING|g" \
	  -e "s|@ARANGODB_VERSION@|$ARANGODB_VERSION|g" \
	  -e "s|@ARANGODB_VERSION_RELEASE_NUMBER@|$ARANGODB_VERSION_RELEASE_NUMBER|g" \
	  < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-source.json.in > $m
  end

  and echo "Source Snippet: $n"
end

## #############################################################################
## debian snippets
## #############################################################################

function buildDebianSnippet
  set snippetArch "-$argv[3]"
  set -l arch "$argv[3]"
  set packageArch $argv[3]
  set tarGzSuffix "_$argv[4]"

  if test "$USE_ARM" = "Off"
    set snippetArch ""
    set tarGzSuffix ""
  end

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"
    set META_EDITION "enterprise"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set META_EDITION "community"
    set DOWNLOAD_LINK ""
  end

  set -l DEBIAN_VERSION "$ARANGODB_DEBIAN_UPSTREAM""-$ARANGODB_DEBIAN_REVISION"
  set -l DEBIAN_NAME_CLIENT "$ARANGODB_PKG_NAME""-client_$DEBIAN_VERSION""_$packageArch.deb"
  set -l DEBIAN_NAME_SERVER "$ARANGODB_PKG_NAME""_$DEBIAN_VERSION""_$packageArch.deb"
  set -l DEBIAN_NAME_DEBUG_SYMBOLS "$ARANGODB_PKG_NAME-dbg_$DEBIAN_VERSION""_$packageArch.deb"

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

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-linux-$ARANGODB_TGZ_UPSTREAM$tarGzSuffix.tar.gz"

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM$tarGzSuffix.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-debian$snippetArch.html"
  set -l m "$OUT/meta-debian-$META_EDITION-$arch.json"

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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/debian$snippetArch.html.in > $n

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-debian.json.in
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
	  < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-debian.json.in > $m
  end

  and echo "Debian Snippet: $n"
end

## #############################################################################
## RPM snippets
## #############################################################################

function buildRPMSnippet
  set snippetArch "-$argv[3]"
  set -l arch "$argv[3]"
  set packageArch $argv[3]
  set tarGzSuffix "_$argv[4]"

  if test "$USE_ARM" = "Off"
    set snippetArch ""
    set tarGzSuffix ""
  end

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"
    set META_EDITION "enterprise"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set META_EDITION "community"
    set DOWNLOAD_LINK ""
  end

  set -l RPM_VERSION "$ARANGODB_RPM_UPSTREAM-$ARANGODB_RPM_REVISION"
  set -l RPM_NAME_CLIENT "$ARANGODB_PKG_NAME-client-$RPM_VERSION.$packageArch.rpm"
  set -l RPM_NAME_SERVER "$ARANGODB_PKG_NAME-$RPM_VERSION.$packageArch.rpm"
  set -l RPM_NAME_DEBUG_SYMBOLS "$ARANGODB_PKG_NAME-debuginfo-$RPM_VERSION.$packageArch.rpm"

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

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-linux-$ARANGODB_TGZ_UPSTREAM$tarGzSuffix.tar.gz"

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM$tarGzSuffix.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-rpm$snippetArch.html"
  set -l m "$OUT/meta-rpm-$META_EDITION-$arch.json"

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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/rpm$snippetArch.html.in > $n

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-rpm.json.in
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
	  < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-rpm.json.in > $m
  end

  and echo "RPM Snippet: $n"

  and set -l n "$OUT/download-$ARANGODB_PKG_NAME-suse$snippetArch.html"

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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/suse$snippetArch.html.in > $n

  and echo "SUSE Snippet: $n"
end

## #############################################################################
## TAR snippets
## #############################################################################

function buildTarGzSnippet
  set snippetArch "-$argv[3]"
  set -l arch "$argv[3]"
  set tarGzSuffix "_$argv[3]"

  if test "$USE_ARM" = "Off"
    set snippetArch ""
    set tarGzSuffix ""
  end

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"
    set META_EDITION "enterprise"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set META_EDITION "community"
    set DOWNLOAD_LINK ""
  end

  set -l TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-linux-$ARANGODB_VERSION$tarGzSuffix.tar.gz"

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/Linux/
  set -l OUT $argv[2]/release/snippets

  if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

  set -l TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER) / 1024 / 1024)
  set -l TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-linux-$ARANGODB_TGZ_UPSTREAM$tarGzSuffix.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-linux$snippetArch.html"
  set -l m "$OUT/meta-tgz-$META_EDITION-$arch.json"

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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/linux$snippetArch.html.in > $n

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-tgz.json.in
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
	  < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-tgz.json.in > $m
  end

  and echo "TarGZ Snippet: $n"
end

## #############################################################################
## bundle snippets
## #############################################################################

function buildBundleSnippet
  set snippetArch "-$argv[3]"
  set -l arch "$argv[3]"
  set packageArch $argv[3]
  set tarGzSuffix "_$argv[3]"

  if test "$USE_ARM" = "Off"
    set snippetArch ""
    set tarGzSuffix ""
  end

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_PKG_NAME "arangodb3e"
    set META_EDITION "enterprise"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_PKG_NAME "arangodb3"
    set META_EDITION "community"
    set DOWNLOAD_LINK ""
  end

  set -l IN $argv[1]/$ARANGODB_PACKAGES/packages/$ARANGODB_EDITION/MacOSX/
  set -l OUT $argv[2]/release/snippets

  set -l BUNDLE_NAME_SERVER ""
  set -l BUNDLE_SIZE_SERVER ""
  set -l BUNDLE_SHA256_SERVER ""
  set -l TARGZ_NAME_SERVER ""
  set -l TARGZ_SIZE_SERVER ""
  set -l TARGZ_SHA256_SERVER ""

  if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 10
    set BUNDLE_NAME_SERVER "$ARANGODB_PKG_NAME-$ARANGODB_DARWIN_UPSTREAM.$packageArch.dmg"
    if test ! -f "$IN/$BUNDLE_NAME_SERVER"; echo "DMG package '$BUNDLE_NAME_SERVER' is missing"; return 1; end

    set BUNDLE_SIZE_SERVER (expr (wc -c < $IN/$BUNDLE_NAME_SERVER | tr -d " ") / 1024 / 1024)
    set BUNDLE_SHA256_SERVER (shasum -a 256 -b < $IN/$BUNDLE_NAME_SERVER | awk '{print $1}')

    set TARGZ_NAME_SERVER "$ARANGODB_PKG_NAME-macos-$ARANGODB_VERSION$tarGzSuffix.tar.gz"

    if test ! -f "$IN/$TARGZ_NAME_SERVER"; echo "TAR.GZ '$TARGZ_NAME_SERVER' is missing"; return 1; end

    set TARGZ_SIZE_SERVER (expr (wc -c < $IN/$TARGZ_NAME_SERVER | tr -d " ") / 1024 / 1024)
    set TARGZ_SHA256_SERVER (shasum -a 256 -b < $IN/$TARGZ_NAME_SERVER | awk '{print $1}')
  end

  set -l TARGZ_NAME_CLIENT "$ARANGODB_PKG_NAME-client-macos-$ARANGODB_TGZ_UPSTREAM$tarGzSuffix.tar.gz"
  set -l TARGZ_SIZE_CLIENT ""
  set -l TARGZ_SHA256_CLIENT ""

  if test -f "$IN/$TARGZ_NAME_CLIENT"
    set TARGZ_SIZE_CLIENT (expr (wc -c < $IN/$TARGZ_NAME_CLIENT) / 1024 / 1024)
    set TARGZ_SHA256_CLIENT (shasum -a 256 -b < $IN/$TARGZ_NAME_CLIENT | awk '{print $1}')
  end

  set -l n "$OUT/download-$ARANGODB_PKG_NAME-macosx$snippetArch.html"
  set -l m "$OUT/meta-bundle-$META_EDITION-$arch.json"

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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/macosx$snippetArch.html.in > $n

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-bundle.json.in
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
          < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-bundle.json.in > $m
  end

  and echo "MacOSX Bundle Snippet: $n"
end

## #############################################################################
## windows snippets
## #############################################################################

function buildWindowsSnippet
  set snippetArch "-$argv[3]"
  set -l arch "$argv[3]"
  set packageArch $argv[3]

  if test "$USE_ARM" = "Off"
    set snippetArch ""
  end

  if test "$ENTERPRISEEDITION" = "On"
    set ARANGODB_EDITION "Enterprise"
    set ARANGODB_EDITION_LC "enterprise"
    set ARANGODB_PKG_NAME "ArangoDB3e"
    set META_EDITION "enterprise"

    if test -z "$ENTERPRISE_DOWNLOAD_KEY"
      set DOWNLOAD_LINK "/enterprise-download"
    else
      set DOWNLOAD_LINK "/$ENTERPRISE_DOWNLOAD_KEY"
    end
  else
    set ARANGODB_EDITION "Community"
    set ARANGODB_EDITION_LC "community"
    set ARANGODB_PKG_NAME "ArangoDB3"
    set META_EDITION "community"
    set DOWNLOAD_LINK ""
  end

  set -l WINDOWS_NAME_SERVER_EXE "$ARANGODB_PKG_NAME-$ARANGODB_VERSION""_$packageArch.exe"
  set -l WINDOWS_NAME_SERVER_ZIP "$ARANGODB_PKG_NAME-$ARANGODB_VERSION""_$packageArch.zip"
  set -l WINDOWS_NAME_CLIENT_EXE "$ARANGODB_PKG_NAME-client-$ARANGODB_VERSION""_$packageArch.exe"

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

  set -l n "$OUT/download-windows$snippetArch-$ARANGODB_EDITION_LC.html"
  set -l m "$OUT/meta-windows-$META_EDITION-$arch.json"

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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/windows$snippetArch.html.in > $n

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-windows.json.in
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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-windows.json.in > $m
  end

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
  set -l m "$OUT/meta-docker-$edition.json"

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

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-docker.json.in
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
      < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-docker.json.in > $m
  end

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
  set -l m "$OUT/meta-k8s-$edition.json"

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

  and if test -f $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-k8s.json.in
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
	  < $WORKDIR/snippets/$ARANGODB_SNIPPETS/meta-k8s.json.in > $m
  end

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

  set -l openssl_version "["(findOpenSSLVersion)"]"

  if test -z "$OPENSSL_VERSION"
    findRequiredOpenSSL > /dev/null 2>&1
    set openssl_version "["(findOpenSSLVersion)"]"
  end

  echo '------------------------------------------------------------------------------'
  echo 'Build Configuration'
  printf $fmt3 'Sanitizer'  $SAN                    '(sanOn/Off)'
  printf $fmt3 'San mode'   $SAN_MODE               '(sanModeAULSan/TSan)'
  printf $fmt3 'Coverage'   $COVERAGE               '(coverageOn/Off)'
  printf $fmt3 'Buildmode'  $BUILDMODE              '(debugMode/releaseMode)'
  printf $fmt3 'Compiler'   $compiler_version       '(compiler x.y.z)'
  printf $fmt3 'OpenSSL'    $openssl_version        '(opensslVersion x.y.z)'
  printf $fmt3 'CPU'        $DEFAULT_ARCHITECTURE   '(defaultArchitecture cpuname)'
  printf $fmt3 'Use ARM'    $USE_ARM                '(ARM true or false)'
  printf $fmt3 'Use rclone' $USE_RCLONE             '(rclone true or false)'
  printf $fmt3 'Enterprise' $ENTERPRISEEDITION      '(community/enterprise)'
  printf $fmt3 'Jemalloc'   $JEMALLOC_OSKAR         '(jemallocOn/jemallocOff)'
  printf $fmt3 'Maintainer' $MAINTAINER             '(maintainerOn/Off)'
  printf $fmt3 'Build sepp' $BUILD_SEPP             '(buildSeppOn/buildSeppOff)'

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
  printf $fmt3 'Test suite'     $TESTSUITE     '(single/cluster/single_cluster/resilience/gtest)'
  printf $fmt2 'Log Levels'     (echo $LOG_LEVELS)
  echo
  echo 'Package Configuration'
  printf $fmt3 'Stable/preview'     $RELEASE_TYPE       '(stable/preview)'
  printf $fmt3 'Docker Distro'      $DOCKER_DISTRO      '(alpineDockerImage/ubiDockerImage)'
  printf $fmt3 'Use GCR Registry'   $GCR_REG            '(gcrRegOn/gcrRegOff)'
  printf $fmt3 'Strip Packages'     $PACKAGE_STRIP      '(packageStripAll/ExceptArangod/None)'
  printf $fmt3 'Minimal Debug Info' $MINIMAL_DEBUG_INFO '(minimalDebugInfoOn/Off)'
  echo
  echo 'Internal Configuration'
  printf $fmt3 'Parallelism'   $PARALLELISM   '(parallelism nnn)'
  printf $fmt3 'Skip MAKE'     $SKIP_MAKE     '(makeOn/Off)'
  printf $fmt3 'Github Mirror' "$GITHUB_MIRROR" '(githubMirror)'
  printf $fmt3 'CCACHE'        $USE_CCACHE    '(ccacheOn/Off/sccacheOn)'
  if test "$CCACHE_MAXSIZE" != ""
  printf $fmt3 'CCACHE size'   $CCACHE_MAXSIZE          '(CCACHE_MAXSIZE)'
  end
  if test "$USE_CCACHE" = "sccache"
    if test "$SCCACHE_BUCKET" != ""
      printf $fmt3 'S3 Bucket' $SCCACHE_BUCKET      '(SCCACHE_BUCKET)'
      printf $fmt3 'S3 Server' $SCCACHE_ENDPOINT    '(SCCACHE_ENDPOINT)'
    end
  end
  printf $fmt3 'Verbose Build' $VERBOSEBUILD          '(verboseBuild/silentBuild)'
  printf $fmt3 'Verbose Oskar' $VERBOSEOSKAR          '(verbose/slient)'
  printf $fmt3 'Details during build' $SHOW_DETAILS   '(showDetails/hideDetails/pingDetails)'
  printf $fmt3 'Logs preserve' $WORKSPACE_LOGS        '(setAllLogsToWorkspace/setOnlyFailLogsToWorkspace)'
  printf $fmt3 'Notarize'      $NOTARIZE_APP          '(notarizeApp/noNotarizedApp)'
  printf $fmt3 'Strict OpenSSL' "$USE_STRICT_OPENSSL" '(strictOpenSSL/nonStrictOpenSSL)'
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
    if test -d $WORKDIR/work/ArangoDB/mini-chaos
      pushd mini-chaos
      printf $fmt3 'Mini Chaos' (findBranch)
      popd
    else
      printf $fmt3 'Mini Chaos' 'missing'
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

      set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH.$ARANGODB_VERSION_RELEASE_TYPE"
    end
  end

  if test -n "$DOCKER_DISTRO"
    set -xg DOCKER_TAG "$DOCKER_TAG-$DOCKER_DISTRO"
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
  echo "ARANGODB_RPM_UPSTREAM/REVISION:    $ARANGODB_RPM_UPSTREAM / $ARANGODB_RPM_REVISION"
  echo "ARANGODB_SNIPPETS:                 $ARANGODB_SNIPPETS"
  echo "ARANGODB_TGZ_UPSTREAM:             $ARANGODB_TGZ_UPSTREAM"
  echo "DOCKER_TAG:                        $DOCKER_TAG"
  echo '------------------------------------------------------------------------------'
  echo
end

## #############################################################################
## CHECK USELESS MACROS
## #############################################################################

function checkMacros
  checkoutIfNeeded
  and pushd $WORKDIR/work/ArangoDB
  or begin popd; return 1; end

  set -l wrong (find lib arangod arangosh client-tools enterprise tests -name "*.cpp" -o -name "*.h" \
  | xargs grep -P -n '# *ifdef +(WIN32|(TRI_ENABLE_|ARANGODB_USE_|USE_)MAINTAINER_MODE)') 

  set -l s 0

  if test "$wrong" != ""
    echo -e "Wrong macros:\n$wrong"
    set s 1
  else
    echo "Wrong macros: NONE"
  end

  popd
  return $s
end

## #############################################################################
## CHECK DUPLICATE LOG ID
## #############################################################################

function checkLogId
  checkoutIfNeeded
  and pushd $WORKDIR/work/ArangoDB
  or begin popd; return 1; end

  python3 utils/checkLogIds.py
  set -l s $status

  popd
  return $s
end

## #############################################################################
## CHECK METRICS
## #############################################################################

function checkMetrics
  checkoutIfNeeded
  and pushd $WORKDIR/work/ArangoDB
  or begin popd; return 1; end

  set -l s 0

  if test -f ./utils/generateAllMetricsDocumentation.py
    rm -rf ./Documentation/Metrics/allMetrics.yaml
    and ./utils/generateAllMetricsDocumentation.py
    or set s 1
  end

  if test $s = 0
    echo "Wrong metrics: NONE"
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
  and find . -maxdepth 1 -name '*.rpm' -o -name '*.deb' -o -name '*.dmg' -o -name '*.tar.gz' -o -name '*.zip' | xargs rm -f
  or begin ; popd ; return 1 ; end
  popd
end

function cleanWorkspace
  if test -d $WORKDIR/work
    pushd $WORKDIR/work
    and find . -maxdepth 1 '!' "(" -name ArangoDB -o -name . -o -name .. -o -name ".cc*" -o -name "sourceInfo.*" ")" -exec rm -rf "{}" ";"
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

      echo "mv test.log"
      mv $WORKDIR/work/test.log $WORKSPACE

      if test -f $WORKDIR/work/testProtocol.txt
        echo "mv testProtocol.txt"
        mv $WORKDIR/work/testProtocol.txt $WORKSPACE/protocol.log
      end
    end

    for x in buildArangoDB.log cmakeArangoDB.log sourceInfo.log sourceInfo.json
      echo "mv $x"
      if test -f $WORKDIR/work/$x ; mv $WORKDIR/work/$x $WORKSPACE ; end
    end

    for x in cppcheck.xml
      if test -f $WORKDIR/work/ArangoDB/$x
        echo "mv $x"
        mv $WORKDIR/work/ArangoDB/$x $WORKSPACE
      end
    end

    if test -d $WORKDIR/work/coverage
      if test -d $WORKSPACE/coverage
        rm -rf $WORKSPACE/coverage.old
        mv $WORKSPACE/coverage $WORKSPACE/coverage.old
      end

      echo "mv coverage"
      mv $WORKDIR/work/coverage $WORKSPACE
    end

    set -l matches $WORKDIR/work/*.{asc,testfailures.txt,deb,dmg,rpm,7z,tar.gz,tar.bz2,zip,html,csv,tar}
    for f in $matches
      echo $f | grep -qv testreport ; and echo "mv $f $WORKSPACE" ; and mv $f $WORKSPACE; or echo "skipping $f"
    end

    for f in $WORKDIR/work/*san.log.* ; echo "mv $f" ; mv $f $WORKSPACE/(basename $f).log ; end

    if test -f $WORKDIR/work/testfailures.txt
      if grep -q -v '^[ \t]*$' $WORKDIR/work/testfailures.txt
        echo "mv $WORKDIR/work/testfailures.txt" ; mv $WORKDIR/work/testfailures.txt $WORKSPACE
      end
    end

    if test -d $WORKDIR/work/Documentation
      echo "mv Documentation"
      mv $WORKDIR/work/Documentation $WORKSPACE/Documentation.generated
    end

    if test -f $WORKDIR/work/testRuns.txt
      echo "mv $WORKDIR/work/testRuns.txt"
      mv $WORKDIR/work/testRuns.txt $WORKSPACE
    end

    if test -d $WORKDIR/work/ArangoDB/testrunXml
      echo "mv JUnit XMLs ($WORKDIR/work/ArangoDB/testrunXml)"
      mv $WORKDIR/work/ArangoDB/testrunXml $WORKSPACE/testrunXml
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

source $WORKDIR/scripts/lib/buildSanFlags.fish

initSourceInfo

if isatty 1
  showHelp
end
