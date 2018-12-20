Copy-Item -Force "$env:WORKSPACE\jenkins\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

switchBranches $env:RELEASE_TAG $env:RELEASE_TAG
If ($global:ok) 
{
    makeEnterpriseRelease
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
