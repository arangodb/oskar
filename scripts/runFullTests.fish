#!/usr/bin/env fish
set -g SCRIPTS (dirname (status -f))
source $SCRIPTS/lib/tests.fish

################################################################################
## Single tests: runtime,command
################################################################################

set -l ST
set ST "$ST""1000,runSingleTest1 'upgrade_data_3.2.*' -\n"
set ST "$ST""1000,runSingleTest1 'upgrade_data_3.3.*' -\n"
set ST "$ST""1000,runSingleTest1 'upgrade_data_3.4.*' -\n"
set ST "$ST""1000,runSingleTest2 replication_static -\n"
set ST "$ST""1000,runSingleTest2 replication_ongoing_32 -\n"
set ST "$ST""1000,runSingleTest2 replication_ongoing_frompresent_32 -\n"
set ST "$ST""1000,runSingleTest2 replication_ongoing_frompresent -\n"
set ST "$ST""1000,runSingleTest2 replication_ongoing_global_spec -\n"
set ST "$ST""1000,runSingleTest2 replication_ongoing_global -\n"
set ST "$ST""1000,runSingleTest2 replication_ongoing -\n"
set ST "$ST""1000,runSingleTest2 replication_aql -\n"
set ST "$ST""1000,runSingleTest2 replication_fuzz -\n"
set ST "$ST""1000,runSingleTest2 replication_random - \n"
set ST "$ST""1000,runSingleTest2 replication_sync -\n"
hasLDAPHOST; and set ST "$ST""2000,runSingleTest1 ldaprole - --ldapHost $LDAPHOST\n"
hasLDAPHOST; and set ST "$ST""2000,runSingleTest1 ldaprolesimple - --ldapHost $LDAPHOST\n"
hasLDAPHOST; and set ST "$ST""2000,runSingleTest1 ldapsearch - --ldapHost $LDAPHOST\n"
hasLDAPHOST; and set ST "$ST""2000,runSingleTest1 ldapsearchsimple - --ldapHost $LDAPHOST\n"
set ST "$ST""2000,runSingleTest1 recovery 0 --testBuckets 4/0\n"
set ST "$ST""2000,runSingleTest1 recovery 1 --testBuckets 4/1\n"
set ST "$ST""2000,runSingleTest1 recovery 2 --testBuckets 4/2\n"
set ST "$ST""2000,runSingleTest1 recovery 3 --testBuckets 4/3\n"
set ST "$ST""250,runSingleTest1 shell_server_aql 0 --testBuckets 6/0\n"
set ST "$ST""750,runSingleTest1 shell_server_aql 1 --testBuckets 6/1\n"
set ST "$ST""500,runSingleTest1 shell_server_aql 2 --testBuckets 6/2\n"
set ST "$ST""250,runSingleTest1 shell_server_aql 3 --testBuckets 6/3\n"
set ST "$ST""250,runSingleTest1 shell_server_aql 4 --testBuckets 6/4\n"
set ST "$ST""250,runSingleTest1 shell_server_aql 5 --testBuckets 6/5\n"
set ST "$ST""250,runSingleTest1 server_http -\n"
set ST "$ST""250,runSingleTest1 ssl_server 0 --testBuckets 2/0\n"
set ST "$ST""250,runSingleTest1 ssl_server 1 --testBuckets 2/1\n"
set ST "$ST""750,runSingleTest1 shell_client -\n"
set ST "$ST""500,runSingleTest1 shell_client_aql -\n"
set ST "$ST""250,runSingleTest1 shell_replication -\n"
set ST "$ST""1000,runSingleTest1 shell_server -\n"
set ST "$ST""250,runSingleTest1 BackupAuthNoSysTests -\n"
set ST "$ST""250,runSingleTest1 BackupAuthSysTests -\n"
set ST "$ST""250,runSingleTest1 BackupNoAuthNoSysTests -\n"
set ST "$ST""250,runSingleTest1 BackupNoAuthSysTests -\n"
set ST "$ST""250,runSingleTest1 active_failover -\n"
set ST "$ST""250,runSingleTest1 agency -\n"
set ST "$ST""250,runSingleTest1 arangobench  -\n"
set ST "$ST""250,runSingleTest1 arangosh -\n"
set ST "$ST""250,runSingleTest1 audit -\n"
set ST "$ST""1000,runSingleTest1 authentication -\n"
set ST "$ST""1000,runSingleTest1 authentication_parameters -\n"
set ST "$ST""1000,runSingleTest1 authentication_server -\n"
set ST "$ST""1000,runSingleTest1 catch -\n"
set ST "$ST""1000,runSingleTest1 config -\n"
set ST "$ST""1000,runSingleTest1 dfdb -\n"
set ST "$ST""250,runSingleTest1 dump -\n"
set ST "$ST""250,runSingleTest1 dump_authentication -\n"
set ST "$ST""250,runSingleTest1 dump_encrypted -\n"
set ST "$ST""250,runSingleTest1 dump_maskings -\n"
set ST "$ST""250,runSingleTest1 dump_multiple -\n"
set ST "$ST""250,runSingleTest1 endpoints - --skipEndpointsIpv6 true\n"
set ST "$ST""250,runSingleTest1 export -\n"
set ST "$ST""500,runSingleTest1 foxx_manager -\n"
set ST "$ST""500,runSingleTest1 http_replication -\n"
set ST "$ST""500,runSingleTest1 http_server 0 --testBuckets 2/0-\n"
set ST "$ST""500,runSingleTest1 http_server 1 --testBuckets 2/1-\n"
set ST "$ST""500,runSingleTest1 importing -\n"
set ST "$ST""500,runSingleTest1 queryCacheAuthorization -\n"
set ST "$ST""500,runSingleTest1 readOnly -\n"
set ST "$ST""500,runSingleTest1 upgrade -\n"
set ST "$ST""250,runSingleTest1 version -\n"
set ST "$ST""500,runSingleTest1 audit_client -\n"
set ST "$ST""500,runSingleTest1 audit_server -\n"
set ST "$ST""500,runSingleTest1 permissions -\n"
set ST "$ST""500,runSingleTest1 permissions_server -\n"
set ST "$ST""500,runSingleTest1 paths_server -\n"

set -g STS (echo -e $ST | fgrep , | sort -rn | awk -F, '{print $2}')
set -g STL (count $STS)

function launchSingleTests
  set -g launchCount (math $launchCount + 1)

  if test $launchCount -gt $STL
    return 0
  end

  set -l test $STS[$launchCount]

  if test -n "$TEST"
    if echo $test | fgrep -q "$TEST"
      echo "Running test '$test' (contains '$TEST')"
    else
      echo "Skipping test '$test' (does not contain '$TEST')"
      return 1
    end
  end

  eval $test
  return 1
end

################################################################################
## Catch tests
################################################################################

function launchCatchTest
  switch $launchCount
    case  0 ; runCatchTest1 catch -
    case '*' ; return 0
  end
  set -g launchCount (math $launchCount + 1)
  return 1
end

################################################################################
## Cluster tests: runtime,command
################################################################################

set -l CT
set CT "$CT""500,runClusterTest1 load_balancing -\n"
set CT "$CT""500,runClusterTest1 load_balancing_auth -\n"
set CT "$CT""600,runClusterTest1 resilience_move -\n"
set CT "$CT""750,runClusterTest1 resilience_move_view -\n"
set CT "$CT""500,runClusterTest1 resilience_repair -\n"
set CT "$CT""750,runClusterTest1 resilience_failover -\n"
set CT "$CT""500,runClusterTest1 resilience_failover_failure -\n"
set CT "$CT""500,runClusterTest1 resilience_failover_view -\n"
set CT "$CT""500,runClusterTest1 resilience_transactions -\n"
set CT "$CT""250,runClusterTest1 resilience_sharddist -\n"
set CT "$CT""500,runClusterTest1 shell_server 0 --testBuckets 5/0\n"
set CT "$CT""1000,runClusterTest1 shell_server 1 --testBuckets 5/1\n"
set CT "$CT""500,runClusterTest1 shell_server 2 --testBuckets 5/2\n"
set CT "$CT""500,runClusterTest1 shell_server 3 --testBuckets 5/3\n"
set CT "$CT""500,runClusterTest1 shell_server 4 --testBuckets 5/4\n"
set CT "$CT""500,runClusterTest1 shell_client 0 --testBuckets 5/0\n"
set CT "$CT""500,runClusterTest1 shell_client 1 --testBuckets 5/1\n"
set CT "$CT""500,runClusterTest1 shell_client 2 --testBuckets 5/2\n"
set CT "$CT""500,runClusterTest1 shell_client 3 --testBuckets 5/3\n"
set CT "$CT""250,runClusterTest1 shell_client 4 --testBuckets 5/4\n"
set CT "$CT""2000,runClusterTest1 shell_server_aql 0 --testBuckets 16/0\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 1 --testBuckets 16/1\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 2 --testBuckets 16/2\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 3 --testBuckets 16/3\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 4 --testBuckets 16/4\n"
set CT "$CT""2000,runClusterTest1 shell_server_aql 5 --testBuckets 16/5\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 6 --testBuckets 16/6\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 7 --testBuckets 16/7\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 8 --testBuckets 16/8\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 9 --testBuckets 16/9\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 10 --testBuckets 16/10\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 11 --testBuckets 16/11\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 12 --testBuckets 16/12\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 13 --testBuckets 16/13\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 14 --testBuckets 16/14\n"
set CT "$CT""1500,runClusterTest1 shell_server_aql 15 --testBuckets 16/15\n"
set CT "$CT""2500,runClusterTest1 shell_client_aql -\n"
set CT "$CT""500,runClusterTest1 authentication 0 --testBuckets 3/0\n"
set CT "$CT""500,runClusterTest1 authentication 1 --testBuckets 3/1\n"
set CT "$CT""500,runClusterTest1 authentication 2 --testBuckets 3/2\n"
set CT "$CT""750,runClusterTest1 http_server -\n"
set CT "$CT""1000,runClusterTest1 ssl_server -\n"
set CT "$CT""500,runClusterTest1 server_http -\n"
set CT "$CT""250,runClusterTest1 dump -\n"
set CT "$CT""500,runClusterTest1 client_resilience -\n"
set CT "$CT""50,runClusterTest1 agency -\n"
set CT "$CT""50,runClusterTest1 dump_authentication -\n"
set CT "$CT""250,runClusterTest1 dump_maskings -\n"
set CT "$CT""250,runClusterTest1 dump_multiple -\n"

set -g CTS (echo -e $CT | fgrep , | sort -rn | awk -F, '{print $2}')
set -g CTL (count $CTS)

function launchClusterTests
  set -g launchCount (math $launchCount + 1)

  if test $launchCount -gt $CTL
    return 0
  end

  eval $CTS[$launchCount]
  return 1
end

################################################################################
## main
################################################################################

# Switch off jemalloc background threads for the tests since this seems
# to overload our systems and is not needed.
set -x MALLOC_CONF background_thread:false

setupTmp
cd $INNERWORKDIR/ArangoDB

if test "$ASAN" = "On"
  ulimit -c 0
end

switch $TESTSUITE
  case "cluster"
    resetLaunch 4
    and if test "$ASAN" = "On"
      waitOrKill 43200 launchClusterTests
    else
      waitOrKill 10800 launchClusterTests
    end
    createReport
  case "single"
    resetLaunch 1
    and if test "$ASAN" = "On"
      waitOrKill 28800 launchSingleTests
    else
      waitOrKill 7200 launchSingleTests
    end
    createReport
  case "catchtest"
    resetLaunch 1
    and if test "$ASAN" = "On"
      waitOrKill 14400 launchCatchTest
    else
      waitOrKill 1800 launchCatchTest
    end
    createReport
  case "resilience"
    resetLaunch 4
    and if test "$ASAN" = "On"
      waitOrKill 43200 launchResilienceTests
    else
      waitOrKill 10800 launchResilienceTests
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
