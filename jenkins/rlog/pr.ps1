Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

community
skipGrey
skipPackagingOn
setAllLogsToWorkspace

switchBranches $env:ARANGODB_BRANCH

If ($global:ok) 
{
    setPDBsToWorkspaceOnCrashOnly
    setPDBsArchive7z
    clcacheOff
    rlogCompile

    If ($global:ok)
    {
        rlogTests
    }
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
