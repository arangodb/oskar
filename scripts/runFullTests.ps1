Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 7200

    registerTest -testname "upgrade_data_3.2.*"
    registerTest -testname "upgrade_data_3.3.*"
    registerTest -testname "upgrade_data_3.4.*"
    registerTest -testname "replication_static" -weight 2
    registerTest -testname "shell_server"
    registerTest -testname "replication_ongoing_32" -weight 2
    registerTest -testname "replication_ongoing_frompresent_32" -weight 2
    registerTest -testname "replication_ongoing_frompresent" -weight 2
    registerTest -testname "replication_ongoing_global_spec" -weight 2
    registerTest -testname "replication_ongoing_global" -weight 2
    registerTest -testname "replication_ongoing" -weight 2
    registerTest -testname "replication_aql" -weight 2
    registerTest -testname "replication_fuzz" -weight 2
    registerTest -testname "replication_random" -weight 2
    registerTest -testname "replication_sync" -weight 2
    #FIXME: No LDAP tests for Windows at the moment
    #registerTest -testname "ldaprole" -ldapHost arangodbtestldapserver
    #registerTest -testname "ldaprolesimple" -ldapHost arangodbtestldapserver
    #registerTest -testname "ldapsearch" -ldapHost arangodbtestldapserver
    #registerTest -testname "ldapsearchsimple" -ldapHost arangodbtestldapserver
    registerTest -testname "recovery" -index "0" -bucket "4/0"
    registerTest -testname "recovery" -index "1" -bucket "4/1"
    registerTest -testname "recovery" -index "2" -bucket "4/2"
    registerTest -testname "recovery" -index "3" -bucket "4/3"
    registerTest -testname "shell_server_aql" -index "0" -bucket "5/0"
    registerTest -testname "shell_server_aql" -index "1" -bucket "5/1"
    registerTest -testname "shell_server_aql" -index "2" -bucket "5/2"
    registerTest -testname "shell_server_aql" -index "3" -bucket "5/3"
    registerTest -testname "shell_server_aql" -index "4" -bucket "5/4"
    registerTest -testname "server_http"
    registerTest -testname "ssl_server"
    registerTest -testname "shell_client"
    registerTest -testname "shell_client_aql"
    registerTest -testname "shell_replication" -weight 2
    registerTest -testname "BackupAuthNoSysTests"
    registerTest -testname "BackupAuthSysTests"
    registerTest -testname "BackupNoAuthNoSysTests"
    registerTest -testname "BackupNoAuthSysTests"
    registerTest -testname "active_failover"
    registerTest -testname "agency"
    registerTest -testname "arangobench"
    registerTest -testname "arangosh"
    registerTest -testname "audit"
    registerTest -testname "authentication"
    registerTest -testname "authentication_parameters"
    registerTest -testname "authentication_server"
    registerTest -testname "catch"
    registerTest -testname "config"
    registerTest -testname "dfdb"
    registerTest -testname "dump"
    registerTest -testname "dump_authentication"
    registerTest -testname "dump_encrypted"
    registerTest -testname "dump_maskings"
    registerTest -testname "dump_multiple"
    registerTest -testname "endpoints"
    registerTest -testname "export"
    registerTest -testname "foxx_manager"
    registerTest -testname "http_replication" -weight 2
    registerTest -testname "http_server"
    registerTest -testname "importing"
    registerTest -testname "queryCacheAuthorization"
    registerTest -testname "readOnly"
    registerTest -testname "upgrade"
    registerTest -testname "version"
    registerTest -testname "audit_client"
    registerTest -testname "audit_server"
    registerTest -testname "permissions"
    registerTest -testname "permissions_server"
    registerTest -testname "paths_server"    
    comm
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 12600

    registerTest -cluster $true -testname "load_balancing"
    registerTest -cluster $true -testname "load_balancing_auth"
    registerTest -cluster $true -testname "resilience_move"
    registerTest -cluster $true -testname "resilience_move_view"
    registerTest -cluster $true -testname "resilience_repair"
    registerTest -cluster $true -testname "resilience_failover"
    registerTest -cluster $true -testname "resilience_failover_failure"
    registerTest -cluster $true -testname "resilience_failover_view"
    registerTest -cluster $true -testname "resilience_transactions"
    registerTest -cluster $true -testname "resilience_sharddist"
    registerTest -cluster $true -testname "shell_client"
    registerTest -cluster $true -testname "shell_server"
    registerTest -cluster $true -testname "http_server"
    registerTest -cluster $true -testname "ssl_server"
    registerTest -cluster $true -testname "shell_server_aql" -index "0" -bucket "5/0"
    registerTest -cluster $true -testname "shell_server_aql" -index "1" -bucket "5/1"
    registerTest -cluster $true -testname "shell_server_aql" -index "2" -bucket "5/2"
    registerTest -cluster $true -testname "shell_server_aql" -index "3" -bucket "5/3"
    registerTest -cluster $true -testname "shell_server_aql" -index "4" -bucket "5/4"
    registerTest -cluster $true -testname "shell_client_aql"
    registerTest -cluster $true -testname "dump"
    registerTest -cluster $true -testname "dump_maskings"
    registerTest -cluster $true -testname "dump_multiple"
    registerTest -cluster $true -testname "server_http"
    # registerTest -cluster $true -testname "agency"
    comm
}

runTests
