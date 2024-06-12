If (!$env:RELEASE_TAG -or $env:RELEASE_TAG -eq "")
{
    Write-Host "RELEASE_TAG required"
    Exit 1
}

# \\nas01.arangodb.biz\buildfiles
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

$dest = "${NAS_SHARE_LETTER}:/stage1/$env:RELEASE_TAG/release"

If(-Not(Test-Path -PathType Container -Path "$dest/packages/Community/Windows"))
{
  New-Item -ItemType Directory -Path "$dest/packages/Community/Windows"
}

If(-Not(Test-Path -PathType Container -Path "$dest/packages/Enterprise/Windows"))
{
  New-Item -ItemType Directory -Path "$dest/packages/Enterprise/Windows"
}

echo $pwd
dir

$ErrorActionPreference = 'Stop'

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3-*.exe").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Community/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3-*.zip").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Community/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3e-*.exe").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Enterprise/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3e-*.zip").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Enterprise/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "download-windows-*.html").fullName)
{
  Copy-Item "$file" -Destination "$dest/snippets"
}
