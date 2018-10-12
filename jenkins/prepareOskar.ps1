If(-Not($env:OSKAR_BRANCH))
{
    $env:OSKAR_BRANCH = "master"
}
$HDD = $(Split-Path -Qualifier $env:WORKSPACE)
If(-Not(Test-Path -PathType Container -Path "$HDD\$env:NODE_NAME"))
{
    New-Item -ItemType Directory -Path "$HDD\$env:NODE_NAME"
}
$OSKARDIR = "$HDD\$env:NODE_NAME"
Set-Location $OSKARDIR
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