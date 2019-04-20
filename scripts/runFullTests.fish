#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

function launchSingleTests
  switch $launchCount
    case  0 ;                   runSingleTest1 'upgrade_data_3.2.*' ""
    case  1 ;                   runSingleTest1 'upgrade_data_3.3.*' ""
    case  2 ;                   runSingleTest1 'upgrade_data_3.4.*' ""
    case  3 ;                   runSingleTest2 replication_static ""
    case  4 ;                   runSingleTest1 shell_server ""
    case  5 ;                   runSingleTest2 replication_ongoing_32 ""
    case  6 ;                   runSingleTest2 replication_ongoing_frompresent_32 ""
    case  7 ;                   runSingleTest2 replication_ongoing_frompresent ""
    case  8 ;                   runSingleTest2 replication_ongoing_global_spec ""
    case  9 ;                   runSingleTest2 replication_ongoing_global ""
    case 10 ;                   runSingleTest2 replication_ongoing ""
    case 11 ;                   runSingleTest2 replication_aql ""
    case 12 ;                   runSingleTest2 replication_fuzz ""
    case 13 ;                   runSingleTest2 replication_random ""
    case 14 ;                   runSingleTest2 replication_sync ""
    case 15 ; hasLDAPHOST;  and runSingleTest1 ldaprole "" --ldapHost $LDAPHOST
    case 16 ; hasLDAPHOST;  and runSingleTest1 ldaprolesimple "" --ldapHost $LDAPHOST
    case 17 ; hasLDAPHOST;  and runSingleTest1 ldapsearch "" --ldapHost $LDAPHOST
    case 18 ; hasLDAPHOST;  and runSingleTest1 ldapsearchsimple "" --ldapHost $LDAPHOST
    case 19 ;                   runSingleTest1 recovery 0 --testBuckets 4/0
    case 20 ;                   runSingleTest1 recovery 1 --testBuckets 4/1
    case 21 ;                   runSingleTest1 recovery 2 --testBuckets 4/2
    case 22 ;                   runSingleTest1 recovery 3 --testBuckets 4/3
    case 23 ;                   runSingleTest1 shell_server_aql 0 --testBuckets 6/0
    case 24 ;                   runSingleTest1 shell_server_aql 1 --testBuckets 6/1
    case 25 ;                   runSingleTest1 shell_server_aql 2 --testBuckets 6/2
    case 26 ;                   runSingleTest1 shell_server_aql 3 --testBuckets 6/3
    case 27 ;                   runSingleTest1 shell_server_aql 4 --testBuckets 6/4
    case 28 ;                   runSingleTest1 shell_server_aql 5 --testBuckets 6/5
    case 29 ;                   runSingleTest1 server_http ""
    case 30 ;                   runSingleTest1 ssl_server 0 --testBuckets 2/0
    case 31 ;                   runSingleTest1 ssl_server 1 --testBuckets 2/1
    case 32 ;                   runSingleTest1 shell_client ""
    case 33 ;                   runSingleTest1 shell_client_aql ""
    case 34 ;                   runSingleTest1 shell_replication ""
    case 35 ;                   runSingleTest1 BackupAuthNoSysTests ""
    case 36 ;                   runSingleTest1 BackupAuthSysTests ""
    case 37 ;                   runSingleTest1 BackupNoAuthNoSysTests ""
    case 38 ;                   runSingleTest1 BackupNoAuthSysTests ""
    case 39 ;                   runSingleTest1 active_failover ""
    case 40 ;                   runSingleTest1 agency ""
    case 41 ;                   runSingleTest1 arangobench  ""
    case 42 ;                   runSingleTest1 arangosh ""
    case 43 ;                   runSingleTest1 audit ""
    case 44 ;                   runSingleTest1 authentication ""
    case 45 ;                   runSingleTest1 authentication_parameters ""
    case 46 ;                   runSingleTest1 authentication_server ""
    case 47 ;                   runSingleTest1 catch ""
    case 48 ;                   runSingleTest1 config ""
    case 49 ;                   runSingleTest1 dfdb ""
    case 50 ;                   runSingleTest1 dump ""
    case 51 ;                   runSingleTest1 dump_authentication ""
    case 52 ;                   runSingleTest1 dump_encrypted ""
    case 53 ;                   runSingleTest1 dump_maskings ""
    case 54 ;                   runSingleTest1 dump_multiple ""
    case 55 ;                   runSingleTest1 endpoints "" --skipEndpointsIpv6 true
    case 56 ;                   runSingleTest1 export ""
    case 57 ;                   runSingleTest1 foxx_manager ""
    case 58 ;                   runSingleTest1 http_replication ""
    case 59 ;                   runSingleTest1 http_server 0 --testBuckets 2/0
    case 60 ;                   runSingleTest1 http_server 1 --testBuckets 2/1
    case 61 ;                   runSingleTest1 importing ""
    case 62 ;                   runSingleTest1 load_balancing ""
    case 63 ;                   runSingleTest1 load_balancing_auth ""
    case 64 ;                   runSingleTest1 queryCacheAuthorization ""
    case 65 ;                   runSingleTest1 readOnly ""
    case 66 ;                   runSingleTest1 upgrade ""
    case 67 ;                   runSingleTest1 version ""
    case 68 ;                   runSingleTest1 audit_client ""
    case 69 ;                   runSingleTest1 audit_server ""
    case 70 ;                   runSingleTest1 permissions ""
    case 71 ;                   runSingleTest1 permissions_server ""
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

function launchCatchTest
  switch $launchCount
    case  0 ; runCatchTest1         catch ""
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

function launchClusterTests
  switch $launchCount
    case  0 ; runClusterTest3 resilience_move                  moving-shards-cluster-grey.js
    case  1 ; runClusterTest3 resilience_move_view             moving-shards-with-arangosearch-view-cluster-grey.js
    case  2 ; runClusterTest3 resilience_repair                repair-distribute-shards-like-spec.js
    case  3 ; runClusterTest3 resilience_failover              resilience-synchronous-repl-cluster.js
    case  4 ; runClusterTest3 resilience_failover_failure      resilience-synchronous-repl-failureAt-cluster.js
    case  5 ; runClusterTest3 resilience_failover_view         resilience-synchronous-repl-cluster-with-arangosearch-view-cluster.js
    case  6 ; runClusterTest3 resilience_transactions          resilience-transactions.js
    case  7 ; runClusterTest3 resilience_sharddist             shard-distribution-spec.js
    case  8 ; runClusterTest1 shell_server_aql 3 --testBuckets 6/3
    case  9 ; runClusterTest1 shell_client ""
    case 10 ; runClusterTest1 shell_server ""
    case 11 ; runClusterTest1 shell_server_aql 2 --testBuckets 6/2
    case 12 ; runClusterTest1 authentication 0 --testBuckets 3/0
    case 13 ; runClusterTest1 shell_server_aql 0 --testBuckets 6/0
    case 14 ; runClusterTest1 authentication 2 --testBuckets 3/2
    case 15 ; runClusterTest1 shell_server_aql 4 --testBuckets 6/4
    case 16 ; runClusterTest1 shell_server_aql 5 --testBuckets 6/5
    case 17 ; runClusterTest1 http_server ""
    case 18 ; runClusterTest1 ssl_server ""
    case 19 ; runClusterTest1 shell_server_aql 1 --testBuckets 6/1
    case 20 ; runClusterTest1 authentication 1 --testBuckets 3/1
    case 21 ; runClusterTest1 shell_client_aql ""
    case 22 ; runClusterTest1 server_http ""
    case 23 ; runClusterTest1 dump ""
    case 24 ; runClusterTest1 client_resilience ""
    case 25 ; runClusterTest1 agency ""
    case 26 ; runClusterTest1 dump_authentication ""
    case 27 ; runClusterTest1 dump_maskings ""
    case 28 ; runClusterTest1 dump_multiple ""
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
