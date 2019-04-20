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
  switch $launchCount
    case  0 ; runClusterTest1 agency ""
    case  1 ; runClusterTest1 shell_server ""
    case  2 ; runClusterTest1 dump ""
    case  3 ; runClusterTest1 dump_authentication ""
    case  4 ; runClusterTest1 dump_maskings ""
    case  5 ; runClusterTest1 dump_multiple ""
    case  6 ; runClusterTest1 http_server ""
    case  7 ; runClusterTest1 resilience_move ""
    case  8 ; runClusterTest1 resilience_failover ""
    case  9 ; runClusterTest1 resilience_sharddist ""
    case 10 ; runClusterTest1 shell_client ""
    case 11 ; runClusterTest1 shell_client_aql ""
    case 12 ; runClusterTest1 shell_server_aql 1 --testBuckets 5/1
    case 13 ; runClusterTest1 shell_server_aql 2 --testBuckets 5/2
    case 14 ; runClusterTest1 shell_server_aql 3 --testBuckets 5/3
    case 15 ; runClusterTest1 shell_server_aql 4 --testBuckets 5/4
    case 16 ; runClusterTest1 server_http ""
    case 17 ; runClusterTest1 shell_server_aql 0 --testBuckets 5/0
    case 18 ; runClusterTest1 ssl_server ""
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
