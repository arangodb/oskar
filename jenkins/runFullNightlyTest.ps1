Copy-Item -Force "$env:WORKSPACE\jenkins\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

. $env:EDITION
. $env:STORAGE_ENGINE
. $env:TEST_SUITE

skipGrey
skipPackagingOn
parallelism ([int]$env:NUMBER_OF_PROCESSORS)

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH
If ($global:ok) 
{
    setPDBsToWorkspaceOnCrashOnly
    oskar1Full
}
$s = $global:ok
setAllLogsToWorkspace
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
