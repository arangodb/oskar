#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

function launchSingleTests
  switch $launchCount
    case  0 ; runSingleTest2 replication_static ""
    case  1 ; runSingleTest1 shell_server ""
    case  2 ; runSingleTest2 replication_ongoing_32 ""
    case  3 ; runSingleTest2 replication_ongoing_frompresent_32 ""
    case  4 ; runSingleTest2 replication_ongoing_frompresent ""
    case  5 ; runSingleTest2 replication_ongoing_global_spec ""
    case  6 ; runSingleTest2 replication_ongoing_global ""
    case  7 ; runSingleTest2 replication_ongoing ""
    case  8 ; runSingleTest2 replication_sync ""
    case  9 ; runSingleTest1 recovery 0 --testBuckets 4/0
    case 10 ; runSingleTest1 recovery 1 --testBuckets 4/1
    case 11 ; runSingleTest1 recovery 2 --testBuckets 4/2
    case 12 ; runSingleTest1 recovery 3 --testBuckets 4/3
    case 13 ; runSingleTest1 shell_server_aql 0 --testBuckets 5/0
    case 14 ; runSingleTest1 shell_server_aql 1 --testBuckets 5/1
    case 15 ; runSingleTest1 shell_server_aql 2 --testBuckets 5/2
    case 16 ; runSingleTest1 shell_server_aql 3 --testBuckets 5/3
    case 17 ; runSingleTest1 shell_server_aql 4 --testBuckets 5/4
    case 18 ; runSingleTest1 server_http ""
    case 19 ; runSingleTest1 shell_client ""
    case 20 ; runSingleTest1 shell_client_aql ""
    case 21 ; runSingleTest1 shell_replication ""
    case 22 ; runSingleTest1 BackupAuthNoSysTests ""
    case 23 ; runSingleTest1 BackupAuthSysTests ""
    case 24 ; runSingleTest1 BackupNoAuthNoSysTests ""
    case 25 ; runSingleTest1 BackupNoAuthSysTests ""
    case 26 ; runSingleTest1 agency ""
    case 27 ; runSingleTest1 authentication ""
    case 28 ; runSingleTest1 catch ""
    case 29 ; runSingleTest1 dump ""
    case 30 ; runSingleTest1 dump_authentication ""
    case 31 ; runSingleTest1 dump_maskings ""
    case 32 ; runSingleTest1 dump_multiple ""
    case 33 ; runSingleTest1 endpoints "" --skipEndpointsIpv6 true
    case 34 ; runSingleTest1 http_replication ""
    case 35 ; runSingleTest1 http_server ""
    case 36 ; runSingleTest1 ssl_server ""
    case 37 ; runSingleTest1 version ""
    case 38 ; runSingleTest1 active_failover ""
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

function launchCatchTest
  switch $launchCount
    case  0 ; runCatchTest1 catch ""
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
    case  7 ; test1 resilience_move ""
    case  8 ; test1 resilience_failover ""
    case  9 ; test1 resilience_sharddist ""
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

# Switch off jemalloc background threads for the tests since this seems
# to overload our systems and is not needed.
set -x MALLOC_CONF background_thread:false

setupTmp
cd $INNERWORKDIR/ArangoDB

switch $TESTSUITE
  case "cluster"
    resetLaunch 4
    and if test "$ASAN" = "On"
      waitOrKill 3600 launchClusterTests
    else
      waitOrKill 3600 launchClusterTests
    end
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
    and if test "$ASAN" = "On"
      waitOrKill 1800 launchCatchTest
    else
      waitOrKill 1800 launchCatchTest
    end
    createReport
  case "resilience"
    resetLaunch 4
    and if test "$ASAN" = "On"
      waitOrKill 3600 launchResilienceTests
    else
      waitOrKill 3600 launchResilienceTests
    end
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
