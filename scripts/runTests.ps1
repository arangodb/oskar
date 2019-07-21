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
    registerTest -testname "agency" -weight 2
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
    registerTest -testname "audit_client"
    registerTest -testname "audit_server"
    # Note that we intentionally do not register the hot_backup test here,
    # since it is currently not supported on Windows. The reason is that
    # the testing framework does not support automatic restarts of instances
    # and hot_backup currently needs a server restart on a restore operation
    # on Windows. On Linux and Mac we use an exec operation for this to
    # restart without changing the PID, which is not possible on Windows.
    # registerTest -testname "hot_backup"
    comm
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 3600

    registerTest -cluster $true -testname "agency"
    registerTest -cluster $true -testname "shell_server"
    registerTest -cluster $true -testname "dump"
    registerTest -cluster $true -testname "dump_authentication"
    registerTest -cluster $true -testname "dump_maskings"
    registerTest -cluster $true -testname "dump_multiple"
    registerTest -cluster $true -testname "http_server"  -sniff true
    registerTest -cluster $true -testname "server_permissions"
    registerTest -cluster $true -testname "resilience_move"
    registerTest -cluster $true -testname "resilience_failover"
    registerTest -cluster $true -testname "resilience_sharddist"
    registerTest -cluster $true -testname "shell_client"
    registerTest -cluster $true -testname "shell_server_aql" -index "0" -bucket "5/0"
    registerTest -cluster $true -testname "shell_server_aql" -index "1" -bucket "5/1"
    registerTest -cluster $true -testname "shell_server_aql" -index "2" -bucket "5/2"
    registerTest -cluster $true -testname "shell_server_aql" -index "3" -bucket "5/3"
    registerTest -cluster $true -testname "shell_server_aql" -index "4" -bucket "5/4"
    registerTest -cluster $true -testname "server_http"
    registerTest -cluster $true -testname "ssl_server"
    # Note that we intentionally do not register the hot_backup test here,
    # since it is currently not supported on Windows. The reason is that
    # the testing framework does not support automatic restarts of instances
    # and hot_backup currently needs a server restart on a restore operation
    # on Windows. On Linux and Mac we use an exec operation for this to
    # restart without changing the PID, which is not possible on Windows.
    # registerTest -cluster $true -testname "hot_backup"
    comm
}

runTests
