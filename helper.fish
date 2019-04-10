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

function skipGrey ; set -gx SKIPGREY true ; end
function includeGrey ; set -gx SKIPGREY false ; end
if test -z "$SKIPGREY"; includeGrey
else ; set -gx SKIPGREY $SKIPGREY ; end

function stable ; set -gx RELEASE_TYPE stable ; end
function preview ; set -gx RELEASE_TYPE preview ; end
if test -z "$RELEASE_TYPE"; preview
else ; set -gx RELEASE_TYPE $RELEASE_TYPE ; end

function keepBuild ; set -gx NO_RM_BUILD 1 ; end
function clearBuild ; set -gx NO_RM_BUILD ; end

# main code between function definitions
# WORDIR IS pwd -  at least check if ./scripts and something
# else is available before proceeding
set -gx WORKDIR (pwd)
if test ! -d scripts ; echo "cannot find scripts directory" ; exit 1 ; end
if test ! -d work ; mkdir work ; end

## #############################################################################
## test
## #############################################################################

function oskar1
  showConfig
  showRepository
  set -x NOSTRIP 1
  buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  oskar
end

function oskar1Full
  showConfig
  showRepository
  set -x NOSTRIP 1
  buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status
  oskarFull
end

function oskar2
  set -l testsuite $TESTSUITE
  set -x NOSTRIP 1

  showConfig
  showRepository
  buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status

  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  set -xg TESTSUITE $testsuite
end

function oskar4
  set -l testsuite $TESTSUITE ; set -l storageengine $STORAGEENGINE
  set -x NOSTRIP 1

  showConfig
  showRepository
  buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status

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
  buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status

  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  community
  buildStaticArangoDB -DUSE_FAILURE_TESTS=On -DDEBUG_SYNC_REPLICATION=On ; or return $status

  rocksdb
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  mmfiles
  cluster ; oskar ; or return $status
  single ; oskar ; or return $status

  set -xg TESTSUITE $testsuite ; set -xg STORAGEENGINE $storageengine ; set -l ENTERPRISEEDITION $enterpriseedition
end

## #############################################################################
## release
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
  and buildSourceSnippet $SOURCE_TAG
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

function buildSourceSnippet
  if test (count $argv) -lt 1
    echo "Need source tag as parameter"
    exit 1
  end

  transformSourceSnippet $argv[1]
  or return 1
end

function transformSourceSnippet
  pushd $WORKDIR
  
  set -l SOURCE_TAR_GZ "ArangoDB-$argv[1].tar.gz"
  set -l SOURCE_TAR_BZ2 "ArangoDB-$argv[1].tar.bz2"
  set -l SOURCE_ZIP "ArangoDB-$argv[1].zip"

  if test ! -f "work/$SOURCE_TAR_GZ"; echo "Source package '$SOURCE_TAR_GZ' is missing"; return 1; end
  if test ! -f "work/$SOURCE_TAR_BZ2"; echo "Source package '$SOURCE_TAR_BZ2"' is missing"; return 1; end
  if test ! -f "work/$SOURCE_ZIP"; echo "Source package '$SOURCE_ZIP"' is missing"; return 1; end

  set -l SOURCE_SIZE_TAR_GZ (expr (wc -c < work/$SOURCE_TAR_GZ) / 1024 / 1024)
  set -l SOURCE_SIZE_TAR_BZ2 (expr (wc -c < work/$SOURCE_TAR_BZ2) / 1024 / 1024)
  set -l SOURCE_SIZE_ZIP (expr (wc -c < work/$SOURCE_ZIP) / 1024 / 1024)

  set -l SOURCE_SHA256_TAR_GZ (shasum -a 256 -b < work/$SOURCE_TAR_GZ | awk '{print $1}')
  set -l SOURCE_SHA256_TAR_BZ2 (shasum -a 256 -b < work/$SOURCE_TAR_BZ2 | awk '{print $1}')
  set -l SOURCE_SHA256_ZIP (shasum -a 256 -b < work/$SOURCE_ZIP | awk '{print $1}')

  set -l n "work/download-source.html"

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
      < snippets/$ARANGODB_SNIPPETS/source.html.in > $n

  echo "Source Snippet: $n"
  popd
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
  and set s $status
  and mv "$name-$v" install
  and popd
  and return $s 
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
  printf $fmt3 'SkipGrey'       $SKIPGREY      '(skipGrey/includeGrey)'
  printf $fmt3 'Storage engine' $STORAGEENGINE '(mmfiles/rocksdb)'
  printf $fmt3 'Test suite'     $TESTSUITE     '(single/cluster/resilience/catchtest)'
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
    set -xg ARANGODB_VERSION_PATCH (grep "$AV""_REVISION" $CMAKELIST | sed -e $SEDFIX)
    set -g  ARANGODB_PACKAGE_REVISION (grep "$APR" $CMAKELIST | sed -e $SEDFIX)

    set -xg ARANGODB_VERSION "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"

    set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
    set -xg ARANGODB_DEBIAN_REVISION "$ARANGODB_PACKAGE_REVISION"

    set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
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

      set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-devel"

      set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_DARWIN_REVISION "$ARANGODB_VERSION_RELEASE_TYPE"

      set -xg ARANGODB_DEBIAN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH~~$ARANGODB_VERSION_RELEASE_TYPE"
      set -xg ARANGODB_DEBIAN_REVISION "1"

      set -xg ARANGODB_TGZ_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-$ARANGODB_VERSION_RELEASE_TYPE"

      if test "$ARANGODB_VERSION_RELEASE_TYPE" = "devel"
        set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
        set -xg ARANGODB_RPM_REVISION "0.1"
        set -xg ARANGODB_REPO nightly
        set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-devel"
      else if test "$ARANGODB_VERSION_RELEASE_TYPE" = "nightly"
        set -xg ARANGODB_RPM_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
        set -xg ARANGODB_RPM_REVISION "0.2"
        set -xg ARANGODB_REPO nightly
        set -xg DOCKER_TAG "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH-nightly"
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

      set -xg ARANGODB_DARWIN_UPSTREAM "$ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR.$ARANGODB_VERSION_PATCH"
      set -xg ARANGODB_DARWIN_REVISION "$ARANGODB_VERSION_RELEASE_TYPE.$ARANGODB_VERSION_RELEASE_NUMBER"

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
  echo "ARANGODB_DARWIN_UPDATE/REVISION:   $ARANGODB_DARWIN_UPSTREAM / $ARANGODB_DARWIN_REVISION"
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
      if head -1 $WORKDIR/work/test.log | grep BAD > /dev/null
        for f in $WORKDIR/work/testreport* ; echo "mv $f" ; mv $f $WORKSPACE ; end
      else
       #for f in $WORKDIR/work/testreport* ; echo "mv $f" ; mv $f $WORKSPACE ; end
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

    for f in $WORKDIR/work/*.asc ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.deb ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.dmg ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.rpm ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.tar.gz ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.tar.bz2 ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.zip ; echo "mv $f" ; mv $f $WORKSPACE ; end
    for f in $WORKDIR/work/*.html ; echo "mv $f" ; mv $f $WORKSPACE ; end

    if test -f $WORKDIR/work/testfailures.txt
      if grep -q -v '^[ \t]*$' $WORKDIR/work/testfailures.txt
        echo "mv $WORKDIR/work/testfailures.txt" ; mv $WORKDIR/work/testfailures.txt $WORKSPACE
      end
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
