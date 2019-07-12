Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 3600

    registerTest -testname "replication_static" -weight 2
    registerTest -testname "shell_server"
    registerTest -testname "replication_ongoing_32" -weight 2
    registerTest -testname "replication_ongoing_frompresent_32" -weight 2
    registerTest -testname "replication_ongoing_frompresent" -weight 2
    registerTest -testname "replication_ongoing_global_spec" -weight 2
    registerTest -testname "replication_ongoing_global" -weight 2
    registerTest -testname "replication_ongoing" -weight 2
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
    registerTest -testname "shell_client"
    registerTest -testname "shell_client_aql"
    registerTest -testname "shell_replication" -weight 2
    registerTest -testname "server_permissions"
    registerTest -testname "BackupAuthNoSysTests"
    registerTest -testname "BackupAuthSysTests"
    registerTest -testname "BackupNoAuthNoSysTests"
    registerTest -testname "BackupNoAuthSysTests"
    registerTest -testname "agency" -weight 3
    registerTest -testname "active_failover"
    registerTest -testname "arangosh"
    registerTest -testname "authentication"
    registerTest -testname "catch"
    registerTest -testname "dump"
    registerTest -testname "dump_authentication"
    registerTest -testname "dump_maskings"
    registerTest -testname "dump_multiple"
    registerTest -testname "endpoints"
    registerTest -testname "http_replication" -weight 2
    registerTest -testname "http_server" -sniff true
    registerTest -testname "ssl_server"
    registerTest -testname "version"
    comm
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 3600

    registerTest -cluster $true -testname "agency" -weight 3
    registerTest -cluster $true -testname "shell_server" -weight 5
    registerTest -cluster $true -testname "dump" -weight 5
    registerTest -cluster $true -testname "dump_authentication" -weight 5
    registerTest -cluster $true -testname "dump_maskings" -weight 5
    registerTest -cluster $true -testname "dump_multiple" -weight 5
    registerTest -cluster $true -testname "http_server"  -sniff true -weight 5
    registerTest -cluster $true -testname "server_permissions" -weight 5
    registerTest -cluster $true -testname "resilience_move" -weight 5
    registerTest -cluster $true -testname "resilience_failover" -weight 5
    registerTest -cluster $true -testname "resilience_sharddist" -weight 5
    registerTest -cluster $true -testname "shell_client" -weight 5
    registerTest -cluster $true -testname "shell_server_aql" -index "0" -bucket "5/0" -weight 5
    registerTest -cluster $true -testname "shell_server_aql" -index "1" -bucket "5/1" -weight 5
    registerTest -cluster $true -testname "shell_server_aql" -index "2" -bucket "5/2" -weight 5
    registerTest -cluster $true -testname "shell_server_aql" -index "3" -bucket "5/3" -weight 5
    registerTest -cluster $true -testname "shell_server_aql" -index "4" -bucket "5/4" -weight 5
    registerTest -cluster $true -testname "server_http" -weight 5
    registerTest -cluster $true -testname "ssl_server" -weight 5
    comm
}

runTests
