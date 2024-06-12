Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

switchBranches $env:RELEASE_TAG $env:RELEASE_TAG
If ($global:ok) 
{
    signPackageOn
    clcacheOff
    releaseBuildRepoInfo
    makeCommunityRelease
    storeSymbolsOn
    storeSymbols
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
