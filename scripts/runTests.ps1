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
    registerTest -testname "replication_ongoing" -index "-32" -filter "replication-ongoing-32.js" -weight 2
    registerTest -testname "replication_ongoing" -index "-frompresent-32" -filter "replication-ongoing-frompresent-32.js" -weight 2
    registerTest -testname "replication_ongoing" -index "-frompresent" -filter "replication-ongoing-frompresent.js" -weight 2
    registerTest -testname "replication_ongoing" -index "-global-spec" -filter "replication-ongoing-global-spec.js" -weight 2
    registerTest -testname "replication_ongoing" -index "-global" -filter "replication-ongoing-global.js" -weight 2
    registerTest -testname "replication_ongoing" -filter "replication-ongoing.js" -weight 2
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
    registerTest -testname "BackupAuthNoSysTests"
    registerTest -testname "BackupAuthSysTests"
    registerTest -testname "BackupNoAuthNoSysTests"
    registerTest -testname "BackupNoAuthSysTests"
    registerTest -testname "agency"
    registerTest -testname "active_failover"
    registerTest -testname "authentication"
    registerTest -testname "catch"
    registerTest -testname "dump"
    registerTest -testname "dump_authentication"
    registerTest -testname "endpoints"
    registerTest -testname "http_replication" -weight 2
    registerTest -testname "http_server"
    registerTest -testname "ssl_server"
    registerTest -testname "version"
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
    registerTest -cluster $true -testname "http_server"
    registerTest -cluster $true -testname "resilience" -index "-move" -filter "moving-shards-cluster.js"
    registerTest -cluster $true -testname "resilience" -index "-failover" -filter "resilience-synchronous-repl-cluster.js"
    registerTest -cluster $true -testname "resilience" -index "-sharddist" -filter "shard-distribution-spec.js"
    registerTest -cluster $true -testname "shell_client"
    registerTest -cluster $true -testname "shell_client_aql"
    registerTest -cluster $true -testname "shell_server_aql" -index "0" -bucket "5/0"
    registerTest -cluster $true -testname "shell_server_aql" -index "1" -bucket "5/1"
    registerTest -cluster $true -testname "shell_server_aql" -index "2" -bucket "5/2"
    registerTest -cluster $true -testname "shell_server_aql" -index "3" -bucket "5/3"
    registerTest -cluster $true -testname "shell_server_aql" -index "4" -bucket "5/4"
    registerTest -cluster $true -testname "server_http"
    registerTest -cluster $true -testname "ssl_server"
    comm
}

runTests