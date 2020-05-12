Write-Host "PWD: $pwd"
Write-Host "WORKSPACE: $env:WORKSPACE"
Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

if (-Not (Test-Path env:MOVE_TO_STAGE2 -ErrorAction SilentlyContinue))
{
    $env:MOVE_TO_STAGE2 = $true
}

If (!$env:ARANGODB_PACKAGES -or $env:ARANGODB_PACKAGES -eq "")
{
    Write-Host "ARANGODB_PACKAGES required"
    Exit 1
}

# \\nas02.arangodb.biz\buildfiles
If (!$env:NAS_SHARE_ROOT -or $env:NAS_SHARE_ROOT -eq "")
{
    Write-Host "NAS_SHARE_ROOT required"
    Exit 1
}

$NAS_SHARE_LETTER="B"

If (Get-PSDrive -Name $NAS_SHARE_LETTER -ErrorAction SilentlyContinue)
{
    If ((Get-PSDrive -Name $NAS_SHARE_LETTER).DisplayRoot -ne "$env:NAS_SHARE_ROOT")
    {
        Write-Host "$env:NAS_SHARE_ROOT could be mounted to ${NAS_SHARE_LETTER}: but it's the letter is already occupied by something other"
        Exit 1
    }
}
Else
{
    If (!$env:NAS_USERNAME -or $env:NAS_USERNAME -eq "" -or !$env:NAS_PASSWORD)
    {
        Write-Host "NAS_USERNAME and NAS_PASSWORD required to mount share to PSDrive with letter ${NAS_SHARE_LETTER}: (since it's not mounted in current system)"
        Exit 1
    }
    New-PSDrive -Name $NAS_SHARE_LETTER -PSProvider FileSystem -Root "$env:NAS_SHARE_ROOT" -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($env:NAS_USERNAME, (ConvertTo-SecureString -String $env:NAS_PASSWORD -AsPlainText -Force)))
}

$PACKAGES="$env:ARANGODB_PACKAGES"

Function movePackagesToStage2
{
    $SRC="$global:INNERWORKDIR"
    Write-Host "SRC: $SRC"

    $DST="${NAS_SHARE_LETTER}:\stage2\nightly\$PACKAGES"
    Write-Host "DST: $DST"

    Write-Host "Windows: $SYSTEM_IS_WINDOWS"
    If ($SYSTEM_IS_WINDOWS)
    {
        Write-Host "Recreate $DST\Windows"
        rm -Force -Recurse $DST\Windows -ErrorAction SilentlyContinue;comm
        mkdir -p $DST\Windows;comm
    }

    ForEach ($file in $(Get-ChildItem $SRC\* -Filter ArangoDB3* -Include *.zip, *.exe))
    {
        Move-Item -Force -Path "$file" -Destination $DST\Windows;comm
    }

  return $global:ok
}

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH
If ($global:ok ) 
{
    setNightlyRelease
    makeRelease
}
$s = $global:ok
If ($global:ok -And $env:MOVE_TO_STAGE2 -eq $true) 
{
    storeSymbols
    movePackagesToStage2
    $s = $global:ok
}
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
