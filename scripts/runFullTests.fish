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
        --extraArgs:log.level replication=trace \
        --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  >"$t""$tt".log ^&1 &
      set -g portBase (math $portBase + 100)
      sleep 1
    end
  end

  switch $launchCount
    case  0 ; jslint
    case  1 ; test1         'upgrade_data_3.2.*' ""
    case  2 ; test1         'upgrade_data_3.3.*' ""
    case  3 ; test1         'upgrade_data_3.4.*' ""
    case  4 ; test1MoreLogs replication_static ""
    case  5 ; test1         shell_server ""
    case  6 ; test1MoreLogs replication_ongoing_32 ""
    case  7 ; test1MoreLogs replication_ongoing_frompresent_32 ""
    case  8 ; test1MoreLogs replication_ongoing_frompresent ""
    case  9 ; test1MoreLogs replication_ongoing_global_spec ""
    case 10 ; test1MoreLogs replication_ongoing_global ""
    case 11 ; test1MoreLogs replication_ongoing ""
    case 12 ; test1MoreLogs replication_aql ""
    case 13 ; test1MoreLogs replication_fuzz ""
    case 14 ; test1MoreLogs replication_random ""
    case 15 ; test1MoreLogs replication_sync ""
    case 16 ; hasLDAPHOST;  and test1         ldaprole "" --ldapHost $LDAPHOST
    case 17 ; hasLDAPHOST;  and test1         ldaprolesimple "" --ldapHost $LDAPHOST
    case 18 ; hasLDAPHOST;  and test1         ldapsearch "" --ldapHost $LDAPHOST
    case 19 ; hasLDAPHOST;  and test1         ldapsearchsimple "" --ldapHost $LDAPHOST
    case 20 ; test1         recovery 0 --testBuckets 4/0
    case 21 ; test1         recovery 1 --testBuckets 4/1
    case 22 ; test1         recovery 2 --testBuckets 4/2
    case 23 ; test1         recovery 3 --testBuckets 4/3
    case 24 ; test1         shell_server_aql 0 --testBuckets 6/0
    case 25 ; test1         shell_server_aql 1 --testBuckets 6/1
    case 26 ; test1         shell_server_aql 2 --testBuckets 6/2
    case 27 ; test1         shell_server_aql 3 --testBuckets 6/3
    case 28 ; test1         shell_server_aql 4 --testBuckets 6/4
    case 29 ; test1         shell_server_aql 5 --testBuckets 6/5
    case 30 ; test1         server_http ""
    case 31 ; test1         ssl_server 0 --testBuckets 2/0
    case 32 ; test1         ssl_server 1 --testBuckets 2/1
    case 33 ; test1         shell_client ""
    case 34 ; test1         shell_client_aql ""
    case 35 ; test1         shell_replication ""
    case 36 ; test1         BackupAuthNoSysTests ""
    case 37 ; test1         BackupAuthSysTests ""
    case 38 ; test1         BackupNoAuthNoSysTests ""
    case 39 ; test1         BackupNoAuthSysTests ""
    case 40 ; test1         active_failover ""
    case 41 ; test1         agency ""
    case 42 ; test1         arangobench  ""
    case 43 ; test1         arangosh ""
    case 44 ; test1         audit ""
    case 45 ; test1         authentication ""
    case 46 ; test1         authentication_parameters ""
    case 47 ; test1         authentication_server ""
    case 48 ; test1         catch ""
    case 49 ; test1         config ""
    case 50 ; test1         dfdb ""
    case 51 ; test1         dump ""
    case 52 ; test1         dump_authentication ""
    case 53 ; test1         dump_encrypted ""
    case 54 ; test1         dump_maskings ""
    case 55 ; test1         dump_multiple ""
    case 56 ; test1         endpoints "" --skipEndpointsIpv6 true
    case 57 ; test1         export ""
    case 58 ; test1         foxx_manager ""
    case 59 ; test1         http_replication ""
    case 60 ; test1         http_server 0 --testBuckets 2/0
    case 61 ; test1         http_server 1 --testBuckets 2/1
    case 62 ; test1         importing ""
    case 63 ; test1         load_balancing ""
    case 64 ; test1         load_balancing_auth ""
    case 65 ; test1         queryCacheAuthorization ""
    case 66 ; test1         readOnly ""
    case 67 ; test1         upgrade ""
    case 68 ; test1         version ""
    case 69 ; test1         audit_client ""
    case 70 ; test1         audit_server ""
    case 71 ; test1         permissions ""
    case 72 ; test1         permissions_server ""
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
        --extraArgs:log.level replication=trace \
        --skipGrey "$SKIPGREY" --onlyGrey "$ONLYGREY"  >"$t""$tt".log ^&1 &
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
    case  0 ; test3 resilience_move          moving-shards-cluster-grey.js
    case  1 ; test3 resilience_move_view     moving-shards-with-arangosearch-view-cluster-grey.js
    case  2 ; test3 resilience_repair        repair-distribute-shards-like-spec.js
    case  3 ; test3 resilience_failover      resilience-synchronous-repl-cluster.js
    case  4 ; test3 resilience_failover_failure      resilience-synchronous-repl-failureAt-cluster.js
    case  5 ; test3 resilience_failover_view resilience-synchronous-repl-cluster-with-arangosearch-view-cluster.js
    case  6 ; test3 resilience_transactions      resilience-transactions.js
    case  7 ; test3 resilience_sharddist     shard-distribution-spec.js
    case  8 ; test1 shell_server_aql 3 --testBuckets 6/3
    case  9 ; test1 shell_client ""
    case 10 ; test1 shell_server ""
    case 11 ; test1 shell_server_aql 2 --testBuckets 6/2
    case 12 ; test1 authentication 0 --testBuckets 3/0
    case 13 ; test1 shell_server_aql 0 --testBuckets 6/0
    case 14 ; test1 authentication 2 --testBuckets 3/2
    case 15 ; test1 shell_server_aql 4 --testBuckets 6/4
    case 16 ; test1 shell_server_aql 5 --testBuckets 6/5
    case 17 ; test1 http_server ""
    case 18 ; test1 ssl_server ""
    case 19 ; test1 shell_server_aql 1 --testBuckets 6/1
    case 20 ; test1 authentication 1 --testBuckets 3/1
    case 21 ; test1 shell_client_aql ""
    case 22 ; test1 server_http ""
    case 23 ; test1 dump ""
    case 24 ; test1 client_resilience ""
    case 25 ; test1 agency ""
    case 26 ; test1 dump_authentication ""
    case 27 ; test1 dump_maskings ""
    case 28 ; test1 dump_multiple ""
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
    waitOrKill 10800 launchClusterTests
    createReport
  case "single"
    resetLaunch 1
    waitOrKill 7200 launchSingleTests
    createReport
  case "catchtest"
    resetLaunch 1
    waitOrKill 1800 launchCatchTest
    createReport
  case "resilience"
    resetLaunch 4
    waitOrKill 10800 launchResilienceTests
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
