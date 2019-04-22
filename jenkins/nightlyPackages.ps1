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

$SRC="$ENV:WORKSPACE"
Write-Host "SRC: $SRC"

New-PSDrive -Name "T" -PSProvider FileSystem -Root "\\nas02.arangodb.biz\buildfiles\"
$DST="T:\stage2\nightly\$PACKAGES"
Write-Host "DST: $DST"

Function movePackagesToStage2
{
    Write-Host "Windows: $SYSTEM_IS_WINDOWS"
    If ($SYSTEM_IS_WINDOWS)
    {
        Write-Host "Recreate $DST\Windows"
        rm -Force -Recurse $DST\Windows -ErrorAction SilentlyContinue
        mkdir -p $DST\Windows
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
    movePackagesToStage2
}
$s = $global:ok
unlockDirectory

If($s)
{
    Exit 0
}
Else
{
    Exit 1
}
