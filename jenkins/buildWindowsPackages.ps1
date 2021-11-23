Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

. $env:EDITION
. $env:STATICEXECUTABLES
. $env:MAINTAINER
. $env:BUILDMODE

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH
If ($global:ok) 
{
    clearWorkdir
    buildArangoDB
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
