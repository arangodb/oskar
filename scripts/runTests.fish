#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

set -g repoState ""
set -g repoStateEnterprise ""

if test -z "$PARALLELISM"
  set -g PARALLELISM 64
end

function getRepoState
  set -g repoState (git rev-parse HEAD) (git status -b -s | grep -v "^[?]")
  if test $ENTERPRISEEDITION = On 
    cd enterprise
    set -g repoStateEnterprise (git rev-parse HEAD) (git status -b -s | grep -v "^[?]")
    cd ..
  else
    set -g repoStateEnterprise ""
  end
end

function noteStartAndRepoState
  getRepoState
  rm -f testProtocol.txt
  set -l d (date -u +%F_%H.%M.%SZ)
  echo $d >> testProtocol.txt
  echo "==========\nStatus of main repository:" >> testProtocol.txt
  echo "==========\nStatus of main repository:"
  for l in $repoState ; echo "  $l" >> testProtocol.txt ; echo "  $l" ; end
  if test $ENTERPRISEEDITION = On
    echo "Status of enterprise repository:" >> testProtocol.txt
    echo "Status of enterprise repository:"
    for l in $repoStateEnterprise
      echo "  $l" >> testProtocol.txt ; echo "  $l"
    end
  end
end

function resetLaunch
  noteStartAndRepoState
  set -g launchFactor $argv[1]
  set -g portBase 10000
  set -g launchCount 0
  echo Launching tests...
end

function launchSingleTests
  function jslint
    if test $VERBOSEOSKAR = On ; echo Launching jslint $argv "($launchCount)" ; end
    echo utils/jslint.sh
    utils/jslint.sh > $TMPDIR/jslint.log &
  end

  function test1
    if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end

    set -l t $argv[1]
    set -l tt $argv[2]
    set -e argv[1..2]
    if grep $t UnitTests/OskarTestSuitesBlackList
      echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
    else
      echo scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE --minPort $portBase --maxPort (math $portBase + 99) $argv --skipNondeterministic true --skipTimeCritical true --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY" 
      mkdir -p $TMPDIR/"$t""$tt".out
      date -u +%s > $TMPDIR/"$t""$tt".out/started
      scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE \
        --minPort $portBase --maxPort (math $portBase + 99) $argv \
        --skipNondeterministic true --skipTimeCritical true \
        --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false \
        --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  >"$t""$tt".log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  function test1MoreLogs
    if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end

    set -l t $argv[1]
    set -l tt $argv[2]
    set -e argv[1..2]
    if grep $t UnitTests/OskarTestSuitesBlackList
      echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
    else
      echo scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE --minPort $portBase --maxPort (math $portBase + 99) $argv --skipNondeterministic true --skipTimeCritical true --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false --extraArgs:log.level replication=trace --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY" 
      mkdir -p $TMPDIR/"$t""$tt".out
      date -u +%s > $TMPDIR/"$t""$tt".out/started
      scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE \
        --minPort $portBase --maxPort (math $portBase + 99) $argv \
        --skipNondeterministic true --skipTimeCritical true \
        --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false \
        --extraArgs:log.level replication=trace --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  \
        >"$t""$tt".log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  switch $launchCount
    case  0 ; jslint
    case  1 ; test1MoreLogs replication_static ""
    case  2 ; test1         shell_server ""
    case  3 ; test1MoreLogs replication_ongoing "-32"             --test replication-ongoing-32.js
    case  4 ; test1MoreLogs replication_ongoing "-frompresent-32" --test replication-ongoing-frompresent-32.js
    case  5 ; test1MoreLogs replication_ongoing "-frompresent"    --test replication-ongoing-frompresent.js
    case  6 ; test1MoreLogs replication_ongoing "-global-spec"    --test replication-ongoing-global-spec.js
    case  7 ; test1MoreLogs replication_ongoing "-global"         --test replication-ongoing-global.js
    case  8 ; test1MoreLogs replication_ongoing ""                --test replication-ongoing.js
    case  9 ; test1MoreLogs replication_sync ""
    case 10 ; test1         recovery 0 --testBuckets 4/0
    case 11 ; test1         recovery 1 --testBuckets 4/1
    case 12 ; test1         recovery 2 --testBuckets 4/2
    case 13 ; test1         recovery 3 --testBuckets 4/3
    case 14 ; test1         shell_server_aql 0 --testBuckets 5/0
    case 15 ; test1         shell_server_aql 1 --testBuckets 5/1
    case 16 ; test1         shell_server_aql 2 --testBuckets 5/2
    case 17 ; test1         shell_server_aql 3 --testBuckets 5/3
    case 18 ; test1         shell_server_aql 4 --testBuckets 5/4
    case 19 ; test1         server_http ""
    case 20 ; test1         shell_client ""
    case 21 ; test1         shell_client_aql ""
    case 22 ; test1         shell_replication ""
    case 23 ; test1         BackupAuthNoSysTests ""
    case 24 ; test1         BackupAuthSysTests ""
    case 25 ; test1         BackupNoAuthNoSysTests ""
    case 26 ; test1         BackupNoAuthSysTests ""
    case 27 ; test1         agency ""
    case 28 ; test1         authentication ""
    case 29 ; test1         catch ""
    case 30 ; test1         dump ""
    case 31 ; test1         dump_authentication ""
    case 32 ; test1         dump_maskings ""
    case 33 ; test1         dump_multiple ""
    case 34 ; test1         endpoints "" --skipEndpointsIpv6 true
    case 35 ; test1         http_replication ""
    case 36 ; test1         http_server ""
    case 37 ; test1         ssl_server ""
    case 38 ; test1         version ""
    case 39 ; test1         active_failover ""
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

function launchCatchTest
  function jslint
    if test $VERBOSEOSKAR = On ; echo Launching jslint $argv ; end
    echo utils/jslint.sh
    utils/jslint.sh > $TMPDIR/jslint.log &
  end

  function test1
    if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end

    set -l t $argv[1]
    set -l tt $argv[2]
    set -e argv[1..2]
    if grep $t UnitTests/OskarTestSuitesBlackList
      echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
    else
      echo scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE --minPort $portBase --maxPort (math $portBase + 99) $argv --skipNondeterministic true --skipTimeCritical true --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY" 
      mkdir -p $TMPDIR/"$t""$tt".out
      date -u +%s > $TMPDIR/"$t""$tt".out/started
      scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE \
        --minPort $portBase --maxPort (math $portBase + 99) $argv \
        --skipNondeterministic true --skipTimeCritical true \
        --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false \
        --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  >"$t""$tt".log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  function test1MoreLogs
    if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end

    set -l t $argv[1]
    set -l tt $argv[2]
    set -e argv[1..2]
    if grep $t UnitTests/OskarTestSuitesBlackList
      echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
    else
      echo scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE --minPort $portBase --maxPort (math $portBase + 99) $argv --skipNondeterministic true --skipTimeCritical true --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false --extraArgs:log.level replication=trace --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY" 
      mkdir -p $TMPDIR/"$t""$tt".out
      date -u +%s > $TMPDIR/"$t""$tt".out/started
      scripts/unittest $t --cluster false --storageEngine $STORAGEENGINE \
        --minPort $portBase --maxPort (math $portBase + 99) $argv \
        --skipNondeterministic true --skipTimeCritical true \
        --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false \
        --extraArgs:log.level replication=trace --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  \
        >"$t""$tt".log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  switch $launchCount
    case  0 ; test1         catch ""
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

function launchClusterTests
  function test1
    if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end
    set -l t $argv[1]
    set -l tt $argv[2]
    set -e argv[1..2]
    if grep $t UnitTests/OskarTestSuitesBlackList
      echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
    else
      echo scripts/unittest $t --cluster true --storageEngine $STORAGEENGINE --minPort $portBase --maxPort (math $portBase + 99) $argv --skipNondeterministic true --skipTimeCritical true --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY" 
      mkdir -p $TMPDIR/"$t""$tt".out
      date -u +%s > $TMPDIR/"$t""$tt".out/started
      scripts/unittest $t --cluster true --storageEngine $STORAGEENGINE \
        --minPort $portBase --maxPort (math $portBase + 99) $argv \
        --skipNondeterministic true --skipTimeCritical true \
        --testOutput $TMPDIR/"$t""$tt".out --writeXmlReport false \
        --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  >"$t""$tt".log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  function test3
    if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end
    if grep $argv[1] UnitTests/OskarTestSuitesBlackList
      echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
    else
      echo scripts/unittest $argv[1] --test $argv[3] --storageEngine $STORAGEENGINE --cluster true --minPort $portBase --maxPort (math $portBase + 99) --skipNondeterministic true --testOutput "$TMPDIR/$argv[1]_$argv[2].out" --writeXmlReport false --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY" 
      mkdir -p $TMPDIR/"$t""$tt".out
      date -u +%s > $TMPDIR/"$t""$tt".out/started
      scripts/unittest $argv[1] --test $argv[3] \
        --storageEngine $STORAGEENGINE --cluster true \
        --minPort $portBase --maxPort (math $portBase + 99) \
        --skipNondeterministic true \
        --testOutput "$TMPDIR/$argv[1]_$argv[2].out" --writeXmlReport false \
        --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  >$argv[1]_$argv[2].log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  switch $launchCount
    case  0 ; test1 agency ""
    case  1 ; test1 shell_server ""
    case  2 ; test1 dump ""
    case  3 ; test1 dump_authentication ""
    case  4 ; test1 dump_maskings ""
    case  5 ; test1 dump_multiple ""
    case  6 ; test1 http_server ""
    case  7 ; test3 resilience move moving-shards-cluster.js
    case  8 ; test3 resilience failover resilience-synchronous-repl-cluster.js
    case  9 ; test3 resilience sharddist shard-distribution-spec.js
    case 10 ; test1 shell_client ""
    case 11 ; test1 shell_client_aql ""
    case 12 ; test1 shell_server_aql 1 --testBuckets 5/1
    case 13 ; test1 shell_server_aql 2 --testBuckets 5/2
    case 14 ; test1 shell_server_aql 3 --testBuckets 5/3
    case 15 ; test1 shell_server_aql 4 --testBuckets 5/4
    case 16 ; test1 server_http ""
    case 17 ; test1 shell_server_aql 0 --testBuckets 5/0
    case 18 ; test1 ssl_server ""
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

function waitForProcesses
  set i $argv[1]
  set launcher $argv[2]
  set start (date -u +%s)
  while true
    # Launch if necessary:
    while test (math (count (jobs -p))"*$launchFactor") -lt "$PARALLELISM"
      if test -z "$launcher" ; break ; end
      if eval "$launcher" ; break ; end
    end
    # Check subprocesses:
    if test (count (jobs -p)) -eq 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 1
    end

    echo (date) (count (jobs -p)) jobs still running, remaining $i "seconds..."

    set i (math $i - 5)
    if test $i -lt 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 0
    end

    sleep 5
  end
end

function waitOrKill
  set timeout $argv[1]
  set launcher $argv[2]
  echo Controlling subprocesses...
  if waitForProcesses $timeout $launcher
    set -l ids (jobs -p)
    if test (count $ids) -gt 0
      kill $ids
      if waitForProcesses 30 ""
        set -l ids (jobs -p)
        if test (count $ids) -gt 0
          kill -9 $ids
          waitForProcesses 60 ""   # give jobs some time to finish
        end
      end
    end
  end
  return 0
end

function log
  for l in $argv
    echo $l
    echo $l >> $INNERWORKDIR/test.log
  end
end

cd $INNERWORKDIR
rm -rf tmp
mkdir tmp
set -xg TMPDIR $INNERWORKDIR/tmp
cd $INNERWORKDIR/ArangoDB
for f in *.log ; rm -f $f ; end

# Switch off jemalloc background threads for the tests since this seems
# to overload our systems and is not needed.
set -x MALLOC_CONF background_thread:false

switch $TESTSUITE
  case "cluster"
    resetLaunch 4
    waitOrKill 3600 launchClusterTests
    createReport
  case "single"
    resetLaunch 1
    and if test "$ASAN" = "On"
      waitOrKill 14400 launchSingleTests
    else
      waitOrKill 3600 launchSingleTests
    end
    createReport
  case "catchtest"
    resetLaunch 1
    waitOrKill 1800 launchCatchTest
    createReport
  case "resilience"
    resetLaunch 4
    waitOrKill 3600 launchResilienceTests
    createReport
  case "*"
    echo Unknown test suite $TESTSUITE
    set -g result BAD
end

if test $result = GOOD
  exit 0
else
  exit 1
end
