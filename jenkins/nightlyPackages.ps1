Write-Host "PWD: $pwd"
Write-Host "WORKSPACE: $env:WORKSPACE"
Copy-Item -Force "$env:WORKSPACE\jenkins\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

If (!$env:ARANGODB_PACKAGES -or $env:ARANGODB_PACKAGES -eq "")
{
    Write-Host "ARANGODB_PACKAGES required"
    Exit 1
}

$PACKAGES="$env:ARANGODB_PACKAGES"

$SRC="$INNERWORKDIR"
Write-Host "SRC: $SRC"
$DST="B:\stage2\nightly\$PACKAGES"
Write-Host "DST: $DST"

Function movePackagesToStage2
{
    If ($env:SYSTEM_IS_WINDOWS)
    {
        rm -Force -Recurse $DST\Windows
        mkdir -p $DST\Windows
    }

    ForEach ($file in $(Get-ChildItem $SRC\* -Include ArangoDB3*-*.zip, ArangoDB3*-*.exe))
    {
        Move-Item -Force -Path "$SRC\$file" -Destination $DST\Windows;comm
    }

  return $global:ok
}

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH
If ($global:ok) 
{
    setNightlyRelease
    makeRelease
    movePackagesToStage2
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
