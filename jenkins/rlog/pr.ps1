Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

community
rocksdb

skipGrey
skipPackagingOn
setAllLogsToWorkspace

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH

If ($global:ok) 
{
    setPDBsToWorkspaceOnCrashOnly
    setPDBsArchive7z
    clcacheOn
    rlogCompile
    rlogTests
}

$s = $global:ok
moveResultsToWorkspace
unlockDirectory

If($s)
{
    Exit 0
}
Else
{
    Exit 1
} 
