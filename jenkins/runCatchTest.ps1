Copy-Item -Force "$env:WORKSPACE\jenkins\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

. $env:EDITION

skipPackagingOn
staticExecutablesOn
catchtest
releaseMode

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH

If ($global:ok) 
{
    setPDBsToWorkspaceOnCrashOnly
    clcacheOn
    oskar1
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
