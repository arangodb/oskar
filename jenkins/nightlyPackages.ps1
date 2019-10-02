Write-Host "PWD: $pwd"
Write-Host "WORKSPACE: $env:WORKSPACE"
Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

If (!$env:ARANGODB_PACKAGES -or $env:ARANGODB_PACKAGES -eq "")
{
    Write-Host "ARANGODB_PACKAGES required"
    Exit 1
}

$PACKAGES="$env:ARANGODB_PACKAGES"

Function movePackagesToStage2
{
    $SRC="$ENV:WORKSPACE"
    Write-Host "SRC: $SRC"

    $DST="\\nas02.arangodb.biz\buildfiles\stage2\nightly\$PACKAGES"
    Write-Host "DST: $DST"

    Write-Host "Windows: $SYSTEM_IS_WINDOWS"
    If ($SYSTEM_IS_WINDOWS)
    {
        Write-Host "Recreate $DST\Windows"
        rm -Force -Recurse $DST\Windows -ErrorAction SilentlyContinue;comm
        mkdir -p $DST\Windows;comm
    }

    ForEach ($file in $(Get-ChildItem $SRC\* -Include ArangoDB3*-*.zip, ArangoDB3*-*.exe))
    {
        Move-Item -Force -Path "$file" -Destination $DST\Windows;comm
    }

  return $global:ok
}

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH
If ($global:ok) 
{
    setNightlyRelease
    makeRelease
}
$s = $global:ok
If ($global:ok) 
{
    storeSymbols
    moveResultsToWorkspace
    movePackagesToStage2
    $s = $global:ok
}
unlockDirectory

If($s)
{
    Exit 0
}
Else
{
    Exit 1
}
