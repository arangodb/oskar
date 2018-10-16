$HDD = $(Split-Path -Qualifier $env:WORKSPACE)
If(-Not(Test-Path -PathType Container -Path "$HDD\$env:NODE_NAME"))
{
    New-Item -ItemType Directory -Path "$HDD\$env:NODE_NAME"
}

$OSKARDIR = "$HDD\$env:NODE_NAME"
Set-Location $OSKARDIR

If(-Not(Test-Path -PathType Container -Path "$HDD\procdump"))
{
    New-Item -ItemType Directory -Path "$HDD\procdump"
}

$REGEX = [Regex]::new("pid: \d+")
ForEach($LINE in (&(Get-Command handle64) $OSKARDIR))
{
    $VALUE = $REGEX.Match($LINE).Value
    $ID = $VALUE.Split(' ',[System.StringSplitOptions]::RemoveEmptyEntries) | select -Last 1
    Write-Host "$((Get-Command procdump).Source) -accepteula -ma $ID $HDD\procdump\$ID.dmp"
    Start-Process $(Get-Command procdump) -ArgumentList "-accepteula -ma $ID $HDD\procdump\$ID.dmp"
    Write-Host "Stop-Process -Force -Id $ID" 
    Stop-Process -Force -Id $ID
}

If(-Not($env:OSKAR_BRANCH))
{
    $env:OSKAR_BRANCH = "master"
}
If(-Not(Test-Path -PathType Container -Path "$OSKARDIR\oskar"))
{
    git clone -b $env:OSKAR_BRANCH https://github.com/arangodb/oskar
    Set-Location "$OSKARDIR\oskar"
}
Else
{
    Set-Location "$OSKARDIR\oskar"
    git fetch 
    git reset --hard 
    git checkout $env:OSKAR_BRANCH 
    git reset --hard origin/$env:OSKAR_BRANCH
}
Import-Module "$OSKARDIR\oskar\helper.psm1"
If(-Not($?))
{
    Write-Host "Did not find oskar modul"
    Exit 1
}
lockDirectory
updateOskar
If($(Get-Module).Name -ccontains "oskar")
{
    Remove-Module helper
}
Import-Module "$OSKARDIR\oskar\helper.psm1"
clearResults