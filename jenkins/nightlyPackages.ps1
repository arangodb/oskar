Write-Host "PWD: $pwd"
Write-Host "WORKSPACE: $env:WORKSPACE"
Copy-Item -Force "$env:WORKSPACE\jenkins\helper\prepareOskar.ps1" $pwd
. "$pwd\prepareOskar.ps1"

if (-Not (Test-Path env:COPY_TO_STAGE2 -ErrorAction SilentlyContinue))
{
    $env:COPY_TO_STAGE2 = $false
}

If (!$env:ARANGODB_PACKAGES -or $env:ARANGODB_PACKAGES -eq "")
{
    Write-Host "ARANGODB_PACKAGES required"
    Exit 1
}

# \\nas01.arangodb.biz\buildfiles
If (!$env:NAS_SHARE_ROOT -or $env:NAS_SHARE_ROOT -eq "" -and $env:COPY_TO_STAGE2 -eq $true)
{
    Write-Host "NAS_SHARE_ROOT required"
    Exit 1
}

If ($env:COPY_TO_STAGE2 -eq $true)
{
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
}

$PACKAGES="$env:ARANGODB_PACKAGES"

Function copyPackagesToStage2
{
    $SRC="$global:INNERWORKDIR"
    Write-Host "SRC: $SRC"

    $DST="${NAS_SHARE_LETTER}:\stage2\nightly\$PACKAGES"
    Write-Host "DST: $DST"

    Write-Host "Windows: $SYSTEM_IS_WINDOWS"
    If ($SYSTEM_IS_WINDOWS)
    {
        Write-Host "Recreate $DST\Windows\x86_64"
        rm -Force -Recurse $DST\Windows\x86_64 -ErrorAction SilentlyContinue;comm
        mkdir -p $DST\Windows\x86_64;comm
    }

    ForEach ($file in $(Get-ChildItem $SRC\* -Filter ArangoDB3* -Include *.zip, *.exe))
    {
        Copy-Item -Force -Path "$file" -Destination $DST\Windows\x86_64;comm
    }

    ForEach ($file in $(Get-ChildItem $SRC -Filter "sourceInfo*" -File))
    {
        Copy-Item -Force -Path "$SRC\$file" -Destination $DST\Windows\x86_64;comm
    }

  return $global:ok
}

If ($env:SIGN_PACKAGE -eq $true)
{
    signPackageOn
}
Else
{
    signPackageOff
}

switchBranches $env:ARANGODB_BRANCH $env:ENTERPRISE_BRANCH
If ($global:ok ) 
{
    clearResults
    setNightlyVersion
    makeRelease
}
$s = $global:ok
If ($global:ok -And $env:COPY_TO_STAGE2 -eq $true) 
{
    copyPackagesToStage2
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
